{% macro update_object_row_count() %}

DECLARE @row_count BIGINT;

SELECT
    @row_count = COUNT(*)
FROM {{ this }};

EXEC META.update_object_row_count
     @run_id       = {{ var('run_id') }},
     @object_layer = '{{ this.schema }}',
     @object_name  = '{{ this.identifier }}',
     @row_count    = @row_count;

{% endmacro %}
