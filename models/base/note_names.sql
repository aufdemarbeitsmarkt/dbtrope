with octaves as (
    select unnest(range(-1, 10)) as octave
),

spelled_notes as (
    select
        (pitch_classes.pitch_name || octaves.octave) as note_name,
        (12 * (octaves.octave + 1) + pitch_classes.semitones_from_c) as midi_note
    from {{ ref('seed_pitch_classes') }} as pitch_classes
    cross join octaves
)

select
    note_name,
    midi_note
from spelled_notes
-- Cb-1 and the top octave's upper notes fall outside MIDI's 0 to 127
where midi_note between 0 and 127
