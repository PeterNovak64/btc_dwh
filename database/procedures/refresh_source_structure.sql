
/*******************************************************************************
 * Procedure: META.refresh_source_structure
 * Description:
 *   Reads the current table structure of a LAND object, compares it to the
 *   previously stored source structure, records structural changes, and updates
 *   the source metadata snapshot.
 *
 * Parameters:
 *   @OBJECT_ID BIGINT
 *     Identifier of the source object in META.SOURCE_OBJECT.
 *
 *   @LAND_SCHEMA_NAME VARCHAR(255) = 'LAND'
 *     Schema name where the LAND table exists.
 *
 * Behavior:
 *   - Loads the current column definitions from the LAND table metadata.
 *   - Generates a per-column signature and hash.
 *   - Marks the source object as MISSING if the LAND table is absent or has no
 *     columns.
 *   - If the structure has changed, records additions, removals, and modifications
 *     in META.SOURCE_STRUCTURE_CHANGE.
 *   - Refreshes META.SOURCE_STRUCTURE with the current snapshot.
 *   - Updates META.SOURCE_OBJECT status, LAST_STRUCTURE_HASH, LAST_SEEN_TS,
 *     and LAST_STRUCTURE_CHANGE_TS.
 *
 * Inserts into: META.SOURCE_STRUCTURE, META.SOURCE_STRUCTURE_CHANGE
 * Updates: META.SOURCE_OBJECT
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[refresh_source_structure]    Script Date: 4. 08. 2026 09:34:52 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--
--  PROCEDURE refresh_source_structure
CREATE OR ALTER   PROCEDURE [META].refresh_source_structure
(
      @OBJECT_ID           BIGINT
    , @LAND_SCHEMA_NAME    VARCHAR(255) = 'LAND'
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
          @LAND_OBJECT_NAME              VARCHAR(255)
        , @LAST_STRUCTURE_HASH           VARBINARY(32)
        , @CURRENT_STRUCTURE_HASH        VARBINARY(32)
        , @CURRENT_STRUCTURE_SIGNATURE   VARCHAR(MAX)
        , @NOW                           DATETIME2(0);

    SET @NOW = SYSDATETIME();

    SELECT
          @LAND_OBJECT_NAME    = LAND_OBJECT_NAME
        , @LAST_STRUCTURE_HASH = LAST_STRUCTURE_HASH
    FROM META.SOURCE_OBJECT
    WHERE OBJECT_ID = @OBJECT_ID;

    IF @LAND_OBJECT_NAME IS NULL
    BEGIN
        RAISERROR('OBJECT_ID ne obstaja v META.SOURCE_OBJECT.', 16, 1);
        RETURN;
    END;

    DROP TABLE IF EXISTS #CURRENT_STRUCTURE;

    CREATE TABLE #CURRENT_STRUCTURE
    (
          OBJECT_ID                 BIGINT NOT NULL
        , COLUMN_NAME               VARCHAR(255) NOT NULL
        , ORDINAL_POSITION          INT NOT NULL
        , COLUMN_SIGNATURE          VARCHAR(2000) NOT NULL
        , COLUMN_SIGNATURE_HASH     VARBINARY(32) NULL
    );

    ;WITH COLUMN_DATA AS
    (
        SELECT
              @OBJECT_ID AS OBJECT_ID
            , CAST(C.NAME AS VARCHAR(255)) AS COLUMN_NAME
            , C.COLUMN_ID AS ORDINAL_POSITION
            , CAST(T.NAME AS VARCHAR(255)) AS DATA_TYPE
            , C.MAX_LENGTH
            , C.PRECISION
            , C.SCALE
            , C.IS_NULLABLE
        FROM SYS.TABLES AS TB
        INNER JOIN SYS.SCHEMAS AS SC
            ON SC.SCHEMA_ID = TB.SCHEMA_ID
        INNER JOIN SYS.COLUMNS AS C
            ON C.OBJECT_ID = TB.OBJECT_ID
        INNER JOIN SYS.TYPES AS T
            ON T.USER_TYPE_ID = C.USER_TYPE_ID
        WHERE SC.NAME = @LAND_SCHEMA_NAME
          AND TB.NAME = @LAND_OBJECT_NAME
    ),
    SIGNATURE_DATA AS
    (
        SELECT
              OBJECT_ID
            , COLUMN_NAME
            , ORDINAL_POSITION

            , CAST
              (
                  CONCAT
                  (
                        UPPER(DATA_TYPE)

                      , CASE
                            WHEN DATA_TYPE IN
                            (
                                'varchar',
                                'char',
                                'varbinary',
                                'binary'
                            )
                            THEN CONCAT
                                 (
                                       '('
                                     , CASE
                                           WHEN MAX_LENGTH = -1
                                               THEN 'MAX'
                                           ELSE CAST(MAX_LENGTH AS VARCHAR(20))
                                       END
                                     , ')'
                                 )

                            WHEN DATA_TYPE IN
                            (
                                'nvarchar',
                                'nchar'
                            )
                            THEN CONCAT
                                 (
                                       '('
                                     , CASE
                                           WHEN MAX_LENGTH = -1
                                               THEN 'MAX'
                                           ELSE CAST(MAX_LENGTH / 2 AS VARCHAR(20))
                                       END
                                     , ')'
                                 )

                            WHEN DATA_TYPE IN
                            (
                                'decimal',
                                'numeric'
                            )
                            THEN CONCAT
                                 (
                                       '('
                                     , CAST(PRECISION AS VARCHAR(20))
                                     , ','
                                     , CAST(SCALE AS VARCHAR(20))
                                     , ')'
                                 )

                            WHEN DATA_TYPE IN
                            (
                                'datetime2',
                                'datetimeoffset',
                                'time'
                            )
                            THEN CONCAT
                                 (
                                       '('
                                     , CAST(SCALE AS VARCHAR(20))
                                     , ')'
                                 )

                            ELSE ''
                        END

                      , CASE
                            WHEN IS_NULLABLE = 1
                                THEN ' NULL'
                            ELSE ' NOT NULL'
                        END
                  )
                  AS VARCHAR(2000)
              ) AS COLUMN_SIGNATURE

        FROM COLUMN_DATA
    )
    INSERT INTO #CURRENT_STRUCTURE
    (
          OBJECT_ID
        , COLUMN_NAME
        , ORDINAL_POSITION
        , COLUMN_SIGNATURE
        , COLUMN_SIGNATURE_HASH
    )
    SELECT
          OBJECT_ID
        , COLUMN_NAME
        , ORDINAL_POSITION
        , COLUMN_SIGNATURE
        , HASHBYTES
          (
              'SHA2_256',
              CONCAT
                (
                    UPPER(COLUMN_NAME),
                    '|',
                    COLUMN_SIGNATURE
                )
          ) AS COLUMN_SIGNATURE_HASH
    FROM SIGNATURE_DATA;

    /*
        Če LAND tabela ne obstaja oziroma nima stolpcev,
        objekta ne brišemo. Samo označimo ga kot MISSING.
    */
    IF NOT EXISTS
    (
        SELECT 1
        FROM #CURRENT_STRUCTURE
    )
    BEGIN
        UPDATE META.SOURCE_OBJECT
        SET STATUS = 'MISSING'
        WHERE OBJECT_ID = @OBJECT_ID;

        RETURN;
    END;

    /*
        Sestavimo podpis celotne strukture.
        STRING_AGG uporabljamo samo za tehnični hash celotne strukture.
        Uporabniško pregledno stanje ostaja v META.SOURCE_STRUCTURE.
    */
    SELECT
        @CURRENT_STRUCTURE_SIGNATURE =
            STRING_AGG
            (
                CONVERT( VARCHAR(MAX), CONCAT
                                      (
                                        UPPER(COLUMN_NAME),
                                        '|',
                                        COLUMN_SIGNATURE
                                      )
                ),
                '|'
            )
            WITHIN GROUP
            (
                ORDER BY
                      ORDINAL_POSITION
                    , COLUMN_NAME
            )
    FROM #CURRENT_STRUCTURE;

    SET @CURRENT_STRUCTURE_HASH =
        HASHBYTES
        (
            'SHA2_256',
            @CURRENT_STRUCTURE_SIGNATURE
        );

    /*
        Če se struktura ni spremenila, ne delamo primerjave stolpcev.
        Posodobimo pa SOURCE_OBJECT, ker je bila LAND tabela uspešno najdena.
    */
    IF @LAST_STRUCTURE_HASH IS NOT NULL
       AND @CURRENT_STRUCTURE_HASH = @LAST_STRUCTURE_HASH
       AND EXISTS
       (
           SELECT 1
           FROM META.SOURCE_STRUCTURE
           WHERE OBJECT_ID = @OBJECT_ID
       )

    BEGIN        
        UPDATE META.SOURCE_OBJECT
        SET
              STATUS       = 'ACTIVE'
            , LAST_SEEN_TS = @NOW
        WHERE OBJECT_ID = @OBJECT_ID;

        RETURN;
    END;

    BEGIN TRY

        BEGIN TRANSACTION;

        /*
            Začetno nalaganje strukture.
        */
        IF NOT EXISTS
        (
            SELECT 1
            FROM META.SOURCE_STRUCTURE
            WHERE OBJECT_ID = @OBJECT_ID
        )
        BEGIN

            INSERT INTO META.SOURCE_STRUCTURE_CHANGE
            (
                  OBJECT_ID
                , ORDINAL_POSITION
                , COLUMN_NAME
                , DETECTED_TS
                , CHANGE_TYPE
                , OLD_SIGNATURE
                , NEW_SIGNATURE
            )
            SELECT
                  CS.OBJECT_ID
                , CS.ORDINAL_POSITION
                , CS.COLUMN_NAME
                , @NOW
                , 'INITIAL_LOAD'
                , NULL
                , CS.COLUMN_SIGNATURE
            FROM #CURRENT_STRUCTURE AS CS;

        END
        ELSE
        BEGIN

            /*
                Dodani stolpci.
            */
            INSERT INTO META.SOURCE_STRUCTURE_CHANGE
            (
                  OBJECT_ID
                , ORDINAL_POSITION
                , COLUMN_NAME
                , DETECTED_TS
                , CHANGE_TYPE
                , OLD_SIGNATURE
                , NEW_SIGNATURE
            )
            SELECT
                  CS.OBJECT_ID
                , CS.ORDINAL_POSITION
                , CS.COLUMN_NAME
                , @NOW
                , 'COLUMN_ADDED'
                , NULL
                , CS.COLUMN_SIGNATURE
            FROM #CURRENT_STRUCTURE AS CS
            LEFT JOIN META.SOURCE_STRUCTURE AS SS
                ON SS.OBJECT_ID = CS.OBJECT_ID
               AND SS.COLUMN_NAME = CS.COLUMN_NAME
            WHERE SS.OBJECT_ID IS NULL;

            /*
                Odstranjeni stolpci.
            */
            INSERT INTO META.SOURCE_STRUCTURE_CHANGE
            (
                  OBJECT_ID
                , ORDINAL_POSITION
                , COLUMN_NAME
                , DETECTED_TS
                , CHANGE_TYPE
                , OLD_SIGNATURE
                , NEW_SIGNATURE
            )
            SELECT
                  SS.OBJECT_ID
                , SS.ORDINAL_POSITION
                , SS.COLUMN_NAME
                , @NOW
                , 'COLUMN_REMOVED'
                , SS.COLUMN_SIGNATURE
                , NULL
            FROM META.SOURCE_STRUCTURE AS SS
            LEFT JOIN #CURRENT_STRUCTURE AS CS
                ON CS.OBJECT_ID = SS.OBJECT_ID
               AND CS.COLUMN_NAME = SS.COLUMN_NAME
            WHERE SS.OBJECT_ID = @OBJECT_ID
              AND CS.OBJECT_ID IS NULL;

            /*
                Spremenjeni stolpci.
                Ker COLUMN_SIGNATURE vsebuje tudi ORDINAL_POSITION,
                se tukaj zazna tudi sprememba vrstnega reda stolpca.
            */
            INSERT INTO META.SOURCE_STRUCTURE_CHANGE
            (
                  OBJECT_ID
                , ORDINAL_POSITION
                , COLUMN_NAME
                , DETECTED_TS
                , CHANGE_TYPE
                , OLD_SIGNATURE
                , NEW_SIGNATURE
            )
            SELECT
                  CS.OBJECT_ID
                , CS.ORDINAL_POSITION
                , CS.COLUMN_NAME
                , @NOW
                , 'COLUMN_CHANGED'
                , SS.COLUMN_SIGNATURE
                , CS.COLUMN_SIGNATURE
            FROM #CURRENT_STRUCTURE AS CS
            INNER JOIN META.SOURCE_STRUCTURE AS SS
                ON SS.OBJECT_ID = CS.OBJECT_ID
               AND SS.COLUMN_NAME = CS.COLUMN_NAME
            WHERE
                (
                       SS.COLUMN_SIGNATURE_HASH <> CS.COLUMN_SIGNATURE_HASH
                    OR SS.COLUMN_SIGNATURE_HASH IS NULL
                    OR CS.COLUMN_SIGNATURE_HASH IS NULL
                );

        END;

        /*
            Osvežitev trenutnega snapshot-a strukture.
        */
        DELETE FROM META.SOURCE_STRUCTURE
        WHERE OBJECT_ID = @OBJECT_ID;

        INSERT INTO META.SOURCE_STRUCTURE
        (
              OBJECT_ID
            , COLUMN_NAME
            , ORDINAL_POSITION
            , COLUMN_SIGNATURE
            , COLUMN_SIGNATURE_HASH
            , DETECTED_TS
        )
        SELECT
              OBJECT_ID
            , COLUMN_NAME
            , ORDINAL_POSITION
            , COLUMN_SIGNATURE
            , COLUMN_SIGNATURE_HASH
            , @NOW
        FROM #CURRENT_STRUCTURE;

        /*
            Obvezna posodobitev SOURCE_OBJECT po uspešni obdelavi.
        */
        UPDATE META.SOURCE_OBJECT
        SET
              STATUS                    = 'ACTIVE'
            , LAST_STRUCTURE_HASH       = @CURRENT_STRUCTURE_HASH
            , LAST_SEEN_TS              = @NOW
            , LAST_STRUCTURE_CHANGE_TS  = @NOW
        WHERE OBJECT_ID = @OBJECT_ID;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE
              @ERROR_MESSAGE   NVARCHAR(4000)
            , @ERROR_SEVERITY  INT
            , @ERROR_STATE     INT;

        SELECT
              @ERROR_MESSAGE  = ERROR_MESSAGE()
            , @ERROR_SEVERITY = ERROR_SEVERITY()
            , @ERROR_STATE    = ERROR_STATE();

        RAISERROR(@ERROR_MESSAGE, @ERROR_SEVERITY, @ERROR_STATE);

    END CATCH;

END;
GO


