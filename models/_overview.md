{% docs __overview__ %}
# dbtrope

A dbt project that composes music. Each piece is a YAML file in `pieces/`;
`dbt build` reads it, turns it into a score with SQL,
synthesises it sample by sample in DuckDB and writes `output/<piece>.wav`
and `output/<piece>.mid`.

## Browsing the scores

- **Pieces** are rows of `pieces`: one per file the build read, with its
  description, tempo, key and the whole file as JSON in `score`.
  `piece_files` shows which files were read; the build renders what the
  piece var names (`--vars '{piece: nocturne}'`, or `all`).
- **Instruments** are rows of `instruments`, one per file in
  `instruments/`. `piece_instruments` shows which instruments each piece
  uses and how each was resolved.
- **The score** is `score_notes`: one row per sounding note,
  with its section, instrument, pitch, velocity and timing. To read a
  piece by bar and beat, run `make score PIECE=<piece>`.
- **Sections** as the form plays them, with their start times, are in
  `sections`.
- **The rendered files** are listed by `render_wav` and `render_midi`, and
  by the `rendered_pieces` exposure.

## Layers

| Layer | Holds |
|---|---|
| `base/` | Theory tables from seeds; piece and instrument files read and flattened into rows |
| `intermediate/` | The steps that build the score (improvisation, pitch and sequencing) and one model per effect's taps |
| `core/` | What render and analyses read: sections, the ensemble and the score |
| `render/` | Partials, per-instrument samples, effects, the mix, WAV and MIDI |

The lineage graph runs left to right through these layers, from
`piece_files` and `instruments` to `render_wav` and `render_midi`.
{% enddocs %}
