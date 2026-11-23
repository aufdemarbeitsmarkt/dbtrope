with timed_events as (
    select
        piece_id,
        voice_id,
        event_index,
        form_index,
        section_name,
        written_event_index,
        velocity,
        start_beats,
        duration_beats,
        start_seconds,
        duration_seconds
    from {{ ref('int_events__timed') }}
),

pitched_tones as (
    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        chord_tone_index,
        midi_note,
        frequency_hz
    from {{ ref('int_notes__pitched') }}
    where not is_rest
),

voice_instruments as (
    select
        piece_id,
        section_name,
        voice_id,
        instrument_name
    from {{ ref('piece_voices') }}
),

instrument_ranges as (
    select
        piece_id,
        instrument_name,
        lowest_midi_note,
        highest_midi_note
    from {{ ref('int_instruments__ranged') }}
)

select
    timed_events.piece_id,
    timed_events.voice_id,
    timed_events.event_index,
    pitched_tones.chord_tone_index,
    timed_events.form_index,
    timed_events.section_name,
    voice_instruments.instrument_name,
    pitched_tones.midi_note,
    pitched_tones.frequency_hz,
    timed_events.velocity,
    timed_events.start_beats,
    timed_events.duration_beats,
    timed_events.start_seconds,
    timed_events.duration_seconds,
    -- an instrument without a range can play every MIDI note
    (
        pitched_tones.midi_note between coalesce(instrument_ranges.lowest_midi_note, 0)
        and coalesce(instrument_ranges.highest_midi_note, 127)
    ) as is_in_instrument_range
from timed_events
join pitched_tones
    on pitched_tones.piece_id = timed_events.piece_id
    and pitched_tones.section_name = timed_events.section_name
    and pitched_tones.voice_id = timed_events.voice_id
    and pitched_tones.event_index = timed_events.written_event_index
join voice_instruments
    on voice_instruments.piece_id = timed_events.piece_id
    and voice_instruments.section_name = timed_events.section_name
    and voice_instruments.voice_id = timed_events.voice_id
left join instrument_ranges
    on instrument_ranges.piece_id = timed_events.piece_id
    and instrument_ranges.instrument_name = voice_instruments.instrument_name
