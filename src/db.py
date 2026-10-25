import os, pyodbc
from dotenv import load_dotenv
load_dotenv()

def get_conn():
    return pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={os.getenv('DB_SERVER')};DATABASE={os.getenv('DB_NAME')};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;"
    )

if __name__ == "__main__":
    print(get_conn().cursor().execute("SELECT DB_NAME()").fetchone())