# dbtrope

Compose music with a dbt project. A piece is a YAML file, transformed into a score with SQL, synthesized sample by sample in DuckDB, and written to WAV and MIDI files, all by `dbt build`.

> Status: all nine milestones of the build plan are done. Pieces are written in note names, scale degrees or chords, arranged in sections and a form, with motifs that can be repeated, reversed, inverted and stretched, voices that improvise from a seed, and played on stored or inline instruments with harmonics, ADSR envelopes, velocity, stereo pan, delay and reverb.

## Quick start

Requires Python 3.10+.

```sh
make install   # create .venv and install dbt-duckdb
make build PIECE=nocturne            # check layer rules, then build and render one piece
make build PIECE=~/sketches/idea.yml # a piece file from anywhere
make build PIECE=all                 # every piece in pieces/
```

`make build PIECE=…` runs `dbt build --vars '{piece: …}'`; the var takes a piece name, a path to a `.yml` file, or `all`. It's required: `dbt build` and `dbt run` stop straight away without it, so a project with a hundred pieces never renders them all by accident. Each piece is written to `output/<piece>.wav`, and its score to `output/<piece>.mid` for a DAW or notation program. The `render_wav` and `render_midi` tables list what was written.

## Tutorial: your first piece

This walks from an empty piece to one that uses most of dbtrope, building after each step. Every key it uses is described under [Writing a piece](#writing-a-piece).

**1. A melody.** A piece is one YAML file in `pieces/`, and its file name is its name. Create `pieces/first_tune.yml`:

```yaml
description: My first piece.
tempo: 100
voices:
  - name: melody
    notes: [E4, D4, C4, D4, E4, E4, E4, r]
    beats: [q, q, q, q, q, q, h, w]
```

Run `make build PIECE=first_tune`, then play `output/first_tune.wav`. `make score PIECE=first_tune` lists what you wrote by bar and beat.

**2. A key and a bass line.** Write in scale degrees and chords so the key does the work. Add a `key` and two voices under `voices`:

```yaml
key: {root: G, scale: major}
voices:
  - name: melody
    degrees: [3, 2, 1, 2, 3, 3, 3, r]
    beats: [q, q, q, q, q, q, h, w]
  - name: chords
    octave: 3
    chords: [I, V, I, I]
    beats: [w]
    velocity: 60
```

Change `root` to `Eb` or `scale` to `dorian` and build again: the same numbers make a different tune. Each step builds the same way, with `make build PIECE=first_tune`.

**3. Instruments.** Give each voice a sound: `instrument: pluck` on the melody and `instrument: soft_pad` on the chords. Then give the pad some space by declaring a variant of it in the piece:

```yaml
instruments:
  pad: {use: soft_pad, reverb: {seconds: 2, mix: 0.3}, pan: -0.3}
```

and use `instrument: pad` instead.

**4. Sections and a form.** Move the voices under a section, add a second section that plays the melody backwards over different chords, and choose the order. The melody becomes a motif so both sections can share it:

```yaml
motifs:
  tune: {degrees: [3, 2, 1, 2, 3, 3, 3, r], beats: [q, q, q, q, q, q, h, w]}
sections:
  a:
    voices:
      - {name: melody, instrument: pluck, motif: tune}
      - {name: chords, instrument: pad, octave: 3, chords: [I, V, I, I], beats: [w], velocity: 60}
  b:
    voices:
      - {name: melody, instrument: pluck, motif: tune, retrograde: true, invert: true}
      - {name: chords, instrument: pad, octave: 3, chords: [IV, I, V, V], beats: [w], velocity: 60}
form: [a, b, a]
```

A piece has either `voices` or `sections`, so delete the old `voices` list.

**5. Improvise.** Add a third section whose melody wanders through the motif's notes, and put it in the form:

```yaml
  c:
    voices:
      - {name: melody, instrument: glass, motif: tune, improv: {method: markov, length: 8}}
      - {name: chords, instrument: pad, octave: 3, chords: [vi, IV, V, I], beats: [w], velocity: 60}
form: [a, b, c, a]
seed: 1
```

Each build gives the same notes. Change `seed` for another take.

**6. Look around.** `make docs` opens dbt docs in your browser, with every model from `piece_files` to `render_wav` and its lineage; `pieces` and `piece_instruments` show your piece as the build read it. Open `output/first_tune.mid` in a DAW to hear it on other instruments.

## Writing a piece

The quickest start is a template:

```sh
make new-piece NAME=my_piece            # pieces/my_piece.yml
make new-instrument NAME=my_instrument  # instruments/my_instrument.yml
make build PIECE=my_piece               # writes output/my_piece.wav and .mid
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

Each is a `.yml` in `pieces/`; after `make build PIECE=<piece>` (or `PIECE=all`), listen to `output/<piece>.wav`.

A piece is a YAML file in `pieces/`. The file's name is the piece's name, so `pieces/ditty.yml` renders to `output/ditty.wav`.

```yaml
# pieces/ditty.yml
description: A short tune in C major for two voices.
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
# pieces/lullaby.yml (excerpt)
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
# excerpt
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
# excerpt
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

An instrument is a set of harmonics and an envelope. Store one as a YAML file in `instruments/` to use it from any piece; the file's name is the instrument's name:

```yaml
# instruments/soft_pad.yml
description: A warm pad with a slow attack and a long release, for chords.
partials: [[1, 0.5], [2, 0.25], [3, 0.12]]   # [frequency ratio, amplitude]
adsr: {a: 0.2, d: 0.1, s: 0.7, r: 0.4}       # seconds, seconds, level, seconds
range: [C2, C6]                              # optional
pan: 0                                       # -1 left to 1 right
```

The library has `sine` (the default for voices without an instrument), `pluck`, `glass` (an inharmonic bell with a little reverb), `soft_pad` and `warm_bass`.

A voice names its instrument with `instrument:`. The name is looked up in this order:

1. **Declared in the piece** under `instruments:`. With `use:`, it starts from that stored instrument and replaces only the keys given, down to single `adsr` values. Without `use:`, it is an inline instrument for that piece only.
2. **Stored** in `instruments/`, used as-is.
3. **Neither**: the build fails a test on `piece_instruments` whose failing row names the piece and the missing instrument.

```yaml
# pieces/lullaby.yml (excerpt)
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

Every build reads the whole instrument library, so after changing an instrument, rebuild the pieces that use it. `piece_instruments` shows which pieces use which instruments.

### How files get into the build

Pieces and instruments are plain YAML files, not dbt models: there's nothing to register after adding, renaming or removing one. Two Python models in `base/` read them with PyYAML (which dbt already installs): `piece_files` reads the piece the `piece` var names, or every `.yml` in the `pieces_dir` var for `piece: all`, and `instruments` reads every `.yml` in the `instruments_dir` var. Everything after that is SQL. dbt doesn't watch the files, so state-based selection such as `state:modified` won't notice an edited piece; build it by name instead.

## How a note becomes sound

1. `base/piece_files` and `base/instruments` read the piece and instrument files into JSON. The rest of `base/` flattens each piece into `pieces`, `piece_motifs`, `piece_sections`, `piece_form`, `piece_voices` and `piece_voice_events`, and resolves its instruments into `piece_instruments` and `piece_instrument_partials`.
2. In `intermediate/`, `int_events__improvised` replaces an improvising voice's pitches with its permutation or markov walk. `int_notes__pitched` turns note names, degrees and chords into MIDI numbers and frequencies, using `base/note_names` and `base/scale_semitones` and inverting where asked. `int_events__sequenced` applies repeats, retrograde and augmentation and places each event within its section.
3. `core/` holds what the rest of the project reads. `sections` lays the sections out along the form. `score_notes` places each event in its section and holds the score: one row per sounding tone, with its instrument, `frequency_hz`, `velocity`, `start_seconds` and `duration_seconds`. `ensemble`, `instrument_partials` and `instrument_effect_taps` hold each piece's instruments with their ranges, harmonics and effects.
4. `note_partials` joins each tone to its instrument's harmonics, envelope and pan.
5. `instrument_samples` expands each partial to one row per sample with `unnest(range(…))`, evaluates `sin(2π·f·t)` under its ADSR envelope, pans it with equal-power gains and sums it by instrument and `sample_index`.
6. `mixed_samples` adds each instrument's delayed copies from `instrument_effect_taps` (the dry sound, delay echoes and reverb reflections) by shifting `sample_index`, sums everything, fills gaps with silence and normalises each piece.
7. `render_wav`, a dbt Python model, writes the samples as 16-bit stereo PCM with the standard library's `wave` module.

`render_midi`, another Python model, writes `score_notes` as a Standard MIDI File without third-party libraries: a tempo and time-signature track, then one named track and channel per voice (channel 10 is skipped, since General MIDI keeps it for drums). MIDI holds pitches, velocities and written lengths, so instruments, releases and effects are left to whatever plays it.

## Browsing

- `make docs` generates and serves dbt docs: every model with its description, columns, tests and lineage. The overview page explains where to look.
- `make score PIECE=<piece>` prints a built piece's notes by section, bar and beat, with chords spelled out (`analyses/score_listing.sql`).
- `score_notes` is the score as a table, for any query you like.

## Layout

```
pieces/                one .yml per composition
instruments/           one .yml per stored instrument
seeds/                 music theory reference tables
models/
  base/                theory tables from seeds; piece and instrument files read and flattened into rows
  intermediate/        int_{topic}__{transformation}: the steps that build the score
  core/                what render/ and analyses read: sections, the ensemble, the score
  render/              partials, mixed samples, effects, WAV and MIDI output
  */_<directory>.yml   one file documenting and testing every model in the directory
analyses/score_listing.sql  a piece's notes by bar and beat, for make score
scripts/check_layers.py  enforces which layers may read which, model naming and where models are documented
scripts/new_from_template.py creates a piece or instrument file from its template
templates/             commented starting points for a piece and an instrument
docs/sql_style.md      how SQL is written here
```

## Configuration

| Setting | Where | Default |
|---|---|---|
| DuckDB file | `DBTROPE_DUCKDB_PATH` env var | `dbtrope.duckdb` |
| Sample rate | `sample_rate` var | `22050` (use `44100` for final renders) |
| Output folder | `output_dir` var | `output` |
| Piece to render | `piece` var: a name, a path to a `.yml` file, or `all` | none: required by `dbt build` and `dbt run` |
| Piece folder | `pieces_dir` var | `pieces` |
| Instrument folder | `instruments_dir` var | `instruments` |

Override vars per run: `dbt build --vars '{piece: nocturne, sample_rate: 44100}'`.
