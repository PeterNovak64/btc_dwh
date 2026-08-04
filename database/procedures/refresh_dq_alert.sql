/*******************************************************************************
 * Procedure: META.refresh_dq_alert
 * Description:
 *   Reconciles data quality alerts for a given run.
 *   - updates existing OPEN alerts for current rule violations
 *   - inserts new OPEN alerts for newly detected violations
 *   - resolves OPEN alerts that are no longer present in the current run
 *
 * Parameters:
 *   @run_id BIGINT  execution run identifier
 *
 * Output:
 *   returns counts of updated, inserted, and resolved alerts
 *******************************************************************************/
CREATE OR ALTER PROCEDURE META.refresh_dq_alert
(
    @run_id BIGINT
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
          @now DATETIME2(0)
        , @updated_open_count INT
        , @inserted_count INT
        , @resolved_count INT;

    SET @now = SYSDATETIME();

    ----------------------------------------------------------------------
    -- Trenutni scope:
    -- Zapiramo samo alerte za objekte, ki so bili profilirani v tem RUN_ID.
    -- To je pomembno pri delnih zagonih, npr. samo TSSPICA.
    ----------------------------------------------------------------------

    DROP TABLE IF EXISTS #CURRENT_SCOPE;

    SELECT DISTINCT
        OBJECT_ID
    INTO #CURRENT_SCOPE
    FROM META.DQ_PROFILE
    WHERE RUN_ID = @run_id;

    ----------------------------------------------------------------------
    -- Trenutne kršitve pravil iz DQ_PROFILE + SOURCE_PROFILE_RULE
    ----------------------------------------------------------------------

    DROP TABLE IF EXISTS #CURRENT_DQ_VIOLATION;

    SELECT
          ALERT_KEY =
              CAST
              (
                  CONCAT
                  (
                        'DQ_PROFILE|'
                      , P.OBJECT_ID
                      , '|'
                      , COALESCE(P.COLUMN_NAME, '<OBJECT>')
                      , '|'
                      , P.RULE_TYPE
                      , '|'
                      , P.RULE_NAME
                  )
                  AS VARCHAR(500)
              )

        , P.RUN_ID
        , P.PROFILE_ID
        , P.RULE_ID
        , P.OBJECT_ID
        , P.OBJECT_NAME
        , P.COLUMN_NAME
        , P.RULE_TYPE
        , P.RULE_NAME

        , ALERT_SEVERITY =
              COALESCE
              (
                  R.ALERT_SEVERITY,
                  'WARNING'
              )

        , ACTUAL_VALUE =
              P.PROFILE_VALUE_NUMERIC

        , EXPECTED_MIN_VALUE =
              R.MIN_VALUE

        , EXPECTED_MAX_VALUE =
              R.MAX_VALUE

        , ALERT_MESSAGE =
              CAST
              (
                  CONCAT
                  (
                        'DQ rule violation: '
                      , P.OBJECT_NAME

                      , CASE
                            WHEN P.COLUMN_NAME IS NOT NULL
                                THEN CONCAT('.', P.COLUMN_NAME)
                            ELSE ''
                        END

                      , ' | Rule: '
                      , P.RULE_TYPE

                      , ' | Actual: '
                      , CONVERT(VARCHAR(100), P.PROFILE_VALUE_NUMERIC)

                      , CASE
                            WHEN R.MIN_VALUE IS NOT NULL
                                 AND P.PROFILE_VALUE_NUMERIC < R.MIN_VALUE
                                THEN CONCAT(
                                        ' | Expected minimum: ',
                                        CONVERT(VARCHAR(100), R.MIN_VALUE)
                                     )
                            ELSE ''
                        END

                      , CASE
                            WHEN R.MAX_VALUE IS NOT NULL
                                 AND P.PROFILE_VALUE_NUMERIC > R.MAX_VALUE
                                THEN CONCAT(
                                        ' | Expected maximum: ',
                                        CONVERT(VARCHAR(100), R.MAX_VALUE)
                                     )
                            ELSE ''
                        END
                  )
                  AS VARCHAR(2000)
              )

    INTO #CURRENT_DQ_VIOLATION

    FROM META.DQ_PROFILE P

    INNER JOIN META.SOURCE_PROFILE_RULE R
        ON R.RULE_ID = P.RULE_ID

    WHERE P.RUN_ID = @run_id

      AND R.RULE_ENABLED = 1

      AND P.PROFILE_VALUE_NUMERIC IS NOT NULL

      AND
      (
             R.MIN_VALUE IS NOT NULL
          OR R.MAX_VALUE IS NOT NULL
      )

      AND
      (
             (
                    R.MIN_VALUE IS NOT NULL
                AND P.PROFILE_VALUE_NUMERIC < R.MIN_VALUE
             )
          OR (
                    R.MAX_VALUE IS NOT NULL
                AND P.PROFILE_VALUE_NUMERIC > R.MAX_VALUE
             )
      );


    ----------------------------------------------------------------------
    -- 1. Če alert že obstaja kot OPEN, ga osvežimo z zadnjo meritvijo.
    --
    -- ALERT_TS namenoma NE spreminjamo, ker predstavlja prvi zaznani čas.
    -- Če boš želel ločeno spremljati zadnji pojav, lahko kasneje dodava
    -- LAST_SEEN_TS.
    ----------------------------------------------------------------------

    UPDATE A
       SET
             A.RUN_ID              = V.RUN_ID
           , A.PROFILE_ID          = V.PROFILE_ID
           , A.RULE_ID             = V.RULE_ID
           , A.OBJECT_ID           = V.OBJECT_ID
           , A.OBJECT_NAME         = V.OBJECT_NAME
           , A.COLUMN_NAME         = V.COLUMN_NAME
           , A.RULE_TYPE           = V.RULE_TYPE
           , A.RULE_NAME           = V.RULE_NAME
           , A.ALERT_SEVERITY      = V.ALERT_SEVERITY
           , A.ACTUAL_VALUE        = V.ACTUAL_VALUE
           , A.EXPECTED_MIN_VALUE  = V.EXPECTED_MIN_VALUE
           , A.EXPECTED_MAX_VALUE  = V.EXPECTED_MAX_VALUE
           , A.ALERT_MESSAGE       = V.ALERT_MESSAGE
           , A.RESOLVED_TS         = NULL
    FROM META.DQ_ALERT A
    INNER JOIN #CURRENT_DQ_VIOLATION V
        ON V.ALERT_KEY = A.ALERT_KEY
    WHERE A.ALERT_STATUS = 'OPEN';

    SET @updated_open_count = @@ROWCOUNT;


    ----------------------------------------------------------------------
    -- 2. Vstavi nove OPEN alerte.
    --
    -- Če je alert SUPPRESSED, ga ne odpremo ponovno.
    ----------------------------------------------------------------------

    INSERT INTO META.DQ_ALERT
    (
          RUN_ID
        , PROFILE_ID
        , RULE_ID
        , OBJECT_ID
        , OBJECT_NAME
        , COLUMN_NAME
        , RULE_TYPE
        , RULE_NAME
        , ALERT_KEY
        , ALERT_SEVERITY
        , ALERT_STATUS
        , ACTUAL_VALUE
        , EXPECTED_MIN_VALUE
        , EXPECTED_MAX_VALUE
        , ALERT_MESSAGE
        , ALERT_TS
        , RESOLVED_TS
    )
    SELECT
          V.RUN_ID
        , V.PROFILE_ID
        , V.RULE_ID
        , V.OBJECT_ID
        , V.OBJECT_NAME
        , V.COLUMN_NAME
        , V.RULE_TYPE
        , V.RULE_NAME
        , V.ALERT_KEY
        , V.ALERT_SEVERITY
        , 'OPEN'
        , V.ACTUAL_VALUE
        , V.EXPECTED_MIN_VALUE
        , V.EXPECTED_MAX_VALUE
        , V.ALERT_MESSAGE
        , @now
        , NULL
    FROM #CURRENT_DQ_VIOLATION V
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM META.DQ_ALERT A
        WHERE A.ALERT_KEY = V.ALERT_KEY
          AND A.ALERT_STATUS IN
          (
              'OPEN',
              'SUPPRESSED'
          )
    );

    SET @inserted_count = @@ROWCOUNT;


    ----------------------------------------------------------------------
    -- 3. Zapri OPEN alerte, ki za objekte iz trenutnega RUN-a
    --    niso več prisotni.
    --
    -- To je tvoja pričakovana logika:
    -- "pri novem LOAD-u popravljenih podatkov se alert zapre".
    ----------------------------------------------------------------------

    UPDATE A
       SET
             A.ALERT_STATUS = 'RESOLVED'
           , A.RESOLVED_TS  = @now
    FROM META.DQ_ALERT A
    INNER JOIN #CURRENT_SCOPE S
        ON S.OBJECT_ID = A.OBJECT_ID
    WHERE A.ALERT_STATUS = 'OPEN'
      AND A.ALERT_KEY LIKE 'DQ_PROFILE|%'
      AND NOT EXISTS
      (
          SELECT 1
          FROM #CURRENT_DQ_VIOLATION V
          WHERE V.ALERT_KEY = A.ALERT_KEY
      );

    SET @resolved_count = @@ROWCOUNT;

    ----------------------------------------------------------------------
    -- Povzetek izvajanja
    ----------------------------------------------------------------------

    DECLARE @current_violation_count INT;
    DECLARE @open_alerts_after_run INT;

    SELECT
        @current_violation_count = COUNT(*)
    FROM #CURRENT_DQ_VIOLATION;

    SELECT
        @open_alerts_after_run = COUNT(*)
    FROM META.DQ_ALERT A
    --INNER JOIN #CURRENT_SCOPE S
    --    ON S.OBJECT_ID = A.OBJECT_ID
    WHERE A.ALERT_STATUS = 'OPEN'
      AND A.ALERT_KEY LIKE 'DQ_PROFILE|%';

    SELECT
          @run_id AS RUN_ID
        , @current_violation_count AS CURRENT_VIOLATIONS
        , @updated_open_count AS UPDATED_OPEN_ALERTS
        , @inserted_count AS INSERTED_NEW_ALERTS
        , @resolved_count AS RESOLVED_ALERTS
        , @open_alerts_after_run AS OPEN_ALERTS_AFTER_RUN;

END;
GO
