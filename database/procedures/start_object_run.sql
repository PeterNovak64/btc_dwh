
/*******************************************************************************
 * Procedure: META.start_object_run
 * Description:
 *   Begins tracking a run for a single DWH object by inserting a new row
 *   into META.DWH_RUN_OBJECT.
 *
 * Parameters:
 *   @run_id BIGINT
 *     Identifier of the DWH run in META.DWH_RUN.
 *
 *   @object_layer VARCHAR(20)
 *     Layer name of the object, such as LAND, STAG, DWH, or MART.
 *
 *   @object_name VARCHAR(255)
 *     Name of the object being executed.
 *
 * Behavior:
 *   - Inserts a new object run record with RUN_ID, OBJECT_LAYER, and OBJECT_NAME.
 *   - The object row is initially created with the default status and timestamps
 *     defined by the table schema.
 *
 * Inserts into: META.DWH_RUN_OBJECT
 *******************************************************************************/
/****** Object:  StoredProcedure [META].[start_object_run]    Script Date: 4. 08. 2026 09:36:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--
CREATE OR ALTER   PROCEDURE [META].[start_object_run]
(
    @run_id        BIGINT,
    @object_layer  VARCHAR(20),
    @object_name   VARCHAR(255)
)
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO META.DWH_RUN_OBJECT
    (
        RUN_ID,
        OBJECT_LAYER,
        OBJECT_NAME
    )
    VALUES
    (
        @run_id,
        @object_layer,
        @object_name
    );

END;
GO


