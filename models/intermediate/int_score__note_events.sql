select
    piece_id,
    voice_id,
    event_index,
    midi_note,
    (440 * pow(2, (midi_note - 69) / 12.0)) as frequency_hz,
    start_seconds,
    duration_seconds
from {{ ref('hello_sine_notes') }}
