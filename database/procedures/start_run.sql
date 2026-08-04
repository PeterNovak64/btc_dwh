
/*******************************************************************************
 * Procedure: META.start_run
 * Description:
 *   Creates a new DWH run record in META.DWH_RUN and returns the generated
 *   RUN_ID for downstream orchestration.
 *
 * Parameters:
 *   @run_type VARCHAR(50)
 *     The type of the run, such as 'DBT'.
 *
 * Behavior:
 *   - Inserts a new row into META.DWH_RUN with the provided run type.
 *   - Returns the inserted RUN_ID using SCOPE_IDENTITY().
 *
 * Inserts into: META.DWH_RUN
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[start_run]    Script Date: 4. 08. 2026 09:37:09 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--
--  Bazne funkcije META
--

--
CREATE OR ALTER   PROCEDURE [META].[start_run]
(
    @run_type VARCHAR(50)
)
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO META.DWH_RUN
    (
        RUN_TYPE
    )
    VALUES
    (
        @run_type
    );

    DECLARE @run_id BIGINT;

    SET @run_id = SCOPE_IDENTITY();

    SELECT @run_id AS RUN_ID;

END;
GO


