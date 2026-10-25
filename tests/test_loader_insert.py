from datetime import date
from decimal import Decimal

import pyodbc
import pytest

from db import get_conn
import load_fiscal
import load_market


@pytest.fixture
def db():
    try:
        conn = get_conn()
    except pyodbc.Error:
        pytest.skip("database not available")
    cur = conn.cursor()
    cur.execute("INSERT INTO dbo.etl_run_log (pipeline) OUTPUT INSERTED.run_id VALUES ('TEST:insert_path')")
    run_id = cur.fetchone()[0]
    yield cur, run_id
    conn.rollback()
    conn.close()


def test_fiscal_insert_statement_works(db):
    cur, run_id = db
    cur.execute(load_fiscal.SQL_INSERT, 2098, date(2098, 9, 30), "TOTAL_REVENUE",
                Decimal("123"), "PROVISIONAL", "test", run_id)
    cur.execute(load_fiscal.SQL_LATEST, 2098)
    rows = cur.fetchall()
    assert len(rows) == 1
    assert rows[0].line_code == "TOTAL_REVENUE"
    assert Decimal(rows[0].value_pkr_mn) == Decimal("123")


def test_market_insert_statement_works(db):
    cur, run_id = db
    series = "TS_GP_IR_REPOMR_D.ORR"
    cur.execute(load_market.SQL_INSERT, series, date(2098, 1, 1), Decimal("11.5"), run_id)
    cur.execute(load_market.SQL_LATEST, series, date(2098, 1, 1), date(2098, 1, 1))
    rows = cur.fetchall()
    assert len(rows) == 1
    assert Decimal(rows[0].value) == Decimal("11.5")