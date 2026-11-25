{#-
    Every effect, as a map from its name to the model that builds its taps.
    The effect models are the models in models/intermediate/effects/, and each
    declares its name with config(meta={'effect_name': ...}), so the name
    lives beside the effect's logic. The graph is only filled in when dbt
    executes, so this is empty while parsing.
#}
{% macro effect_models() %}
    {%- set effect_models = {} %}
    {%- if execute %}
        {%- for node in graph.nodes.values() if node.resource_type == 'model' and node.original_file_path.startswith('models/intermediate/effects/') %}
            {%- set effect_name = node.config.meta.get('effect_name') %}
            {%- if not effect_name %}
                {{ exceptions.raise_compiler_error(node.name ~ " is an effect model, so declare its name with config(meta={'effect_name': ...}).") }}
            {%- endif %}
            {%- do effect_models.update({effect_name: node.name}) %}
        {%- endfor %}
    {%- endif %}
    {{ return(effect_models) }}
{% endmacro %}
