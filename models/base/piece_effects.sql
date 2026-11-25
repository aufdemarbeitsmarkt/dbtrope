with pieces as (
    select
        piece_id,
        score
    from {{ ref('pieces') }}
)

-- a named effect holds one effect, as in hall: {reverb: {seconds: 2.5}}; a second key is a second row and fails uniqueness
select
    pieces.piece_id,
    named_effects.key as named_effect,
    effect.key as effect_name,
    effect.value as effect_settings
from pieces,
    json_each(pieces.score -> 'effects') as named_effects,
    json_each(named_effects.value) as effect
