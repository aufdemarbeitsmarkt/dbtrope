with sequenced_events as (
    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        velocity,
        start_beats,
        duration_beats
    from {{ ref('int_events__sequenced') }}
),

sections as (
    select
        piece_id,
        form_index,
        section_name,
        start_beats,
        tempo_bpm
    from {{ ref('sections') }}
),

-- a section the form plays more than once has its events placed each time
events_in_form as (
    select
        sequenced_events.piece_id,
        sequenced_events.voice_id,
        sections.form_index,
        sequenced_events.section_name,
        sequenced_events.event_index as written_event_index,
        sequenced_events.velocity,
        (sections.start_beats + sequenced_events.start_beats) as start_beats,
        sequenced_events.duration_beats,
        sections.tempo_bpm
    from sequenced_events
    join sections
        on sections.piece_id = sequenced_events.piece_id
        and sections.section_name = sequenced_events.section_name
),

-- numbered before rests are dropped, so a voice's event_index counts its rests
timed_events as (
    select
        piece_id,
        voice_id,
        -- a voice's events never overlap, so their start times order them
        row_number() over (
            partition by piece_id, voice_id
            order by start_beats
        ) as event_index,
        form_index,
        section_name,
        written_event_index,
        velocity,
        start_beats,
        duration_beats,
        (start_beats * 60 / tempo_bpm) as start_seconds,
        (duration_beats * 60 / tempo_bpm) as duration_seconds
    from events_in_form
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
    from {{ ref('ensemble') }}
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
