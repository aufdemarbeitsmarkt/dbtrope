# dbtrope

A dbt project that composes music. Pieces are YAML files in `pieces/`, turned into a score with SQL, synthesized sample by sample in DuckDB, and written to WAV and MIDI.

## Commands

- `make install`: create `.venv` and install dbt-duckdb
- `make new-piece NAME=…`, `make new-instrument NAME=…`: create `pieces/<name>.yml` or `instruments/<name>.yml` from `templates/`
- `make check`: `dbt parse`, then check layer and naming rules (`scripts/check_layers.py`)
- `make build PIECE=…`: `make check`, then `dbt build --vars '{piece: …}'`, rendering one piece by name or path to a `.yml` file, or every piece in `pieces/` with `PIECE=all`. `dbt build` and `dbt run` stop without the piece var (`macros/require_piece.sql`), so nothing renders every piece by accident
- `make build TARGET=ci PIECE=all`: build every piece against an in-memory DuckDB, as CI does
- `make docs`: generate and serve dbt docs for every model, with lineage (no piece needed)
- `make score PIECE=…`: list a built piece's notes by bar and beat (`analyses/score_listing.sql`)
- `make clean`: remove `target/`, rendered WAV and MIDI files in `output/` and local `.duckdb` files

The dev database is `dbtrope.duckdb` in the project root; override with `DBTROPE_DUCKDB_PATH`. Rendered WAV and MIDI files go to `output/` (the `output_dir` var). The sample rate is the `sample_rate` var.

## Rules

- Write SQL following `docs/sql_style.md`. Read it before writing or editing a model.
- Pieces and stored instruments are YAML files in `pieces/` and `instruments/`, not models. A file's name is the piece's or instrument's name. `base/piece_files` and `base/instruments` (Python) read them; nothing else touches the files.
- Layers are directories under `models/`: `base/`, `intermediate/`, `render/`. The table in `docs/sql_style.md` says what each may read.
- Only `intermediate/` models have a prefix: `int_{topic}__{transformation}`. Never use `stg_`. Other models are named for what they hold.
- Python only reads YAML files into JSON and writes WAV and MIDI bytes. Music logic belongs in SQL.
- Randomness must be deterministic: derive it from `hash()` of a seed and an index, never `random()`.
- Every model gets a YAML `description:` stating its grain. Models are documented in their directory's `_<directory>.yml` (`models/base/_base.yml`), in lineage order, with that directory's unit tests; never a per-model `.yml`. `make check` enforces this.
