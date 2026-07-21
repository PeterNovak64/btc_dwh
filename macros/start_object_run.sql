--
--  macros/start_object_run.sql
--

{% macro start_object_run() %}

EXEC META.start_object_run
     @run_id       = {{ var('run_id') }},
     @object_layer = '{{ this.schema }}',
     @object_name  = '{{ this.identifier }}'

{% endmacro %}
