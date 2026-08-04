# BTC DWH

This repository contains a dbt-based data warehouse project for the BTC environment, including orchestration logic, metadata tracking, data quality result processing, and SQL Server integration.

## Project structure

- `models/`
  - `land/` - staging tables for source data ingestion
  - `stag/` - transform layer before DWH loading
  - `dwh/` - core DWH tables
  - `mart/` - analytical marts and business-facing models
- `macros/` - dbt macros used by models and hooks
- `database/` - SQL object definitions for stored procedures and metadata tables
- `scripts/` - orchestration and ingestion helpers
- `scripts/lib/` - Python helper modules for DB access, dbt result processing, and metadata refresh
- `target/` - dbt artifacts generated during execution

## Key components

### Orchestrator

`script/orchestrator.py` is the main orchestration script.
It performs the following steps:

1. opens a SQL Server connection
2. starts a run record in `META.DWH_RUN`
3. executes `dbt run` for load models
4. processes `target/run_results.json` and updates `META.DWH_RUN_OBJECT`
5. refreshes source metadata and profile rules via stored procedures
6. refreshes DQ profile metadata
7. executes `dbt build` for build models
8. processes build results again
9. inserts data quality test results into `META.DQ_RESULT`
10. refreshes load statistics
11. finishes the run with success or failure status

### DBT configuration

`dbt_project.yml` defines:

- project name: `btc_dwh`
- model paths
- materialization rules and schemas for `LAND`, `STAG`, `DWH`, and `MART`
- pre- and post-hooks for object run tracking

### Metadata and data quality

- `scripts/lib/run.py` contains helpers for run lifecycle management
- `scripts/lib/insert_results.py` parses dbt `run_results.json` and updates object-level metadata
- `scripts/lib/dq.py` parses dbt test output and writes results into `META.DQ_RESULT`
- `scripts/lib/metadata.py` calls stored procedures in the `META` schema to refresh source metadata, profile rules, DQ profile, and load statistics

## Prerequisites

- Python 3.8+ (or compatible runtime)
- `pyodbc` Python package
- `dbt` installed and configured with the `btc_dwh` profile
- Access to SQL Server with the configured `SERVER`, `DATABASE`, and ODBC driver

## Setup

1. Install Python dependencies:

```powershell
pip install pyodbc
```

2. Ensure the dbt profile `btc_dwh` is configured in your `~/.dbt/profiles.yml`.
3. Confirm `scripts/lib/config.py` contains the correct SQL Server connection settings or replace it with environment-aware configuration.

## Usage

Run the orchestrator with selectors for the load and build phases:

```powershell
python scripts/orchestrator.py --load-selector <load_selector> --build-selector <build_selector>
```

Optional flag:

```powershell
--full-refresh
```

Example:

```powershell
python scripts/orchestrator.py --load-selector tag:load --build-selector tag:build
```

## Testing

Existing test scripts under `scripts/` include coverage for run lifecycle and result processing.
Run them with Python directly or add a test runner integration.

## Artifacts

- `target/run_results.json` - dbt run/build execution metadata
- `target/manifest.json` - dbt node dependency graph and test metadata

## Notes

- This project relies on `dbt` execution as an external subprocess.
- The orchestrator currently hardcodes `target/` artifact paths.
- Errors during orchestration update the run status to `FAILED` in the metadata tables.

## Architecture

See `ARCHITECTURE.md` for a detailed data flow and component diagram.
