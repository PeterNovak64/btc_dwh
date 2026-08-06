
/*******************************************************************************
 * Table: META.LOAD_STATISTICS
 * Description:
 *   Stores load statistics for each object and layer during run execution.
 *   Includes row counts and load timestamp for monitoring and reporting.
 *
 * Columns:
 *   STAT_ID       unique load statistic identifier
 *   RUN_ID        execution run reference
 *   LAYER_NAME    layer name such as META, MART, DWH, STAG, LAND
 *   OBJECT_NAME   name of the loaded object
 *   ROW_COUNT     number of rows loaded
 *   LOAD_TS       load timestamp
 *******************************************************************************/

/****** Object:  Table [META].[LOAD_STATISTICS]    Script Date: 4. 08. 2026 09:48:17 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[META].[LOAD_STATISTICS]') AND type in (N'U'))
DROP TABLE [META].[LOAD_STATISTICS]
GO

/****** Object:  Table [META].[LOAD_STATISTICS]    Script Date: 4. 08. 2026 09:48:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [META].[LOAD_STATISTICS](
	[STAT_ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RUN_ID] [bigint] NOT NULL,
	[LAYER_NAME] [varchar](20) NOT NULL,
	[OBJECT_NAME] [varchar](200) NOT NULL,
	[ROW_COUNT] [bigint] NOT NULL,
	[LOAD_TS] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[STAT_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO


