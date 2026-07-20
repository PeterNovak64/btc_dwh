#
#   scripts/orchestrator.py
#
#   Orchestrator for managing and executing data processing workflows
#

"""
orchestrator.py

Glavni orchestrator za dbt izvajanje.
"""

import json
import subprocess
from pathlib import Path

from lib.run import (
    start_dwh_run,
    finish_dwh_run,
    fail_dwh_run
)

from lib.insert_results import process_run_results
# ali kamorkoli boš dal to logiko



def run_dbt():

    cmd = ["dbt", "run"]

    result = subprocess.run(
        cmd,
        check=True,
        text=True,
        capture_output=True
    )

    return result



def load_run_results():

    path = Path("target/run_results.json")

    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)



def calculate_final_status(run_results):

    for result in run_results["results"]:

        if result["status"] not in (
            "success",
            "skipped"
        ):
            return "FAILED"

    return "SUCCESS"



def main():

    run_id = None

    try:

        run_id = start_dwh_run(
            run_type="FULL",
            initiated_by="SQL_AGENT"
        )

        run_dbt()

        run_results = load_run_results()

        process_run_results(
            run_id,
            run_results
        )

        final_status = calculate_final_status(
            run_results
        )

        if final_status == "SUCCESS":

            finish_dwh_run(
                run_id=run_id,
                status="SUCCESS"
            )

        else:

            fail_dwh_run(
                run_id=run_id,
                error_message="One or more dbt models failed"
            )

    except Exception as ex:

        if run_id:

            fail_dwh_run(
                run_id=run_id,
                error_message=str(ex)
            )

        raise




if __name__ == "__main__":
    main()
