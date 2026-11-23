-- Fails for each piece whose MIDI file is missing or holds a different number of notes from its score.
with scored_notes as (
    select
        piece_id,
        count(*) as note_count
    from {{ ref('int_score__note_events') }}
    where velocity > 0
    group by piece_id
)

select
    scored_notes.piece_id,
    scored_notes.note_count,
    render_midi.note_count as written_note_count
from scored_notes
left join {{ ref('render_midi') }} as render_midi
    on render_midi.piece_id = scored_notes.piece_id
where render_midi.piece_id is null
    or render_midi.note_count != scored_notes.note_count
