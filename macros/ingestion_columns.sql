--
-- macros/ingestion_columns.sql
--

{% macro ingestion_columns(land_object_name) %}

    {% set sql %}
        SELECT
            so.OBJECT_ID,
            ss.COLUMN_NAME,
            ss.ORDINAL_POSITION,
            ss.COLUMN_SIGNATURE
        FROM META.SOURCE_OBJECT so
        INNER JOIN META.SOURCE_STRUCTURE ss
            ON ss.OBJECT_ID = so.OBJECT_ID
        WHERE so.LAND_OBJECT_NAME = '{{ land_object_name }}'
          AND so.STATUS = 'ACTIVE'
          AND ss.COLUMN_NAME NOT LIKE 'LND_%'
        ORDER BY ss.ORDINAL_POSITION
    {% endset %}

    {% set result = run_query(sql) %}

    {% if execute %}

        {% if result.rows | length == 0 %}
            {{ exceptions.raise_compiler_error(
                "SOURCE_STRUCTURE not found for LAND object: " ~ land_object_name
            ) }}
        {% endif %}

        {% for row in result.rows %}

            {% set column_name = row[1] %}
            {% set signature = row[3] | upper %}

            {% if signature.startswith('VARBINARY')
                  or signature.startswith('BINARY')
                  or signature.startswith('IMAGE') %}

                CAST(
                    NULL AS {{ signature.split(' NULL')[0] }}
                ) AS [{{ column_name }}]

            {% else %}

                t1.[{{ column_name }}]

            {% endif %}

            {% if not loop.last %},{% endif %}

        {% endfor %}

    {% else %}

        NULL

    {% endif %}

{% endmacro %}
