{% test unique_combination_of_columns(model, combination_of_columns) %}
-- Fails if any combination of the given columns appears more than once.
SELECT
    {{ combination_of_columns | join(', ') }},
    COUNT(*) AS n
FROM {{ model }}
GROUP BY {{ combination_of_columns | join(', ') }}
HAVING COUNT(*) > 1
{% endtest %}
