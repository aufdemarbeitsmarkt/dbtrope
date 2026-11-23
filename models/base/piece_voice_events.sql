with voice_lists as (
    select
        piece_id,
        section_name,
        voice_id,
        velocity,
        from_json(voice -> pitch_kind, '["varchar"]') as pitch_specs,
        -- an empty beats or velocities list counts as leaving it out, and can't be repeated below
        coalesce(nullif(from_json(voice -> 'beats', '["varchar"]'), []), ['1']) as duration_specs,
        nullif(from_json(voice -> 'velocities', '["integer"]'), []) as velocities
    from {{ ref('piece_voices') }}
),

unnested_events as (
    select
        piece_id,
        section_name,
        voice_id,
        velocity,
        duration_specs,
        velocities,
        unnest(pitch_specs) as pitch_spec,
        generate_subscripts(pitch_specs, 1) as event_index
    from voice_lists
)

select
    piece_id,
    section_name,
    voice_id,
    event_index,
    pitch_spec,
    -- beats and velocities lists shorter than the pitch list repeat from their start
    duration_specs[((event_index - 1) % len(duration_specs)) + 1] as duration_spec,
    coalesce(
        velocities[((event_index - 1) % len(velocities)) + 1],
        velocity
    ) as velocity
from unnested_events
