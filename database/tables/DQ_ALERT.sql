/*******************************************************************************
 * Table: META.DQ_ALERT
 * Description:
 *   Stores data quality alerts generated from profile rules.
 *   Each alert links a run, profile result, rule, and source object.
 *
 * Columns:
 *   ALERT_ID           unique alert identifier
 *   RUN_ID             execution run reference
 *   PROFILE_ID         source profile result reference
 *   RULE_ID            profile rule reference
 *   OBJECT_ID          source object reference
 *   OBJECT_NAME        object name at alert time
 *   COLUMN_NAME        optional column-scoped alert name
 *   RULE_TYPE          rule type that triggered the alert
 *   RULE_NAME          rule name
 *   ALERT_SEVERITY     alert severity level
 *   ACTUAL_VALUE       observed metric value
 *   EXPECTED_MIN_VALUE optional expected minimum threshold
 *   EXPECTED_MAX_VALUE optional expected maximum threshold
 *   ALERT_MESSAGE      human-readable alert message
 *   ALERT_TS           alert timestamp
 *   ALERT_KEY          optional external alert key
 *   ALERT_STATUS       current alert status
 *   RESOLVED_TS        optional resolution timestamp
 *******************************************************************************/

DROP TABLE IF EXISTS META.DQ_ALERT;
GO

CREATE TABLE META.DQ_ALERT
(
    ALERT_ID            BIGINT IDENTITY(1,1) NOT NULL,

    -------------------------------------------------------------
    -- Run context
    -------------------------------------------------------------

    RUN_ID              BIGINT NOT NULL,

    -------------------------------------------------------------
    -- Source profile result
    -------------------------------------------------------------

    PROFILE_ID          BIGINT NOT NULL,

    -------------------------------------------------------------
    -- Rule context
    -------------------------------------------------------------

    RULE_ID             BIGINT NOT NULL,
    OBJECT_ID           BIGINT NOT NULL,
    OBJECT_NAME         VARCHAR(255) NOT NULL,
    COLUMN_NAME         VARCHAR(255) NULL,
    RULE_TYPE           VARCHAR(50) NOT NULL,
    RULE_NAME           VARCHAR(255) NOT NULL,

    -------------------------------------------------------------
    -- Alert details
    -------------------------------------------------------------

    ALERT_SEVERITY      VARCHAR(20) NOT NULL,
    ACTUAL_VALUE        DECIMAL(38,10) NULL,
    EXPECTED_MIN_VALUE  DECIMAL(38,10) NULL,
    EXPECTED_MAX_VALUE  DECIMAL(38,10) NULL,
    ALERT_MESSAGE       VARCHAR(2000) NOT NULL,

    -------------------------------------------------------------
    -- Audit
    -------------------------------------------------------------

    ALERT_TS            DATETIME2(0) NOT NULL
        CONSTRAINT DF_DQ_ALERT_TS DEFAULT SYSDATETIME(),

    ALERT_KEY           VARCHAR(500) NULL,
    ALERT_STATUS        VARCHAR(20) NOT NULL
        CONSTRAINT DF_DQ_ALERT_STATUS DEFAULT 'OPEN',

    RESOLVED_TS         DATETIME2(0) NULL,

    -------------------------------------------------------------
    -- Primary key
    -------------------------------------------------------------

    CONSTRAINT PK_DQ_ALERT PRIMARY KEY (ALERT_ID),

    -------------------------------------------------------------
    -- Foreign keys
    -------------------------------------------------------------

    CONSTRAINT FK_DQ_ALERT_RUN FOREIGN KEY (RUN_ID) REFERENCES META.DWH_RUN(RUN_ID),
    CONSTRAINT FK_DQ_ALERT_PROFILE FOREIGN KEY (PROFILE_ID) REFERENCES META.DQ_PROFILE(PROFILE_ID),
    CONSTRAINT FK_DQ_ALERT_RULE FOREIGN KEY (RULE_ID) REFERENCES META.SOURCE_PROFILE_RULE(RULE_ID),
    CONSTRAINT FK_DQ_ALERT_OBJECT FOREIGN KEY (OBJECT_ID) REFERENCES META.SOURCE_OBJECT(OBJECT_ID),

    -------------------------------------------------------------
    -- Valid values
    -------------------------------------------------------------

    CONSTRAINT CK_DQ_ALERT_SEVERITY CHECK (ALERT_SEVERITY IN ('INFO','WARNING','ERROR','CRITICAL')),
    CONSTRAINT CK_DQ_ALERT_STATUS CHECK (ALERT_STATUS IN ('OPEN','RESOLVED','SUPPRESSED'))
);
GO

CREATE INDEX IX_DQ_ALERT_RUN ON META.DQ_ALERT (RUN_ID, ALERT_SEVERITY);
GO

CREATE INDEX IX_DQ_ALERT_PROFILE ON META.DQ_ALERT (PROFILE_ID);
GO

CREATE INDEX IX_DQ_ALERT_RULE ON META.DQ_ALERT (RULE_ID, ALERT_TS);
GO

CREATE INDEX IX_DQ_ALERT_OBJECT ON META.DQ_ALERT (OBJECT_ID, COLUMN_NAME, ALERT_TS);
GO

CREATE INDEX IX_DQ_ALERT_ALERT_KEY ON META.DQ_ALERT (ALERT_KEY, ALERT_STATUS, ALERT_TS);
GO