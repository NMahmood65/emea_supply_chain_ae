{% macro calculate_glec_emissions(distance_km, gross_weight_tonnes, emission_factor_grams) %}
    round(
        ( ({{ distance_km }} * {{ gross_weight_tonnes }}) * {{ emission_factor_grams }} ) / 1000000.0,
        4
    )
{% endmacro %}