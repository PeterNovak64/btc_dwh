#
#   metadata.py
#

from lib.db import get_sqlserver_connection

def refresh_source(connection):

    cursor = connection.cursor()

    try:

        cursor.execute(
            "EXEC META.refresh_source"
        )

        connection.commit()

    finally:

        cursor.close()


def refresh_load_statistics(
        connection,
        run_id):

    cursor = connection.cursor()

    try:

        cursor.execute(
            """
            EXEC META.refresh_load_statistics
                 @run_id = ?
            """,
            run_id
        )

        connection.commit()

    finally:

        cursor.close()

