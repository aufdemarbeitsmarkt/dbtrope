{%- set voice_event_order %}
    partition by
        voice_events.piece_id,
        voice_events.voice_id
    order by voice_events.event_index
{%- endset %}

with voice_events as (
    select
        piece_events.piece_id,
        piece_events.voice_id,
        piece_events.event_index,
        piece_events.pitch_spec,
        piece_events.velocity,
        coalesce(
            duration_aliases.duration_beats,
            try_cast(piece_events.duration_spec as double)
        ) as duration_beats
    from {{ ref('piece_voice_events') }} as piece_events
    left join {{ ref('duration_aliases') }} as duration_aliases
        on duration_aliases.duration_name = piece_events.duration_spec
),

piece_tempos as (
    select
        piece_id,
        tempo_bpm
    from {{ ref('pieces') }}
),

events_with_start_beats as (
    select
        voice_events.piece_id,
        voice_events.voice_id,
        voice_events.event_index,
        voice_events.pitch_spec,
        voice_events.velocity,
        voice_events.duration_beats,
        (
            sum(voice_events.duration_beats) over (
                {{ voice_event_order }}
            )
            - voice_events.duration_beats
        ) as start_beats
    from voice_events
)

select
    events_with_start_beats.piece_id,
    events_with_start_beats.voice_id,
    events_with_start_beats.event_index,
    events_with_start_beats.pitch_spec,
    events_with_start_beats.velocity,
    events_with_start_beats.start_beats,
    events_with_start_beats.duration_beats,
    (events_with_start_beats.start_beats * 60 / piece_tempos.tempo_bpm) as start_seconds,
    (events_with_start_beats.duration_beats * 60 / piece_tempos.tempo_bpm) as duration_seconds
from events_with_start_beats
join piece_tempos
    on piece_tempos.piece_id = events_with_start_beats.piece_id
