{%- set sample_rate = var('sample_rate') %}
{#
    Each note fades in over attack_seconds and out over release_seconds, so the
    waveform never starts or stops mid-cycle, which would click. Instruments
    replace these fixed fades with their own envelopes.
#}
{%- set attack_seconds = 0.01 %}
{%- set release_seconds = 0.05 %}
{#- Normalise each piece to just under full scale (about -1 dBFS). #}
{%- set peak_amplitude = 0.89 %}

with note_events as (
    select
        piece_id,
        voice_id,
        event_index,
        frequency_hz,
        start_seconds,
        duration_seconds
    from {{ ref('int_score__note_events') }}
),

note_samples as (
    select
        piece_id,
        frequency_hz,
        duration_seconds,
        start_seconds,
        unnest(range(
            round(start_seconds * {{ sample_rate }})::bigint,
            round((start_seconds + duration_seconds) * {{ sample_rate }})::bigint
        )) as sample_index
    from note_events
),

note_samples_with_offsets as (
    select
        piece_id,
        frequency_hz,
        duration_seconds,
        sample_index,
        ((sample_index / {{ sample_rate }}) - start_seconds) as _seconds_into_note
    from note_samples
),

summed_samples as (
    select
        piece_id,
        sample_index,
        sum(
            sin(2 * pi() * frequency_hz * _seconds_into_note)
            * least(
                1,
                (_seconds_into_note / {{ attack_seconds }}),
                ((duration_seconds - _seconds_into_note) / {{ release_seconds }})
            )
        ) as _amplitude
    from note_samples_with_offsets
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
        coalesce(summed_samples._amplitude, 0) as _amplitude
    from all_samples
    left join summed_samples
        on summed_samples.piece_id = all_samples.piece_id
        and summed_samples.sample_index = all_samples.sample_index
)

select
    piece_id,
    sample_index,
    coalesce(
        (
            _amplitude
            * {{ peak_amplitude }}
            / nullif(max(abs(_amplitude)) over (partition by piece_id), 0)
        ),
        0
    ) as amplitude
from dense_samples
