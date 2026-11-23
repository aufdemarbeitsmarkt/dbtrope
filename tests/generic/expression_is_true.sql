{% test expression_is_true(model, expression, column_name=none) %}

select *
from {{ model }}
where not ({{ column_name if column_name is not none else '' }} {{ expression }})

{% endtest %}
