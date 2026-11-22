with octaves as (
    select unnest(range(-1, 10)) as octave
)

select
    (pitch_classes.pitch_name || octaves.octave) as note_name,
    (12 * (octaves.octave + 1) + pitch_classes.semitones_from_c) as midi_note
from {{ ref('pitch_classes') }} as pitch_classes
cross join octaves
where (12 * (octaves.octave + 1) + pitch_classes.semitones_from_c) between 0 and 127
