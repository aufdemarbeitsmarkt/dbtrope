import struct
from pathlib import Path

# Standard MIDI File, type 1: a tempo track, then one track per voice.
TICKS_PER_BEAT = 480
# MIDI channel 10 (index 9) is for drums in General MIDI, so voices skip it.
DRUM_CHANNEL = 9
NOTE_ON = 0x90
NOTE_OFF = 0x80


def variable_length(value):
    """MIDI's variable-length quantity: 7 bits per byte, high bit set on all but the last."""
    encoded = [value & 0x7F]
    value >>= 7
    while value:
        encoded.insert(0, (value & 0x7F) | 0x80)
        value >>= 7
    return bytes(encoded)


def meta_event(kind, data):
    return bytes([0xFF, kind]) + variable_length(len(data)) + data


def track_chunk(events):
    """events are (tick, sort_key, message bytes); a note-off sorts before a
    note-on at the same tick so repeated notes restart cleanly."""
    body = b""
    previous_tick = 0
    for tick, _, message in sorted(events, key=lambda event: (event[0], event[1])):
        body += variable_length(tick - previous_tick) + message
        previous_tick = tick
    body += variable_length(0) + meta_event(0x2F, b"")
    return b"MTrk" + struct.pack(">I", len(body)) + body


def ticks(beats):
    return round(beats * TICKS_PER_BEAT)


def tempo_track(piece_id, sections):
    events = [(0, 0, meta_event(0x03, piece_id.encode()))]
    current = None
    for start_beats, tempo_bpm, meter in sections:
        if (tempo_bpm, meter) == current:
            continue
        current = (tempo_bpm, meter)
        numerator, denominator = (int(part) for part in meter.split("/"))
        microseconds_per_beat = round(60_000_000 / tempo_bpm)
        # the denominator is written as a power of two; 24 clocks per click, 8 thirty-seconds per beat
        time_signature = bytes([numerator, denominator.bit_length() - 1, 24, 8])
        events.append((ticks(start_beats), 1, meta_event(0x58, time_signature)))
        events.append((ticks(start_beats), 2, meta_event(0x51, microseconds_per_beat.to_bytes(3, "big"))))
    return track_chunk(events)


def voice_track(voice_id, channel, notes):
    events = [(0, 0, meta_event(0x03, voice_id.encode()))]
    for start_beats, duration_beats, midi_note, velocity in notes:
        events.append((ticks(start_beats), 2, bytes([NOTE_ON | channel, midi_note, velocity])))
        events.append((ticks(start_beats + duration_beats), 1, bytes([NOTE_OFF | channel, midi_note, 0])))
    return track_chunk(events)


def model(dbt, session):
    dbt.config(materialized="table")
    output_dir = Path(dbt.config.get("output_dir"))
    output_dir.mkdir(parents=True, exist_ok=True)

    sections = dbt.ref("sections").query(
        "sections",
        """
        select
            piece_id,
            start_beats,
            tempo_bpm,
            meter
        from sections
        order by
            piece_id,
            form_index
        """,
    ).fetchall()

    # A note-on with velocity 0 means note-off in MIDI, so silent notes are left out.
    voices = dbt.ref("score_notes").query(
        "note_events",
        """
        select
            piece_id,
            voice_id,
            list(
                [start_beats, duration_beats, midi_note, velocity]
                order by start_beats, chord_tone_index
            ) as notes
        from note_events
        where velocity > 0
        group by
            piece_id,
            voice_id
        order by
            piece_id,
            min(start_beats),
            voice_id
        """,
    ).fetchall()

    sections_by_piece = {}
    for piece_id, start_beats, tempo_bpm, meter in sections:
        sections_by_piece.setdefault(piece_id, []).append((float(start_beats), float(tempo_bpm), meter))

    voices_by_piece = {}
    for piece_id, voice_id, notes in voices:
        voices_by_piece.setdefault(piece_id, []).append((voice_id, notes))

    written = []
    for piece_id, piece_sections in sorted(sections_by_piece.items()):
        tracks = [tempo_track(piece_id, piece_sections)]
        note_count = 0
        for voice_number, (voice_id, notes) in enumerate(voices_by_piece.get(piece_id, [])):
            channel = voice_number % 15
            channel = channel + 1 if channel >= DRUM_CHANNEL else channel
            notes = [(float(start), float(duration), int(note), int(velocity)) for start, duration, note, velocity in notes]
            tracks.append(voice_track(voice_id, channel, notes))
            note_count += len(notes)

        header = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), TICKS_PER_BEAT)
        midi_path = output_dir / f"{piece_id}.mid"
        midi_path.write_bytes(header + b"".join(tracks))
        written.append((piece_id, str(midi_path), len(tracks), note_count))

    # One row per MIDI file written.
    session.execute(
        """
        create or replace temp table _rendered_midis (
            piece_id varchar,
            midi_path varchar,
            track_count integer,
            note_count bigint
        )
        """
    )
    if written:
        session.executemany("insert into _rendered_midis values (?, ?, ?, ?)", written)

    return session.sql("select piece_id, midi_path, track_count, note_count from _rendered_midis")
