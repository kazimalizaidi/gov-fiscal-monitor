import os
import sys
from datetime import date, datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)   # relative paths (data/, reports/, .env) must resolve from the project root

from db import get_conn
from load_market import list_series, load_series, next_start
from load_fiscal import load_fiscal
import build_report


def last_success(pipeline):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT MAX(finished_at) FROM dbo.etl_run_log "
                    "WHERE pipeline = ? AND status = 'SUCCESS'", pipeline)
        return cur.fetchone()[0]
    finally:
        conn.close()


def file_utc(path):
    ts = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
    return ts.replace(tzinfo=None)


def main():
    problems = []

    for sid in list_series():
        try:
            n = load_series(sid, next_start(sid), date.today().isoformat())
            print(f"market {sid}: {n} new/changed rows")
        except Exception as e:
            print(f"market {sid}: FAILED - {e}")
            problems.append(f"market:{sid}")

    for pdf in sorted(Path("data/raw").glob("july_june_*.pdf")):
        try:
            done = last_success(f"fiscal:{pdf.name}")
            if done is not None and file_utc(pdf) <= done:
                print(f"fiscal {pdf.name}: unchanged since last successful load, skipped")
                continue
            n = load_fiscal(pdf)
            print(f"fiscal {pdf.name}: {n} new/changed rows")
        except Exception as e:
            print(f"fiscal {pdf.name}: FAILED - {e}")
            problems.append(f"fiscal:{pdf.name}")

    try:
        build_report.main()
    except Exception as e:
        print(f"report: FAILED - {e}")
        problems.append("report")

    if problems:
        print("PIPELINE FAILED: " + ", ".join(problems))
        sys.exit(1)
    print("PIPELINE OK")


if __name__ == "__main__":
    main()