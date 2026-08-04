
/*******************************************************************************
 * Procedure: META.refresh_source_profile_rule
 * Description:
 *   Generates default source profiling rules for active source objects and columns.
 *   The procedure is idempotent and only inserts missing baseline rules.
 *
 * Parameters:
 *   @object_id BIGINT = NULL
 *     Optional filter to refresh rules for a single source object. If NULL,
 *     rules are refreshed for all active source objects.
 *
 * Behavior:
 *   - Inserts an OBJECT-level ROW_COUNT rule for each active source object
 *     that does not already have one.
 *   - Inserts COLUMN-level NULL_COUNT and NULL_PCT rules for each active
 *     column that does not already have them.
 *   - Inserts COLUMN-level DISTINCT_COUNT and DISTINCT_PCT rules for each
 *     eligible active column. Columns with binary/blob/text-like signatures are
 *     excluded from DISTINCT_* rule generation.
 *
 * Inserts into: META.SOURCE_PROFILE_RULE
 * Reads from:   META.SOURCE_OBJECT, META.SOURCE_STRUCTURE
 *
 * Notes:
 *   - Existing rules are preserved; no updates or deletes are performed.
 *   - Only objects with STATUS = 'ACTIVE' are processed.
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[refresh_source_profile_rule]    Script Date: 4. 08. 2026 09:33:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


--
--  kreiranje default pravil za profiliranje vhodnih podatkov
CREATE OR ALTER   PROCEDURE [META].[refresh_source_profile_rule]
(
      @object_id BIGINT = NULL
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @now DATETIME2(0);

    SET @now = SYSDATETIME();

    ----------------------------------------------------------------------
    -- ROW_COUNT
    -- 1 pravilo na objekt
    ----------------------------------------------------------------------

    INSERT INTO META.SOURCE_PROFILE_RULE
    (
          OBJECT_ID
        , COLUMN_NAME
        , RULE_SCOPE
        , RULE_NAME
        , RULE_TYPE
        , RULE_ENABLED
        , DESCRIPTION
        , CREATED_TS
    )
    SELECT
          SO.OBJECT_ID
        , NULL
        , 'OBJECT'
        , 'ROW_COUNT'
        , 'ROW_COUNT'
        , 1
        , 'Automatically generated baseline rule'
        , @now
    FROM META.SOURCE_OBJECT SO
    WHERE SO.STATUS = 'ACTIVE'

      AND
      (
            @object_id IS NULL
         OR SO.OBJECT_ID = @object_id
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM META.SOURCE_PROFILE_RULE R
          WHERE R.OBJECT_ID = SO.OBJECT_ID
            AND R.RULE_SCOPE = 'OBJECT'
            AND R.RULE_TYPE = 'ROW_COUNT'
      );

    ----------------------------------------------------------------------
    -- NULL_COUNT
    ----------------------------------------------------------------------

    INSERT INTO META.SOURCE_PROFILE_RULE
    (
          OBJECT_ID
        , COLUMN_NAME
        , RULE_SCOPE
        , RULE_NAME
        , RULE_TYPE
        , RULE_ENABLED
        , DESCRIPTION
        , CREATED_TS
    )
    SELECT
          SS.OBJECT_ID
        , SS.COLUMN_NAME
        , 'COLUMN'
        , CONCAT(SS.COLUMN_NAME, '_NULL_COUNT')
        , 'NULL_COUNT'
        , 1
        , 'Automatically generated baseline rule'
        , @now
    FROM META.SOURCE_STRUCTURE SS
    INNER JOIN META.SOURCE_OBJECT SO
        ON SO.OBJECT_ID = SS.OBJECT_ID

    WHERE SO.STATUS = 'ACTIVE'

      AND
      (
            @object_id IS NULL
         OR SS.OBJECT_ID = @object_id
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM META.SOURCE_PROFILE_RULE R
          WHERE R.OBJECT_ID   = SS.OBJECT_ID
            AND R.COLUMN_NAME = SS.COLUMN_NAME
            AND R.RULE_SCOPE  = 'COLUMN'
            AND R.RULE_TYPE   = 'NULL_COUNT'
      );

    ----------------------------------------------------------------------
    -- NULL_PCT
    ----------------------------------------------------------------------

    INSERT INTO META.SOURCE_PROFILE_RULE
    (
          OBJECT_ID
        , COLUMN_NAME
        , RULE_SCOPE
        , RULE_NAME
        , RULE_TYPE
        , RULE_ENABLED
        , DESCRIPTION
        , CREATED_TS
    )
    SELECT
          SS.OBJECT_ID
        , SS.COLUMN_NAME
        , 'COLUMN'
        , CONCAT(SS.COLUMN_NAME, '_NULL_PCT')
        , 'NULL_PCT'
        , 1
        , 'Automatically generated baseline rule'
        , @now
    FROM META.SOURCE_STRUCTURE SS
    INNER JOIN META.SOURCE_OBJECT SO
        ON SO.OBJECT_ID = SS.OBJECT_ID

    WHERE SO.STATUS = 'ACTIVE'

      AND
      (
            @object_id IS NULL
         OR SS.OBJECT_ID = @object_id
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM META.SOURCE_PROFILE_RULE R
          WHERE R.OBJECT_ID   = SS.OBJECT_ID
            AND R.COLUMN_NAME = SS.COLUMN_NAME
            AND R.RULE_SCOPE  = 'COLUMN'
            AND R.RULE_TYPE   = 'NULL_PCT'
      );

    ----------------------------------------------------------------------
    -- DISTINCT_COUNT
    ----------------------------------------------------------------------

    INSERT INTO META.SOURCE_PROFILE_RULE
    (
          OBJECT_ID
        , COLUMN_NAME
        , RULE_SCOPE
        , RULE_NAME
        , RULE_TYPE
        , RULE_ENABLED
        , DESCRIPTION
        , CREATED_TS
    )
    SELECT
          SS.OBJECT_ID
        , SS.COLUMN_NAME
        , 'COLUMN'
        , CONCAT(SS.COLUMN_NAME, '_DISTINCT_COUNT')
        , 'DISTINCT_COUNT'
        , 1
        , 'Automatically generated baseline rule'
        , @now
    FROM META.SOURCE_STRUCTURE SS
    INNER JOIN META.SOURCE_OBJECT SO
        ON SO.OBJECT_ID = SS.OBJECT_ID

    WHERE SO.STATUS = 'ACTIVE'

      AND
      (
            @object_id IS NULL
         OR SS.OBJECT_ID = @object_id
      )

      AND SS.COLUMN_SIGNATURE NOT LIKE 'VARBINARY%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'BINARY%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'IMAGE%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'XML%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'TEXT%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'NTEXT%'

      AND NOT EXISTS
      (
          SELECT 1
          FROM META.SOURCE_PROFILE_RULE R
          WHERE R.OBJECT_ID   = SS.OBJECT_ID
            AND R.COLUMN_NAME = SS.COLUMN_NAME
            AND R.RULE_SCOPE  = 'COLUMN'
            AND R.RULE_TYPE   = 'DISTINCT_COUNT'
      );

    ----------------------------------------------------------------------
    -- DISTINCT_PCT
    ----------------------------------------------------------------------

    INSERT INTO META.SOURCE_PROFILE_RULE
    (
          OBJECT_ID
        , COLUMN_NAME
        , RULE_SCOPE
        , RULE_NAME
        , RULE_TYPE
        , RULE_ENABLED
        , DESCRIPTION
        , CREATED_TS
    )
    SELECT
          SS.OBJECT_ID
        , SS.COLUMN_NAME
        , 'COLUMN'
        , CONCAT(SS.COLUMN_NAME, '_DISTINCT_PCT')
        , 'DISTINCT_PCT'
        , 1
        , 'Automatically generated baseline rule'
        , @now
    FROM META.SOURCE_STRUCTURE SS
    INNER JOIN META.SOURCE_OBJECT SO
        ON SO.OBJECT_ID = SS.OBJECT_ID

    WHERE SO.STATUS = 'ACTIVE'

      AND
      (
            @object_id IS NULL
         OR SS.OBJECT_ID = @object_id
      )

      AND SS.COLUMN_SIGNATURE NOT LIKE 'VARBINARY%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'BINARY%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'IMAGE%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'XML%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'TEXT%'
      AND SS.COLUMN_SIGNATURE NOT LIKE 'NTEXT%'

      AND NOT EXISTS
      (
          SELECT 1
          FROM META.SOURCE_PROFILE_RULE R
          WHERE R.OBJECT_ID   = SS.OBJECT_ID
            AND R.COLUMN_NAME = SS.COLUMN_NAME
            AND R.RULE_SCOPE  = 'COLUMN'
            AND R.RULE_TYPE   = 'DISTINCT_PCT'
      );

END;
GO


