{#- An inverted voice mirrors its pitches around its first written pitch, so every window here runs over a voice's tones in written order. #}
{%- set voice_tone_order %}
    partition by
        piece_id,
        section_name,
        voice_id
    order by
        event_index,
        chord_tone_index
{%- endset %}

with voice_events as (
    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        pitch_spec
    from {{ ref('piece_voice_events') }}
),

voice_settings as (
    select
        piece_id,
        section_name,
        voice_id,
        pitch_kind,
        octave,
        transpose_semitones,
        is_inverted
    from {{ ref('piece_voices') }}
),

piece_keys as (
    select
        piece_id,
        key_root,
        scale_name
    from {{ ref('pieces') }}
),

note_names as (
    select
        note_name,
        midi_note
    from {{ ref('int_theory__note_names') }}
),

pitch_classes as (
    select
        pitch_name,
        semitones_from_c
    from {{ ref('pitch_classes') }}
),

scales as (
    select
        scale_name,
        semitones_above_root,
        degree_count
    from {{ ref('int_theory__scales') }}
),

roman_numerals as (
    select
        numeral,
        scale_degree
    from {{ ref('roman_numerals') }}
),

events_in_context as (
    select
        voice_events.piece_id,
        voice_events.section_name,
        voice_events.voice_id,
        voice_events.event_index,
        voice_events.pitch_spec,
        (lower(voice_events.pitch_spec) = 'r') as is_rest,
        voice_settings.pitch_kind,
        voice_settings.octave,
        voice_settings.transpose_semitones,
        voice_settings.is_inverted,
        piece_keys.key_root,
        piece_keys.scale_name
    from voice_events
    join voice_settings
        on voice_settings.piece_id = voice_events.piece_id
        and voice_settings.section_name = voice_events.section_name
        and voice_settings.voice_id = voice_events.voice_id
    join piece_keys
        on piece_keys.piece_id = voice_events.piece_id
),

/*
    A chord is stacked in thirds from its root within the key's scale, so its
    quality comes from the key: in C major, ii is D F A (minor) and V is G B D
    (major). The numeral's case is for the reader and doesn't change the
    chord. A trailing 7 adds the seventh.
*/
chord_degrees as (
    select
        events_in_context.piece_id,
        events_in_context.section_name,
        events_in_context.voice_id,
        events_in_context.event_index,
        case
            when ends_with(events_in_context.pitch_spec, '7')
                then [0, 2, 4, 6]
            else [0, 2, 4]
        end as _steps_above_root,
        roman_numerals.scale_degree as _root_degree
    from events_in_context
    left join roman_numerals
        on roman_numerals.numeral = lower(regexp_extract(events_in_context.pitch_spec, '^([ivIV]+)7?$', 1))
    where events_in_context.pitch_kind = 'chords'
        and not events_in_context.is_rest
),

chord_tones as (
    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        (_root_degree + unnest(_steps_above_root))::varchar as degree_spec,
        generate_subscripts(_steps_above_root, 1) as chord_tone_index
    from chord_degrees
),

-- every event becomes one or more tones; a chord's tones are written as scale degrees
event_tones as (
    select
        events_in_context.*,
        coalesce(chord_tones.chord_tone_index, 1) as chord_tone_index,
        case
            when events_in_context.pitch_kind = 'chords' then chord_tones.degree_spec
            when events_in_context.pitch_kind = 'degrees' then events_in_context.pitch_spec
        end as degree_spec
    from events_in_context
    left join chord_tones
        on chord_tones.piece_id = events_in_context.piece_id
        and chord_tones.section_name = events_in_context.section_name
        and chord_tones.voice_id = events_in_context.voice_id
        and chord_tones.event_index = events_in_context.event_index
),

/*
    A degree is a number with optional sharps or flats in front: 3, b7, #4.
    Degrees past the end of the scale continue into the next octave (8 is 1
    an octave up in a seven-note scale), and 0 and below continue downward
    (0 is the step below 1).
*/
parsed_degrees as (
    select
        event_tones.*,
        regexp_extract(event_tones.degree_spec, '^([#b]*)-?[0-9]+$', 1) as _accidentals,
        (
            try_cast(regexp_extract(event_tones.degree_spec, '^[#b]*(-?[0-9]+)$', 1) as integer)
            - 1
        ) as _written_steps_above_tonic
    from event_tones
),

/*
    Inverting a voice written in degrees or chords mirrors it within the
    scale: each step above the first degree becomes a step below it, and
    sharps become flats. A chord voice mirrors around its first root, so its
    chords turn upside down too.
*/
oriented_degrees as (
    select
        parsed_degrees.*,
        case
            when parsed_degrees.is_inverted
                then (
                    2 * first_value(parsed_degrees._written_steps_above_tonic ignore nulls) over (
                        {{ voice_tone_order }}
                    )
                    - parsed_degrees._written_steps_above_tonic
                )
            else parsed_degrees._written_steps_above_tonic
        end as _steps_above_tonic,
        -- sharps minus flats
        (
            (case when parsed_degrees.is_inverted then -1 else 1 end)
            * (
                length(replace(parsed_degrees._accidentals, 'b', ''))
                - length(replace(parsed_degrees._accidentals, '#', ''))
            )
        ) as _accidental_semitones
    from parsed_degrees
),

degrees_in_scale as (
    select
        oriented_degrees.*,
        pitch_classes.semitones_from_c as _tonic_semitones_from_c,
        scales.semitones_above_root as _scale_semitones,
        -- the 1-based position in the scale, wrapping in both directions
        (
            (((oriented_degrees._steps_above_tonic % scales.degree_count) + scales.degree_count) % scales.degree_count)
            + 1
        ) as _scale_degree,
        floor(oriented_degrees._steps_above_tonic / scales.degree_count)::integer as _octaves_above
    from oriented_degrees
    left join pitch_classes
        on pitch_classes.pitch_name = oriented_degrees.key_root
    left join scales
        on scales.scale_name = oriented_degrees.scale_name
),

tones_with_midi as (
    select
        degrees_in_scale.piece_id,
        degrees_in_scale.section_name,
        degrees_in_scale.voice_id,
        degrees_in_scale.event_index,
        degrees_in_scale.chord_tone_index,
        degrees_in_scale.pitch_spec,
        degrees_in_scale.is_rest,
        degrees_in_scale.pitch_kind,
        degrees_in_scale.transpose_semitones,
        degrees_in_scale.is_inverted,
        case
            when degrees_in_scale.pitch_kind = 'notes' then note_names.midi_note
            else (
                12 * (degrees_in_scale.octave + 1 + degrees_in_scale._octaves_above)
                + degrees_in_scale._tonic_semitones_from_c
                + degrees_in_scale._scale_semitones[degrees_in_scale._scale_degree]
                + degrees_in_scale._accidental_semitones
            )
        end as _untransposed_midi_note
    from degrees_in_scale
    left join note_names
        on note_names.note_name = degrees_in_scale.pitch_spec
),

-- inverting a voice written in note names mirrors it by semitones around its first note
oriented_tones as (
    select
        piece_id,
        section_name,
        voice_id,
        event_index,
        chord_tone_index,
        pitch_spec,
        is_rest,
        (
            case
                when (is_inverted and pitch_kind = 'notes')
                    then (
                        2 * first_value(_untransposed_midi_note ignore nulls) over (
                            {{ voice_tone_order }}
                        )
                        - _untransposed_midi_note
                    )
                else _untransposed_midi_note
            end
            + transpose_semitones
        ) as midi_note
    from tones_with_midi
)

select
    piece_id,
    section_name,
    voice_id,
    event_index,
    chord_tone_index,
    pitch_spec,
    is_rest,
    case when not is_rest then midi_note end as midi_note,
    case when not is_rest then (440 * pow(2, (midi_note - 69) / 12.0)) end as frequency_hz
from oriented_tones
