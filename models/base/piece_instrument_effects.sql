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

-- a stored effect file holds one effect beside its description, like a piece's named effect
stored_effects as (
    select
        effects.named_effect,
        effect.key as effect_name,
        effect.value as effect_settings
    from {{ ref('effects') }} as effects,
        json_each(effects.definition) as effect
    where effect.key != 'description'
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
    An effect with use: starts from the piece's named effect of that name,
    or else the stored effect in music/effects/. When the piece
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
),

resolved as (
    select
        used_settings.piece_id,
        used_settings.instrument_name,
        used_settings.effect_name,
        used_settings.named_effect,
        used_settings.resolved_settings,
        used_settings.own_settings,
        case
            when named_effects.named_effect is not null then 'piece'
            when stored_effects.named_effect is not null then 'library'
        end as named_effect_source,
        coalesce(named_effects.effect_name, stored_effects.effect_name) as named_effect_name,
        coalesce(named_effects.effect_settings, stored_effects.effect_settings) as named_effect_settings
    from used_settings
    left join named_effects
        on named_effects.piece_id = used_settings.piece_id
        and named_effects.named_effect = used_settings.named_effect
    left join stored_effects
        on stored_effects.named_effect = used_settings.named_effect
)

select
    piece_id,
    instrument_name,
    effect_name,
    named_effect,
    named_effect_source,
    (
        named_effect is null
        or coalesce(named_effect_name = effect_name, false)
    ) as is_resolved,
    case
        when named_effect is null then resolved_settings
        else json_merge_patch(
            json_merge_patch(coalesce(named_effect_settings, '{}'), own_settings),
            '{"use": null}'
        )
    end as effect_settings
from resolved
