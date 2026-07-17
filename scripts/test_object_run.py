#
#   scripts/test_object_run.py
#
 
from lib.run import (
    create_dwh_run,
    start_object_run,
    finish_object_run
)

run_id = create_dwh_run(
    run_name="TEST_OBJECT_SUCCESS",
    run_type="TEST"
)

run_object_id = start_object_run(
    run_id=run_id,
    object_layer="STG",
    object_name="stg_customer"
)

# simulacija dela
print("Processing stg_customer...")

finish_object_run(
    run_object_id=run_object_id,
    row_count=125487
)

print("OBJECT SUCCESS")
