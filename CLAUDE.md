# dbtrope

A dbt project that composes music. Pieces are YAML files in `music/pieces/`, turned into a score with SQL, synthesized sample by sample in DuckDB, and written to WAV and MIDI.

## Commands

- `make install`: create `.venv` and install dbt-duckdb
- `make new-piece NAME=…`, `make new-instrument NAME=…`, `make new-effect NAME=…`: create `music/pieces/<name>.yml`, `music/instruments/<name>.yml` or `music/effects/<name>.yml` from `music/templates/`
- `make check`: `dbt parse`, then check layer and naming rules (`scripts/check_layers.py`)
- `make build PIECE=…`: `make check`, then `dbt build --vars '{piece: …}'`, rendering one piece by name or path to a `.yml` file, or every piece in `music/pieces/` with `PIECE=all`. `dbt build` and `dbt run` stop without the piece var (`macros/require_piece.sql`), so nothing renders every piece by accident
- `make build TARGET=ci PIECE=all`: build every piece against an in-memory DuckDB, as CI does
- `make docs`: generate and serve dbt docs for every model, with lineage (no piece needed)
- `make score PIECE=…`: list a built piece's notes by bar and beat (`analyses/score_listing.sql`)
- `make clean`: remove `target/`, rendered WAV and MIDI files in `output/` and local `.duckdb` files

The dev database is `dbtrope.duckdb` in the project root; override with `DBTROPE_DUCKDB_PATH`. Rendered WAV and MIDI files go to `output/` (the `output_dir` var). The sample rate is the `sample_rate` var.

## Rules

- Write SQL following `docs/sql_style.md`. Read it before writing or editing a model.
- Pieces, stored instruments and stored effects are YAML files in `music/pieces/`, `music/instruments/` and `music/effects/`, not models. A file's name is the piece's, instrument's or effect's name. `base/piece_files`, `base/instruments` and `base/effects` (Python) read them; nothing else touches the files.
- Layers are directories under `models/`: `base/`, `intermediate/`, `core/`, `render/`. The table in `docs/sql_style.md` says what each may read. `core/` holds the objects render and analyses read (`sections`, `ensemble`, `score_notes`); `intermediate/` holds only the steps that build them.
- Only `intermediate/` models have a prefix: `int_{topic}__{transformation}`. Never use `stg_`. Other models are named for what they hold.
- Seeds are named `seed_<name>.csv` (`seed_scales.csv`); no model uses the `seed_` prefix.
- Python only reads YAML files into JSON and writes WAV and MIDI bytes. Music logic belongs in SQL.
- Each effect is its own model in `models/intermediate/effects/` (`int_taps__delayed`, `int_taps__reverberated`) reading its rows of `base/piece_instrument_effects`. Each declares the effect's name with `config(meta={'effect_name': …})`; `macros/effect_models.sql` collects them into `base/effect_registry`, the list of effects, which the effect-name tests read, and an enforced contract in `_effects.yml` gives every effect the same columns. A new effect adds a model there and to the list in `core/instrument_effect_taps`; `make check` fails until it does both. Effect names are reserved: no named or stored effect may take one. Instruments list effects under `effects:`, keyed by name; a piece names shared effects under its own `effects:` (`base/piece_effects`), and an instrument's effect points to one, or to a stored effect in `music/effects/`, with `use:`.
- Randomness must be deterministic: derive it from `hash()` of a seed and an index, never `random()`.
- Every directory of dbt resources has one YAML file, named for the directory with a leading underscore, documenting everything in it: `models/base/_base.yml`, `models/core/_core.yml`, `seeds/_seeds.yml`, `macros/_macros.yml`, `analyses/_analyses.yml`, `tests/_tests.yml`, `tests/generic/_generic.yml`. Never a per-resource `.yml`. Every model's `description:` states its grain; every seed, macro, analysis and singular test also gets one. Models go in lineage order, with that directory's unit tests. `make check` enforces this.

## Git

- Name branches for the change, such as `effect-presets` or `sql-comments`, with no prefix like `claude/`.
- Stack a new PR on the most recent open PR's branch, and target that branch.
