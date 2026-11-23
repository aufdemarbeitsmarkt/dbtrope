{%- set sample_rate = var('sample_rate') %}

with note_samples as (
    select
        piece_id,
        instrument_name,
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
        instrument_name,
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

select
    piece_id,
    instrument_name,
    sample_index,
    sum(_signal * left_gain) as left_amplitude,
    sum(_signal * right_gain) as right_amplitude
from enveloped_samples
group by
    piece_id,
    instrument_name,
    sample_index
