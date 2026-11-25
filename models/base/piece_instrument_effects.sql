with instruments as (
    select
        piece_id,
        instrument_name,
        effects
    from {{ ref('piece_instruments') }}
)

-- an instrument has an effect when its key is under effects:, even as {}; a piece turns one off with delay: null
select
    instruments.piece_id,
    instruments.instrument_name,
    instrument_effects.key as effect_name,
    instrument_effects.value as effect_settings
from instruments,
    json_each(instruments.effects) as instrument_effects
