{#
    The body of every stored instrument model. The instrument is written in
    the model's YAML under config.meta; instrument() serialises it to a JSON
    literal and does nothing else.
#}
{% macro instrument() %}
select
    '{{ this.name }}' as instrument_name,
    '{{ tojson(config.get("meta") or {}) | replace("'", "''") }}'::json as definition
{% endmacro %}
