#
#   scripts/lib/run.py
#

from lib.db import get_sqlserver_connection


def create_dwh_run(
        run_name="DAILY_DWH",
        run_type="FULL"):

    conn = get_sqlserver_connection()
    cursor = conn.cursor()

    sql = """
    INSERT INTO META.DWH_RUN
    (
        RUN_NAME,
        RUN_TYPE,
        STATUS,
        START_TS
    )
    OUTPUT INSERTED.RUN_ID
    VALUES
    (
        ?,
        ?,
        'RUNNING',
        SYSDATETIME()
    )
    """

    cursor.execute(sql, run_name, run_type)

    run_id = cursor.fetchone()[0]

    conn.commit()

    cursor.close()
    conn.close()

    return run_id



def finish_dwh_run(
        run_id,
        status="SUCCESS",
        dbt_invocation_id=None):

    conn = get_sqlserver_connection()
    cursor = conn.cursor()

    sql = """
    UPDATE META.DWH_RUN
       SET STATUS = ?,
           END_TS = SYSDATETIME(),
           DURATION_SEC =
               DATEDIFF(
                   SECOND,
                   START_TS,
                   SYSDATETIME()
               ),
           DBT_INVOCATION_ID = ?
     WHERE RUN_ID = ?
    """

    cursor.execute(
        sql,
        status,
        dbt_invocation_id,
        run_id
    )

    conn.commit()

    cursor.close()
    conn.close()



def fail_dwh_run(
        run_id,
        error_message):

    conn = get_sqlserver_connection()
    cursor = conn.cursor()

    sql = """
    UPDATE META.DWH_RUN
       SET STATUS = 'FAILED',
           END_TS = SYSDATETIME(),
           DURATION_SEC =
               DATEDIFF(
                   SECOND,
                   START_TS,
                   SYSDATETIME()
               ),
           ERROR_MESSAGE = ?
     WHERE RUN_ID = ?
    """

    cursor.execute(
        sql,
        error_message,
        run_id
    )

    conn.commit()

    cursor.close()
    conn.close()