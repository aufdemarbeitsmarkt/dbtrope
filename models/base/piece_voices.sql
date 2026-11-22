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
    case
        when (voice -> 'chords') is not null then 'chords'
        when (voice -> 'degrees') is not null then 'degrees'
        when (voice -> 'notes') is not null then 'notes'
    end as pitch_kind,
    (
        ((voice -> 'chords') is not null)::integer
        + ((voice -> 'degrees') is not null)::integer
        + ((voice -> 'notes') is not null)::integer
    ) as pitch_list_count,
    coalesce((voice ->> 'octave')::integer, 4) as octave,
    coalesce((voice ->> 'transpose')::integer, 0) as transpose_semitones,
    voice
from unnested_voices
