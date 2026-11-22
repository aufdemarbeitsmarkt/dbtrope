# SQL style

How SQL and dbt models are written in dbtrope. Follow this guide for every new model. Where this guide and a plan or older file disagree, this guide wins, unless a DuckDB or audio constraint makes a rule impossible.

## General

- Lowercase SQL keywords (`select`, `from`, `where`, `case`, …).
- *Almost-river* style: 4-space indents, line breaks and parentheses for legibility. Aim for alignment without being a stickler about it. ([background](https://gist.github.com/mattmc3/38a85e6a4ca1093816c08d4815fbebfb#river-formatting))
- A model has one clear style. Don't restyle part of an existing file; restyle the whole file or leave it alone.
- Comment only what someone editing the file couldn't work out from the SQL: a non-obvious musical or DSP rule, a DuckDB quirk, a surprising edge case. No file header comments. A model's grain and purpose go in its YAML `description:`.
- Prefer descriptive names to terse ones.
- Commas go at the end of each line.
- Filter early, unless filtering later makes complex logic easier to read.

## Conventions

- `snake_case` for models, CTEs, columns and aliases.
- Avoid DuckDB reserved words as names or aliases. `select * from duckdb_keywords()` lists them.
- Abbreviate an object rather than shrinking it to one letter: `pn` or `pitched_notes`, not `p`.
- Prefer `coalesce()` to `ifnull()`.

### Almost-river style

```sql
select
    notes.piece_id,
    notes.voice_id,
    notes.event_index,
    notes.midi_note,
    instruments.instrument_name,
    (notes.duration_beats * 60 / pieces.tempo_bpm) as duration_seconds
from {{ ref('int_notes__pitched') }} as notes
join {{ ref('piece_instruments') }} as instruments
    on instruments.piece_id = notes.piece_id
    and instruments.instrument_name = notes.instrument_name
join {{ ref('pieces') }} as pieces
    on pieces.piece_id = notes.piece_id
where not notes.is_rest
    and notes.midi_note between 21 and 108
order by notes.piece_id, notes.voice_id, notes.event_index
```

### Joins

- In `join … on`, lead with the table being joined, then the table already in scope. The new table's key is then easy to spot.
- Use an explicit `on`; avoid `using ()`. `using ()` merges the keys into one unqualified column and hides the case where two relations share a column name for different reasons.

```sql
-- preferred
from pitched_notes
join piece_tempos
    on piece_tempos.piece_id = pitched_notes.piece_id
```

## Formatting

### `case`

`case` and `end` mark the start and end of the expression. Keep `then` on the same line as a short `when`. Group long compound conditions in parentheses.

```sql
select
    midi_note,
    case
        when midi_note < 48 then 'low'
        when midi_note < 72 then 'middle'
        else 'high'
    end as register,

    case
        when (
            instrument_family = 'plucked'
            and duration_seconds > 2
        ) then 'let_ring'

        when is_rest then 'silent'
        else 'normal'
    end as release_behaviour,

    -- simple case expressions can stay on one line
    case when velocity >= 100 then 'accent' else 'normal' end as dynamic
from notes
```

### Window functions

One 4-space indent, with `partition by` and `order by` on their own lines inside the parentheses.

```sql
select
    piece_id,
    voice_id,
    event_index,
    duration_beats,

    sum(duration_beats) over (
        partition by piece_id, voice_id
        order by event_index
    ) as _cumulative_beats,

    lead(midi_note) over (
        partition by piece_id, voice_id
        order by event_index
    ) as next_midi_note
from motif_events
```

### Booleans

Write boolean columns as expressions, not `case … then true else false`.

```sql
select
    event_index,
    (pitch_spec = 'r') as is_rest,
    (abs(next_midi_note - midi_note) > 12) as is_leap_over_octave
from motif_events
```

### Expressions and maths

- Wrap maths in parentheses.
- Break long expressions at the operator so the order of operations is obvious.

```sql
(440 * pow(2, (midi_note - 69) / 12.0)) as frequency_hz,

(
    sin(2 * pi() * harmonic * frequency_hz * _seconds_into_note)
    * partial_amplitude
    * _envelope_level
) as amplitude
```

### Filtering

- Order filters from broad to specific.
- No `where 1=1` in committed code.

### Ordering values

Sort lists of values (`in (…)`, `case` branches that bucket categories) alphanumerically unless there is a clear reason not to. When there is one, such as scale order or pitch order, say so in a comment.

### Comments

```sql
-- short comments like this

/*
    Longer comments that explain musical or DSP logic,
    or that don't fit on one line, use C-style delimiters.
*/

{# Comments about Jinja use Jinja delimiters, so they stay out of compiled SQL. #}
```

- Put comments above the line they describe.
- Name what you are talking about, such as the column, CTE or expression. A detached "this" means nothing after code moves.
- A `TODO` says why the work wasn't done yet, links to an issue, and describes the fix.
- Delete comments that are no longer true and leftovers from development.

## CTEs

- Don't name a CTE after the model it reads, or after a column.
- Name a CTE for what it holds or what it did: `pitched_notes`, `notes_with_offsets`, `unioned`. Avoid bare `data`, `base` or `temp`. `final` is acceptable for the last CTE, but a descriptive name is better.

## Columns and aliases

- List columns explicitly. Never `select *` from a `ref()`; always list the final select's columns. `*` from a CTE in the same model is allowed, but ask whether that CTE needs to exist.
- Always alias with `as`.
- Suffixes and prefixes carry type and unit:
  - `_id`: identifier or foreign key
  - `_index`: position within an ordered set (`event_index`, `sample_index`)
  - `_beats`, `_seconds`, `_hz`, `_bpm`: musical and physical units
  - `is_*`, `has_*`, `was_*`: booleans
  - `_at`, `_date`: timestamps and dates, which are rare here
- Don't alias a column to the name of its table or CTE.
- Start stepping-stone columns that shouldn't reach the final output with `_`: `_cumulative_beats`, `_envelope_level`.

### Qualify column sources

When more than one relation is in scope, qualify every column. List columns in each CTE so lineage is readable from the top.

```sql
with pitched_notes as (
    select
        piece_id,
        voice_id,
        event_index,
        midi_note,
        frequency_hz,
        duration_beats
    from {{ ref('int_notes__pitched') }}
),

piece_tempos as (
    select
        piece_id,
        tempo_bpm
    from {{ ref('pieces') }}
)

select
    pitched_notes.piece_id,
    pitched_notes.voice_id,
    pitched_notes.event_index,
    pitched_notes.frequency_hz,
    (pitched_notes.duration_beats * 60 / piece_tempos.tempo_bpm) as duration_seconds
from pitched_notes
join piece_tempos
    on piece_tempos.piece_id = pitched_notes.piece_id
```

## Jinja

- Use `{% set %} … {% endset %}` for long SQL fragments; this keeps syntax highlighting and avoids nested quotes.
- Explain Jinja with `{# #}` comments.
- Name repeated window clauses once:

```sql
{%- set voice_event_order %}
    partition by
        piece_id,
        voice_id
    order by event_index
{%- endset %}

select
    piece_id,
    voice_id,
    event_index,

    sum(duration_beats) over (
        {{ voice_event_order }}
    ) as _cumulative_beats,

    lag(midi_note) over (
        {{ voice_event_order }}
    ) as previous_midi_note
from motif_events
```

## DuckDB features

### `qualify`

Use `qualify` for intentional one-row-per-partition picks. Don't use it to hide fan-out; fix the grain upstream instead.

```sql
-- a piece-level instrument override wins over the stored instrument of the same name
select
    piece_id,
    instrument_name,
    partials,
    adsr
from resolved_instruments
qualify row_number() over (
    partition by piece_id, instrument_name
    order by resolution_priority
) = 1
```

### Lists, structs and JSON

| Purpose | DuckDB |
|---|---|
| Aggregate into a list | `list(x order by y)` |
| Build a struct | `struct_pack(key := value, …)` or `{'key': value}` |
| Filter a list | `list_filter(list, x -> …)` |
| List length | `len(list)` |
| Expand a list to rows | `unnest(list)` |
| Read piece YAML | `from_json(score -> 'voices', '["json"]')`, `score ->> 'tempo'` |
| Integer ranges | `range(start, stop)`, `generate_series(start, stop)` |

## Layers

A model's layer is the first directory under `models/`. `make check` enforces these rules from `target/manifest.json` using `scripts/check_layers.py`.

| Layer | Holds | May read |
|---|---|---|
| `pieces/` | One YAML-defined model per composition (`{{ compose() }}`) | instruments, seeds |
| `instruments/` | One YAML-defined model per stored instrument (`{{ instrument() }}`) | seeds |
| `base/` | Piece and instrument YAML flattened into rows | pieces, instruments, base, seeds |
| `intermediate/` | Theory, form, transforms, timing, the score | base, intermediate, seeds |
| `render/` | Partials, samples, effects, WAV output | intermediate, render |

## Naming models

- Models outside `intermediate/` have no layer prefix. Name them for what they hold: `pieces`, `piece_motifs`, `mixed_samples`. Never `stg_`.
- Intermediate models are named `int_{topic}__{transformation}`. `transformation` is a verb for what happened (`__expanded`, `__pitched`, `__timed`) or a noun for what is created (`__note_events`). Use a verb when a topic has more than one step.

## Influences

- [The Case Against SQL Formatting](https://benn.substack.com/p/the-case-against-sql-formatting), Benn Stancil
- [mattmc3's SQL formatting gist](https://gist.github.com/mattmc3/38a85e6a4ca1093816c08d4815fbebfb)
