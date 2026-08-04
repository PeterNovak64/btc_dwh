
/*******************************************************************************
 * Procedure: META.refresh_dq_profile
 * Description:
 *   Rebuilds data quality profile records for active source objects and columns.
 *   The procedure generates aggregate values from source LAND objects, inserts
 *   profile results into META.DQ_PROFILE, and avoids duplicate profiling data
 *   for the same run and object.
 *
 * Parameters:
 *   @run_id BIGINT
 *     DWH run identifier for which profile data is generated.
 *
 *   @object_id BIGINT = NULL
 *     Optional object filter. When provided, only the specified object is
 *     re-profiled. When omitted, all active source objects are processed.
 *
 *   @land_schema_name VARCHAR(255) = 'LAND'
 *     Schema containing source LAND objects used for profile aggregation.
 *
 * Behavior:
 *   - Deletes existing META.DQ_PROFILE rows for the run and active objects or
 *     for the specific object if @object_id is provided.
 *   - Iterates active source objects using a cursor.
 *   - Builds dynamic aggregation expressions for enabled profile rules:
 *       ROW_COUNT, NULL_COUNT, NULL_PCT, DISTINCT_COUNT, DISTINCT_PCT.
 *   - Skips DISTINCT_* rules for unsupported or expensive types such as
 *     VARBINARY, BINARY, IMAGE, XML, TEXT, NTEXT, SQL_VARIANT.
 *   - Inserts computed profile values into META.DQ_PROFILE.
 *
 * Inserts into: META.DQ_PROFILE
 * Reads from:   META.SOURCE_OBJECT, META.SOURCE_PROFILE_RULE,
 *               META.SOURCE_STRUCTURE, [LAND].<object>
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[refresh_dq_profile]    Script Date: 4. 08. 2026 09:27:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--
--  izpolni DQ_PROFILE
CREATE OR ALTER   PROCEDURE [META].[refresh_dq_profile]
(
      @run_id            BIGINT
    , @object_id         BIGINT = NULL
    , @land_schema_name  VARCHAR(255) = 'LAND'
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
          @current_object_id     BIGINT
        , @land_object_name      VARCHAR(255)
        , @object_name           VARCHAR(255)
        , @sql                   NVARCHAR(MAX)
        , @aggregate_list        NVARCHAR(MAX)
        , @values_list           NVARCHAR(MAX)
        , @separator             NVARCHAR(10)
        , @crlf                  NCHAR(2);

    SET @crlf = NCHAR(13) + NCHAR(10);
    SET @separator = N',' + @crlf;

    ----------------------------------------------------------------------
    -- Idempotentnost:
    -- za isti RUN_ID in isti objekt ne podvajamo rezultatov.
    ----------------------------------------------------------------------

    IF @object_id IS NULL
    BEGIN

        DELETE DP
        FROM META.DQ_PROFILE DP
        INNER JOIN META.SOURCE_OBJECT SO
            ON SO.OBJECT_ID = DP.OBJECT_ID
        WHERE DP.RUN_ID = @run_id
          AND SO.STATUS = 'ACTIVE';

    END
    ELSE
    BEGIN

        DELETE FROM META.DQ_PROFILE
        WHERE RUN_ID = @run_id
          AND OBJECT_ID = @object_id;

    END;

    ----------------------------------------------------------------------
    -- Cursor po aktivnih LAND objektih.
    ----------------------------------------------------------------------

    DECLARE object_cursor CURSOR LOCAL FAST_FORWARD FOR

        SELECT
              SO.OBJECT_ID
            , SO.LAND_OBJECT_NAME
            , SO.OBJECT_NAME
        FROM META.SOURCE_OBJECT SO
        WHERE SO.STATUS = 'ACTIVE'
          AND
          (
                @object_id IS NULL
             OR SO.OBJECT_ID = @object_id
          )
        ORDER BY
              SO.OBJECT_ID;

    OPEN object_cursor;

    FETCH NEXT FROM object_cursor
    INTO
          @current_object_id
        , @land_object_name
        , @object_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        SET @aggregate_list = NULL;
        SET @values_list = NULL;
        SET @sql = NULL;

        ------------------------------------------------------------------
        -- Priprava izrazov za trenutni objekt.
        --
        -- To je namenoma v začasni tabeli, ker SQL Server ne mara več
        -- ordered STRING_AGG funkcij v istem scope-u.
        ------------------------------------------------------------------

        DROP TABLE IF EXISTS #PROFILE_RULE_EXPRESSIONS;

        CREATE TABLE #PROFILE_RULE_EXPRESSIONS
        (
              RULE_ID             BIGINT NOT NULL
            , RULE_ORDER          INT NULL
            , ORDINAL_POSITION    INT NULL
            , AGG_EXPR            NVARCHAR(MAX) NULL
            , VALUE_EXPR          NVARCHAR(MAX) NULL
        );

        ;WITH RULES AS
        (
            SELECT
                  R.RULE_ID
                , R.OBJECT_ID
                , R.COLUMN_NAME
                , R.RULE_SCOPE
                , R.RULE_TYPE
                , R.RULE_NAME
                , R.RULE_ORDER

                , SS.ORDINAL_POSITION
                , SS.COLUMN_SIGNATURE

                , 'VAL_' + CAST(R.RULE_ID AS VARCHAR(30)) AS VALUE_ALIAS

                , CASE
                      WHEN R.RULE_TYPE IN ('NULL_PCT', 'DISTINCT_PCT')
                          THEN 'PCT'
                      WHEN R.RULE_TYPE IN ('ROW_COUNT', 'NULL_COUNT', 'DISTINCT_COUNT')
                          THEN 'COUNT'
                      ELSE NULL
                  END AS PROFILE_UNIT

            FROM META.SOURCE_PROFILE_RULE R

            LEFT JOIN META.SOURCE_STRUCTURE SS
                ON SS.OBJECT_ID = R.OBJECT_ID
               AND SS.COLUMN_NAME = R.COLUMN_NAME

            WHERE R.OBJECT_ID = @current_object_id
              AND R.RULE_ENABLED = 1
              AND R.RULE_TYPE IN
              (
                    'ROW_COUNT'
                  , 'NULL_COUNT'
                  , 'NULL_PCT'
                  , 'DISTINCT_COUNT'
                  , 'DISTINCT_PCT'
              )

              AND
              (
                    R.RULE_SCOPE = 'OBJECT'
                 OR
                    (
                        R.RULE_SCOPE = 'COLUMN'
                        AND SS.COLUMN_NAME IS NOT NULL
                    )
              )

              -- DISTINCT pravil ne izvajamo na tipih, kjer to ni smiselno
              -- oziroma je lahko zelo drago ali problematično.
              AND NOT
              (
                    R.RULE_TYPE IN ('DISTINCT_COUNT', 'DISTINCT_PCT')
                AND
                    (
                           SS.COLUMN_SIGNATURE LIKE 'VARBINARY%'
                        OR SS.COLUMN_SIGNATURE LIKE 'BINARY%'
                        OR SS.COLUMN_SIGNATURE LIKE 'IMAGE%'
                        OR SS.COLUMN_SIGNATURE LIKE 'XML%'
                        OR SS.COLUMN_SIGNATURE LIKE 'TEXT%'
                        OR SS.COLUMN_SIGNATURE LIKE 'NTEXT%'
                        OR SS.COLUMN_SIGNATURE LIKE 'SQL_VARIANT%'
                    )
              )
        ),
        AGGREGATES AS
        (
            SELECT
                  RULE_ID
                , RULE_ORDER
                , ORDINAL_POSITION

                ----------------------------------------------------------
                -- Dinamični agregatni izraz
                ----------------------------------------------------------

                , CONVERT
                  (
                      NVARCHAR(MAX),
                      CASE
                          WHEN RULE_TYPE = 'ROW_COUNT'
                              THEN NULL

                          WHEN RULE_TYPE = 'NULL_COUNT'
                              THEN
                                  N'    SUM(CASE WHEN '
                                  + QUOTENAME(COLUMN_NAME)
                                  + N' IS NULL THEN CONVERT(BIGINT,1) ELSE CONVERT(BIGINT,0) END) AS '
                                  + QUOTENAME(VALUE_ALIAS)

                          WHEN RULE_TYPE = 'NULL_PCT'
                              THEN
                                  N'    CAST(CASE WHEN COUNT_BIG(1) = 0 THEN 0 ELSE '
                                  + N'100.0 * '
                                  + N'SUM(CASE WHEN '
                                  + QUOTENAME(COLUMN_NAME)
                                  + N' IS NULL THEN CONVERT(DECIMAL(38,10),1) ELSE CONVERT(DECIMAL(38,10),0) END) '
                                  + N'/ CONVERT(DECIMAL(38,10), COUNT_BIG(1)) '
                                  + N'END AS DECIMAL(38,10)) AS '
                                  + QUOTENAME(VALUE_ALIAS)

                          WHEN RULE_TYPE = 'DISTINCT_COUNT'
                              THEN
                                  N'    COUNT_BIG(DISTINCT '
                                  + QUOTENAME(COLUMN_NAME)
                                  + N') AS '
                                  + QUOTENAME(VALUE_ALIAS)

                          WHEN RULE_TYPE = 'DISTINCT_PCT'
                              THEN
                                  N'    CAST(CASE WHEN COUNT_BIG(1) = 0 THEN 0 ELSE '
                                  + N'100.0 * CONVERT(DECIMAL(38,10), COUNT_BIG(DISTINCT '
                                  + QUOTENAME(COLUMN_NAME)
                                  + N')) / CONVERT(DECIMAL(38,10), COUNT_BIG(1)) '
                                  + N'END AS DECIMAL(38,10)) AS '
                                  + QUOTENAME(VALUE_ALIAS)

                          ELSE NULL
                      END
                  ) AS AGG_EXPR

                ----------------------------------------------------------
                -- VALUES vrstica za insert v DQ_PROFILE
                ----------------------------------------------------------

                , CONVERT
                  (
                      NVARCHAR(MAX),
                      N'('
                      + CAST(RULE_ID AS NVARCHAR(30))

                      + N', '
                      + N'''' + REPLACE(ISNULL(COLUMN_NAME, ''), '''', '''''') + N''''

                      + N', '
                      + N'''' + RULE_SCOPE + N''''

                      + N', '
                      + N'''' + RULE_TYPE + N''''

                      + N', '
                      + N'''' + REPLACE(RULE_NAME, '''', '''''') + N''''

                      + N', '
                      + COALESCE(CAST(RULE_ORDER AS NVARCHAR(20)), N'NULL')

                      + N', '
                      + CASE
                            WHEN RULE_TYPE = 'ROW_COUNT'
                                THEN N'CONVERT(DECIMAL(38,10), A.ROW_COUNT)'
                            ELSE N'CONVERT(DECIMAL(38,10), A.' + QUOTENAME(VALUE_ALIAS) + N')'
                        END

                      + N', '
                      + N'CAST(NULL AS VARCHAR(4000))'

                      + N', '
                      + CASE
                            WHEN PROFILE_UNIT IS NULL
                                THEN N'NULL'
                            ELSE N'''' + PROFILE_UNIT + N''''
                        END

                      + N')'
                  ) AS VALUE_EXPR

            FROM RULES
        )
        INSERT INTO #PROFILE_RULE_EXPRESSIONS
        (
              RULE_ID
            , RULE_ORDER
            , ORDINAL_POSITION
            , AGG_EXPR
            , VALUE_EXPR
        )
        SELECT
              RULE_ID
            , RULE_ORDER
            , ORDINAL_POSITION
            , AGG_EXPR
            , VALUE_EXPR
        FROM AGGREGATES
        WHERE VALUE_EXPR IS NOT NULL;

        ------------------------------------------------------------------
        -- STRING_AGG za agregatne izraze.
        -- Ločeno zaradi SQL Server omejitve Msg 8711.
        ------------------------------------------------------------------

        SELECT
            @aggregate_list =
                STRING_AGG
                (
                    CONVERT(NVARCHAR(MAX), AGG_EXPR),
                    @separator
                )
                WITHIN GROUP
                (
                    ORDER BY
                          ISNULL(RULE_ORDER, 999)
                        , ISNULL(ORDINAL_POSITION, 0)
                        , RULE_ID
                )
        FROM #PROFILE_RULE_EXPRESSIONS
        WHERE AGG_EXPR IS NOT NULL;

        ------------------------------------------------------------------
        -- STRING_AGG za VALUES izraze.
        -- Ločeno zaradi SQL Server omejitve Msg 8711.
        ------------------------------------------------------------------

        SELECT
            @values_list =
                STRING_AGG
                (
                    CONVERT(NVARCHAR(MAX), VALUE_EXPR),
                    @separator
                )
                WITHIN GROUP
                (
                    ORDER BY
                          ISNULL(RULE_ORDER, 999)
                        , ISNULL(ORDINAL_POSITION, 0)
                        , RULE_ID
                )
        FROM #PROFILE_RULE_EXPRESSIONS
        WHERE VALUE_EXPR IS NOT NULL;

        ------------------------------------------------------------------
        -- Če ni pravil, objekt preskočimo.
        ------------------------------------------------------------------

        IF @values_list IS NOT NULL
        BEGIN

            SET @sql = N'
SET ANSI_WARNINGS OFF;

;WITH A AS
(
    SELECT
          COUNT_BIG(1) AS ROW_COUNT'
            + CASE
                  WHEN @aggregate_list IS NOT NULL
                      THEN N',' + @crlf + @aggregate_list
                  ELSE N''
              END
            + @crlf
            + N'    FROM '
            + QUOTENAME(@land_schema_name)
            + N'.'
            + QUOTENAME(@land_object_name)
            + N'
)
INSERT INTO META.DQ_PROFILE
(
      RUN_ID
    , RULE_ID
    , OBJECT_ID
    , OBJECT_NAME
    , COLUMN_NAME
    , RULE_SCOPE
    , RULE_TYPE
    , RULE_NAME
    , RULE_ORDER
    , PROFILE_VALUE_NUMERIC
    , PROFILE_VALUE_TEXT
    , PROFILE_UNIT
)
SELECT
      @p_run_id
    , V.RULE_ID
    , @p_object_id
    , @p_object_name
    , NULLIF(V.COLUMN_NAME, '''')
    , V.RULE_SCOPE
    , V.RULE_TYPE
    , V.RULE_NAME
    , V.RULE_ORDER
    , V.PROFILE_VALUE_NUMERIC
    , V.PROFILE_VALUE_TEXT
    , V.PROFILE_UNIT
FROM A
CROSS APPLY
(
    VALUES
'
            + @values_list
            + N'
) AS V
(
      RULE_ID
    , COLUMN_NAME
    , RULE_SCOPE
    , RULE_TYPE
    , RULE_NAME
    , RULE_ORDER
    , PROFILE_VALUE_NUMERIC
    , PROFILE_VALUE_TEXT
    , PROFILE_UNIT
);

SET ANSI_WARNINGS ON;
';

            EXEC sys.sp_executesql
                  @sql
                , N'
                      @p_run_id BIGINT,
                      @p_object_id BIGINT,
                      @p_object_name VARCHAR(255)
                  '
                , @p_run_id = @run_id
                , @p_object_id = @current_object_id
                , @p_object_name = @land_object_name;

        END;

        FETCH NEXT FROM object_cursor
        INTO
              @current_object_id
            , @land_object_name
            , @object_name;

    END;

    CLOSE object_cursor;
    DEALLOCATE object_cursor;

END;
GO


