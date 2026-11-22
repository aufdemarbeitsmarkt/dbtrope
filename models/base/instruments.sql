{%- set instrument_names = registered_instruments() %}
{%- if execute %}
    {{- assert_registry_current(instrument_names, 'instrument') }}
{%- endif %}

{%- for instrument_name in instrument_names %}
select
    instrument_name,
    definition
from {{ ref(instrument_name) }}
{%- if not loop.last %}
union all
{%- endif %}
{%- endfor %}
