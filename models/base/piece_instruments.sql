with declared_instruments as (
    select
        piece_id,
        unnest(json_keys(score -> 'instruments')) as instrument_name,
        score -> 'instruments' as _declarations
    from {{ ref('pieces') }}
),

declarations as (
    select
        piece_id,
        instrument_name,
        json_extract(_declarations, '$."' || instrument_name || '"') as declaration
    from declared_instruments
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

resolved as (
    select
        named_declarations.piece_id,
        named_declarations.instrument_name,
        named_declarations.instrument_source,
        named_declarations.library_instrument_name,
        named_declarations.declaration,
        library.definition
    from named_declarations
    left join library
        on library.instrument_name = named_declarations.library_instrument_name
)

select
    piece_id,
    instrument_name,
    instrument_source,
    library_instrument_name,
    (instrument_source = 'inline' or definition is not null) as is_resolved,
    -- a declaration's settings win over the stored instrument's, key by key
    coalesce(declaration -> 'partials', definition -> 'partials', '[[1, 1]]'::json) as partials,
    coalesce((declaration -> 'adsr' ->> 'a')::double, (definition -> 'adsr' ->> 'a')::double, 0.01) as attack_seconds,
    coalesce((declaration -> 'adsr' ->> 'd')::double, (definition -> 'adsr' ->> 'd')::double, 0) as decay_seconds,
    coalesce((declaration -> 'adsr' ->> 's')::double, (definition -> 'adsr' ->> 's')::double, 1) as sustain_level,
    coalesce((declaration -> 'adsr' ->> 'r')::double, (definition -> 'adsr' ->> 'r')::double, 0.05) as release_seconds,
    coalesce((declaration ->> 'pan')::double, (definition ->> 'pan')::double, 0) as pan,
    coalesce(declaration -> 'range', definition -> 'range') ->> 0 as lowest_note_name,
    coalesce(declaration -> 'range', definition -> 'range') ->> 1 as highest_note_name
from resolved
