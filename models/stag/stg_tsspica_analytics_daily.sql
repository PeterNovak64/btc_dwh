--
-- model: STG_TSSPICA_ANALYTICS_DAILY
--
-- description: Technical standardization of TSSPICA_analytics_daily data.
--

select
    {{ stg_columns('tsspica_analytics_daily') }}
from {{ ref('tsspica_analytics_daily') }} t1