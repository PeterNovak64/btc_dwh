--
-- model: stg_tsspica_users_raw
-- description: This model is a staging table for tsspica_users data. It selects only used columns from the tsspica_users source table and prepares it for further transformations.
--

SELECT  LND_SRC_SYSTEM,
        LND_LOAD_TS,
        LND_RUN_ID,
        NO,
        LASTNAME,
        FIRSTNAME,
        ADDRESS,
        CITY,
        STATE,
        PHONE,
        MOBILEPHONE, 
        FAX, 
        ID, 
        DEPARTMENT,
        SUBDEPARTMENT,
        DIVISION,
        HOST,
        EMAIL,
        ORGNO,
        ADDITIONAL_FIELD_1,
        ADDITIONAL_FIELD_2,
        BLOCKED,
        ACTIVE
    FROM {{ ref('tsspica_users') }};