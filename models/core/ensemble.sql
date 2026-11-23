with piece_instruments as (
    select
        piece_id,
        instrument_name,
        attack_seconds,
        decay_seconds,
        sustain_level,
        release_seconds,
        pan,
        lowest_note_name,
        highest_note_name
    from {{ ref('piece_instruments') }}
),

note_names as (
    select
        note_name,
        midi_note
    from {{ ref('note_names') }}
)

select
    piece_instruments.piece_id,
    piece_instruments.instrument_name,
    piece_instruments.attack_seconds,
    piece_instruments.decay_seconds,
    piece_instruments.sustain_level,
    piece_instruments.release_seconds,
    piece_instruments.pan,
    piece_instruments.lowest_note_name,
    piece_instruments.highest_note_name,
    lowest_notes.midi_note as lowest_midi_note,
    highest_notes.midi_note as highest_midi_note
from piece_instruments
left join note_names as lowest_notes
    on lowest_notes.note_name = piece_instruments.lowest_note_name
left join note_names as highest_notes
    on highest_notes.note_name = piece_instruments.highest_note_name
