#
# scripts/test_start_run.py
#

from lib.db import get_sqlserver_connection
from lib.run import start_run


def main():

    connection = get_sqlserver_connection()

    try:

        run_id = start_run(
            connection=connection,
            run_type="DBT"
        )

        print(f"RUN_ID = {run_id}")

    finally:
        connection.close()


if __name__ == "__main__":
    main()
