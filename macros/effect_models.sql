{#-
    Every effect, as a map from its name to the model that builds its taps.
    Each effect model declares its name with config(meta={'effect_name': ...}),
    so the name lives beside the effect's logic. The graph is only filled in
    when dbt executes, so this is empty while parsing.
#}
{% macro effect_models() %}
    {%- set effect_models = {} %}
    {%- if execute %}
        {%- for node in graph.nodes.values() if node.resource_type == 'model' and node.config.meta.get('effect_name') %}
            {%- do effect_models.update({node.config.meta['effect_name']: node.name}) %}
        {%- endfor %}
    {%- endif %}
    {{ return(effect_models) }}
{% endmacro %}
