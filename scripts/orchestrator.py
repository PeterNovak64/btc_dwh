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

def model_spinner(stop_event, model_name):

    start_time = time.time()

    for char in itertools.cycle("|/-\\"):

        if stop_event.is_set():
            break

        elapsed = time.time() - start_time

        print(
            f"\rRunning {model_name} ... "
            f"{char} "
            f"{elapsed:.2f}s",
            end="",
            flush=True
        )

        time.sleep(0.5)

    print(
        "\r" + " " * 120 + "\r",
        end=""
    )


def run_operation(
        function,
        message,
        *args,
        **kwargs):

    """
    Run a normal Python operation with the same visual pattern
    used by dbt model execution:

        Refreshing source metadata ... OK [0.18s]

    The function is deliberately the first argument so existing
    calls can use:

        run_operation(metadata.refresh_source, "Refreshing source metadata")
    """

    stop_event = threading.Event()

    spinner_thread = threading.Thread(
        target=operation_spinner,
        args=(stop_event, message)
    )

    start_time = time.time()

    spinner_thread.start()

    try:

        result = function(
            *args,
            **kwargs
        )

        duration = time.time() - start_time

        stop_event.set()
        spinner_thread.join()

        print(
            f"{message} ... OK [{duration:.2f}s]"
        )

        return result

    except Exception:

        duration = time.time() - start_time

        stop_event.set()
        spinner_thread.join()

        print(
            f"{message} ... ERROR [{duration:.2f}s]"
        )

        raise


