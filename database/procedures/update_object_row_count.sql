
/*******************************************************************************
 * Procedure: META.update_object_row_count
 * Description:
 *   Updates the row count for a currently running DWH object within a run.
 *   This procedure is typically invoked after a model finishes execution.
 *
 * Parameters:
 *   @run_id BIGINT
 *     Identifier of the DWH run.
 *
 *   @object_layer VARCHAR(20)
 *     Layer of the object, such as LAND, STAG, DWH, or MART.
 *
 *   @object_name VARCHAR(255)
 *     Name of the object being updated.
 *
 *   @row_count BIGINT
 *     Row count value to store for the object.
 *
 * Behavior:
 *   - Updates ROW_COUNT in META.DWH_RUN_OBJECT for the matching RUN_ID,
 *     OBJECT_LAYER, OBJECT_NAME, and status 'RUNNING'.
 *
 * Updates: META.DWH_RUN_OBJECT
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[update_object_row_count]    Script Date: 4. 08. 2026 09:37:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--
CREATE OR ALTER   PROCEDURE [META].[update_object_row_count]
(
    @run_id        BIGINT,
    @object_layer  VARCHAR(20),
    @object_name   VARCHAR(255),
    @row_count     BIGINT
)
AS
BEGIN

    SET NOCOUNT ON;

    UPDATE META.DWH_RUN_OBJECT
       SET ROW_COUNT = @row_count
     WHERE RUN_ID = @run_id
       AND OBJECT_LAYER = @object_layer
       AND OBJECT_NAME = @object_name
       AND STATUS = 'RUNNING';

END;
GO


