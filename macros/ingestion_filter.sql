--
--  macros/ingestion_filter.sql
--

{% macro ingestion_filter(land_object_name) %}

    {% if execute %}

        {% set sql %}
            SELECT
                LOAD_TYPE,
                WATERMARK_COLUMN,
                WATERMARK_OVERLAP_DAY
            FROM META.SOURCE_OBJECT
            WHERE LAND_OBJECT_NAME = '{{ land_object_name }}'
              AND STATUS = 'ACTIVE'
        {% endset %}

        {% set result = run_query(sql) %}

        {% if result.rows | length == 0 %}
            {{ exceptions.raise_compiler_error(
                "SOURCE_OBJECT not found: " ~ land_object_name
            ) }}
        {% endif %}

        {% set load_type = result.rows[0][0] %}
        {% set watermark_column = result.rows[0][1] %}
        {% set overlap_day = result.rows[0][2] %}

        {% if load_type == 'FULL' %}

            -- brez filtra

        {% elif load_type == 'ROLLING_WINDOW' %}

            {% if watermark_column is none %}
                {{ exceptions.raise_compiler_error(
                    "WATERMARK_COLUMN is required for ROLLING_WINDOW: "
                    ~ land_object_name
                ) }}
            {% endif %}

            {% if overlap_day is none %}
                {{ exceptions.raise_compiler_error(
                    "WATERMARK_OVERLAP_DAY is required for ROLLING_WINDOW: "
                    ~ land_object_name
                ) }}
            {% endif %}

            WHERE t1.[{{ watermark_column }}] >=
                  DATEADD(
                      DAY,
                      -{{ overlap_day }},
                      CAST(GETDATE() AS date)
                  )
              AND t1.[{{ watermark_column }}] <
                  CAST(GETDATE() AS date)

        {% else %}

            {{ exceptions.raise_compiler_error(
                "Unsupported LOAD_TYPE: " ~ load_type
                ~ " for " ~ land_object_name
            ) }}

        {% endif %}

    {% endif %}

{% endmacro %}
