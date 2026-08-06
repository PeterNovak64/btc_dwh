/****** Object:  StoredProcedure [META].[refresh_source_object]    Script Date: 6. 08. 2026 15:54:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER   PROCEDURE [META].[refresh_source_object]
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @NOW DATETIME2(0);

    SET @NOW = SYSDATETIME();

    ------------------------------------------------------------------
    -- REGISTRACIJA NOVIH LAND OBJEKTOV
    ------------------------------------------------------------------

    INSERT INTO META.SOURCE_OBJECT
    (
          SOURCE_SYSTEM
        , SERVER_NAME
        , DATABASE_NAME
        , SCHEMA_NAME
        , OBJECT_NAME

        , LAND_OBJECT_NAME

        , OBJECT_TYPE
        , DWH_LAYER
        , OBJECT_ORIGIN

        , STATUS

        , LAST_SEEN_TS

        , CREATED_TS
    )
    SELECT
          LEFT(T.NAME, CHARINDEX('_', T.NAME) - 1)

        , NULL
        , NULL
        , NULL

        , SUBSTRING
          (
                T.NAME
              , CHARINDEX('_', T.NAME) + 1
              , LEN(T.NAME)
          )

        , T.NAME

        , 'TABLE'
        , 'LAND'
        , 'SOURCE'

        , 'ACTIVE'

        , @NOW

        , @NOW

    FROM SYS.TABLES T
    INNER JOIN SYS.SCHEMAS S
        ON S.SCHEMA_ID = T.SCHEMA_ID
    WHERE S.NAME = 'LAND'
      AND CHARINDEX('_', T.NAME) > 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM META.SOURCE_OBJECT SO
          WHERE SO.DWH_LAYER = 'LAND'
            AND SO.LAND_OBJECT_NAME = T.NAME

      );

    ------------------------------------------------------------------
    -- OBSTOJEČI LAND OBJEKTI SO BILI PONOVNO VIDENI
    ------------------------------------------------------------------

    UPDATE SO
       SET STATUS          = 'ACTIVE'
         , LAST_SEEN_TS    = @NOW
         , DWH_LAYER       = 'LAND'
         , OBJECT_ORIGIN   = 'SOURCE'
    FROM META.SOURCE_OBJECT SO
    INNER JOIN SYS.TABLES T
        ON T.NAME = SO.LAND_OBJECT_NAME
    INNER JOIN SYS.SCHEMAS S
        ON S.SCHEMA_ID = T.SCHEMA_ID
    WHERE S.NAME = 'LAND';

    ------------------------------------------------------------------
    -- LAND OBJEKTI KI SO IZGINILI
    ------------------------------------------------------------------

    UPDATE SO
       SET STATUS = 'MISSING'
    FROM META.SOURCE_OBJECT SO
    WHERE SO.DWH_LAYER = 'LAND'
      AND SO.STATUS = 'ACTIVE'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SYS.TABLES T
          INNER JOIN SYS.SCHEMAS S
              ON S.SCHEMA_ID = T.SCHEMA_ID
          WHERE S.NAME = 'LAND'
            AND T.NAME = SO.LAND_OBJECT_NAME
      );

END;
GO


