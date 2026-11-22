import array
import wave
from pathlib import Path

# 16-bit PCM: an amplitude of 1.0 maps to the largest positive sample value.
SAMPLE_WIDTH_BYTES = 2
FULL_SCALE = 32767


def model(dbt, session):
    dbt.config(materialized="table")
    sample_rate = int(dbt.config.get("sample_rate"))
    output_dir = Path(dbt.config.get("output_dir"))
    output_dir.mkdir(parents=True, exist_ok=True)

    pieces = dbt.ref("mixed_samples").query(
        "mixed_samples",
        f"""
        select
            piece_id,
            list(round(amplitude * {FULL_SCALE})::smallint order by sample_index) as pcm
        from mixed_samples
        group by piece_id
        order by piece_id
        """,
    ).fetchall()

    rendered = []
    for piece_id, pcm in pieces:
        wav_path = output_dir / f"{piece_id}.wav"
        with wave.open(str(wav_path), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(SAMPLE_WIDTH_BYTES)
            wav.setframerate(sample_rate)
            wav.writeframes(array.array("h", pcm).tobytes())
        rendered.append((piece_id, str(wav_path), 1, len(pcm)))

    # One row per WAV file written.
    session.execute(
        """
        create or replace temp table _rendered_wavs (
            piece_id varchar,
            wav_path varchar,
            channel_count integer,
            sample_count bigint
        )
        """
    )
    if rendered:
        session.executemany("insert into _rendered_wavs values (?, ?, ?, ?)", rendered)

    return session.sql(
        f"""
        select
            piece_id,
            wav_path,
            channel_count,
            {sample_rate}::integer as sample_rate,
            sample_count,
            (sample_count / {sample_rate}) as duration_seconds
        from _rendered_wavs
        """
    )
