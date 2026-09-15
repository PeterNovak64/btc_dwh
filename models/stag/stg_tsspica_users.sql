--
-- model: STG_TSSPICA_USERS
--
-- description: Technical standardization of TSSPICA_users data.
--

select
    {{ stg_columns('tsspica_users') }}
from {{ ref('tsspica_users') }} t1