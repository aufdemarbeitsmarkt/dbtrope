{%- set sample_rate = var('sample_rate') %}
{#- Normalise each piece to just under full scale (about -1 dBFS). #}
{%- set peak_amplitude = 0.89 %}

with note_samples as (
    select
        piece_id,
        frequency_hz,
        amplitude,
        start_seconds,
        duration_seconds,
        attack_seconds,
        decay_seconds,
        sustain_level,
        release_seconds,
        release_start_level,
        left_gain,
        right_gain,
        unnest(range(first_sample_index, end_sample_index)) as sample_index
    from {{ ref('note_partials') }}
),

note_samples_with_offsets as (
    select
        *,
        ((sample_index / {{ sample_rate }}) - start_seconds) as _seconds_into_note
    from note_samples
),

/*
    ADSR envelope: rise to 1 over the attack, fall to the sustain level over
    the decay, hold until the note's written length ends, then fade from
    wherever it got to down to silence over the release.
*/
enveloped_samples as (
    select
        piece_id,
        sample_index,
        left_gain,
        right_gain,
        (
            sin(2 * pi() * frequency_hz * _seconds_into_note)
            * amplitude
            * case
                when _seconds_into_note >= duration_seconds
                    then (
                        release_start_level
                        * greatest(0, 1 - (_seconds_into_note - duration_seconds) / release_seconds)
                    )
                when _seconds_into_note < attack_seconds
                    then (_seconds_into_note / attack_seconds)
                when _seconds_into_note < (attack_seconds + decay_seconds)
                    then (1 - (1 - sustain_level) * (_seconds_into_note - attack_seconds) / decay_seconds)
                else sustain_level
            end
        ) as _signal
    from note_samples_with_offsets
),

summed_samples as (
    select
        piece_id,
        sample_index,
        sum(_signal * left_gain) as _left_amplitude,
        sum(_signal * right_gain) as _right_amplitude
    from enveloped_samples
    group by
        piece_id,
        sample_index
),

piece_lengths as (
    select
        piece_id,
        (max(sample_index) + 1) as sample_count
    from summed_samples
    group by piece_id
),

-- rests and gaps between notes have no rows in summed_samples; all_samples fills them with silence
all_samples as (
    select
        piece_id,
        unnest(range(sample_count)) as sample_index
    from piece_lengths
),

dense_samples as (
    select
        all_samples.piece_id,
        all_samples.sample_index,
        coalesce(summed_samples._left_amplitude, 0) as _left_amplitude,
        coalesce(summed_samples._right_amplitude, 0) as _right_amplitude
    from all_samples
    left join summed_samples
        on summed_samples.piece_id = all_samples.piece_id
        and summed_samples.sample_index = all_samples.sample_index
),

-- both channels share one gain, so normalising keeps the stereo balance
piece_gains as (
    select
        piece_id,
        ({{ peak_amplitude }} / nullif(max(greatest(abs(_left_amplitude), abs(_right_amplitude))), 0)) as _gain
    from dense_samples
    group by piece_id
)

select
    dense_samples.piece_id,
    dense_samples.sample_index,
    coalesce(dense_samples._left_amplitude * piece_gains._gain, 0) as left_amplitude,
    coalesce(dense_samples._right_amplitude * piece_gains._gain, 0) as right_amplitude
from dense_samples
join piece_gains
    on piece_gains.piece_id = dense_samples.piece_id
