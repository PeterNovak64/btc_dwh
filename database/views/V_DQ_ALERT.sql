/*******************************************************************************
 * View: META.V_DQ_ALERT
 * Description:
 *   Provides a consolidated alert view with source object, rule, business domain,
 *   and governance metadata. Useful for monitoring data quality alerts together
 *   with related domain and ownership context.
 *
 * Columns:
 *   ALERT_ID               alert identifier
 *   RUN_ID                 execution run reference
 *   ALERT_KEY              external alert key
 *   ALERT_STATUS           current alert status
 *   ALERT_SEVERITY         severity level
 *   ALERT_TS               alert timestamp
 *   RESOLVED_TS            alert resolution timestamp
 *   ALERT_AGE_DAYS         days between alert timestamp and resolution or now
 *   ACTUAL_VALUE           observed metric value
 *   EXPECTED_MIN_VALUE     optional expected minimum metric threshold
 *   EXPECTED_MAX_VALUE     optional expected maximum metric threshold
 *   ALERT_MESSAGE          human-readable alert message
 *   OBJECT_ID              source object identifier
 *   OBJECT_NAME            source object name
 *   RULE_ID                profile rule identifier
 *   RULE_NAME              rule name
 *   RULE_TYPE              profile rule type
 *   COLUMN_NAME            optional column-level rule name
 *   BUSINESS_DOMAIN_ID     linked business domain identifier
 *   DOMAIN_NAME            domain name
 *   DOMAIN_SHORT           domain short code
 *   OWNER_ROLE             domain owner role
 *   OWNER_NAME             domain owner name
 *   OWNER_EMAIL            domain owner email
 *   STEWARD_ROLE           domain steward role
 *   STEWARD_NAME           domain steward name
 *   STEWARD_EMAIL          domain steward email
 *******************************************************************************/

CREATE OR ALTER VIEW META.V_DQ_ALERT
AS
SELECT

    ----------------------------------------------------
    -- Alert
    ----------------------------------------------------

    A.ALERT_ID,
    A.RUN_ID,
    A.ALERT_KEY,
    A.ALERT_STATUS,
    A.ALERT_SEVERITY,
    A.ALERT_TS,
    A.RESOLVED_TS,
    DATEDIFF(DAY, A.ALERT_TS, ISNULL(A.RESOLVED_TS, SYSDATETIME())) AS ALERT_AGE_DAYS,
    A.ACTUAL_VALUE,
    A.EXPECTED_MIN_VALUE,
    A.EXPECTED_MAX_VALUE,
    A.ALERT_MESSAGE,

    ----------------------------------------------------
    -- Source object
    ----------------------------------------------------

    O.OBJECT_ID,
    O.OBJECT_NAME,

    ----------------------------------------------------
    -- Rule
    ----------------------------------------------------

    A.RULE_ID,
    A.RULE_NAME,
    A.RULE_TYPE,
    A.COLUMN_NAME,

    ----------------------------------------------------
    -- Business domain
    ----------------------------------------------------

    D.BUSINESS_DOMAIN_ID,
    D.DOMAIN_NAME,
    D.DOMAIN_SHORT,

    ----------------------------------------------------
    -- Governance
    ----------------------------------------------------

    D.OWNER_ROLE,
    D.OWNER_NAME,
    D.OWNER_EMAIL,
    D.STEWARD_ROLE,
    D.STEWARD_NAME,
    D.STEWARD_EMAIL

FROM META.DQ_ALERT A

INNER JOIN META.SOURCE_OBJECT O
    ON O.OBJECT_ID = A.OBJECT_ID

LEFT JOIN META.BUSINESS_DOMAIN D
    ON D.BUSINESS_DOMAIN_ID = O.BUSINESS_DOMAIN_ID;
GO

