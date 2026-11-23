with scored_notes as (
    select
        piece_id,
        count(*) as note_count
    from {{ ref('score_notes') }}
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
