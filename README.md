# dbtrope

Compose music with a dbt project. A piece is written in YAML, transformed into a score with SQL, synthesized sample by sample in DuckDB, and written to a WAV file, all by `dbt build`.

> Status: milestone 2, hello sine. A hand-written seed score renders to `output/hello_sine.wav`, proving the path from rows to audio.

## Quick start

Requires Python 3.10+.

```sh
make install   # create .venv and install dbt-duckdb
make build     # check layer rules, then dbt build
```

Each piece is written to `output/<piece>.wav`. The `render_wav` table lists what was written.

## How a note becomes sound

1. `int_score__note_events` holds the score: one row per note, with `frequency_hz`, `start_seconds` and `duration_seconds`.
2. `mixed_samples` expands each note to one row per sample with `unnest(range(…))`, evaluates `sin(2π·f·t)` with short fades at each end, sums every note by `sample_index`, fills gaps with silence and normalises each piece.
3. `render_wav`, a dbt Python model, writes the samples as 16-bit PCM with the standard library's `wave` module.

## Layout

```
seeds/                 music theory reference tables
models/
  pieces/              one .yml + one-line .sql per composition
  instruments/         one .yml + one-line .sql per stored instrument
  base/                piece and instrument YAML flattened into rows
  intermediate/        int_{topic}__{transformation}: theory, form, timing, the score
  render/              partials, mixed samples, effects, WAV output
macros/                compose(), instrument() and helpers
scripts/check_layers.py  enforces which layers may read which, and model naming
docs/sql_style.md      how SQL is written here
```

## Configuration

| Setting | Where | Default |
|---|---|---|
| DuckDB file | `DBTROPE_DUCKDB_PATH` env var | `dbtrope.duckdb` |
| Sample rate | `sample_rate` var | `22050` (use `44100` for final renders) |
| Output folder | `output_dir` var | `output` |

Override vars per run: `dbt build --vars '{sample_rate: 44100}'`.
