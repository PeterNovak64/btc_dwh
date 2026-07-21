#
# scripts/test_finish_run.py
#

from lib.db import get_sqlserver_connection
from lib.run import start_run, finish_run


connection = get_sqlserver_connection()

try:

    run_id = start_run(
        connection=connection,
        run_type="DBT"
    )

    print(f"RUN_ID = {run_id}")

    finish_run(
        connection=connection,
        run_id=run_id,
        status="SUCCESS"
    )

    print("RUN finished")

finally:

    connection.close()

