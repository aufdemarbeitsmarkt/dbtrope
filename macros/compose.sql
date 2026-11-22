{#
    The body of every piece model. The piece is written in the model's YAML
    under config.meta; compose() serialises it to a JSON literal and does
    nothing else. base/ models flatten it with SQL.
#}
{% macro compose() %}
select
    '{{ this.name }}' as piece_id,
    '{{ tojson(config.get("meta") or {}) | replace("'", "''") }}'::json as score
{% endmacro %}
