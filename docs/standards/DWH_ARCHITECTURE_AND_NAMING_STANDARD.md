# BTC DWH Architecture and Naming Standard

Version: 1.0

Status: Draft

Owner: BTC DWH Architecture

---

# Purpose

This document defines:

- DWH architecture layers
- Layer responsibilities
- Naming conventions
- SCD2 standards
- Metadata standards
- One Truth principles

The primary goal is to create a maintainable, self-documenting and reusable enterprise data warehouse architecture.

---

# Architecture Overview

```text
LAND

↓

STAG

    STG_*   Source Standardization

    REF_*   Reference Data

    INT_*   Business Integration

↓

DWH

    DIM_*   Dimensions

    FACT_*  Facts

↓

Power BI Semantic Models
```

---

# Core Principles

1. Every layer must have a single responsibility.
2. DWH is the Enterprise Source of Truth.
3. Power BI consumes truth and does not create truth.
4. Historical tracking belongs to DWH.
5. Reference data belongs to REF.
6. Business integration belongs to INT.
7. Technical standardization belongs to STG.
8. Naming must prioritize readability.
9. Meaning is more important than abbreviations.
10. Column names must be understandable without external documentation.

---

# LAND Layer

## Purpose

Local copy of source systems.

## Responsibilities

- source preservation
- audit trail
- troubleshooting
- replay capability

## Examples

```text
LAND.TSSPICA_USERS
LAND.WMS_ARTICLE
LAND.ERP_CUSTOMER
```

## Mandatory Metadata

```sql
LND_SRC_SYSTEM
LND_LOAD_TS
LND_RUN_ID
```

| Column | Description |
|----------|-------------|
| LND_SRC_SYSTEM | Source system name |
| LND_LOAD_TS | Row load timestamp |
| LND_RUN_ID | ETL execution identifier |

---

# STAG Layer

## Purpose

Technical standardization of a single source system.

## Naming Pattern

```text
STG_<SOURCE>_<ENTITY>
```

## Examples

```text
STG_TSSPICA_USERS
STG_WMS_ARTICLE
STG_ERP_CUSTOMER
```

## Allowed Operations

- column selection
- column renaming
- TRIM()
- UPPER()
- LOWER()
- NULLIF()
- TRY_CONVERT()
- data type standardization
- technical key preparation

## Examples

```sql
TRY_CONVERT(INT, EMPLOYEE_NO) AS EMPLOYEE_ID

UPPER(TRIM(FIRST_NAME))

TRY_CONVERT(DATE, BIRTH)
```

## Not Allowed

- joins between source systems
- source prioritization
- business mappings
- harmonization
- surrogate keys
- SCD processing

## Guiding Question

> How do we technically standardize a source?

---

# REF Layer

## Purpose

Enterprise reference data.

REF objects are physically stored in the STAG schema.

## Naming Pattern

```text
REF_<ENTITY>
```

## Examples

```text
REF_LOCATION

REF_LOCATION_MAPPING

REF_COST_CENTER

REF_PLAN

REF_KPI_DEFINITION
```

## Characteristics

- business maintained
- enterprise owned
- manually maintained
- not sourced directly from operational systems

## Typical Content

- reference hierarchies
- translation tables
- mapping tables
- planning data
- override data

## Guiding Question

> What are the official enterprise reference definitions?

---

# INT Layer

## Purpose

Business integration of multiple source systems.

INT objects are physically stored in the STAG schema.

## Naming Pattern

```text
INT_<ENTITY>
```

## Examples

```text
INT_EMPLOYEE

INT_LOCATION

INT_ARTICLE

INT_CUSTOMER
```

## Allowed Operations

- joins between source systems
- REF lookups
- source prioritization
- COALESCE logic
- code harmonization
- business key harmonization

## Example

```text
TSSPICA Employee
+
AD Employee
+
Exchange Employee

↓

INT_EMPLOYEE
```

## Not Allowed

- surrogate keys
- SCD processing
- historical tracking

## Guiding Question

> How do we create a single business entity from multiple sources?

---

# DWH Layer

## Purpose

Enterprise Source of Truth.

## Naming Patterns

```text
DIM_<ENTITY>

FACT_<ENTITY>
```

## Examples

```text
DIM_EMPLOYEE
DIM_LOCATION
DIM_ARTICLE
DIM_DATE

FACT_ATTENDANCE
FACT_STOCK
FACT_SHIPMENT
```

## Responsibilities

