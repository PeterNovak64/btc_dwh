#
#   scripts/orchestrator.py
#
#   Orchestrator for managing and executing data processing workflows
#

"""
orchestrator.py

Glavni orchestrator za dbt izvajanje.
"""

from pathlib import Path
import subprocess

from lib.db import get_sqlserver_connection

from lib.run import (
    start_run,
    finish_run
)

from lib.insert_results import (
    process_run_results
)


def run_dbt(run_id):

    cmd = [
        "dbt",
        "run",
        "--vars",
        f"{{run_id: {run_id}}}"
    ]

    return subprocess.run(
        cmd,
        check=True,
        text=True,
        capture_output=True
    )


def main():

    connection = None
    run_id = None

    try:

        connection = get_sqlserver_connection()

        # Start run
        run_id = start_run(
            connection=connection,
            run_type="DBT"
        )

        print(f"RUN_ID = {run_id}")

        # Execute dbt
        run_dbt(run_id)

        # Process run_results.json
        process_run_results(
            connection=connection,
            run_id=run_id,
            results_file=Path("target/run_results.json")
        )

        # Finish run
        finish_run(
            connection=connection,
            run_id=run_id,
            status="SUCCESS"
        )

        print("RUN SUCCESS")

    except Exception as ex:

        print(f"ERROR: {ex}")

        # Mark run as failed
        if connection and run_id:

            try:

                finish_run(
                    connection=connection,
                    run_id=run_id,
                    status="FAILED"
                )

            except Exception:
                pass

        raise

    finally:

        if connection:
            connection.close()


if __name__ == "__main__":
    main()