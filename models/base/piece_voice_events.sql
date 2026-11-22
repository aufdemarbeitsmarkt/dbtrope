with voice_lists as (
    select
        piece_id,
        voice_id,
        from_json(voice -> pitch_kind, '["varchar"]') as pitch_specs,
        coalesce(from_json(voice -> 'beats', '["varchar"]'), ['1']) as duration_specs
    from {{ ref('piece_voices') }}
),

unnested_events as (
    select
        piece_id,
        voice_id,
        duration_specs,
        unnest(pitch_specs) as pitch_spec,
        generate_subscripts(pitch_specs, 1) as event_index
    from voice_lists
)

select
    piece_id,
    voice_id,
    event_index,
    pitch_spec,
    -- a beats list shorter than the notes list repeats from its start
    duration_specs[((event_index - 1) % len(duration_specs)) + 1] as duration_spec
from unnested_events
