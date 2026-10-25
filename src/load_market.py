from datetime import date
from decimal import Decimal

from db import get_conn
from sbp_client import fetch_series

SERIES_ID = "TS_GP_IR_REPOMR_D.ORR"
BACKFILL_START = "2015-05-25"   # first available date per the series page

SQL_LATEST = """
SELECT o.obs_date, o.value
FROM dbo.market_observation o
WHERE o.series_code = ? AND o.obs_date BETWEEN ? AND ?
  AND o.loaded_at = (SELECT MAX(loaded_at) FROM dbo.market_observation
                     WHERE series_code = o.series_code AND obs_date = o.obs_date)
"""

SQL_INSERT = """
INSERT INTO dbo.market_observation (series_code, obs_date, value, run_id)
VALUES (?, ?, ?, ?)
"""


def start_run(cur, pipeline):
    cur.execute(
        "INSERT INTO dbo.etl_run_log (pipeline) OUTPUT INSERTED.run_id VALUES (?)",
        pipeline,
    )
    return cur.fetchone()[0]


def finish_run(cur, run_id, status, rows, error=None):
    cur.execute(
        "UPDATE dbo.etl_run_log SET finished_at = SYSUTCDATETIME(), "
        "status = ?, rows_loaded = ?, error_message = ? WHERE run_id = ?",
        status, rows, error, run_id,
    )


def load_series(series_id, start, end):
    conn = get_conn()
    cur = conn.cursor()
    run_id = start_run(cur, f"market:{series_id}")
    conn.commit()  # keep the run record even if the load fails
    try:
        df = fetch_series(series_id, start, end)
        if df.empty:
            finish_run(cur, run_id, "SUCCESS", 0)
            conn.commit()
            return 0

        cur.execute(SQL_LATEST, series_id, df["obs_date"].min(), df["obs_date"].max())
        existing = {row.obs_date: Decimal(row.value) for row in cur.fetchall()}

        rows = []
        for r in df.itertuples(index=False):
            new_value = Decimal(str(r.value))
            if r.obs_date not in existing or existing[r.obs_date] != new_value:
                rows.append((r.series_code, r.obs_date, new_value, run_id))

        if rows:
            cur.executemany(SQL_INSERT, rows)
        finish_run(cur, run_id, "SUCCESS", len(rows))
        conn.commit()
        return len(rows)
    except Exception as e:
        conn.rollback()
        finish_run(cur, run_id, "FAILED", None, str(e)[:2000])
        conn.commit()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    n = load_series(SERIES_ID, BACKFILL_START, date.today().isoformat())
    print(f"rows inserted: {n}")