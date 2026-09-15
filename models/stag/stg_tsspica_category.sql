--
-- model: STG_TSSPICA_CATEGORY
--
-- description: Technical standardization of TSSPICA categories.
--

select
    {{ stg_columns('tsspica_category') }}
from {{ ref('tsspica_category') }} t1