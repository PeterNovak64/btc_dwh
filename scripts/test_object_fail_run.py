from lib.run import (
    create_dwh_run,
    start_object_run,
    fail_object_run
)

run_id = create_dwh_run(
    run_name="TEST_OBJECT_FAIL",
    run_type="TEST"
)

run_object_id = start_object_run(
    run_id=run_id,
    object_layer="STG",
    object_name="stg_customer"
)

try:

    raise Exception("Simulirana napaka")

except Exception as ex:

    fail_object_run(
        run_object_id=run_object_id,
        error_message=str(ex)
    )

print("OBJECT FAILED")

