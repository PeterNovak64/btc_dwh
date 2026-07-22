#
#   scripts/lib/insert_results.py
#


import json
from pathlib import Path


def load_run_results(results_file):
    """
    Prebere dbt run_results.json in vrne Python objekt.

    Parameters
    ----------
    results_file : str | Path
        Pot do run_results.json

    Returns
    -------
    dict
        Vsebina run_results.json

    Raises
    ------
    FileNotFoundError
        Če datoteka ne obstaja.

    ValueError
        Če datoteka ni veljaven JSON.
    """

    results_file = Path(results_file)

    if not results_file.exists():
        raise FileNotFoundError(
            f"run_results.json ne obstaja: {results_file}"
        )

    try:
        with open(results_file, "r", encoding="utf-8") as f:
            return json.load(f)

    except json.JSONDecodeError as ex:
        raise ValueError(
            f"Neveljaven JSON: {results_file}"
        ) from ex


def extract_result_data(result):
    """
    Iz dbt result objekta pripravi podatke
    za META.DWH_RUN_OBJECT.
    """

    # OBJECT_NAME
    unique_id = result.get("unique_id", "")

    object_name = None

    if unique_id:
        object_name = unique_id.split(".")[-1]

    # OBJECT_LAYER
    relation_name = result.get("relation_name", "")

    object_layer = "META"

    if relation_name:

        parts = (
            relation_name
            .replace('"', '')
            .replace("[", "")
            .replace("]", "")
            .split(".")
        )

        # BTCDWH02_TEST.LAND.tsppica_users
        if len(parts) >= 2:
            object_layer = parts[1].upper()

    # STATUS
    dbt_status = str(
        result.get("status", "")
    ).lower()

    status_mapping = {
        "success": "SUCCESS",
        "error": "FAILED",
        "fail": "FAILED",
        "warn": "WARNING",
        "warning": "WARNING",
        "skipped": "SKIPPED",
        "cancelled": "CANCELLED",
        "canceled": "CANCELLED"
    }

    status = status_mapping.get(
        dbt_status,
        "FAILED"
    )

    # DURATION_SEC
    duration_sec = round(
        float(
            result.get("execution_time", 0)
        ),
        4
    )

    # END_TS
    end_ts = None

    timing = result.get("timing", [])

    if timing:

        last_timing = timing[-1]

        end_ts = (
            last_timing.get("completed_at")
            or last_timing.get("ended_at")
        )

    # ROW_COUNT
    adapter_response = result.get(
        "adapter_response",
        {}
    )

    row_count = (
        adapter_response.get("rows_affected")
        or adapter_response.get("rowcount")
        or adapter_response.get("rows")
    )

    # SQL Server adapter pogosto vrne -1
    if row_count == -1:
        row_count = None

    # ERROR_MESSAGE
    error_message = None

    if status != "SUCCESS":

        error_message = (
            result.get("message")
            or result.get("failures")
        )

        if error_message:
            error_message = str(error_message)[:2000]

    # Return
    return {
        "object_layer": object_layer,
        "object_name": object_name,
        "status": status,
        "duration_sec": duration_sec,
        "end_ts": end_ts,
        "row_count": row_count,
        "error_message": error_message
    }


def update_object_result(
        connection,
        run_id,
        result_data):
    """
    Posodobi objekt v META.DWH_RUN_OBJECT
    na podlagi podatkov iz run_results.json.
    """
    
    sql = """
    UPDATE META.DWH_RUN_OBJECT
       SET END_TS        = ?,
           DURATION_SEC  = ?,
           STATUS        = ?,
           ROW_COUNT     = COALESCE(?, ROW_COUNT),
           ERROR_MESSAGE = ?
     WHERE RUN_ID        = ?
       AND OBJECT_LAYER  = ?
       AND OBJECT_NAME   = ?
       AND STATUS        = 'RUNNING'
    """

    params = (
        result_data["end_ts"],
        result_data["duration_sec"],
        result_data["status"],
        result_data["row_count"],
        result_data["error_message"],
        run_id,
        result_data["object_layer"],
        result_data["object_name"]
    )

    cursor = connection.cursor()

    try:
        #print(params)

        cursor.execute(sql, params)

        rows_updated = cursor.rowcount

        #print("ROWS_UPDATED =", cursor.rowcount)

        if rows_updated == 0:
            raise RuntimeError(
                f"RUNNING zapis ni bil najden: "
                f"{result_data['object_name']}"
            )

        connection.commit()

        return rows_updated

    finally:
        cursor.close()


def process_run_results(
        connection,
        run_id,
        results_file):
    """
    Obdela celoten run_results.json in posodobi
    META.DWH_RUN_OBJECT.
    """

    run_results = load_run_results(results_file)

    results = run_results.get("results", [])

    stats = {
        "total": 0,
        "success": 0,
        "failed": 0,
        "warning": 0,
        "skipped": 0,
        "cancelled": 0
    }

    first_error = None

    for result in results:

        result_data = extract_result_data(result)

        #print(
        #    f"RUN_ID={run_id}, "
        #    f"LAYER={result_data['object_layer']}, "
        #    f"OBJECT={result_data['object_name']}, "
        #    f"STATUS={result_data['status']}"
        #)

        if ( result_data["status"] == "FAILED"
                and first_error is None):

            first_error = result_data["error_message"]

        update_object_result(
            connection,
            run_id,
            result_data
        )

        stats["total"] += 1

        status = result_data["status"]

        if status == "SUCCESS":
            stats["success"] += 1

        elif status == "FAILED":
            stats["failed"] += 1

        elif status == "WARNING":
            stats["warning"] += 1

        elif status == "SKIPPED":
            stats["skipped"] += 1

        elif status == "CANCELLED":
            stats["cancelled"] += 1

    return {
        "stats": stats, 
        "first_error": first_error
    }

