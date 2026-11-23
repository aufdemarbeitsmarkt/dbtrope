{#- Enough reflections that the reverb blurs rather than echoes, few enough to stay quick. #}
{%- set reverb_tap_count = 24 %}
{#- The first reflection arrives this long after the dry sound. #}
{%- set reverb_predelay_seconds = 0.02 %}

with instruments as (
    select
        piece_id,
        instrument_name,
        delay_seconds,
        delay_feedback,
        delay_repeats,
        reverb_seconds,
        reverb_mix
    from {{ ref('piece_instruments') }}
),

dry_taps as (
    select
        piece_id,
        instrument_name,
        'dry' as effect_name,
        0 as tap_index,
        0.0 as delay_seconds,
        1.0 as left_gain,
        1.0 as right_gain
    from instruments
),

delay_tap_indexes as (
    select
        piece_id,
        instrument_name,
        delay_seconds,
        delay_feedback,
        unnest(range(1, delay_repeats + 1)) as tap_index
    from instruments
    where delay_seconds is not null
),

-- echo n comes n delay times after the dry sound, at feedback to the power n
delay_taps as (
    select
        piece_id,
        instrument_name,
        'delay' as effect_name,
        tap_index,
        (delay_seconds * tap_index) as delay_seconds,
        pow(delay_feedback, tap_index) as left_gain,
        pow(delay_feedback, tap_index) as right_gain
    from delay_tap_indexes
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
    from instruments,
        range(1, {{ reverb_tap_count }} + 1) as taps(tap_index)
    where reverb_seconds is not null
),

reverb_taps as (
    select
        piece_id,
        instrument_name,
        'reverb' as effect_name,
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
    effect_name,
    tap_index,
    delay_seconds,
    left_gain,
    right_gain
from dry_taps

union all

select
    piece_id,
    instrument_name,
    effect_name,
    tap_index,
    delay_seconds,
    left_gain,
    right_gain
from delay_taps

union all

select
    piece_id,
    instrument_name,
    effect_name,
    tap_index,
    delay_seconds,
    case when _is_left then _tap_gain else 0 end as left_gain,
    case when _is_left then 0 else _tap_gain end as right_gain
from reverb_taps
