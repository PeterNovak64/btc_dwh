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

from lib.metadata import (
    refresh_source,
    refresh_load_statistics
)

from lib.dq import (
    process_dq_results
)

import itertools
import threading
import time
import re

import argparse


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


def run_dbt(
        run_id,
        dbt_command="run",
        selector=None,
        full_refresh=False):

    cmd = [
        "dbt",
        dbt_command,
        "--vars",
        f"{{run_id: {run_id}}}"
    ]

    if selector:

        cmd.extend([
            "--select",
            selector
        ])

    if full_refresh:

        cmd.append(
            "--full-refresh"
        )

    print()
    print("DBT COMMAND:")
    print(" ".join(cmd))
    print()

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

        print(line)

    return process.wait()



def parse_arguments():

    parser = argparse.ArgumentParser(
        description="BTC DWH Orchestrator"
    )

    parser.add_argument(
        "--load-selector",
        required=True,
        help="dbt selector za LAND del"
    )

    parser.add_argument(
        "--build-selector",
        required=True,
        help="dbt selector za STAG+ del"
    )

    parser.add_argument(
        "--full-refresh",
        action="store_true",
        help="Dodaj --full-refresh na LOAD del"
    )

    return parser.parse_args()



def main():

    args = parse_arguments()

    connection = None
    run_id = None

    try:

        print("[1/7] Opening SQL connection")

        connection = get_sqlserver_connection()

        print("[2/7] Starting DWH run")

        run_id = start_run(
            connection=connection,
            run_type="DBT"
        )

        print(f"RUN_ID = {run_id}")

        #
        # LOAD
        #
        print("[3/7] Executing DBT LOAD")

        run_dbt(
            run_id=run_id,
            dbt_command="run",
            selector=args.load_selector,
            full_refresh=args.full_refresh
        )

        #
        # LOAD results
        #
        print("[4/7] Processing LOAD run_results.json")

        process_run_results(
            connection=connection,
            run_id=run_id,
            results_file="target/run_results.json"
        )

        #
        # refresh_source
        #
        print("[5/7] Refresh source metadata")

        refresh_source(connection)

        #
        # BUILD
        #
        print("[6/7] Executing DBT BUILD")

        run_dbt(
            run_id=run_id,
            dbt_command="build",
            selector=args.build_selector
        )

        #
        # BUILD results
        #
        print("[7/7] Processing BUILD run_results.json")

        process_run_results(
            connection=connection,
            run_id=run_id,
            results_file="target/run_results.json"
        )

        #
        # DQ results
        #
        print("[8/7] Processing DQ results")

        dq_stats = process_dq_results(
            connection=connection,
            run_id=run_id,
            run_results_file="target/run_results.json",
            manifest_file="target/manifest.json"
        )

        print(
            f"DQ tests: "
            f"{dq_stats['total']} "
            f"(PASS={dq_stats['pass']}, "
            f"FAIL={dq_stats['fail']}, "
            f"WARN={dq_stats['warn']})"
        )

        print("[9/9] Refresh load statistics")

        refresh_load_statistics(
            connection=connection,
            run_id=run_id
        )

        finish_run(
            connection=connection,
            run_id=run_id,
            status="SUCCESS"
        )

        print(
            f"RUN {run_id} completed successfully"
        )

    except Exception as ex:

        print(f"ERROR: {ex}")

        if connection and run_id:

            try:

                finish_run(
                    connection=connection,
                    run_id=run_id,
                    status="FAILED",
                    error_message=str(ex)
                )

            except Exception:
                pass

        raise

    finally:

        if connection:
            connection.close()

if __name__ == "__main__":
    main()