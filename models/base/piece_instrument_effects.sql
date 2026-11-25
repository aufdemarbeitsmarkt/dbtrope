with instruments as (
    select
        piece_id,
        instrument_name,
        effects,
        declared_effects
    from {{ ref('piece_instruments') }}
),

named_effects as (
    select
        piece_id,
        named_effect,
        effect_name,
        effect_settings
    from {{ ref('piece_effects') }}
),

-- an instrument has an effect when its key is under effects:, even as {}; a piece turns one off with delay: null
instrument_effects as (
    select
        instruments.piece_id,
        instruments.instrument_name,
        instrument_effects.key as effect_name,
        instrument_effects.value as resolved_settings,
        instruments.declared_effects -> instrument_effects.key as declared_settings
    from instruments,
        json_each(instruments.effects) as instrument_effects
),

/*
    An effect with use: starts from the piece's named effect. When the piece
    writes use: itself, its keys replace the stored instrument's for that
    effect, so a stored reverb doesn't leak into the named one; otherwise
    the stored instrument's keys apply over the named effect.
*/
used_settings as (
    select
        piece_id,
        instrument_name,
        effect_name,
        (resolved_settings ->> 'use') as named_effect,
        resolved_settings,
        case
            when (declared_settings ->> 'use') is not null then declared_settings
            else resolved_settings
        end as own_settings
    from instrument_effects
)

select
    used_settings.piece_id,
    used_settings.instrument_name,
    used_settings.effect_name,
    used_settings.named_effect,
    (
        used_settings.named_effect is null
        or coalesce(named_effects.effect_name = used_settings.effect_name, false)
    ) as is_resolved,
    case
        when used_settings.named_effect is null then used_settings.resolved_settings
        else json_merge_patch(
            json_merge_patch(coalesce(named_effects.effect_settings, '{}'), used_settings.own_settings),
            '{"use": null}'
        )
    end as effect_settings
from used_settings
left join named_effects
    on named_effects.piece_id = used_settings.piece_id
    and named_effects.named_effect = used_settings.named_effect
