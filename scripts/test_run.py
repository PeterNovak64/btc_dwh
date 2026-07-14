#
#   scripts/test_run.py
#

from lib.run import (
    create_dwh_run,
    finish_dwh_run
)

run_id = create_dwh_run("test_run")

print(f"RUN_ID = {run_id}")

finish_dwh_run(run_id)

print("RUN completed")
