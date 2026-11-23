{%- set sample_rate = var('sample_rate') %}

with note_events as (
    select
        piece_id,
        voice_id,
        event_index,
        chord_tone_index,
        instrument_name,
        frequency_hz,
        velocity,
        start_seconds,
        duration_seconds
    from {{ ref('int_score__note_events') }}
),

instruments as (
    select
        piece_id,
        instrument_name,
        -- a zero-length stage would divide by zero; one sample is short enough to be inaudible
        greatest(attack_seconds, 1 / {{ sample_rate }}) as attack_seconds,
        greatest(decay_seconds, 1 / {{ sample_rate }}) as decay_seconds,
        sustain_level,
        greatest(release_seconds, 1 / {{ sample_rate }}) as release_seconds,
        pan
    from {{ ref('int_instruments__ranged') }}
),

partials as (
    select
        piece_id,
        instrument_name,
        partial_index,
        frequency_ratio,
        partial_amplitude
    from {{ ref('int_instruments__partials') }}
),

note_partials as (
    select
        note_events.piece_id,
        note_events.voice_id,
        note_events.event_index,
        note_events.chord_tone_index,
        partials.partial_index,
        note_events.instrument_name,
        (note_events.frequency_hz * partials.frequency_ratio) as frequency_hz,
        (partials.partial_amplitude * note_events.velocity / 127) as amplitude,
        note_events.start_seconds,
        note_events.duration_seconds,
        instruments.attack_seconds,
        instruments.decay_seconds,
        instruments.sustain_level,
        instruments.release_seconds,
        instruments.pan
    from note_events
    join instruments
        on instruments.piece_id = note_events.piece_id
        and instruments.instrument_name = note_events.instrument_name
    join partials
        on partials.piece_id = note_events.piece_id
        and partials.instrument_name = note_events.instrument_name
)

select
    piece_id,
    voice_id,
    event_index,
    chord_tone_index,
    partial_index,
    instrument_name,
    frequency_hz,
    amplitude,
    start_seconds,
    duration_seconds,
    attack_seconds,
    decay_seconds,
    sustain_level,
    release_seconds,
    -- the envelope level when the note's written length ends and the release begins
    case
        when duration_seconds < attack_seconds then (duration_seconds / attack_seconds)
        when duration_seconds < (attack_seconds + decay_seconds)
            then (1 - (1 - sustain_level) * (duration_seconds - attack_seconds) / decay_seconds)
        else sustain_level
    end as release_start_level,
    -- equal-power panning keeps a note equally loud wherever it sits
    cos((pan + 1) * pi() / 4) as left_gain,
    sin((pan + 1) * pi() / 4) as right_gain,
    /*
        The samples that fall within the note and its release. Rounding up
        means no sample before the note's start is included; rounding a start
        down would give that sample a negative time into the note, and so a
        negative envelope level.
    */
    ceil(start_seconds * {{ sample_rate }})::bigint as first_sample_index,
    ceil((start_seconds + duration_seconds + release_seconds) * {{ sample_rate }})::bigint as end_sample_index
from note_partials
-- partials at or above the Nyquist frequency can't be represented and would alias
where frequency_hz < ({{ sample_rate }} / 2)
