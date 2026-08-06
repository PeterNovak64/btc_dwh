
/*******************************************************************************
 * Table: META.SOURCE_STRUCTURE
 * Description:
 *   Stores the structure of source object columns used for schema tracking.
 *   Each row contains the column signature, ordinal position, and the time
 *   the structure was detected for a source object.
 *
 * Columns:
 *   OBJECT_ID             reference to META.SOURCE_OBJECT
 *   COLUMN_NAME           source column name
 *   ORDINAL_POSITION      column ordinal position
 *   COLUMN_SIGNATURE      detailed column signature
 *   COLUMN_SIGNATURE_HASH optional signature hash for change detection
 *   DETECTED_TS           timestamp when the structure was detected
 *******************************************************************************/

ALTER TABLE [META].[SOURCE_STRUCTURE] DROP CONSTRAINT [FK_SOURCE_STRUCTURE_OBJECT]
GO

/****** Object:  Table [META].[SOURCE_STRUCTURE]    Script Date: 4. 08. 2026 09:50:25 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[META].[SOURCE_STRUCTURE]') AND type in (N'U'))
DROP TABLE [META].[SOURCE_STRUCTURE]
GO

/****** Object:  Table [META].[SOURCE_STRUCTURE]    Script Date: 4. 08. 2026 09:50:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [META].[SOURCE_STRUCTURE](
	[OBJECT_ID] [bigint] NOT NULL,
	[COLUMN_NAME] [varchar](255) NOT NULL,
	[ORDINAL_POSITION] [int] NOT NULL,
	[COLUMN_SIGNATURE] [varchar](2000) NOT NULL,
	[COLUMN_SIGNATURE_HASH] [varbinary](32) NULL,
	[DETECTED_TS] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SOURCE_STRUCTURE] PRIMARY KEY CLUSTERED 
(
	[OBJECT_ID] ASC,
	[COLUMN_NAME] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [META].[SOURCE_STRUCTURE]  WITH CHECK ADD  CONSTRAINT [FK_SOURCE_STRUCTURE_OBJECT] FOREIGN KEY([OBJECT_ID])
REFERENCES [META].[SOURCE_OBJECT] ([OBJECT_ID])
GO

ALTER TABLE [META].[SOURCE_STRUCTURE] CHECK CONSTRAINT [FK_SOURCE_STRUCTURE_OBJECT]
GO


