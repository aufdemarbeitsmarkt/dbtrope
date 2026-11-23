{%- set sample_rate = var('sample_rate') %}
{#- Normalise each piece to just under full scale (about -1 dBFS). #}
{%- set peak_amplitude = 0.89 %}

with instrument_samples as (
    select
        piece_id,
        instrument_name,
        sample_index,
        left_amplitude,
        right_amplitude
    from {{ ref('instrument_samples') }}
),

effect_taps as (
    select
        piece_id,
        instrument_name,
        round(delay_seconds * {{ sample_rate }})::bigint as delay_sample_count,
        left_gain,
        right_gain
    from {{ ref('int_instruments__effect_taps') }}
),

-- the dry sound, every echo and every reverb reflection, each a shifted, scaled copy of its instrument's samples
tapped_samples as (
    select
        instrument_samples.piece_id,
        (instrument_samples.sample_index + effect_taps.delay_sample_count) as sample_index,
        (instrument_samples.left_amplitude * effect_taps.left_gain) as _left_amplitude,
        (instrument_samples.right_amplitude * effect_taps.right_gain) as _right_amplitude
    from instrument_samples
    join effect_taps
        on effect_taps.piece_id = instrument_samples.piece_id
        and effect_taps.instrument_name = instrument_samples.instrument_name
),

summed_samples as (
    select
        piece_id,
        sample_index,
        sum(_left_amplitude) as _left_amplitude,
        sum(_right_amplitude) as _right_amplitude
    from tapped_samples
    group by
        piece_id,
        sample_index
),

written_lengths as (
    select
        piece_id,
        ceil(max(start_seconds + duration_seconds) * {{ sample_rate }})::bigint as sample_count
    from {{ ref('int_events__timed') }}
    group by piece_id
),

sounding_lengths as (
    select
        piece_id,
        (max(sample_index) + 1) as sample_count
    from summed_samples
    group by piece_id
),

-- a piece lasts until its last event ends, rests included, or its last release or echo fades, whichever is later
piece_lengths as (
    select
        written_lengths.piece_id,
        greatest(
            written_lengths.sample_count,
            coalesce(sounding_lengths.sample_count, 0)
        ) as sample_count
    from written_lengths
    left join sounding_lengths
        on sounding_lengths.piece_id = written_lengths.piece_id
),

-- rests and gaps between notes have no rows in summed_samples; all_samples fills them with silence
all_samples as (
    select
        piece_id,
        unnest(range(sample_count)) as sample_index
    from piece_lengths
),

dense_samples as (
    select
        all_samples.piece_id,
        all_samples.sample_index,
        coalesce(summed_samples._left_amplitude, 0) as _left_amplitude,
        coalesce(summed_samples._right_amplitude, 0) as _right_amplitude
    from all_samples
    left join summed_samples
        on summed_samples.piece_id = all_samples.piece_id
        and summed_samples.sample_index = all_samples.sample_index
),

-- both channels share one gain, so normalising keeps the stereo balance
piece_gains as (
    select
        piece_id,
        ({{ peak_amplitude }} / nullif(max(greatest(abs(_left_amplitude), abs(_right_amplitude))), 0)) as _gain
    from dense_samples
    group by piece_id
)

select
    dense_samples.piece_id,
    dense_samples.sample_index,
    coalesce(dense_samples._left_amplitude * piece_gains._gain, 0) as left_amplitude,
    coalesce(dense_samples._right_amplitude * piece_gains._gain, 0) as right_amplitude
from dense_samples
join piece_gains
    on piece_gains.piece_id = dense_samples.piece_id
