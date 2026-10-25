import sys
from decimal import Decimal
from pathlib import Path

from db import get_conn
from load_market import start_run, finish_run
from parse_fiscal import EXPECTED, TOL, parse_table1, run_checks

SQL_LATEST = """
SELECT f.period_end, f.line_code, f.value_pkr_mn, f.pub_status
FROM dbo.fiscal_cumulative f
WHERE f.fiscal_year = ?
  AND f.loaded_at = (SELECT MAX(loaded_at) FROM dbo.fiscal_cumulative
                     WHERE fiscal_year = f.fiscal_year
                       AND period_end = f.period_end
                       AND line_code = f.line_code)
"""

SQL_DQ = """
INSERT INTO dbo.dq_check_result
    (run_id, source_file, fiscal_year, check_name, max_difference, tolerance, passed)
VALUES (?, ?, ?, ?, ?, ?, ?)
"""


def load_fiscal(path):
    path = Path(path)
    conn = get_conn()
    cur = conn.cursor()
    run_id = start_run(cur, f"fiscal:{path.name}")
    conn.commit()  # keep the run record even if the load fails
    try:
        df, status = parse_table1(path)

        wide = df.pivot(index="line_code", columns="period_end", values="value_pkr_mn")
        wide = wide.loc[[code for _, code in EXPECTED]]
        results = run_checks(wide)
        fiscal_year = int(df["fiscal_year"].iloc[0])
        cur.executemany(SQL_DQ, [(run_id, path.name, fiscal_year, name, worst, TOL, int(ok))
                                 for name, worst, ok in results])
        conn.commit()   # keep the check results even if we refuse the load
        failures = [name for name, _, ok in results if not ok]
        if failures:
            raise RuntimeError("Reconciliation failed, nothing loaded: " + "; ".join(failures))
        cur.execute(SQL_LATEST, fiscal_year)
        existing = {
            (r.period_end, r.line_code): (Decimal(r.value_pkr_mn), r.pub_status)
            for r in cur.fetchall()
        }

        rows = []
        for r in df.itertuples(index=False):
            new = (Decimal(int(r.value_pkr_mn)), status)
            if existing.get((r.period_end, r.line_code)) != new:
                rows.append((fiscal_year, r.period_end, r.line_code,
                             new[0], status, path.name, run_id))

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
    pdf = sys.argv[1] if len(sys.argv) > 1 else "data/raw/july_june_2025_26.pdf"
    print(f"rows inserted: {load_fiscal(pdf)}")