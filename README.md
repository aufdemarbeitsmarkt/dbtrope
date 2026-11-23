# dbtrope

Compose music with a dbt project. A piece is written in YAML, transformed into a score with SQL, synthesized sample by sample in DuckDB, and written to a WAV file, all by `dbt build`.

> Status: milestone 8, effects. Pieces are written in note names, scale degrees or chords, arranged in sections and a form, with motifs that can be repeated, reversed, inverted and stretched, voices that improvise from a seed, and played on stored or inline instruments with harmonics, ADSR envelopes, velocity, stereo pan, delay and reverb.

## Quick start

Requires Python 3.10+.

```sh
make install   # create .venv and install dbt-duckdb
make build     # check layer rules, then dbt build
```

Each piece is written to `output/<piece>.wav`, and its score to `output/<piece>.mid` for a DAW or notation program. The `render_wav` and `render_midi` tables list what was written.

## Writing a piece

The quickest start is a template:

```sh
make new-piece NAME=my_piece            # models/pieces/my_piece.yml and .sql
make new-instrument NAME=my_instrument  # models/instruments/my_instrument.yml and .sql
make build                              # registers it and writes output/my_piece.wav
```

The new piece uses every feature below, with a comment on each key, and renders as-is. The templates are in `templates/`.

### Examples

| Piece | Shows |
|---|---|
| `ditty` | note names, beats and velocities on two voices |
| `lullaby` | scale degrees, Roman-numeral chords, a stored instrument overridden and an inline one |
| `round_in_f` | a three-voice round built from sections of motifs, with panned delays |
| `variations` | a theme played backwards, upside down, twice as fast and twice as slow |
| `nocturne` | a markov-improvised melody, an inverted and an augmented theme, delay and reverb |

Each is a `.yml` in `models/pieces/`; after `make build`, listen to `output/<piece>.wav`.

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

### Keys, degrees and chords

A voice can be written in scale degrees or chords instead of note names, relative to the piece's `key`:

```yaml
# models/pieces/lullaby.yml (meta)
tempo: 96
meter: 3/4
key: {root: D, scale: dorian}
voices:
  - name: melody
    octave: 4
    degrees: [5, 4, 3, 2, 1, 2, 3, 4, 5, 6, 6, 5, 4, 3, 2, 1]
    beats: [h, q, q, q, q, h, q, dotted_h, h, q, q, q, q, h, q, dotted_h]
  - name: chords
    octave: 3
    chords: [i, i, v, IV, i, IV, v7, i]
    beats: [dotted_h]
```

