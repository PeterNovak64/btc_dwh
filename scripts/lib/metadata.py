#
#   scripts/lib/metadata.py
#

from lib.db import get_sqlserver_connection


class MetadataService:

    def _execute_procedure(
            self,
            procedure_name,
            params=None):
        """
        Izvede stored proceduro.
        """

        params = params or {}

        conn = get_sqlserver_connection()

        try:

            cursor = conn.cursor()

            if params:

                parameter_list = ", ".join(
                    f"@{key}=?"
                    for key in params.keys()
                )

                sql = (
                    f"EXEC {procedure_name} "
                    f"{parameter_list}"
                )

                cursor.execute(
                    sql,
                    *params.values()
                )

            else:

                sql = f"EXEC {procedure_name}"

                cursor.execute(sql)

            conn.commit()

        finally:

            cursor.close()
            conn.close()

    # --------------------------------------------------
    # SOURCE METADATA
    # --------------------------------------------------

    def refresh_source(self):

        self._execute_procedure(
            "META.refresh_source"
        )

    # --------------------------------------------------
    # PROFILE RULES
    # --------------------------------------------------

    def refresh_source_profile_rule(self):

        self._execute_procedure(
            "META.refresh_source_profile_rule"
        )

    # --------------------------------------------------
    # DQ PROFILE
    # --------------------------------------------------

    def refresh_dq_profile(
            self,
            run_id):

        self._execute_procedure(
            "META.refresh_dq_profile",
            {
                "run_id": run_id
            }
        )

    # --------------------------------------------------
    # LOAD STATISTICS
    # --------------------------------------------------

    def refresh_load_statistics(
            self,
            run_id):

        self._execute_procedure(
            "META.refresh_load_statistics",
            {
                "run_id": run_id
            }
        )
        