with voice_events as (
    select
        piece_events.piece_id,
        piece_events.section_name,
        piece_events.voice_id,
        piece_events.event_index,
        piece_events.velocity,
        coalesce(
            duration_aliases.duration_beats,
            try_cast(piece_events.duration_spec as double)
        ) as _written_duration_beats
    from {{ ref('piece_voice_events') }} as piece_events
    left join {{ ref('duration_aliases') }} as duration_aliases
        on duration_aliases.duration_name = piece_events.duration_spec
),

voice_settings as (
    select
        piece_id,
        section_name,
        voice_id,
        repeat_count,
        is_retrograde,
        augmentation
    from {{ ref('piece_voices') }}
),

repeated_events as (
    select
        voice_events.piece_id,
        voice_events.section_name,
        voice_events.voice_id,
        unnest(range(1, voice_settings.repeat_count + 1)) as repetition_index,
        voice_events.event_index,
        voice_events.velocity,
        (voice_events._written_duration_beats * voice_settings.augmentation) as duration_beats,
        -- a retrograde voice plays its events last to first, each keeping its own length
        case
            when voice_settings.is_retrograde then -voice_events.event_index
            else voice_events.event_index
        end as _play_order
    from voice_events
    join voice_settings
        on voice_settings.piece_id = voice_events.piece_id
        and voice_settings.section_name = voice_events.section_name
        and voice_settings.voice_id = voice_events.voice_id
)

select
    piece_id,
    section_name,
    voice_id,
    repetition_index,
    event_index,
    velocity,
    -- an event starts when the voice's earlier events in the section have all ended
    coalesce(
        sum(duration_beats) over (
            partition by piece_id, section_name, voice_id
            order by repetition_index, _play_order
            rows between unbounded preceding and 1 preceding
        ),
        0
    ) as start_beats,
    duration_beats
from repeated_events
