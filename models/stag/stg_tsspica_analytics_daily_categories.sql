--
-- model: STG_TSSPICA_ANALYTICS_DAILY_CATEGORIES
--
-- description: Technical standardization of TSSPICA_analytics_daily_categories data.
--

select
    {{ stg_columns('tsspica_analytics_daily_categories') }}
from {{ ref('tsspica_analytics_daily_categories') }} t1