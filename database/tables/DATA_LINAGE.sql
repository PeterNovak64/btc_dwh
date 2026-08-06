/*******************************************************************************
 * Table: META.DATA_LINEAGE
 * Description:
 *   Stores parent-child lineage relationships between source objects.
 *   Each row links a parent object to a child object and is used by
 *   metadata and data lineage processes for dependency tracking.
 *
 * Columns:
 *   LINEAGE_ID          surrogate key for the lineage relationship
 *   PARENT_OBJECT_ID    parent source object identifier
 *   CHILD_OBJECT_ID     child source object identifier
 *   CREATED_TS          record creation timestamp, default sysdatetime()
 *******************************************************************************/

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[META].[DATA_LINEAGE]') AND type in (N'U'))
    DROP TABLE [META].[DATA_LINEAGE];
GO

CREATE TABLE [META].[DATA_LINEAGE]
(
    [LINEAGE_ID] BIGINT IDENTITY(1,1) NOT NULL,

    -------------------------------------------------------------
    -- Relationship
    -------------------------------------------------------------

    [PARENT_OBJECT_ID] BIGINT NOT NULL,
    [CHILD_OBJECT_ID] BIGINT NOT NULL,

    -------------------------------------------------------------
    -- Audit
    -------------------------------------------------------------

    [CREATED_TS] DATETIME2(0) NOT NULL
        CONSTRAINT [DF_DATA_LINEAGE_CREATED_TS] DEFAULT SYSDATETIME(),

    -------------------------------------------------------------
    -- Constraints
    -------------------------------------------------------------

    CONSTRAINT [PK_DATA_LINEAGE] PRIMARY KEY ([LINEAGE_ID]),

    CONSTRAINT [FK_DATA_LINEAGE_PARENT] FOREIGN KEY ([PARENT_OBJECT_ID])
        REFERENCES [META].[SOURCE_OBJECT] ([OBJECT_ID]),

    CONSTRAINT [FK_DATA_LINEAGE_CHILD] FOREIGN KEY ([CHILD_OBJECT_ID])
        REFERENCES [META].[SOURCE_OBJECT] ([OBJECT_ID]),

    CONSTRAINT [UQ_DATA_LINEAGE] UNIQUE ([PARENT_OBJECT_ID], [CHILD_OBJECT_ID])
);
GO

CREATE INDEX [IX_DATA_LINEAGE_PARENT]
ON [META].[DATA_LINEAGE] ([PARENT_OBJECT_ID]);
GO

CREATE INDEX [IX_DATA_LINEAGE_CHILD]
ON [META].[DATA_LINEAGE] ([CHILD_OBJECT_ID]);
GO

