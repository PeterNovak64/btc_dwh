#
#   scripts/lib/db.py
#

import pyodbc

from lib.config import (
    SERVER,
    DATABASE,
    DRIVER
)

SQLSERVER_DRIVER = DRIVER
SQLSERVER_SERVER = SERVER
SQLSERVER_DATABASE = DATABASE

ORACLE_DSN = "ORCL"
ORACLE_USER = "..."
ORACLE_PASSWORD = "..."

SQLSERVER_CONNECTION_STRING = f"""
DRIVER={{{SQLSERVER_DRIVER}}};
SERVER={SQLSERVER_SERVER};
DATABASE={SQLSERVER_DATABASE};
Trusted_Connection=yes;
TrustServerCertificate=yes;
"""

def get_sqlserver_connection():
    #Vrne povezavo na SQL server
    conn = pyodbc.connect(SQLSERVER_CONNECTION_STRING)
    return conn
