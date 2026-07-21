#
# scripts/test_process_run_results.py
#

from lib.db import get_sqlserver_connection
from lib.insert_results import process_run_results

connection = get_sqlserver_connection()

try:

    stats = process_run_results(
        connection=connection,
        run_id=11,
        results_file="target/run_results.json"
    )

    print(stats)

finally:

    connection.close()
    