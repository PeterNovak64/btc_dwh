#
#   scripts/test_db.py
#

from lib.db import get_sqlserver_connection

conn = get_sqlserver_connection()

print("Povezava na SQL server je bila uspešno vzpostavljena.")

conn.close()

print("Povezava na SQL server je bila uspešno zaprta.")
