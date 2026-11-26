with effect_names as (
    select effect_name
    from {{ ref('effect_registry') }}
),

named_effects as (
    select
        piece_id,
        named_effect
    from {{ ref('piece_effects') }}

    union all

    select
        'music/effects/' as piece_id,
        named_effect
    from {{ ref('effects') }}
)

-- delay: {use: delay} would read as the effect itself, so its names are reserved
select
    named_effects.piece_id,
    named_effects.named_effect
from named_effects
inner join effect_names
    on effect_names.effect_name = named_effects.named_effect
