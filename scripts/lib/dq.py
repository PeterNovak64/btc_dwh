#
#   scripts/lib/dq.py
#

import json
from pathlib import Path


def load_artifacts(
        run_results_file,
        manifest_file):
    """
    Prebere dbt artefakte in vrne Python objekta.
    """

    run_results_file = Path(run_results_file)
    manifest_file = Path(manifest_file)

    if not run_results_file.exists():
        raise FileNotFoundError(
            f"run_results.json ne obstaja: "
            f"{run_results_file}"
        )

    if not manifest_file.exists():
        raise FileNotFoundError(
            f"manifest.json ne obstaja: "
            f"{manifest_file}"
        )

    with open(
        run_results_file,
        encoding="utf8"
    ) as f:

        run_results = json.load(f)

    with open(
        manifest_file,
        encoding="utf8"
    ) as f:

        manifest = json.load(f)

    return run_results, manifest


def extract_test_data(
        result,
        manifest):
    """
    Iz dbt test rezultata pripravi podatke
    za META.DQ_RESULT.
    """

    unique_id = result.get(
        "unique_id",
        ""
    )

    node = manifest.get(
        "nodes",
        {}
    ).get(
        unique_id
    )

    if not node:
        return None

    if node.get(
        "resource_type"
    ) != "test":
        return None

    #
    # model
    #
    model_name = None

    for dep in node.get(
        "depends_on",
        {}
    ).get(
        "nodes",
        []
    ):

        if dep.startswith(
            "model."
        ):

            model_name = dep.split(
                "."
            )[-1]

            break

    #
    # test type
    #
    test_metadata = node.get(
        "test_metadata",
        {}
    )

    test_type = test_metadata.get(
        "name"
    )

    #
    # column
    #
    column_name = node.get(
        "column_name"
    )

    if not column_name:

        column_name = (
            test_metadata
            .get(
                "kwargs",
                {}
            )
            .get(
                "column_name"
            )
        )

    #
    # status
    #
    status = str(
        result.get(
            "status",
            ""
        )
    ).upper()

    failures = (
        result.get(
            "failures",
            0
        ) or 0
    )

    test_name = node.get(
        "name"
    )

    error_text = None

    if status != "PASS":

        error_text = (
            result.get("message")
            or result.get("failures")
        )

        if error_text:
            error_text = str(
                error_text
            )[:4000]

    return {
        "model_name": model_name,
        "test_name": test_name,
        "test_status": status,
        "failed_rows": failures,
        "error_text": error_text,
        "test_type": test_type,
        "column_name": column_name
    }


def insert_dq_result(
        connection,
        run_id,
        test_data):
    """
    Doda en zapis v META.DQ_RESULT.
    """

    cursor = connection.cursor()

    try:

        cursor.execute(
            """
            INSERT INTO META.DQ_RESULT
            (
                RUN_ID,
                TEST_TS,
                MODEL_NAME,
                TEST_NAME,
                TEST_STATUS,
                FAILED_ROWS,
                ERROR_TEXT,
                TEST_TYPE,
                COLUMN_NAME
            )
            VALUES
            (
                ?,
                GETDATE(),
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                ?
            )
            """,
            run_id,
            test_data["model_name"],
            test_data["test_name"],
            test_data["test_status"],
            test_data["failed_rows"],
            test_data["error_text"],
            test_data["test_type"],
            test_data["column_name"]
        )

        connection.commit()

    finally:

        cursor.close()


def process_dq_results(
        connection,
        run_id,
        run_results_file,
        manifest_file):
    """
    Obdela vse dbt teste in jih zapiše
    v META.DQ_RESULT.
    """

    run_results, manifest = load_artifacts(
        run_results_file,
        manifest_file
    )

    stats = {
        "total": 0,
        "pass": 0,
        "fail": 0,
        "warn": 0
    }

    for result in run_results.get(
        "results",
        []
    ):

        test_data = extract_test_data(
            result,
            manifest
        )

        if test_data is None:
            continue

        insert_dq_result(
            connection=connection,
            run_id=run_id,
            test_data=test_data
        )

        stats["total"] += 1

        if test_data["test_status"] == "PASS":
            stats["pass"] += 1

        elif test_data["test_status"] == "FAIL":
            stats["fail"] += 1

        elif test_data["test_status"] == "WARN":
            stats["warn"] += 1

    return stats

