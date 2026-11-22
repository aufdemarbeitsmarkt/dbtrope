select
    piece_id,
    instrument_name,
    partial_index,
    frequency_ratio,
    -- scaled so an instrument's partials sum to 1, making instruments equally loud whatever their partial count
    (
        partial_amplitude
        / nullif(sum(partial_amplitude) over (partition by piece_id, instrument_name), 0)
    ) as partial_amplitude
from {{ ref('piece_instrument_partials') }}
