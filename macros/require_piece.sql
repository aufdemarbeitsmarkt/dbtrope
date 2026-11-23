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
