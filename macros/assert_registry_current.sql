{#
    Fails the run when the generated registry (macros/registry.sql) doesn't
    list exactly the project's models tagged `tag`. Call it inside
    `if execute`, where `graph` is populated.
#}
{% macro assert_registry_current(registered, tag) %}
    {%- set in_project = [] %}
    {%- for node in graph.nodes.values() %}
        {%- if node.resource_type == 'model' and node.package_name == project_name and tag in node.tags %}
            {%- do in_project.append(node.name) %}
        {%- endif %}
    {%- endfor %}

    {%- if in_project | sort != registered | sort %}
        {{ exceptions.raise_compiler_error(
            "The " ~ tag ~ " registry is out of date. Registered: " ~ (registered | sort | join(', '))
            ~ "; in the project: " ~ (in_project | sort | join(', '))
            ~ ". Run `make registry`."
        ) }}
    {%- endif %}
{% endmacro %}
