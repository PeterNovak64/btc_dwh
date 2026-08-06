
/*******************************************************************************
 * Table: META.SOURCE_STRUCTURE_CHANGE
 * Description:
 *   Records detected structural changes for source object columns.
 *   Each row captures the change type, old/new signatures, and the time
 *   the change was detected for source object metadata tracking.
 *
 * Columns:
 *   CHANGE_ID      unique change event identifier
 *   OBJECT_ID      reference to META.SOURCE_OBJECT
 *   ORDINAL_POSITION optional column position at the time of detection
 *   COLUMN_NAME    column name for the changed column
 *   DETECTED_TS    timestamp when the change was detected
 *   CHANGE_TYPE    type of schema change detected
 *   OLD_SIGNATURE  previous column signature
 *   NEW_SIGNATURE  new column signature
 *******************************************************************************/

ALTER TABLE [META].[SOURCE_STRUCTURE_CHANGE] DROP CONSTRAINT [CK_SOURCE_STRUCTURE_CHANGE_TYPE]
GO

ALTER TABLE [META].[SOURCE_STRUCTURE_CHANGE] DROP CONSTRAINT [FK_SOURCE_STRUCTURE_CHANGE_SOURCE]
GO

/****** Object:  Table [META].[SOURCE_STRUCTURE_CHANGE]    Script Date: 4. 08. 2026 09:51:02 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[META].[SOURCE_STRUCTURE_CHANGE]') AND type in (N'U'))
DROP TABLE [META].[SOURCE_STRUCTURE_CHANGE]
GO

/****** Object:  Table [META].[SOURCE_STRUCTURE_CHANGE]    Script Date: 4. 08. 2026 09:51:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [META].[SOURCE_STRUCTURE_CHANGE](
	[CHANGE_ID] [bigint] IDENTITY(1,1) NOT NULL,
	[OBJECT_ID] [bigint] NOT NULL,
	[ORDINAL_POSITION] [int] NULL,
	[COLUMN_NAME] [varchar](255) NOT NULL,
	[DETECTED_TS] [datetime2](0) NOT NULL,
	[CHANGE_TYPE] [varchar](30) NOT NULL,
	[OLD_SIGNATURE] [varchar](2000) NULL,
	[NEW_SIGNATURE] [varchar](2000) NULL,
PRIMARY KEY CLUSTERED 
(
	[CHANGE_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [META].[SOURCE_STRUCTURE_CHANGE]  WITH CHECK ADD  CONSTRAINT [FK_SOURCE_STRUCTURE_CHANGE_SOURCE] FOREIGN KEY([OBJECT_ID])
REFERENCES [META].[SOURCE_OBJECT] ([OBJECT_ID])
GO

ALTER TABLE [META].[SOURCE_STRUCTURE_CHANGE] CHECK CONSTRAINT [FK_SOURCE_STRUCTURE_CHANGE_SOURCE]
GO

ALTER TABLE [META].[SOURCE_STRUCTURE_CHANGE]  WITH CHECK ADD  CONSTRAINT [CK_SOURCE_STRUCTURE_CHANGE_TYPE] CHECK  (([CHANGE_TYPE]='COLUMN_CHANGED' OR [CHANGE_TYPE]='COLUMN_REMOVED' OR [CHANGE_TYPE]='COLUMN_ADDED' OR [CHANGE_TYPE]='INITIAL_LOAD'))
GO

ALTER TABLE [META].[SOURCE_STRUCTURE_CHANGE] CHECK CONSTRAINT [CK_SOURCE_STRUCTURE_CHANGE_TYPE]
GO


