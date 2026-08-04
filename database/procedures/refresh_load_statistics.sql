
/*******************************************************************************
 * Procedure: META.refresh_load_statistics
 * Description:
 *   Calculates and inserts load statistics for a completed DWH run.
 *   The procedure reads successful run objects for the specified run and
 *   writes their row counts and load timestamps into META.LOAD_STATISTICS.
 *
 * Parameters:
 *   @run_id BIGINT
 *     The identifier of the DWH run whose successful objects should be
 *     included in the statistics calculation.
 *
 * Behavior:
 *   - Selects records from META.DWH_RUN_OBJECT where RUN_ID matches and
 *     STATUS = 'SUCCESS'.
 *   - Only includes rows with non-null ROW_COUNT.
 *   - Writes one statistic row per object into META.LOAD_STATISTICS.
 *   - Uses END_TS if available, otherwise current system time for LOAD_TS.
 *
 * Inserts into: META.LOAD_STATISTICS
 * Reads from:   META.DWH_RUN_OBJECT
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[refresh_load_statistics]    Script Date: 4. 08. 2026 09:29:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--
--  izračuna statistike
CREATE OR ALTER   PROCEDURE [META].[refresh_load_statistics]
(
    @run_id BIGINT
)
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO META.LOAD_STATISTICS
    (
        RUN_ID,
        LAYER_NAME,
        OBJECT_NAME,
        ROW_COUNT,
        LOAD_TS
    )
    SELECT
          RUN_ID
        , OBJECT_LAYER
        , OBJECT_NAME
        , ROW_COUNT
        , ISNULL(END_TS, SYSDATETIME())
    FROM META.DWH_RUN_OBJECT
    WHERE RUN_ID = @run_id
      AND STATUS = 'SUCCESS'
      AND ROW_COUNT IS NOT NULL;

END;
GO


