with voice_lists as (
    select
        piece_id,
        from_json(score -> 'voices', '["json"]') as voices
    from {{ ref('pieces') }}
),

unnested_voices as (
    select
        piece_id,
        unnest(voices) as voice,
        generate_subscripts(voices, 1) as voice_index
    from voice_lists
)

select
    piece_id,
    coalesce(voice ->> 'name', 'voice_' || voice_index) as voice_id,
    voice_index,
    voice
from unnested_voices
