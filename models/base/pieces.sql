{%- set piece_names = registered_pieces() %}
{%- if execute %}
    {{- assert_registry_current(piece_names, 'piece') }}
{%- endif %}

with unioned as (
    {%- for piece_name in piece_names %}
    select
        piece_id,
        score
    from {{ ref(piece_name) }}
    {%- if not loop.last %}
    union all
    {%- endif %}
    {%- endfor %}
)

select
    piece_id,
    coalesce((score ->> 'tempo')::double, 120) as tempo_bpm,
    coalesce(score ->> 'meter', '4/4') as meter,
    split_part(coalesce(score ->> 'meter', '4/4'), '/', 1)::integer as beats_per_bar,
    score
from unioned