- **key**: `root` is a pitch name and `scale` a name from `seeds/scales.csv` (`major`, `minor`, the modes, `harmonic_minor`, `major_pentatonic`, `minor_pentatonic`, `whole_tone`, `chromatic`). Defaults to C major.
- **degrees**: `1` is the key's root in the voice's `octave`. Numbers past the scale continue upward (`8` is `1` an octave up in a seven-note scale); `0` and below continue downward. Put `#` or `b` in front to raise or lower by a semitone (`b7`, `#4`).
- **chords**: Roman numerals `i` to `vii`, stacked in thirds within the scale, so the key decides each chord's quality (in D dorian `IV` is G major). Case is for the reader. A trailing `7` adds the seventh. Each chord becomes one row per chord tone.
- **octave**: where degree `1` and chord roots sit. Defaults to 4 (middle C's octave).
- **transpose**: semitones added to every pitch in the voice, for any kind of list.

A voice uses exactly one of `notes`, `degrees` and `chords`.

### Sections, motifs and form

Longer pieces are built from sections. Each section has its own `voices`, and `form` sets the order the sections play in:

```yaml
# meta
motifs:
  hook:
    notes: [C4, D4, E4, G4, E4, D4, C4, r]
    beats: [e, e, e, e, q, q, h, h]
sections:
  verse:
    voices:
      - {name: melody, motif: hook, repeat: 2}
      - {name: chords, octave: 3, chords: [I, vi, IV, V7], beats: [w]}
  bridge:
    voices:
      - {name: melody, motif: hook, retrograde: true, invert: true, augment: 0.5, repeat: 2}
      - {name: chords, octave: 3, chords: [IV, V], beats: [w]}
form: [verse, bridge, verse]
```

- **sections**: named groups of voices. A section lasts as long as its longest voice, and the next one starts when it ends. The build warns if a section doesn't fill whole bars of the `meter`. Voices with the same name in different sections are one voice in the score.
- **form**: the order the sections play in, repeats allowed. Leave it out to play each section once, in the order written.
- **motifs**: named phrases. A voice plays one with `motif: <name>`; the motif can hold any voice keys, and the voice's own keys win, so `{motif: hook, octave: 5}` or `{motif: hook, beats: [q]}` change one thing.
- **repeat**: play the voice's events this many times in a row.
- **retrograde**: play them last to first, each keeping its own length.
- **invert**: mirror every pitch around the voice's first written pitch, within the scale for degrees and chords and by semitones for note names.
- **augment**: multiply every length: `2` doubles them, `0.5` halves them.

Each transform is a key of its own, so the order they are written in doesn't matter. A piece written with top-level `voices` and no `sections`, like `ditty` and `lullaby`, is one section.

### Improvisation

A voice can improvise on its written pitches:

```yaml
# meta
seed: 7
voices:
  - name: walker
    degrees: [1, 2, 3, 1, 3, 5, 3, 2, 1]
    beats: [q, q, h]
    improv: {method: markov, length: 16}
  - name: shuffled
    notes: [C4, E4, G4, B4]
    improv: {method: permutation}
```

- **markov**: starts on the first written pitch, then steps each time to a pitch that followed the current one somewhere in the written line. A pitch that follows more often is chosen more often. If the walk reaches a pitch nothing followed, it starts again from the first pitch. `length` is the number of events; it defaults to the number written.
- **permutation**: plays the written pitches, rests included, in a shuffled order.
- Either way the voice keeps its written rhythm and velocities event by event, repeating them if the walk is longer. Improvisation happens before `repeat`, `retrograde`, `invert` and `augment`, so a repeated voice repeats the same improvisation.
- **seed**: the piece's `seed` (default 0), or `improv: {seed: …}` for one voice. Choices come from DuckDB's `hash()` of the seed, the piece, section and voice names and the step, so a rebuild always gives the same notes, and two voices with the same seed still improvise differently. Change the seed for another take.

### Instruments

An instrument is a set of harmonics and an envelope. Store one in `models/instruments/` to use it from any piece, the same way a piece is stored:

```sql
-- models/instruments/soft_pad.sql
{{ instrument() }}
```

```yaml
# models/instruments/soft_pad.yml
models:
  - name: soft_pad
    description: A warm pad with a slow attack and a long release, for chords.
    config:
      meta:
        partials: [[1, 0.5], [2, 0.25], [3, 0.12]]   # [frequency ratio, amplitude]
        adsr: {a: 0.2, d: 0.1, s: 0.7, r: 0.4}       # seconds, seconds, level, seconds
        range: [C2, C6]                              # optional
        pan: 0                                       # -1 left to 1 right
```

The library has `sine` (the default for voices without an instrument), `pluck`, `glass` (an inharmonic bell with a little reverb), `soft_pad` and `warm_bass`.

A voice names its instrument with `instrument:`. The name is looked up in this order:

1. **Declared in the piece** under `instruments:`. With `use:`, it starts from that stored instrument and replaces only the keys given, down to single `adsr` values. Without `use:`, it is an inline instrument for that piece only.
2. **Stored** in `models/instruments/`, used as-is.
3. **Neither**: `dbt parse` fails, naming the piece and the missing instrument.

```yaml
# models/pieces/lullaby.yml (meta)
instruments:
  soft: {use: soft_pad, pan: -0.3, adsr: {r: 0.8}}   # stored, two settings changed
  bell:                                              # inline, this piece only
    partials: [[1, 0.6], [2.76, 0.3], [5.4, 0.1]]
    adsr: {a: 0.005, d: 0.4, s: 0, r: 0.8}
    pan: 0.3
voices:
  - {name: melody, instrument: bell, …}
  - {name: chords, instrument: soft, velocity: 70, …}
  - {name: bass, instrument: warm_bass, velocity: 85, …}   # stored, not declared
```

- **partials**: each harmonic's frequency as a multiple of the note's, and its level relative to the others. Levels are rescaled to sum to 1, so instruments are equally loud however many partials they have. Partials at or above half the sample rate are dropped.
- **adsr**: attack, decay and release in seconds, sustain as a level from 0 to 1. The release starts when the note's written length ends, so notes ring on for `r` seconds.
- **range**: a note outside it makes the build warn but still plays.
- **velocity** (voice): 0 to 127, default 100. `velocities: [110, 80, 90, 80]` sets it note by note, repeating like `beats`.

#### Effects

An instrument can have a delay and a reverb, stored or set in the piece like any other key:

```yaml
instruments:
  lead: {use: pluck, delay: {seconds: 0.375, feedback: 0.35, repeats: 3}}
  hall: {use: soft_pad, reverb: {seconds: 1.8, mix: 0.3}}
```

- **delay**: `repeats` echoes, `seconds` apart, each `feedback` times the level of the one before. Defaults: 0.25 s, 0.4, 3.
- **reverb**: 24 reflections spread over `seconds` and alternating between the channels, fading by 60 dB by the end; `mix` is their level against the dry sound. Defaults: 1.5 s, 0.25. It's a multi-tap delay rather than a feedback reverb (SQL can't easily feed a sample back into later ones), so it suits pads and sustained sounds better than short percussive ones, where the reflections can be heard separately.
- Writing the key, even as `{}`, turns the effect on with its defaults. A piece's `delay: null` or `reverb: null` turns off a stored instrument's.
- The piece lasts until the last echo or reflection fades.

