{% test is_effect_name(model, column_name, also=[]) %}

-- the names the effect models declare (macros/effect_models.sql), plus any in also
with effect_names as (
    select unnest({{ (effect_models().keys() | list + also) | sort }}::varchar[]) as effect_name
)

select *
from {{ model }}
where {{ column_name }} not in (
    select effect_name
    from effect_names
)

{% endtest %}
