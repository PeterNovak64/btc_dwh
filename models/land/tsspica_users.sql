--
-- model: tsspica_users
--
-- description: Landing table for tsspica_users data.
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
        {{ ingestion_columns('tsspica_users') }}
    {% endif %}

from [BTCSQL01\BTC].[TSSPICA].[dbo].[USERS] t1

{% if var('sync_structure', false) %}
    WHERE 1 = 0
{% endif %}
