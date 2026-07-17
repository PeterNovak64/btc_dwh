#
#   scripts/test_fail_run.py
#

from lib.run import (
    create_dwh_run,
    fail_dwh_run
)

run_id = create_dwh_run("test_fail_run", "FULL")

print(f"RUN_ID = {run_id}")

fail_dwh_run(
    run_id,
    "Testna napaka"
)

print("FAILED")