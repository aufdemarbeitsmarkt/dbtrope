{#-
    Randomness comes from hash() of the voice's seed, the piece, section and
    voice, and an index, so a rebuild plays the same notes and two voices
    with one seed still improvise differently.
#}
{%- set voice_order %}
    partition by
        piece_id,
        section_name,
        voice_id
    order by event_index
{%- endset %}

with recursive written_events as (
    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        pitch_spec,
        duration_spec,
        velocity
    from {{ ref('piece_voice_events') }}
),

voice_settings as (
    select
        piece_id,
        section_name,
        voice_id,
        improv_method,
        improv_length,
        improv_seed
    from {{ ref('piece_voices') }}
),

events_with_settings as (
    select
        written_events.piece_id,
        written_events.section_name,
        written_events.voice_id,
        written_events.event_index,
        written_events.pitch_spec,
        written_events.duration_spec,
        written_events.velocity,
        voice_settings.improv_method,
        voice_settings.improv_seed,
        coalesce(
            voice_settings.improv_length,
            count(*) over (
                partition by written_events.piece_id, written_events.section_name, written_events.voice_id
            )
        ) as improv_length,
        count(*) over (
            partition by written_events.piece_id, written_events.section_name, written_events.voice_id
        ) as written_event_count
    from written_events
    join voice_settings
        on voice_settings.piece_id = written_events.piece_id
        and voice_settings.section_name = written_events.section_name
        and voice_settings.voice_id = written_events.voice_id
),

-- a permutation plays the written pitches in an order set by the seed, over the written rhythm
permuted_pitches as (
    select
        piece_id,
        section_name,
        voice_id,
        row_number() over (
            partition by piece_id, section_name, voice_id
            order by hash(improv_seed, piece_id, section_name, voice_id, event_index), event_index
        ) as event_index,
        pitch_spec
    from events_with_settings
    where improv_method = 'permutation'
),

/*
    Each time one pitch is followed by another in the written line is one
    transition. A pitch followed by different pitches has a transition to
    each, and a pitch that's often followed by the same one has that
    transition more than once, so it's chosen more often.
*/
transitions as (
    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        pitch_spec as from_pitch_spec,
        lead(pitch_spec) over (
            {{ voice_order }}
        ) as to_pitch_spec
    from events_with_settings
    where improv_method = 'markov'
),

numbered_transitions as (
    select
        piece_id,
        section_name,
        voice_id,
        from_pitch_spec,
        to_pitch_spec,
        row_number() over (
            partition by piece_id, section_name, voice_id, from_pitch_spec
            order by event_index
        ) as transition_index,
        count(*) over (
            partition by piece_id, section_name, voice_id, from_pitch_spec
        ) as transition_count
    from transitions
    where to_pitch_spec is not null
),

/*
    A markov walk starts on the first written pitch and takes one transition
    from the current pitch at each step. The last written pitch may have no
    transition out of it; the walk then starts again from the first pitch.
*/
markov_walk as (
    select
        piece_id,
        section_name,
        voice_id,
        improv_seed,
        improv_length,
        pitch_spec as first_pitch_spec,
        1 as event_index,
        pitch_spec
    from events_with_settings
    where improv_method = 'markov'
        and event_index = 1

    union all

    select
        markov_walk.piece_id,
        markov_walk.section_name,
        markov_walk.voice_id,
        markov_walk.improv_seed,
        markov_walk.improv_length,
        markov_walk.first_pitch_spec,
        (markov_walk.event_index + 1) as event_index,
        coalesce(numbered_transitions.to_pitch_spec, markov_walk.first_pitch_spec) as pitch_spec
    from markov_walk
    left join numbered_transitions
        on numbered_transitions.piece_id = markov_walk.piece_id
        and numbered_transitions.section_name = markov_walk.section_name
        and numbered_transitions.voice_id = markov_walk.voice_id
        and numbered_transitions.from_pitch_spec = markov_walk.pitch_spec
        and numbered_transitions.transition_index = (
            (
                hash(
                    markov_walk.improv_seed,
                    markov_walk.piece_id,
                    markov_walk.section_name,
                    markov_walk.voice_id,
                    markov_walk.event_index
                )
                % numbered_transitions.transition_count
            )
            + 1
        )
    where markov_walk.event_index < markov_walk.improv_length
),

improvised_pitches as (
    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        pitch_spec
    from permuted_pitches

    union all

    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        pitch_spec
    from markov_walk
),

/*
    An improvised voice keeps its written rhythm and velocities event by
    event; a walk longer than the written line repeats them from the start.
*/
improvised_events as (
    select
        improvised_pitches.piece_id,
        improvised_pitches.section_name,
        improvised_pitches.voice_id,
        improvised_pitches.event_index,
        improvised_pitches.pitch_spec,
        events_with_settings.duration_spec,
        events_with_settings.velocity
    from improvised_pitches
    join events_with_settings
        on events_with_settings.piece_id = improvised_pitches.piece_id
        and events_with_settings.section_name = improvised_pitches.section_name
        and events_with_settings.voice_id = improvised_pitches.voice_id
        and events_with_settings.event_index = (
            ((improvised_pitches.event_index - 1) % events_with_settings.written_event_count)
            + 1
        )
)

select
    piece_id,
    section_name,
    voice_id,
    event_index,
    pitch_spec,
    duration_spec,
    velocity
from events_with_settings
where improv_method is null

union all

select
    piece_id,
    section_name,
    voice_id,
    event_index,
    pitch_spec,
    duration_spec,
    velocity
from improvised_events
