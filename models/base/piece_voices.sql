with voice_lists as (
    select
        piece_id,
        section_name,
        from_json(section -> 'voices', '["json"]') as voices
    from {{ ref('piece_sections') }}
),

unnested_voices as (
    select
        piece_id,
        section_name,
        unnest(voices) as written_voice,
        generate_subscripts(voices, 1) as voice_index
    from voice_lists
),

motifs as (
    select
        piece_id,
        motif_name,
        motif
    from {{ ref('piece_motifs') }}
),

/*
    A voice that plays a motif starts from the motif's keys, and any key the
    voice sets as well wins, the way an instrument's use: works. So a voice
    can play a motif with other beats, or in another octave.
*/
voices_with_motifs as (
    select
        unnested_voices.piece_id,
        unnested_voices.section_name,
        unnested_voices.voice_index,
        (unnested_voices.written_voice ->> 'motif') as motif_name,
        (
            (unnested_voices.written_voice ->> 'motif') is null
            or motifs.motif is not null
        ) as is_motif_defined,
        json_merge_patch(coalesce(motifs.motif, '{}'), unnested_voices.written_voice) as voice
    from unnested_voices
    left join motifs
        on motifs.piece_id = unnested_voices.piece_id
        and motifs.motif_name = (unnested_voices.written_voice ->> 'motif')
)

select
    piece_id,
    section_name,
    coalesce(voice ->> 'name', 'voice_' || voice_index) as voice_id,
    voice_index,
    motif_name,
    is_motif_defined,
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
    -- voices without an instrument play the stored sine instrument
    coalesce(voice ->> 'instrument', 'sine') as instrument_name,
    coalesce((voice ->> 'velocity')::integer, 100) as velocity,
    coalesce((voice ->> 'repeat')::integer, 1) as repeat_count,
    coalesce((voice ->> 'retrograde')::boolean, false) as is_retrograde,
    coalesce((voice ->> 'invert')::boolean, false) as is_inverted,
    coalesce((voice ->> 'augment')::double, 1) as augmentation,
    voice
from voices_with_motifs
