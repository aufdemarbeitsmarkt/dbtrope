{#- The effect's name: its key under effects:, reserved from named and stored effects (macros/effect_models.sql). #}
{%- set effect_name = 'delay' %}
{{ config(meta={'effect_name': effect_name}) }}

with delays as (
    select
        piece_id,
        instrument_name,
        coalesce((effect_settings ->> 'seconds')::double, 0.25) as delay_seconds,
        coalesce((effect_settings ->> 'feedback')::double, 0.4) as delay_feedback,
        coalesce((effect_settings ->> 'repeats')::integer, 3) as delay_repeats
    from {{ ref('piece_instrument_effects') }}
    where effect_name = '{{ effect_name }}'
),

delay_tap_indexes as (
    select
        piece_id,
        instrument_name,
        delay_seconds,
        delay_feedback,
        unnest(range(1, delay_repeats + 1)) as tap_index
    from delays
)

-- echo n comes n delay times after the dry sound, at feedback to the power n
select
    piece_id,
    instrument_name,
    '{{ effect_name }}' as effect_name,
    tap_index,
    (delay_seconds * tap_index) as delay_seconds,
    pow(delay_feedback, tap_index) as left_gain,
    pow(delay_feedback, tap_index) as right_gain
from delay_tap_indexes
