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
    dbt_failed = False

    try:

        connection = get_sqlserver_connection()

        # Start run
        run_id = start_run(
            connection=connection,
            run_type="DBT"
        )

        dbt_status = "SUCCESS"

        # Execute dbt
        try:

            run_dbt(run_id)

        except subprocess.CalledProcessError:

            dbt_failed = True

        # vedno preberi run_results.json
        proces_result = process_run_results(
            connection=connection,
            run_id=run_id,
            results_file="target/run_results.json"
        )

        stats = proces_result["stats"]
        first_error = proces_result["first_error"]

        #   določi končni status dbt izvajanja

        if stats["failed"] > 0:
            dbt_status = "FAILED"
        else:
            dbt_status = "SUCCESS"

        # Finish run
        finish_run(
            connection=connection,
            run_id=run_id,
            status=dbt_status,
            error_message=first_error
        )

        # Če je eden od dbt padel,
        # vrni napako šele po obdelavi rezultatov
        #if dbt_failed:
        #
        #    raise RuntimeError(
        #        "One or more dbt models failed"
        #    )
        if dbt_status == "SUCCESS":
            print(f"RUN {run_id} completed successfully")
        else:
            print(f"RUN {run_id} completed with FAILED status")    
            if first_error:
                print(f"First error: {first_error}")

    except Exception as ex:

        print(f"ERROR: {ex}")

        # Mark run as failed
        if connection and run_id:

            try:

                finish_run(
                    connection=connection,
                    run_id=run_id,
                    status="FAILED",
                    error_message=first_error
                )

            except Exception:
                pass

        raise

    finally:

        if connection:
            connection.close()


if __name__ == "__main__":
    main()