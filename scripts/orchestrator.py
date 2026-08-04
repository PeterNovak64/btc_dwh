#
#   scripts/orchestrator.py
#
#   BTC DWH Orchestrator
#

from pathlib import Path
import subprocess
import itertools
import threading
import time
import argparse

from lib.db import get_sqlserver_connection

from lib.run import (
    start_run,
    finish_run
)

from lib.insert_results import (
    process_run_results
)

from lib.dq import (
    process_dq_results
)

from lib.metadata import (
    MetadataService
)


# ==========================================================
# HELPERS
# ==========================================================

def format_duration(seconds):

    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60

    return f"{h:02}:{m:02}:{s:02}"


def model_spinner(
        stop_event,
        model_name):

    start_time = time.time()

    for char in itertools.cycle("|/-\\"):

        if stop_event.is_set():
            break

        elapsed = int(
            time.time() - start_time
        )

        print(
            f"\rRunning {model_name} ... "
            f"{char} "
            f"{format_duration(elapsed)}",
            end="",
            flush=True
        )

        time.sleep(0.5)

    print(
        "\r" + " " * 120 + "\r",
        end=""
    )


# ==========================================================
# DBT
# ==========================================================

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

        cmd.extend(
            [
                "--select",
                selector
            ]
        )

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
                args=(
                    spinner_stop,
                    model_name
                )
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


# ==========================================================
# ARGUMENTS
# ==========================================================

def parse_arguments():

    parser = argparse.ArgumentParser(
        description="BTC DWH Orchestrator"
    )

    parser.add_argument(
        "--load-selector",
        required=True,
        help="dbt selector za LAND"
    )

    parser.add_argument(
        "--build-selector",
        required=True,
        help="dbt selector za BUILD"
    )

    parser.add_argument(
        "--full-refresh",
        action="store_true",
        help="Uporabi --full-refresh"
    )

    return parser.parse_args()


# ==========================================================
# MAIN
# ==========================================================

def main():

    args = parse_arguments()

    connection = None
    run_id = None

    metadata = MetadataService()

    try:

        # --------------------------------------------------
        # SQL CONNECTION
        # --------------------------------------------------

        print("[1/12] Opening SQL connection")

        connection = get_sqlserver_connection()

        # --------------------------------------------------
        # START RUN
        # --------------------------------------------------

        print("[2/12] Starting DWH run")

        run_id = start_run(
            connection=connection,
            run_type="DBT"
        )

        print(f"RUN_ID = {run_id}")

        # --------------------------------------------------
        # LOAD
        # --------------------------------------------------

        print("[3/12] Executing DBT LOAD")

        run_dbt(
            run_id=run_id,
            dbt_command="run",
            selector=args.load_selector,
            full_refresh=args.full_refresh
        )

        # --------------------------------------------------
        # LOAD RESULTS
        # --------------------------------------------------

        print("[4/12] Processing LOAD run_results.json")

        process_run_results(
            connection=connection,
            run_id=run_id,
            results_file="target/run_results.json"
        )

        # --------------------------------------------------
        # SOURCE METADATA
        # --------------------------------------------------

        print("[5/12] Refresh source metadata")

        metadata.refresh_source()

        # --------------------------------------------------
        # SOURCE PROFILE RULES
        # --------------------------------------------------

        print("[6/12] Refresh source profile rules")

        metadata.refresh_source_profile_rule()

        # --------------------------------------------------
        # DQ PROFILE
        # --------------------------------------------------

        print("[7/12] Refresh DQ profile")

        metadata.refresh_dq_profile(
            run_id=run_id
        )

        # --------------------------------------------------
        # BUILD
        # --------------------------------------------------

        print("[8/12] Executing DBT BUILD")

        run_dbt(
            run_id=run_id,
            dbt_command="build",
            selector=args.build_selector
        )

        # --------------------------------------------------
        # BUILD RESULTS
        # --------------------------------------------------

        print("[9/12] Processing BUILD run_results.json")

        process_run_results(
            connection=connection,
            run_id=run_id,
            results_file="target/run_results.json"
        )

        # --------------------------------------------------
        # DQ RESULTS
        # --------------------------------------------------

        print("[10/12] Processing DQ results")

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

        # --------------------------------------------------
        # LOAD STATISTICS
        # --------------------------------------------------

        print("[11/12] Refresh load statistics")

        metadata.refresh_load_statistics(
            run_id=run_id
        )

        # --------------------------------------------------
        # FINISH
        # --------------------------------------------------

        print("[12/12] Finish run")

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