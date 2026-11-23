with sequenced_events as (
    select
        piece_id,
        section_name,
        start_beats,
        duration_beats
    from {{ ref('int_events__sequenced') }}
),

form_entries as (
    select
        piece_id,
        form_index,
        section_name
    from {{ ref('piece_form') }}
),

piece_tempos as (
    select
        piece_id,
        tempo_bpm,
        meter,
        -- beats are quarter notes, so a bar of 6/8 is 3 beats long
        (
            beats_per_bar * 4
            / split_part(meter, '/', 2)::integer
        ) as bar_beats
    from {{ ref('pieces') }}
),

-- a section lasts as long as its longest voice, rests included
section_lengths as (
    select
        piece_id,
        section_name,
        max(start_beats + duration_beats) as duration_beats
    from sequenced_events
    group by
        piece_id,
        section_name
),

form_sections as (
    select
        form_entries.piece_id,
        form_entries.form_index,
        form_entries.section_name,
        -- a section with no voices takes no time
        coalesce(section_lengths.duration_beats, 0) as duration_beats
    from form_entries
    left join section_lengths
        on section_lengths.piece_id = form_entries.piece_id
        and section_lengths.section_name = form_entries.section_name
),

-- each section starts when the ones before it in the form have ended
timed_sections as (
    select
        piece_id,
        form_index,
        section_name,
        coalesce(
            sum(duration_beats) over (
                partition by piece_id
                order by form_index
                rows between unbounded preceding and 1 preceding
            ),
            0
        ) as start_beats,
        duration_beats
    from form_sections
)

select
    timed_sections.piece_id,
    timed_sections.form_index,
    timed_sections.section_name,
    timed_sections.start_beats,
    timed_sections.duration_beats,
    (timed_sections.start_beats * 60 / piece_tempos.tempo_bpm) as start_seconds,
    (timed_sections.duration_beats * 60 / piece_tempos.tempo_bpm) as duration_seconds,
    piece_tempos.tempo_bpm,
    piece_tempos.meter,
    piece_tempos.bar_beats,
    ((timed_sections.duration_beats % piece_tempos.bar_beats) = 0) as is_whole_bars
from timed_sections
join piece_tempos
    on piece_tempos.piece_id = timed_sections.piece_id
