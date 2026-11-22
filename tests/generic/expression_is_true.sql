{#
    Fails for each row where `<column> <expression>` is not true.
    On a model rather than a column, the expression is checked on its own.
#}
{% test expression_is_true(model, expression, column_name=none) %}

select *
from {{ model }}
where not ({{ column_name if column_name is not none else '' }} {{ expression }})

{% endtest %}
