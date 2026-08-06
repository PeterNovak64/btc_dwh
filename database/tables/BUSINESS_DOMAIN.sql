/*******************************************************************************
 * Table: META.BUSINESS_DOMAIN
 * Description:
 *   Stores business domain metadata for governance, ownership, and status.
 *   Domains are used to classify business entities and provide owner/steward
 *   contact details for data governance.
 *
 * Columns:
 *   BUSINESS_DOMAIN_ID  surrogate key for the business domain
 *   DOMAIN_NAME         business domain name
 *   DOMAIN_SHORT        short business domain code
 *   DESCRIPTION         optional business domain description
 *   OWNER_ROLE          owning role for the domain
 *   OWNER_NAME          owner name or team
 *   OWNER_EMAIL         owner email address
 *   STEWARD_ROLE        steward role for the domain
 *   STEWARD_NAME        steward name or team
 *   STEWARD_EMAIL       steward email address
 *   ACTIVE_FLAG         active indicator, default 1
 *   CREATED_TS          record creation timestamp, default sysdatetime()
 *******************************************************************************/

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[META].[BUSINESS_DOMAIN]') AND type in (N'U'))
    DROP TABLE [META].[BUSINESS_DOMAIN];
GO

CREATE TABLE [META].[BUSINESS_DOMAIN]
(
    [BUSINESS_DOMAIN_ID] BIGINT IDENTITY(1,1) NOT NULL,

    -------------------------------------------------------------
    -- Domain
    -------------------------------------------------------------

    [DOMAIN_NAME] VARCHAR(100) NOT NULL,
    [DOMAIN_SHORT] VARCHAR(20) NOT NULL,
    [DESCRIPTION] VARCHAR(1000) NULL,

    -------------------------------------------------------------
    -- Governance
    -------------------------------------------------------------

    [OWNER_ROLE] VARCHAR(255) NOT NULL,
    [OWNER_NAME] VARCHAR(255) NULL,
    [OWNER_EMAIL] VARCHAR(255) NULL,

    [STEWARD_ROLE] VARCHAR(255) NULL,
    [STEWARD_NAME] VARCHAR(255) NULL,
    [STEWARD_EMAIL] VARCHAR(255) NULL,

    -------------------------------------------------------------
    -- Status
    -------------------------------------------------------------

    [ACTIVE_FLAG] BIT NOT NULL
        CONSTRAINT [DF_BUSINESS_DOMAIN_ACTIVE] DEFAULT (1),

    -------------------------------------------------------------
    -- Audit
    -------------------------------------------------------------

    [CREATED_TS] DATETIME2(0) NOT NULL
        CONSTRAINT [DF_BUSINESS_DOMAIN_CREATED_TS] DEFAULT SYSUTCDATETIME(),

    -------------------------------------------------------------
    -- Constraints
    -------------------------------------------------------------

    CONSTRAINT [PK_BUSINESS_DOMAIN] PRIMARY KEY ([BUSINESS_DOMAIN_ID]),

    CONSTRAINT [UQ_BUSINESS_DOMAIN_NAME] UNIQUE ([DOMAIN_NAME]),

    CONSTRAINT [UQ_BUSINESS_DOMAIN_SHORT] UNIQUE ([DOMAIN_SHORT])
);
GO