Each piece's stored instruments are upstream of it in lineage, so `dbt build -s soft_pad+` rebuilds and re-renders after changing `soft_pad`.

After adding, renaming or removing a piece or instrument, run `make build` (or `make registry`). dbt applies YAML after parsing SQL, so a model can't find pieces or instruments by itself; `scripts/build_registry.py` reads the YAML and writes `macros/registry.sql`, which gives `base/pieces` and `base/instruments` a real `ref()` to each one and gives each piece `depends_on` lines for its stored instruments. The build fails if the list of pieces or instruments is stale, and CI checks the committed registry is current.

## How a note becomes sound

1. `base/` flattens each piece's JSON into `pieces`, `piece_motifs`, `piece_sections`, `piece_form`, `piece_voices` and `piece_voice_events`, and resolves its instruments into `piece_instruments` and `piece_instrument_partials`.
2. `int_events__improvised` replaces an improvising voice's pitches with its permutation or markov walk. `int_notes__pitched` turns note names, degrees and chords into MIDI numbers and frequencies, inverting where asked. `int_events__sequenced` applies repeats, retrograde and augmentation and places each event within its section; `int_sections__timed` lays the sections out along the form; `int_events__timed` combines the two into start times in beats and seconds.
3. `int_score__note_events` holds the score: one row per sounding tone, with its instrument, `frequency_hz`, `velocity`, `start_seconds` and `duration_seconds`.
4. `note_partials` joins each tone to its instrument's harmonics, envelope and pan.
5. `instrument_samples` expands each partial to one row per sample with `unnest(range(…))`, evaluates `sin(2π·f·t)` under its ADSR envelope, pans it with equal-power gains and sums it by instrument and `sample_index`.
6. `mixed_samples` adds each instrument's delayed copies from `int_instruments__effect_taps` (the dry sound, delay echoes and reverb reflections) by shifting `sample_index`, sums everything, fills gaps with silence and normalises each piece.
7. `render_wav`, a dbt Python model, writes the samples as 16-bit stereo PCM with the standard library's `wave` module.

`render_midi`, another Python model, writes `int_score__note_events` as a Standard MIDI File without third-party libraries: a tempo and time-signature track, then one named track and channel per voice (channel 10 is skipped, since General MIDI keeps it for drums). MIDI holds pitches, velocities and written lengths, so instruments, releases and effects are left to whatever plays it.

## Layout

```
seeds/                 music theory reference tables
models/
  pieces/              one .yml + one-line .sql per composition
  instruments/         one .yml + one-line .sql per stored instrument
  base/                piece and instrument YAML flattened into rows
  intermediate/        int_{topic}__{transformation}: theory, form, timing, the score
  render/              partials, mixed samples, effects, WAV and MIDI output
macros/                compose(), instrument(), the generated registry and helpers
scripts/check_layers.py  enforces which layers may read which, and model naming
scripts/build_registry.py writes macros/registry.sql from the piece and instrument YAML
scripts/new_model.py   creates a piece or instrument from its template
templates/             commented starting points for a piece and an instrument
docs/sql_style.md      how SQL is written here
```

## Configuration

| Setting | Where | Default |
|---|---|---|
| DuckDB file | `DBTROPE_DUCKDB_PATH` env var | `dbtrope.duckdb` |
| Sample rate | `sample_rate` var | `22050` (use `44100` for final renders) |
| Output folder | `output_dir` var | `output` |

Override vars per run: `dbt build --vars '{sample_rate: 44100}'`.
