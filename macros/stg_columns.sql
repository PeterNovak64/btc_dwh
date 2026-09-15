{% macro stg_columns(land_object_name) %}

    {% if execute %}

        {% set sql %}
            SELECT
                so.OBJECT_ID,
                ss.COLUMN_NAME,
                cfg.STG_COLUMN_NAME,
                ss.ORDINAL_POSITION,
                ss.COLUMN_SIGNATURE,
                cfg.TEXT_STANDARDIZATION
            FROM META.SOURCE_OBJECT so
            INNER JOIN META.SOURCE_STRUCTURE ss
                ON ss.OBJECT_ID = so.OBJECT_ID
            INNER JOIN META.STG_COLUMN_CONFIG cfg
                ON cfg.OBJECT_ID = ss.OBJECT_ID
               AND cfg.COLUMN_NAME = ss.COLUMN_NAME
            WHERE so.LAND_OBJECT_NAME = '{{ land_object_name }}'
              AND so.STATUS = 'ACTIVE'
              AND cfg.INCLUDE_IN_STG = 1
              AND ss.COLUMN_NAME NOT LIKE 'LND_%'
            ORDER BY ss.ORDINAL_POSITION
        {% endset %}

        {% set result = run_query(sql) %}

        {% if result.rows | length == 0 %}
            {{ exceptions.raise_compiler_error(
                "STG_COLUMN_CONFIG not found or no columns included for LAND object: "
                ~ land_object_name
            ) }}
        {% endif %}

        {% for row in result.rows %}

            {% set column_name = row[1] %}
            {% set stg_column_name = row[2] %}
            {% set signature = row[4] | upper %}
            {% set text_standardization = row[5] | upper %}

            {% set is_text =
                signature.startswith('VARCHAR')
                or signature.startswith('NVARCHAR')
                or signature.startswith('CHAR')
                or signature.startswith('NCHAR')
            %}

            {% if is_text %}

                {% if text_standardization == 'LOWER' %}

                    LOWER(NULLIF(TRIM(t1.[{{ column_name }}]), ''))

                {% elif text_standardization == 'UPPER' %}

                    UPPER(NULLIF(TRIM(t1.[{{ column_name }}]), ''))

                {% else %}

                    NULLIF(TRIM(t1.[{{ column_name }}]), '')

                {% endif %}

            {% else %}

                t1.[{{ column_name }}]

            {% endif %}

            AS [{{ stg_column_name }}]

            {% if not loop.last %},{% endif %}

        {% endfor %}

    {% endif %}

{% endmacro %}
