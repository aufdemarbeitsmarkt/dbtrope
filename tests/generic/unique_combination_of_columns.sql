{# Fails for each combination of the columns that appears more than once. #}
{% test unique_combination_of_columns(model, combination_of_columns) %}

select
    {{ combination_of_columns | join(',\n    ') }},
    count(*) as row_count
from {{ model }}
group by all
having count(*) > 1

{% endtest %}
