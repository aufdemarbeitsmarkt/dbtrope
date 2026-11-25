{#- The effect's name: its key under effects:, reserved from named and stored effects (macros/effect_models.sql). #}
{%- set effect_name = 'reverb' %}
{{ config(meta={'effect_name': effect_name}) }}

{#- Enough reflections that the reverb blurs rather than echoes, few enough to stay quick. #}
{%- set reverb_tap_count = 24 %}
{#- The first reflection arrives this long after the dry sound. #}
{%- set reverb_predelay_seconds = 0.02 %}

with reverbs as (
    select
        piece_id,
        instrument_name,
        coalesce((effect_settings ->> 'seconds')::double, 1.5) as reverb_seconds,
        coalesce((effect_settings ->> 'mix')::double, 0.25) as reverb_mix
    from {{ ref('piece_instrument_effects') }}
    where effect_name = '{{ effect_name }}'
),

/*
    The reverb is a multi-tap delay: reflections spread across the reverb
    time, each at an irregular point within its own slot so they don't ring
    at one pitch, alternating between the channels for width, and fading by
    60 dB (a factor of 1000) by the end. The irregularity comes from hash(),
    so it is the same on every build.
*/
reverb_tap_times as (
    select
        piece_id,
        instrument_name,
        reverb_seconds,
        reverb_mix,
        tap_index,
        (
            {{ reverb_predelay_seconds }}
            + (reverb_seconds - {{ reverb_predelay_seconds }})
            * (tap_index - 1 + (hash(instrument_name, tap_index) % 1000) / 1000.0)
            / {{ reverb_tap_count }}
        ) as delay_seconds
    from reverbs,
        range(1, {{ reverb_tap_count }} + 1) as taps(tap_index)
),

reverb_taps as (
    select
        piece_id,
        instrument_name,
        tap_index,
        delay_seconds,
        -- half the taps feed each channel, so each half is scaled to the mix's level of energy
        (
            reverb_mix
            * pow(10, -3 * delay_seconds / reverb_seconds)
            * sqrt(2.0 / {{ reverb_tap_count }})
        ) as _tap_gain,
        (tap_index % 2 = 1) as _is_left
    from reverb_tap_times
)

select
    piece_id,
    instrument_name,
    '{{ effect_name }}' as effect_name,
    tap_index,
    delay_seconds,
    case when _is_left then _tap_gain else 0 end as left_gain,
    case when _is_left then 0 else _tap_gain end as right_gain
from reverb_taps