- surrogate key generation
- SCD2 processing
- history tracking
- conformed dimensions
- conformed hierarchies
- enterprise business rules

## Guiding Question

> How do we store and govern enterprise truth?

---

# Dimension Standard

## Mandatory Columns

```sql
<ENTITY>_SID

SCD_VALID_FROM_DT
SCD_VALID_TO_DT

SCD_CURRENT_RECORD

SCD_CHANGE_HASH

SCD_RUN_ID
```

## Definitions

| Column | Description |
|----------|-------------|
| SCD_VALID_FROM_DT | Version start date |
| SCD_VALID_TO_DT | Version end date |
| SCD_CURRENT_RECORD | Current active version |
| SCD_CHANGE_HASH | Change detection hash |
| SCD_RUN_ID | ETL execution identifier |

---

# State Fact Standard

## Examples

```text
FACT_EMPLOYEE_STATE

FACT_BUDGET

FACT_PLAN
```

## Mandatory Columns

```sql
<FACT>_SID

SCD_VALID_FROM_DT
SCD_VALID_TO_DT

SCD_CURRENT_RECORD

SCD_CHANGE_HASH

SCD_RUN_ID
```

State Facts use the same historization pattern as dimensions.

---

# Transaction Fact Standard

## Examples

```text
FACT_STOCK_MOVEMENT

FACT_SHIPMENT

FACT_RECEIPT
```

## Characteristics

- transactional history
- no SCD processing
- no surrogate fact key by default

---

# One Truth Principle

One Truth means:

> The same business question must return the same answer regardless of report, dashboard, semantic model or Power BI workspace.

This is achieved through:

```text
DIM_DATE

DIM_LOCATION

DIM_EMPLOYEE

DIM_ARTICLE
```

and shared enterprise hierarchies.

Business truth is defined in DWH.

---

# Power BI Principle

Power BI does not create truth.

Power BI presents truth.

## Architecture

```text
Shared Semantic Models

    DIM_DATE
    DIM_LOCATION
    DIM_EMPLOYEE
    DIM_ARTICLE

+

Domain Semantic Models

    HR
    LOGISTICS
    FINANCE
```

Reuse whenever possible:

- dimensions
- hierarchies
- KPI definitions

---

# Naming Standards

## Business Keys

```sql
_ID
```

Examples:

```sql
EMPLOYEE_ID
ARTICLE_ID
LOCATION_ID
```

---

## Surrogate Keys

```sql
_SID
```

Examples:

```sql
EMPLOYEE_SID
ARTICLE_SID
LOCATION_SID
```

---

## Dates

```sql
_DT
```

SQL Type:

```sql
DATE
```

Examples:

```sql
BIRTH_DT

HIRE_DT

SCD_VALID_FROM_DT

SCD_VALID_TO_DT
```

Default function:

```sql
CAST(SYSDATETIME() AS DATE)
```

---

## Timestamps

```sql
_TS
```

SQL Type:

```sql
DATETIME2
```

Examples:

```sql
LND_LOAD_TS

CREATED_TS

UPDATED_TS
```

Default function:

```sql
SYSDATETIME()
```

---

# Readability First Principle

Prefer:

```sql
EMPLOYEE_NAME

LOCATION_NAME

STATUS_CODE

STATUS_DESCRIPTION
```

Avoid:

```sql
EMPLOYEE_NM

LOCATION_CD

STATUS_DESC
```

## Allowed Abbreviations

```sql
_ID

_SID

_DT

_TS
```

---

# Layer Summary

| Layer | Responsibility |
|---------|---------------|
| LAND | Source preservation |
| STG | Technical standardization |
| REF | Reference definitions |
| INT | Business integration |
| DWH | Enterprise truth |
| Power BI | Presentation layer |

---

# Final Principle

Every layer must answer exactly one question:

STG

> How do we technically standardize a source?

REF

> What are the official enterprise reference definitions?

INT

> How do we create a single business entity from multiple systems?

DWH

> How do we store and govern enterprise truth?

Power BI

> How do we present enterprise truth?

---

# Fabric Medallion Mapping

| BTC Layer | Fabric Layer |
|------------|-------------|
| LAND | Bronze |
| STG_* | Silver |
| REF_* | Silver |
| INT_* | Silver |
| DIM_* | Gold |
| FACT_* | Gold |
| Power BI Semantic Models | Semantic Layer |

The BTC architecture follows Medallion principles while maintaining a traditional dimensional enterprise DWH model.

