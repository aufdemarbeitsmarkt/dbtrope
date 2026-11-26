{#- Rows come from dbt's graph (macros/effect_models.sql), so the registry can't drift from the effect models. #}
{%- set effect_models = effect_models() %}

-- one row per model in intermediate/effects/, named as the model declares
{%- for effect_name, effect_model in effect_models | dictsort %}
select
    '{{ effect_name }}' as effect_name,
    '{{ effect_model.name }}' as model_name,
    '{{ effect_model.description | trim | replace("'", "''") }}' as description
{%- if not loop.last %}

union all
{% endif %}
{%- else %}
select
    null::varchar as effect_name,
    null::varchar as model_name,
    null::varchar as description
where false
{%- endfor %}
