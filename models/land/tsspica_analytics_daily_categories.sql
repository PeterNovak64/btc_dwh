--
-- model: tsspica_analytics_daily_categories
--
-- description: Landing table for tsspica_analytics_daily_categories data.
--              sync_structure mode creates/synchronizes the LAND structure.
--              Normal mode loads columns defined by source metadata.
--

select
    'TSSPICA' as LND_SRC_SYSTEM,
    SYSDATETIME() AS LND_LOAD_TS,
    {{ var('run_id') }} AS LND_RUN_ID,

    {% if var('sync_structure', false) %}

        t1.*

    {% else %}

        {{ ingestion_columns('tsspica_analytics_daily_categories') }}

    {% endif %}

from [BTCSQL01\BTC].[TSSPICA].[dbo].[ANALYTICS_DAILY_CATEGORIES] t1

{% if var('sync_structure', false) %}

    WHERE 1 = 0

{% else %}

    {{ ingestion_filter('tsspica_analytics_daily_categories') }}

{% endif %}