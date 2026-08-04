
/*******************************************************************************
 * Procedure: META.finish_run
 * Description:
 *   Completes a DWH run by updating the run status, end timestamp, duration,
 *   and optional error message in META.DWH_RUN.
 *
 * Parameters:
 *   @run_id BIGINT
 *     Identifier of the DWH run to close.
 *
 *   @status VARCHAR(20)
 *     Final run status, typically 'SUCCESS' or 'FAILED'.
 *
 *   @error_message VARCHAR(2000) = NULL
 *     Optional error details recorded when the run fails.
 *
 * Behavior:
 *   - Sets END_TS to the current system timestamp.
 *   - Calculates DURATION_SEC from START_TS to END_TS.
 *   - Updates STATUS and ERROR_MESSAGE for the specified run.
 *
 * Updates: META.DWH_RUN
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[finish_run]    Script Date: 4. 08. 2026 09:22:48 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--EXEC META.start_run @run_type = 'DBT';
--GO
--

--
CREATE OR ALTER PROCEDURE [META].[finish_run]
(
    @run_id BIGINT,
    @status VARCHAR(20),
    @error_message VARCHAR(2000) = NULL
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @end_ts DATETIME2(7);

    SET @end_ts = SYSDATETIME();

    UPDATE META.DWH_RUN
       SET END_TS       = @end_ts,
           STATUS       = @status,
           DURATION_SEC =
                ROUND(
                    DATEDIFF_BIG(
                        MICROSECOND,
                        START_TS,
                        @end_ts
                    ) / 1000000.0,
                    4
                ),
           ERROR_MESSAGE = @error_message 
     WHERE RUN_ID = @run_id;

END;
GO


