with pitched_notes as (
    select
        piece_id,
        voice_id,
        event_index,
        chord_tone_index,
        midi_note,
        frequency_hz,
        velocity,
        start_beats,
        duration_beats,
        start_seconds,
        duration_seconds
    from {{ ref('int_notes__pitched') }}
    where not is_rest
),

voice_instruments as (
    select
        piece_id,
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
    pitched_notes.piece_id,
    pitched_notes.voice_id,
    pitched_notes.event_index,
    pitched_notes.chord_tone_index,
    voice_instruments.instrument_name,
    pitched_notes.midi_note,
    pitched_notes.frequency_hz,
    pitched_notes.velocity,
    pitched_notes.start_beats,
    pitched_notes.duration_beats,
    pitched_notes.start_seconds,
    pitched_notes.duration_seconds,
    -- an instrument without a range can play every MIDI note
    (
        pitched_notes.midi_note between coalesce(instrument_ranges.lowest_midi_note, 0)
        and coalesce(instrument_ranges.highest_midi_note, 127)
    ) as is_in_instrument_range
from pitched_notes
join voice_instruments
    on voice_instruments.piece_id = pitched_notes.piece_id
    and voice_instruments.voice_id = pitched_notes.voice_id
left join instrument_ranges
    on instrument_ranges.piece_id = pitched_notes.piece_id
    and instrument_ranges.instrument_name = voice_instruments.instrument_name
