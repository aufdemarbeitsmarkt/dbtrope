{#
    The body of every piece model. The piece is written in the model's YAML
    under config.meta; compose() serialises it to a JSON literal. base/
    models flatten it with SQL.

    The depends_on lines put each stored instrument the piece uses upstream
    of it, so lineage and `dbt build -s <instrument>+` include the piece. The
    list comes from the generated registry, because YAML isn't visible while
    dbt parses.
#}
{% macro compose() %}
{%- for instrument_name in piece_instrument_uses(this.name) %}
-- depends_on: {{ ref(instrument_name) }}
{%- endfor %}
select
    '{{ this.name }}' as piece_id,
    '{{ tojson(config.get("meta") or {}) | replace("'", "''") }}'::json as score
{% endmacro %}
