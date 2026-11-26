{#-
    Each effect is its own intermediate model returning the columns below,
    so effects are built and tested apart. A new effect that is a set of
    delayed, scaled copies of the sound adds its model to this list.
#}
{%- set effect_tap_models = [
    'int_taps__delayed',
    'int_taps__reverberated',
] %}
{#- An effect model missing from the list would have its taps left out without a word, so stop instead. #}
{%- set unlisted_effect_models = effect_models().values() | map(attribute='name') | reject('in', effect_tap_models) | list %}
{%- if unlisted_effect_models %}
    {{ exceptions.raise_compiler_error('Add ' ~ unlisted_effect_models | join(', ') ~ ' to effect_tap_models in instrument_effect_taps.') }}
{%- endif %}

with instruments as (
    select
        piece_id,
        instrument_name
    from {{ ref('piece_instruments') }}
)

select
    piece_id,
    instrument_name,
    'dry' as effect_name,
    0 as tap_index,
    0.0 as delay_seconds,
    1.0 as left_gain,
    1.0 as right_gain
from instruments
{%- for effect_tap_model in effect_tap_models %}

union all

select
    piece_id,
    instrument_name,
    effect_name,
    tap_index,
    delay_seconds,
    left_gain,
    right_gain
from {{ ref(effect_tap_model) }}
{%- endfor %}
