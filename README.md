# dbtrope

Compose music with a dbt project. A piece is written in YAML, transformed into a score with SQL, synthesized sample by sample in DuckDB, and written to a WAV file, all by `dbt build`.

> Status: milestone 3, YAML to score. Pieces are written in YAML with note names, beats and tempo, for any number of voices.

## Quick start

Requires Python 3.10+.

```sh
make install   # create .venv and install dbt-duckdb
make build     # check layer rules, then dbt build
```

Each piece is written to `output/<piece>.wav`. The `render_wav` table lists what was written.

## Writing a piece

A piece is a model in `models/pieces/`: a one-line `.sql` file and a `.yml` file holding the music under `config.meta`.

```sql
-- models/pieces/ditty.sql
{{ compose() }}
```

```yaml
# models/pieces/ditty.yml
models:
  - name: ditty
    description: A short tune in C major for two voices.
    config:
      meta:
        tempo: 112          # quarter-note beats per minute
        meter: 4/4
        voices:
          - name: lead
            notes: [C4, E4, G4, C5, B4, G4, A4, F4, E4, D4, C4, r]
            beats: [e, e, e, e, q, q, dotted_q, e, q, q, h, h]
          - name: bass
            notes: [C3, G2, F2, G2, C3]
            beats: [2, 2, 2, 2, 4]
```

- **notes**: note names in scientific pitch notation (`C4` is middle C), with `#` or `b` for sharps and flats (`F#3`, `Bb4`). `r` is a rest.
- **beats**: one length per note, as a number of beats or a name from `seeds/duration_aliases.csv` (`w`, `h`, `q`, `e`, `s`, `dotted_q`, `triplet_e`, …). A shorter list repeats from its start; leaving it out makes every note one beat.
- Voices play at the same time; each voice's notes follow one another.

After adding, renaming or removing a piece, run `make build` (or `make registry`). dbt applies YAML after parsing SQL, so a model can't find the pieces by itself; `scripts/build_registry.py` reads the YAML and writes `macros/registry.sql`, which gives `base/pieces` a real `ref()` to each piece. The build fails if the registry is stale.

## How a note becomes sound

1. `base/` flattens each piece's JSON into `pieces`, `piece_voices` and `piece_voice_events`. `int_events__timed` turns beats into start times and seconds; `int_notes__pitched` turns note names into MIDI numbers and frequencies.
2. `int_score__note_events` holds the score: one row per note, with `frequency_hz`, `start_seconds` and `duration_seconds`.
3. `mixed_samples` expands each note to one row per sample with `unnest(range(…))`, evaluates `sin(2π·f·t)` with short fades at each end, sums every note by `sample_index`, fills gaps with silence and normalises each piece.
4. `render_wav`, a dbt Python model, writes the samples as 16-bit PCM with the standard library's `wave` module.

## Layout

```
seeds/                 music theory reference tables
models/
  pieces/              one .yml + one-line .sql per composition
  instruments/         one .yml + one-line .sql per stored instrument
  base/                piece and instrument YAML flattened into rows
  intermediate/        int_{topic}__{transformation}: theory, form, timing, the score
  render/              partials, mixed samples, effects, WAV output
macros/                compose(), the generated piece registry and helpers
scripts/check_layers.py  enforces which layers may read which, and model naming
scripts/build_registry.py writes macros/registry.sql from the piece YAML
docs/sql_style.md      how SQL is written here
```

## Configuration

| Setting | Where | Default |
|---|---|---|
| DuckDB file | `DBTROPE_DUCKDB_PATH` env var | `dbtrope.duckdb` |
| Sample rate | `sample_rate` var | `22050` (use `44100` for final renders) |
| Output folder | `output_dir` var | `output` |

Override vars per run: `dbt build --vars '{sample_rate: 44100}'`.
