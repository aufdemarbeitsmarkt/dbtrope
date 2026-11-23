{#
    Runs at the start of dbt build and dbt run (see on-run-start in
    dbt_project.yml). Rendering is the slow part of a build, so the piece
    var must say what to render: a piece name, a path to a .yml file, or
    `all`. Leaving it out stops the run before anything is built, rather
    than rendering every piece in pieces/ by accident.

    parse, compile, ls, show and docs don't render, so they don't need it.
#}
{% macro require_piece() %}
    {%- if execute and flags.WHICH in ('build', 'run') and not var('piece') %}
        {{ exceptions.raise_compiler_error(
            "Choose what to render with the piece var: a piece name "
            ~ "(--vars '{piece: nocturne}'), a path to a .yml file "
            ~ "(--vars '{piece: ~/sketches/idea.yml}') or every piece in "
            ~ var('pieces_dir') ~ "/ (--vars '{piece: all}'). "
            ~ "With make: make build PIECE=nocturne, or PIECE=all."
        ) }}
    {%- endif %}
{% endmacro %}
