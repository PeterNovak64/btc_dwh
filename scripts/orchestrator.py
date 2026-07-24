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

import itertools
import threading
import time
import re


def format_duration(seconds):

    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60

    return f"{h:02}:{m:02}:{s:02}"


def model_spinner(stop_event, model_name):

    start_time = time.time()

    for char in itertools.cycle("|/-\\"):

        if stop_event.is_set():
            break

        elapsed = int(time.time() - start_time)

        print(
            f"\rRunning {model_name} ... {char} {format_duration(elapsed)}",
            end="",
            flush=True
        )

        time.sleep(0.5)

    print("\r" + " " * 120 + "\r", end="")


def run_dbt(run_id):

    cmd = [
        "dbt",
        "run",
        "--vars",
        f"{{run_id: {run_id}}}"
    ]

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    spinner_thread = None
    spinner_stop = None

    for line in process.stdout:

        line = line.rstrip()

        #
        # START model
        #
        if "START sql table model" in line:

            model_name = (
                line
                .split("model")[-1]
                .split("[")[0]
                .strip()
            )

            model_name = model_name.split()[0]

            print(line)

            spinner_stop = threading.Event()

            spinner_thread = threading.Thread(
                target=model_spinner,
                args=(spinner_stop, model_name)
            )

            spinner_thread.start()

            continue

        # model končan
        if (
            "OK created sql table model" in line
            or "ERROR creating sql table model" in line
        ):

            if spinner_stop:
                spinner_stop.set()

            if spinner_thread:
                spinner_thread.join()

            print(line)

            continue

        # ostalo
        print(line)

    return_code = process.wait()

    return return_code



def main():

    connection = None
    run_id = None
    dbt_failed = False

    try:

        print("[1/5] Opening SQL connection")

        connection = get_sqlserver_connection()

        print("[2/5] Starting DWH run")

        # Start run
        run_id = start_run(
            connection=connection,
            run_type="DBT"
        )

        print(f"        RUN_ID = {run_id}")

        dbt_status = "SUCCESS"

        print("[3/5] Executing dbt")

        # Execute dbt
        try:

            return_code = run_dbt(run_id)

            if return_code != 0:
                dbt_failed = True

        except subprocess.CalledProcessError:

            dbt_failed = True

        print("[4/5] Processing run_results.json")

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

        print("[5/5] Finalizing run")

        # Finish run
        finish_run(
            connection=connection,
            run_id=run_id,
            status=dbt_status,
            error_message=first_error
        )

        # Če je eden od dbt padel,
        # vrni napako šele po obdelavi rezultatov
        if dbt_status == "SUCCESS":
            print(f"RUN {run_id} completed successfully")
        else:
            print(f"RUN {run_id} completed with FAILED status")    
            if first_error:
                print(f"First error: {first_error}")

            raise RuntimeError( first_error if first_error else "DBT run failed" )

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