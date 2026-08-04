
/*******************************************************************************
 * Table: META.DWH_RUN
 * Description:
 *   Stores metadata for DWH runs, including run type, status, timing,
 *   error details, and dbt invocation information.
 *
 * Columns:
 *   RUN_ID              BIGINT IDENTITY(1,1) PRIMARY KEY
 *   RUN_TYPE            run type identifier, e.g. 'DBT'
 *   STATUS              run state, default 'RUNNING'
 *   START_TS            run start timestamp, default sysdatetime()
 *   END_TS              run end timestamp
 *   DURATION_SEC        elapsed duration in seconds
 *   DBT_INVOCATION_ID   optional dbt invocation identifier
 *   CREATED_BY          user name that created the run record
 *   ERROR_MESSAGE       optional error details
 *   RUN_NAME            optional run name
 *
 * This script drops the existing table and recreate it with its constraints.
 *******************************************************************************/
ALTER TABLE [META].[DWH_RUN] DROP CONSTRAINT [DF_DHW_RZN_CREATED_BY]
GO

ALTER TABLE [META].[DWH_RUN] DROP CONSTRAINT [DF_DWH_RUN_START_TS]
GO

ALTER TABLE [META].[DWH_RUN] DROP CONSTRAINT [DF_DWH_RUN_STATUS]
GO

/****** Object:  Table [META].[DWH_RUN]    Script Date: 4. 08. 2026 09:47:04 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[META].[DWH_RUN]') AND type in (N'U'))
DROP TABLE [META].[DWH_RUN]
GO

/****** Object:  Table [META].[DWH_RUN]    Script Date: 4. 08. 2026 09:47:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [META].[DWH_RUN](
	[RUN_ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RUN_TYPE] [varchar](20) NOT NULL,
	[STATUS] [varchar](20) NOT NULL,
	[START_TS] [datetime2](7) NOT NULL,
	[END_TS] [datetime2](7) NULL,
	[DURATION_SEC] [decimal](18, 4) NULL,
	[DBT_INVOCATION_ID] [varchar](100) NULL,
	[CREATED_BY] [varchar](100) NULL,
	[ERROR_MESSAGE] [varchar](2000) NULL,
	[RUN_NAME] [varchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[RUN_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [META].[DWH_RUN] ADD  CONSTRAINT [DF_DWH_RUN_STATUS]  DEFAULT ('RUNNING') FOR [STATUS]
GO

ALTER TABLE [META].[DWH_RUN] ADD  CONSTRAINT [DF_DWH_RUN_START_TS]  DEFAULT (sysdatetime()) FOR [START_TS]
GO

ALTER TABLE [META].[DWH_RUN] ADD  CONSTRAINT [DF_DHW_RZN_CREATED_BY]  DEFAULT (suser_sname()) FOR [CREATED_BY]
GO


