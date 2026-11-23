{% docs __overview__ %}
# dbtrope

A dbt project that composes music. Each piece is a model in `pieces/` whose
YAML `meta` holds the music; `dbt build` turns it into a score with SQL,
synthesises it sample by sample in DuckDB and writes `output/<piece>.wav`
and `output/<piece>.mid`.

## Browsing the scores

- **Pieces** are the models tagged `piece`. A piece's page shows its
  description, and its music under **Details → Meta**: tempo, key,
  instruments, motifs, sections and form, exactly as written.
- **Instruments** are the models tagged `instrument`. Open an
  instrument's lineage graph to see every piece that plays it; `dbt build
  -s <instrument>+` re-renders them all.
- **The score** is `int_score__note_events`: one row per sounding note,
  with its section, instrument, pitch, velocity and timing. To read a
  piece by bar and beat, run `make score PIECE=<piece>`.
- **Sections** as the form plays them, with their start times, are in
  `int_sections__timed`.
- **The rendered files** are listed by `render_wav` and `render_midi`, and
  by the `rendered_pieces` exposure.

## Layers

| Layer | Holds |
|---|---|
| `pieces/`, `instruments/` | YAML-defined compositions and stored instruments |
| `base/` | Their YAML flattened into rows |
| `intermediate/` | Improvisation, pitch, timing, form and the score |
| `render/` | Partials, per-instrument samples, effects, the mix, WAV and MIDI |

The lineage graph of any piece runs left to right through these layers,
from its YAML to its audio.
{% enddocs %}
