--
--  procedure: initialize_stg_column_config
--  This procedure initializes the STG_COLUMN_CONFIG table based on the SOURCE_STRUCTURE and SOURCE_OBJECT tables, 
--  taking into account the DQ_PROFILE for null percentage checks. 
--  It inserts new records for active source objects and their columns that are not already present in the STG_COLUMN_CONFIG table, setting the INCLUDE_IN_STG flag based on the null percentage profile value.
--

CREATE OR ALTER PROCEDURE META.initialize_stg_column_config
    @RUN_ID bigint
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO META.STG_COLUMN_CONFIG
    (
        OBJECT_ID,
        COLUMN_NAME,
        STG_COLUMN_NAME,
        INCLUDE_IN_STG,
        TEXT_STANDARDIZATION
    )
    SELECT
        ss.OBJECT_ID,
        ss.COLUMN_NAME,
        ss.COLUMN_NAME AS STG_COLUMN_NAME,
        CASE
            WHEN dp.PROFILE_VALUE_NUMERIC < 1 THEN 1
            ELSE 0
        END AS INCLUDE_IN_STG,
        'NONE' AS TEXT_STANDARDIZATION
    FROM META.SOURCE_STRUCTURE ss
    INNER JOIN META.SOURCE_OBJECT so
        ON so.OBJECT_ID = ss.OBJECT_ID
    LEFT JOIN META.DQ_PROFILE dp
        ON dp.OBJECT_ID = ss.OBJECT_ID
       AND dp.COLUMN_NAME = ss.COLUMN_NAME
       AND dp.RUN_ID = @RUN_ID
       AND dp.RULE_TYPE = 'NULL_PCT'
    WHERE so.STATUS = 'ACTIVE'
      AND ss.COLUMN_NAME NOT LIKE 'LND_%'
      AND NOT EXISTS
      (
          SELECT 1
          FROM META.STG_COLUMN_CONFIG cfg
          WHERE cfg.OBJECT_ID = ss.OBJECT_ID
            AND cfg.COLUMN_NAME = ss.COLUMN_NAME
      );
END;
GO
