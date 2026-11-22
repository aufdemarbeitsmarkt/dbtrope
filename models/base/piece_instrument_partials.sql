with partial_lists as (
    select
        piece_id,
        instrument_name,
        from_json(partials, '[["double"]]') as partials
    from {{ ref('piece_instruments') }}
),

unnested_partials as (
    select
        piece_id,
        instrument_name,
        unnest(partials) as _partial,
        generate_subscripts(partials, 1) as partial_index
    from partial_lists
)

select
    piece_id,
    instrument_name,
    partial_index,
    _partial[1] as frequency_ratio,
    _partial[2] as partial_amplitude
from unnested_partials
