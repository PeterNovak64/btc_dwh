--
-- model: STG_TSSPICA_ANALYTICS_USER
--
-- description: Technical standardization of TSSPICA_analytics_user data.
--

select
    {{ stg_columns('tsspica_analytics_user') }}
from {{ ref('tsspica_analytics_user') }} t1