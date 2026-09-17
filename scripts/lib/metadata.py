import json
import os
from datetime import datetime

from lib.db import get_sqlserver_connection


class MetadataService:

    def _execute_procedure(
            self,
            procedure_name,
            params=None,
            fetch_one=False):
        """
        Izvede stored proceduro.

        Če fetch_one=True, vrne prvo vrstico kot dict.
        """

        params = params or {}

        conn = get_sqlserver_connection()
        cursor = None

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

            result = None

            if fetch_one and cursor.description:

                columns = [
                    column[0]
                    for column in cursor.description
                ]

                row = cursor.fetchone()

                if row:
                    result = dict(
                        zip(
                            columns,
                            row
                        )
                    )

            conn.commit()

            return result

        finally:

            if cursor:
                cursor.close()

            conn.close()

    # --------------------------------------------------
    # SOURCE METADATA
    # --------------------------------------------------

    def refresh_source(self):

        self._execute_procedure(
            "META.refresh_source"
        )

    def refresh_dwh_objects(
            self,
            manifest_file):
        """
        Osveži katalog dbt DWH objektov v META.SOURCE_OBJECT.

        Vir:
            dbt target/manifest.json

        LAND objekti niso obravnavani tukaj.
        Te obravnava refresh_source().

        Funkcija:
            - registrira nove DWH objekte
            - obstoječe objekte označi kot ACTIVE
            - objekte, ki jih ni več v manifestu,
              označi kot MISSING

        run_results.json se ne uporablja, ker predstavlja
        samo rezultate konkretnega dbt izvajanja.
        """

        if not os.path.isfile(manifest_file):
            raise FileNotFoundError(
                f"Manifest file not found: {manifest_file}"
            )

        with open(
            manifest_file,
            "r",
            encoding="utf-8"
        ) as file:

            manifest = json.load(file)

        now = datetime.now()

        dwh_objects = []

        # --------------------------------------------------
        # PREBERI DWH MODELE IZ MANIFESTA
        # --------------------------------------------------

        for unique_id, node in manifest.get(
                "nodes",
                {}).items():

            # Obravnavamo samo dbt modele
            if node.get("resource_type") != "model":
                continue

            original_file_path = (
                node.get("original_file_path") or ""
            )

            path_parts = (
                original_file_path
                .replace("\\", "/")
                .split("/")
            )

            # Pričakujemo:
            #
            # models/<podmapa>/<model>.sql

            if len(path_parts) < 3:
                continue

            model_area = path_parts[1].lower()

            model_name = node.get("name")
            schema_name = node.get("schema")

            if not model_name or not schema_name:
                continue

            # --------------------------------------------------
            # LAND
            # --------------------------------------------------

            if model_area == "land":

                # LAND objekte obravnava refresh_source()
                continue

            # --------------------------------------------------
            # STAG
            # --------------------------------------------------

            if model_area == "stag":

                model_name_lower = model_name.lower()

                if model_name_lower.startswith("stg_"):
                    dwh_layer = "STG"

                elif model_name_lower.startswith("ref_"):
                    dwh_layer = "REF"

                elif model_name_lower.startswith("int_"):
                    dwh_layer = "INT"

                else:
                    raise ValueError(
                        "Neznan STAG model: "
                        f"{original_file_path}"
                    )

            # --------------------------------------------------
            # DWH
            # --------------------------------------------------

            elif model_area == "dwh":

                model_name_lower = model_name.lower()

                if model_name_lower.startswith("dim_"):
                    dwh_layer = "DIM"

                elif model_name_lower.startswith("fact_"):
                    dwh_layer = "FACT"

                else:
                    raise ValueError(
                        "Neznan DWH model: "
                        f"{original_file_path}"
                    )

            # --------------------------------------------------
            # MART
            # --------------------------------------------------

            elif model_area == "mart":

                dwh_layer = "MART"

            else:

                # Druga dbt področja niso del kataloga
                continue

            object_name = (
                node.get("alias")
                or model_name
            )

            dwh_objects.append(
                {
                    "unique_id": unique_id,
                    "object_name": object_name,
                    "schema_name": schema_name.upper(),
                    "dwh_layer": dwh_layer
                }
            )

        # --------------------------------------------------
        # SQL CONNECTION
        # --------------------------------------------------

        conn = get_sqlserver_connection()
        cursor = None

        try:

            cursor = conn.cursor()

            # --------------------------------------------------
            # REGISTRACIJA / OSVEŽITEV OBJEKTOV
            # --------------------------------------------------

            for obj in dwh_objects:

                cursor.execute(
                    """
                    SELECT OBJECT_ID
                    FROM META.SOURCE_OBJECT
                    WHERE OBJECT_ORIGIN = 'DWH'
                      AND SCHEMA_NAME = ?
                      AND OBJECT_NAME = ?
                    """,
                    obj["schema_name"],
                    obj["object_name"]
                )

                row = cursor.fetchone()

                # ----------------------------------------------
                # NOV OBJEKT
                # ----------------------------------------------

                if row is None:

                    cursor.execute(
                        """
                        INSERT INTO META.SOURCE_OBJECT
                        (
                              SOURCE_SYSTEM
                            , SERVER_NAME
                            , DATABASE_NAME
                            , SCHEMA_NAME
                            , OBJECT_NAME
                            , LAND_OBJECT_NAME
                            , OBJECT_TYPE
                            , DWH_LAYER
                            , OBJECT_ORIGIN
                            , STATUS
                            , LAST_SEEN_TS
                            , CREATED_TS
                        )
                        VALUES
                        (
                              NULL
                            , NULL
                            , NULL
                            , ?
                            , ?
                            , NULL
                            , 'TABLE'
                            , ?
                            , 'DWH'
                            , 'ACTIVE'
                            , ?
                            , ?
                        )
                        """,
                        obj["schema_name"],
                        obj["object_name"],
                        obj["dwh_layer"],
                        now,
                        now
                    )

                # ----------------------------------------------
                # OBSTOJEČ OBJEKT
                # ----------------------------------------------

                else:

                    cursor.execute(
                        """
                        UPDATE META.SOURCE_OBJECT
                           SET STATUS = 'ACTIVE'
                             , SCHEMA_NAME = ?
                             , DWH_LAYER = ?
                             , OBJECT_ORIGIN = 'DWH'
                             , LAST_SEEN_TS = ?
                        WHERE OBJECT_ID = ?
                        """,
                        obj["schema_name"],
                        obj["dwh_layer"],
                        now,
                        row[0]
                    )

            # --------------------------------------------------
            # MISSING OBJEKTI
            # --------------------------------------------------

            manifest_keys = {
                (
                    obj["schema_name"],
                    obj["object_name"]
                )
                for obj in dwh_objects
            }

            cursor.execute(
                """
                SELECT
                      OBJECT_ID
                    , SCHEMA_NAME
                    , OBJECT_NAME
                FROM META.SOURCE_OBJECT
                WHERE OBJECT_ORIGIN = 'DWH'
                """
            )

            existing_objects = cursor.fetchall()

            for (
                object_id,
                schema_name,
                object_name
            ) in existing_objects:

                key = (
                    (schema_name or "").upper(),
                    object_name
                )

                if key not in manifest_keys:

                    cursor.execute(
                        """
                        UPDATE META.SOURCE_OBJECT
                           SET STATUS = 'MISSING'
                        WHERE OBJECT_ID = ?
                        """,
                        object_id
                    )

            conn.commit()

        except Exception:

            conn.rollback()
            raise

        finally:

            if cursor:
                cursor.close()

            conn.close()

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
    # DQ ALERT
    # --------------------------------------------------

    def refresh_dq_alert(
            self,
            run_id):

        return self._execute_procedure(
            "META.refresh_dq_alert",
            {
                "run_id": run_id
            },
            fetch_one=True
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

