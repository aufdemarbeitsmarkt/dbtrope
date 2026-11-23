{#-
    The score as a musician would read it: one row per note or chord, with
    its bar and beat and note names. Show one piece with

        make score PIECE=nocturne

    or every piece by leaving PIECE out.
-#}
{%- set piece = var('piece', none) %}

with note_events as (
    select
        piece_id,
        voice_id,
        event_index,
        chord_tone_index,
        form_index,
        section_name,
        instrument_name,
        midi_note,
        velocity,
        start_beats,
        duration_beats
    from {{ ref('int_score__note_events') }}
    {%- if piece %}
    where piece_id = '{{ piece }}'
    {%- endif %}
),

sections as (
    select
        piece_id,
        form_index,
        bar_beats
    from {{ ref('int_sections__timed') }}
),

named_notes as (
    select
        note_events.*,
        sections.bar_beats,
        -- spelled with sharps, as the score keeps MIDI numbers rather than the written spelling
        (
            ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'][(note_events.midi_note % 12) + 1]
            || ((note_events.midi_note // 12) - 1)
        ) as note_name
    from note_events
    join sections
        on sections.piece_id = note_events.piece_id
        and sections.form_index = note_events.form_index
)

select
    piece_id,
    section_name,
    (floor(start_beats / bar_beats) + 1)::integer as bar,
    ((start_beats % bar_beats) + 1) as beat,
    voice_id,
    string_agg(note_name, ' ' order by chord_tone_index) as notes,
    duration_beats,
    velocity,
    instrument_name
from named_notes
group by
    piece_id,
    form_index,
    section_name,
    voice_id,
    event_index,
    bar_beats,
    start_beats,
    duration_beats,
    velocity,
    instrument_name
order by
    piece_id,
    start_beats,
    voice_id
