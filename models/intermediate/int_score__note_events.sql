select
    piece_id,
    voice_id,
    event_index,
    midi_note,
    frequency_hz,
    start_beats,
    duration_beats,
    start_seconds,
    duration_seconds
from {{ ref('int_notes__pitched') }}
where not is_rest
