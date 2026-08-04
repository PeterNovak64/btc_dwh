
/*******************************************************************************
 * Procedure: META.refresh_source
 * Description:
 *   Refreshes source objects and their structures for all active LAND objects.
 *   It updates the object list and then rebuilds source structure metadata for
 *   each active source object.
 *
 * Behavior:
 *   1. Executes META.refresh_source_object to refresh the catalog of LAND objects.
 *   2. Iterates all active objects from META.SOURCE_OBJECT.
 *   3. Calls META.refresh_source_structure for each object.
 *   4. Logs errors per object without stopping the overall refresh.
 *
 * Affected objects:
 *   - META.SOURCE_OBJECT (via refresh_source_object)
 *   - META.SOURCE_STRUCTURE
 *   - META.SOURCE_STRUCTURE_CHANGE
 *
 * Notes:
 *   - Errors during object processing are caught and printed.
 *   - A failure for one object does not prevent the remaining objects from
 *     being refreshed.
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[refresh_source]    Script Date: 4. 08. 2026 09:30:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--
--  META.refresh_source
--
CREATE OR ALTER   PROCEDURE [META].[refresh_source]
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @object_id BIGINT;

    ------------------------------------------------------------
    -- 1. Osveži seznam LAND objektov
    ------------------------------------------------------------

    EXEC META.refresh_source_object;

    ------------------------------------------------------------
    -- 2. Osveži strukturo vseh aktivnih objektov
    ------------------------------------------------------------

    DECLARE object_cursor CURSOR LOCAL FAST_FORWARD FOR

    SELECT OBJECT_ID
    FROM META.SOURCE_OBJECT
    WHERE STATUS = 'ACTIVE';

    OPEN object_cursor;

    FETCH NEXT
    FROM object_cursor
    INTO @object_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        BEGIN TRY

            EXEC META.refresh_source_structure
                @OBJECT_ID = @object_id;

        END TRY
        BEGIN CATCH

            PRINT CONCAT(
                'Napaka pri OBJECT_ID=',
                @object_id,
                ': ',
                ERROR_MESSAGE()
            );

        END CATCH;

        FETCH NEXT
        FROM object_cursor
        INTO @object_id;

    END;

    CLOSE object_cursor;
    DEALLOCATE object_cursor;

END;
GO


