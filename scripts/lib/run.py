#
#   scripts/lib/run.py
#

from lib.db import get_sqlserver_connection


def create_dwh_run(
        run_name="DAILY_DWH",
        run_type="FULL"):

    """ Ustvari zapis v META.DWH_RUN in vrne RUN_ID. """

    conn = get_sqlserver_connection()
    cursor = conn.cursor()

    sql = """
    INSERT INTO META.DWH_RUN
    (
        RUN_NAME,
        RUN_TYPE
    )
    OUTPUT INSERTED.RUN_ID
    VALUES
    (
        ?,
        ?
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
        error_message=None,
        dbt_invocation_id=None):
    
    """ Dokonča DWH run s statusom SUCCESS in posodobi njegove podatke. """

    conn = get_sqlserver_connection()
    cursor = conn.cursor()

    sql = """
    DECLARE @end_ts DATETIME2 = SYSDATETIME();

    UPDATE META.DWH_RUN
    SET STATUS = ?,
        END_TS = @end_ts,
        DURATION_SEC =
            DATEDIFF(
                SECOND,
                START_TS,
                @end_ts
            ),
           DBT_INVOCATION_ID = ?,
           ERROR_MESSAGE = ?
     WHERE RUN_ID = ?
    """

    cursor.execute(
        sql,
        status,
        dbt_invocation_id,
        error_message,
        run_id
    )

    conn.commit()

    cursor.close()
    conn.close()



def fail_dwh_run(
        run_id,
        error_message,
        dbt_invocation_id=None):

    """ Dokonča DWH run s statusom FAILED in posodobi njegove podatke. """
    
    finish_dwh_run(
        run_id=run_id,
        status="FAILED",
        error_message=error_message,
        dbt_invocation_id=dbt_invocation_id
    )



def start_object_run(
        run_id,
        object_layer,
        object_name):
    
    """ 
    Ustvari zapis v META.DWH_RUN_OBJECT in vrne RUN_OBJECT_ID. 
    """

    conn = get_sqlserver_connection()
    cursor = conn.cursor()

    sql = """
    INSERT INTO META.DWH_RUN_OBJECT
    (
        RUN_ID,
        OBJECT_LAYER,
        OBJECT_NAME
    )
    OUTPUT INSERTED.RUN_OBJECT_ID
    VALUES
    (
        ?,
        ?,
        ?
    )
    """

    cursor.execute(
        sql,
        run_id,
        object_layer,
        object_name
    )

    run_object_id = cursor.fetchone()[0]

    conn.commit()

    cursor.close()
    conn.close()

    return run_object_id



def finish_object_run(
        run_object_id,
        status="SUCCESS",
        row_count=None,
        error_message=None):
    """
    Zaključi objekt_run in posodobi njegove podatke.
    """

    conn = get_sqlserver_connection()
    cursor = conn.cursor()

    sql = """
    DECLARE @end_ts DATETIME2 = SYSDATETIME();

    UPDATE META.DWH_RUN_OBJECT
       SET STATUS = ?,
           END_TS = @end_ts,
           DURATION_SEC =
               DATEDIFF(
                   SECOND,
                   START_TS,
                   @end_ts
               ),
           ROW_COUNT = ?,
           ERROR_MESSAGE = ?
     WHERE RUN_OBJECT_ID = ?
    """

    cursor.execute(
        sql,
        status,
        row_count,
        error_message,
        run_object_id
    )

    conn.commit()

    cursor.close()
    conn.close()



def fail_object_run(
        run_object_id,
        error_message):
    """
    Zaključi objekt_run s statusom FAILED.
    """

    finish_object_run(
        run_object_id=run_object_id,
        status="FAILED",
        error_message=error_message
    )



def start_run(connection, run_type="DBT"):
    """
    Ustvari zapis v META.DWH_RUN
    in vrne RUN_ID.
    """

    cursor = connection.cursor()

    try:

        cursor.execute(
            """
            EXEC META.start_run
                 @run_type = ?
            """,
            run_type
        )

        row = cursor.fetchone()

        if row is None:
            raise RuntimeError(
                "META.start_run ni vrnila RUN_ID"
            )

        run_id = row[0]

        connection.commit()

        return run_id

    finally:
        cursor.close()



def finish_run(
        connection,
        run_id,
        status):
    """
    Zaključi izvajanje v META.DWH_RUN.
    """

    cursor = connection.cursor()

    try:

        cursor.execute(
            """
            EXEC META.finish_run
                 @run_id = ?,
                 @status = ?
            """,
            run_id,
            status
        )

        connection.commit()

    finally:
        cursor.close()
