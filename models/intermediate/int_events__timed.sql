with sequenced_events as (
    select
        piece_id,
        section_name,
        voice_id,
        repetition_index,
        event_index,
        velocity,
        start_beats,
        duration_beats
    from {{ ref('int_events__sequenced') }}
),

timed_sections as (
    select
        piece_id,
        form_index,
        section_name,
        start_beats
    from {{ ref('int_sections__timed') }}
),

piece_tempos as (
    select
        piece_id,
        tempo_bpm
    from {{ ref('pieces') }}
),

-- a section the form plays more than once has its events placed each time
events_in_form as (
    select
        sequenced_events.piece_id,
        sequenced_events.voice_id,
        timed_sections.form_index,
        sequenced_events.section_name,
        sequenced_events.repetition_index,
        sequenced_events.event_index as written_event_index,
        sequenced_events.velocity,
        (timed_sections.start_beats + sequenced_events.start_beats) as start_beats,
        sequenced_events.duration_beats
    from sequenced_events
    join timed_sections
        on timed_sections.piece_id = sequenced_events.piece_id
        and timed_sections.section_name = sequenced_events.section_name
)

select
    events_in_form.piece_id,
    events_in_form.voice_id,
    -- a voice's events never overlap, so their start times order them
    row_number() over (
        partition by events_in_form.piece_id, events_in_form.voice_id
        order by events_in_form.start_beats
    ) as event_index,
    events_in_form.form_index,
    events_in_form.section_name,
    events_in_form.repetition_index,
    events_in_form.written_event_index,
    events_in_form.velocity,
    events_in_form.start_beats,
    events_in_form.duration_beats,
    (events_in_form.start_beats * 60 / piece_tempos.tempo_bpm) as start_seconds,
    (events_in_form.duration_beats * 60 / piece_tempos.tempo_bpm) as duration_seconds
from events_in_form
join piece_tempos
    on piece_tempos.piece_id = events_in_form.piece_id
