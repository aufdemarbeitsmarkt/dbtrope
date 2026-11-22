with timed_events as (
    select
        piece_id,
        voice_id,
        event_index,
        pitch_spec,
        start_beats,
        duration_beats,
        start_seconds,
        duration_seconds
    from {{ ref('int_events__timed') }}
),

note_names as (
    select
        note_name,
        midi_note
    from {{ ref('int_theory__note_names') }}
),

pitched_events as (
    select
        timed_events.piece_id,
        timed_events.voice_id,
        timed_events.event_index,
        timed_events.pitch_spec,
        (lower(timed_events.pitch_spec) = 'r') as is_rest,
        note_names.midi_note,
        timed_events.start_beats,
        timed_events.duration_beats,
        timed_events.start_seconds,
        timed_events.duration_seconds
    from timed_events
    left join note_names
        on note_names.note_name = timed_events.pitch_spec
)

select
    piece_id,
    voice_id,
    event_index,
    pitch_spec,
    is_rest,
    midi_note,
    (440 * pow(2, (midi_note - 69) / 12.0)) as frequency_hz,
    start_beats,
    duration_beats,
    start_seconds,
    duration_seconds
from pitched_events
