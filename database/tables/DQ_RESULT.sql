
/*******************************************************************************
 * Table: META.DQ_RESULT
 * Description:
 *   Stores dbt and data quality test results generated during runs.
 *   Each row captures the outcome of a test execution, including timing,
 *   object context, failure count, and error details.
 *
 * Columns:
 *   DQ_RESULT_ID   result surrogate key
 *   RUN_ID         execution run reference
 *   TEST_TS        test execution timestamp
 *   MODEL_NAME     model or source object name under test
 *   TEST_NAME      test identifier or description
 *   TEST_STATUS    pass/fail status for the test
 *   FAILED_ROWS    count of failed rows when the test failed
 *   ERROR_TEXT     optional failure details or error message
 *   TEST_TYPE      optional test type or category
 *   COLUMN_NAME    optional column-specific test target
 *******************************************************************************/

ALTER TABLE [META].[DQ_RESULT] DROP CONSTRAINT [DF__DQ_RESULT__TEST___5EBF139D]
GO

/****** Object:  Table [META].[DQ_RESULT]    Script Date: 4. 08. 2026 09:44:14 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[META].[DQ_RESULT]') AND type in (N'U'))
DROP TABLE [META].[DQ_RESULT]
GO

/****** Object:  Table [META].[DQ_RESULT]    Script Date: 4. 08. 2026 09:44:14 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [META].[DQ_RESULT](
	[DQ_RESULT_ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RUN_ID] [bigint] NOT NULL,
	[TEST_TS] [datetime2](7) NOT NULL,
	[MODEL_NAME] [sysname] NOT NULL,
	[TEST_NAME] [varchar](200) NOT NULL,
	[TEST_STATUS] [varchar](20) NOT NULL,
	[FAILED_ROWS] [bigint] NULL,
	[ERROR_TEXT] [nvarchar](max) NULL,
	[TEST_TYPE] [varchar](100) NULL,
	[COLUMN_NAME] [varchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[DQ_RESULT_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [META].[DQ_RESULT] ADD  DEFAULT (sysdatetime()) FOR [TEST_TS]
GO


