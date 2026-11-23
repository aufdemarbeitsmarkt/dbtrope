with declarations as (
    select
        pieces.piece_id,
        declared.key as instrument_name,
        declared.value as declaration
    from {{ ref('pieces') }} as pieces,
        json_each(pieces.score -> 'instruments') as declared
),

voice_instruments as (
    select distinct
        piece_id,
        instrument_name
    from {{ ref('piece_voices') }}
),

library as (
    select
        instrument_name,
        definition
    from {{ ref('instruments') }}
),

/*
    Every instrument a piece declares or a voice names. A name the piece
    declares uses that declaration, which starts from the stored instrument
    in `use:` if it has one. Any other name is a stored instrument used
    as-is.
*/
piece_instrument_names as (
    select
        piece_id,
        instrument_name
    from declarations

    union

    select
        piece_id,
        instrument_name
    from voice_instruments
),

named_declarations as (
    select
        piece_instrument_names.piece_id,
        piece_instrument_names.instrument_name,
        case
            when declarations.declaration is null then 'library'
            when (declarations.declaration ->> 'use') is not null then 'override'
            else 'inline'
        end as instrument_source,
        case
            when declarations.declaration is null then piece_instrument_names.instrument_name
            else declarations.declaration ->> 'use'
        end as library_instrument_name,
        declarations.declaration
    from piece_instrument_names
    left join declarations
        on declarations.piece_id = piece_instrument_names.piece_id
        and declarations.instrument_name = piece_instrument_names.instrument_name
),

/*
    A declaration's settings win over the stored instrument's, key by key:
    json_merge_patch merges objects such as adsr one value at a time and
    replaces lists such as partials whole.
*/
resolved as (
    select
        named_declarations.piece_id,
        named_declarations.instrument_name,
        named_declarations.instrument_source,
        named_declarations.library_instrument_name,
        (named_declarations.instrument_source = 'inline' or library.definition is not null) as is_resolved,
        json_merge_patch(
            coalesce(library.definition, '{}'),
            coalesce(named_declarations.declaration, '{}')
        ) as settings
    from named_declarations
    left join library
        on library.instrument_name = named_declarations.library_instrument_name
)

select
    piece_id,
    instrument_name,
    instrument_source,
    library_instrument_name,
    is_resolved,
    coalesce(settings -> 'partials', '[[1, 1]]'::json) as partials,
    coalesce((settings -> 'adsr' ->> 'a')::double, 0.01) as attack_seconds,
    coalesce((settings -> 'adsr' ->> 'd')::double, 0) as decay_seconds,
    coalesce((settings -> 'adsr' ->> 's')::double, 1) as sustain_level,
    coalesce((settings -> 'adsr' ->> 'r')::double, 0.05) as release_seconds,
    coalesce((settings ->> 'pan')::double, 0) as pan,
    (settings -> 'range' ->> 0) as lowest_note_name,
    (settings -> 'range' ->> 1) as highest_note_name,
    -- an instrument has an effect when the key is there, even as {}; a piece turns one off with delay: null
    case
        when (settings -> 'delay') is not null
            then coalesce((settings -> 'delay' ->> 'seconds')::double, 0.25)
    end as delay_seconds,
    coalesce((settings -> 'delay' ->> 'feedback')::double, 0.4) as delay_feedback,
    coalesce((settings -> 'delay' ->> 'repeats')::integer, 3) as delay_repeats,
    case
        when (settings -> 'reverb') is not null
            then coalesce((settings -> 'reverb' ->> 'seconds')::double, 1.5)
    end as reverb_seconds,
    coalesce((settings -> 'reverb' ->> 'mix')::double, 0.25) as reverb_mix
from resolved
