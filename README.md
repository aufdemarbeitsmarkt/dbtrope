# dbtrope

Compose music with a dbt project. A piece is written in YAML, transformed into a score with SQL, synthesized sample by sample in DuckDB, and written to a WAV file, all by `dbt build`.

> Status: scaffolding. The project structure, tooling and CI are in place; models arrive in the next milestones.

## Quick start

Requires Python 3.10+.

```sh
make install   # create .venv and install dbt-duckdb
make build     # check layer rules, then dbt build
```

Rendered pieces will be written to `output/<piece>.wav`.

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