def operation_spinner(
        stop_event,
        message):

    for char in itertools.cycle("|/-\\"):

        if stop_event.is_set():
            break

        print(
            f"\r{message} ... {char}",
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
        full_refresh=False,
        sync_structure=False):

    vars_value = (
        f"{{run_id: {run_id}, "
        f"sync_structure: {'true' if sync_structure else 'false'}}}"
    )

    cmd = [
        "dbt",
        dbt_command,
        "--vars",
        vars_value
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


def run_dbt_step(
        message,
        run_id,
        dbt_command="run",
        selector=None,
        full_refresh=False,
        sync_structure=False):

    """
    Wrapper for a complete dbt invocation.

    dbt already prints model-level timings, so this wrapper does
    not add another spinner. It only adds the elapsed time for
    the complete dbt invocation.
    """

    print(message)

    start_time = time.time()

    try:

        return_code = run_dbt(
            run_id=run_id,
            dbt_command=dbt_command,
            selector=selector,
            full_refresh=full_refresh,
            sync_structure=sync_structure
        )

        duration = time.time() - start_time

        if return_code == 0:
            print(
                f"{message} ... OK [{duration:.2f}s]"
            )
        else:
            print(
                f"{message} ... ERROR [{duration:.2f}s]"
            )

        return return_code

    except Exception:

        duration = time.time() - start_time

        print(
            f"{message} ... ERROR [{duration:.2f}s]"
        )

        raise


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

        connection = run_operation(
            get_sqlserver_connection,
            "Opening SQL connection"
        )

        # --------------------------------------------------
        # START RUN
        # --------------------------------------------------

        run_id = run_operation(
            start_run,
            "Starting DWH run",
            connection=connection,
            run_type="DBT"
        )

        print(f"RUN_ID = {run_id}")

        # --------------------------------------------------
        # LAND STRUCTURE SYNCHRONIZATION
        # --------------------------------------------------

        sync_return_code = run_dbt_step(
            "Executing DBT LAND structure synchronization",
            run_id=run_id,
            dbt_command="run",
            selector=args.load_selector,
            full_refresh=args.full_refresh,
            sync_structure=True
        )

        if sync_return_code != 0:
            raise RuntimeError(
                "DBT LAND structure synchronization failed"
            )

        # --------------------------------------------------
        # STRUCTURE SYNC RESULTS
        # --------------------------------------------------

        print("[4/16] Processing structure synchronization run_results.json")

        sync_result = run_operation(
            process_run_results,
            "Processing structure synchronization results",
            connection=connection,
            run_id=run_id,
            results_file="target/run_results.json"
        )

        sync_stats = sync_result["stats"]

        print(
            f"SYNC STRUCTURE results: "
            f"TOTAL={sync_stats['total']}, "
            f"SUCCESS={sync_stats['success']}, "
            f"FAILED={sync_stats['failed']}, "
            f"WARNING={sync_stats['warning']}, "
            f"SKIPPED={sync_stats['skipped']}"
        )

        if sync_stats["failed"] > 0:
            raise RuntimeError(
                "DBT LAND structure synchronization failed"
            )

        # --------------------------------------------------
        # SOURCE METADATA
        # --------------------------------------------------

        print("[5/16] Refresh source metadata")

        run_operation(
            metadata.refresh_source,
            "Refreshing source metadata"
        )

        # --------------------------------------------------
        # SOURCE PROFILE RULES
        # --------------------------------------------------

        print("[6/16] Refresh source profile rules")

        run_operation(
            metadata.refresh_source_profile_rule,
            "Refreshing source profile rules"
        )

        # --------------------------------------------------
        # LOAD LAND
        # --------------------------------------------------

        load_return_code = run_dbt_step(
            "Executing DBT LAND load",
            run_id=run_id,
            dbt_command="run",
            selector=args.load_selector,
            full_refresh=args.full_refresh,
            sync_structure=False
        )

        if load_return_code != 0:
            raise RuntimeError(
                "DBT LAND load failed"
            )

        # --------------------------------------------------
        # LOAD RESULTS
        # --------------------------------------------------

        print("[8/16] Processing LOAD run_results.json")

        load_result = run_operation(
            process_run_results,
            "Processing LOAD results",
            connection=connection,
            run_id=run_id,
            results_file="target/run_results.json"
        )

        load_stats = load_result["stats"]

        print(
            f"LOAD results: "
            f"TOTAL={load_stats['total']}, "
            f"SUCCESS={load_stats['success']}, "
            f"FAILED={load_stats['failed']}, "
            f"WARNING={load_stats['warning']}, "
            f"SKIPPED={load_stats['skipped']}"
        )

        if load_stats["failed"] > 0:
            raise RuntimeError(
                "DBT LAND load failed"
            )

        # --------------------------------------------------
        # DQ PROFILE
        # --------------------------------------------------

        print("[9/16] Refresh DQ profile")

        run_operation(
            metadata.refresh_dq_profile,
            "Refreshing DQ profile",
            run_id=run_id
        )

        # --------------------------------------------------
        # DQ ALERT
        # --------------------------------------------------

        print("[10/16] Refresh DQ alerts")

        dq_alert_stats = run_operation(
            metadata.refresh_dq_alert,
            "Refreshing DQ alerts",
            run_id=run_id
        )

        if dq_alert_stats:

            print(
                f"DQ alerts: "
                f"CURRENT={dq_alert_stats.get('CURRENT_VIOLATIONS', 0)}, "
                f"NEW={dq_alert_stats.get('INSERTED_NEW_ALERTS', 0)}, "
                f"UPDATED={dq_alert_stats.get('UPDATED_OPEN_ALERTS', 0)}, "
                f"RESOLVED={dq_alert_stats.get('RESOLVED_ALERTS', 0)}, "
                f"OPEN={dq_alert_stats.get('OPEN_ALERTS_AFTER_RUN', 0)}"
            )

        else:

            print(
                "DQ alerts: no summary returned"
            )

        # --------------------------------------------------
        # BUILD
        # --------------------------------------------------

        build_return_code = run_dbt_step(
            "Executing DBT BUILD",
            run_id=run_id,
            dbt_command="build",
            selector=args.build_selector
        )

        if build_return_code != 0:
            raise RuntimeError(
                "DBT BUILD failed"
            )

        # --------------------------------------------------
        # BUILD RESULTS
        # --------------------------------------------------

        print("[12/16] Processing BUILD run_results.json")

        build_result = run_operation(
            process_run_results,
            "Processing BUILD results",
            connection=connection,
            run_id=run_id,
            results_file="target/run_results.json"
        )

        build_stats = build_result["stats"]

        print(
            f"BUILD results: "
            f"TOTAL={build_stats['total']}, "
            f"SUCCESS={build_stats['success']}, "
            f"FAILED={build_stats['failed']}, "
            f"WARNING={build_stats['warning']}, "
            f"SKIPPED={build_stats['skipped']}"
        )

        if build_stats["failed"] > 0:
            raise RuntimeError(
                "DBT BUILD failed"
            )

        # --------------------------------------------------
        # DQ RESULTS
        # --------------------------------------------------

        print("[13/16] Processing DBT DQ results")

        dq_stats = run_operation(
            process_dq_results,
            "Processing DBT DQ results",
            connection=connection,
            run_id=run_id,
            run_results_file="target/run_results.json",
            manifest_file="target/manifest.json"
        )

        print(
            f"DBT DQ tests: "
            f"{dq_stats['total']} "
            f"(PASS={dq_stats['pass']}, "
            f"FAIL={dq_stats['fail']}, "
            f"WARN={dq_stats['warn']})"
        )

        # --------------------------------------------------
        # LOAD STATISTICS
        # --------------------------------------------------

        print("[14/16] Refresh load statistics")

        run_operation(
            metadata.refresh_load_statistics,
            "Refreshing load statistics",
            run_id=run_id
        )

        # --------------------------------------------------
        # FINISH
        # --------------------------------------------------

        print("[15/16] Finish run")

        run_operation(
            finish_run,
            "Finishing DWH run",
            connection=connection,
            run_id=run_id,
            status="SUCCESS"
        )

        print(
            f"RUN {run_id} completed successfully"
        )

        print("[16/16] Done")

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

