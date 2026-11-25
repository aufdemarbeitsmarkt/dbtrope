with effect_names as (
    select effect_name
    from {{ ref('seed_effect_names') }}
),

named_effects as (
    select
        piece_id,
        named_effect
    from {{ ref('piece_effects') }}

    union all

    select
        'effects/' as piece_id,
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
