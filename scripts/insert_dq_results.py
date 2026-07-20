# ==========================================
# Branje dbt test rezultatov
# in zapis v META.DQ_RESULT
# ==========================================

import json
import pyodbc
from datetime import datetime

# ==========================================
# Parametri
# ==========================================

RUN_ID = 1

# ==========================================
# Branje dbt artefaktov
# ==========================================

with open("target/run_results.json", encoding="utf8") as f:
    rr = json.load(f)

with open("target/manifest.json", encoding="utf8") as f:
    mf = json.load(f)

# ==========================================
# SQL Server povezava
# ==========================================

conn = pyodbc.connect(
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=BTCDWH;"
    "DATABASE=BTCDWH02_TEST;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

cur = conn.cursor()

# ==========================================
# Obdelava testov
# ==========================================

for r in rr["results"]:

    uid = r["unique_id"]

    node = mf["nodes"].get(uid)

    if not node:
        continue

    if node["resource_type"] != "test":
        continue

    # --------------------------------------
    # MODEL
    # --------------------------------------

    model_name = None

    for dep in node.get("depends_on", {}).get("nodes", []):

        if dep.startswith("model."):

            model_name = dep.split(".")[-1]
            break

    # --------------------------------------
    # TEST TYPE
    # --------------------------------------

    test_metadata = node.get("test_metadata", {})

    test_type = test_metadata.get("name")

    # --------------------------------------
    # COLUMN NAME
    # --------------------------------------

    column_name = node.get("column_name")

    if not column_name:
        column_name = (
            test_metadata
            .get("kwargs", {})
            .get("column_name")
        )

    # --------------------------------------
    # STATUS
    # --------------------------------------

    status = r["status"].upper()

    failures = r.get("failures", 0)

    # --------------------------------------
    # TEST NAME
    # --------------------------------------

    test_name = node["name"]

    # --------------------------------------
    # Izpis
    # --------------------------------------

    print("MODEL      :", model_name)
    print("TEST       :", test_name)
    print("TEST TYPE  :", test_type)
    print("COLUMN NAME:", column_name)
    print("STATUS     :", status)
    print("FAILURES   :", failures)
    print("-" * 60)

    # --------------------------------------
    # INSERT
    # --------------------------------------

    cur.execute(
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
            ?, GETDATE(), ?, ?, ?, ?, NULL, ?, ?
        )
        """,
        RUN_ID,
        model_name,
        test_name,
        status,
        failures,
        test_type,
        column_name
    )

# ==========================================
# Commit in zapiranje povezave
# ==========================================

conn.commit()

cur.close()

conn.close()

print()
print("Rezultati zapisani v META.DQ_RESULT")