from pathlib import Path

import pandas as pd
import pytest

import parse_fiscal as pf

ROOT = Path(__file__).resolve().parent.parent


def test_split_line_plain_numbers():
    label, vals = pf.split_line("Federal 2,884,370 6,160,842 9,305,903 13,010,413")
    assert label == "Federal"
    assert vals == [2884370, 6160842, 9305903, 13010413]


def test_split_line_space_before_comma():
    label, vals = pf.split_line("1. Total Revenue (a+b) 2 ,016,977 4 ,698,948 6 ,938,244 9 ,633,505")
    assert label == "1. Total Revenue (a+b)"
    assert vals == [2016977, 4698948, 6938244, 9633505]


def test_split_line_first_digit_separated():
    label, vals = pf.split_line("Provincial 1 48,162 3 03,015 4 61,833 6 49,559")
    assert vals == [148162, 303015, 461833, 649559]


def test_split_line_two_digit_prefix():
    label, vals = pf.split_line("2. Total Expenditure (a+b+c) 2 ,836,283 6 ,382,410 1 0,016,917 1 6,154,950")
    assert vals == [2836283, 6382410, 10016917, 16154950]


def test_split_line_dashes_are_zero():
    label, vals = pf.split_line("Privatization Proceeds - - - -")
    assert label == "Privatization Proceeds"
    assert vals == [0, 0, 0, 0]


def test_split_line_old_pattern_with_dashes():
    label, vals = pf.split_line("Privatization Proceeds - - - 4 ,065")
    assert vals == [0, 0, 0, 4065]


def test_split_line_negative_numbers():
    label, vals = pf.split_line("(c) Statistical Discrepancy 78,203 -315,409 -288,124 -245,750")
    assert vals == [78203, -315409, -288124, -245750]


@pytest.mark.parametrize("line", [
    "Memo Items:- (As % of GDP)",
    "Total Revenue 4.9 8.4 11.7 15.6",
    "July-Sept. July-Dec. July-March. July-June.",
])
def test_split_line_ignores_non_data_rows(line):
    assert pf.split_line(line) is None


@pytest.mark.parametrize("raw, expected", [
    ("1. Total Revenue (a+b)", "total revenue"),
    ("(a) Tax Revenue", "tax revenue"),
    ("(b) Non-Tax", "non-tax"),
    ("3.Overall Budget Balance", "overall budget balance"),
    ("Of which : Mark-up Payments", "of which : mark-up payments"),
    ("2. Total Expenditure (a+b+c)", "total expenditure"),
])
def test_normalise(raw, expected):
    assert pf.normalise(raw) == expected


def _zero_wide():
    return pd.DataFrame(0, index=[code for _, code in pf.EXPECTED],
                        columns=[pd.Timestamp("2025-09-30")])


def test_run_checks_passes_on_consistent_data():
    results = pf.run_checks(_zero_wide())
    assert len(results) == len(pf.CHECKS)
    assert all(ok for _, _, ok in results)


def test_run_checks_catches_a_wrong_number():
    wide = _zero_wide()
    wide.loc["TAX_REVENUE", wide.columns[0]] = 100
    results = {name: (worst, ok) for name, worst, ok in pf.run_checks(wide)}
    assert results["revenue = tax + non-tax"] == (100, False)


def test_run_checks_tolerance_boundary():
    at_limit = _zero_wide()
    at_limit.loc["TAX_REVENUE", at_limit.columns[0]] = pf.TOL
    assert all(ok for _, _, ok in pf.run_checks(at_limit))
    over = _zero_wide()
    over.loc["TAX_REVENUE", over.columns[0]] = pf.TOL + 1
    assert not all(ok for _, _, ok in pf.run_checks(over))


def test_unit_guard_refuses_other_units(monkeypatch):
    fake = "Table 1\nTotal Revenue\nMark-up\n(In Billion of Pakistan Rupees)\n"
    monkeypatch.setattr(pf, "extract_table1_text", lambda path: fake)
    with pytest.raises(RuntimeError, match="Unit check failed"):
        pf.parse_table1("ignored.pdf")


FULL_YEAR_REVENUE = {
    "july_june_2022_23.pdf": 9633505,
    "july_june_2023_24.pdf": 13269037,
    "july_june_2024_25.pdf": 17997486,
    "july_june_2025_26.pdf": 19773932,
}


@pytest.mark.parametrize("name, total", FULL_YEAR_REVENUE.items())
def test_real_pdf_parses_and_reconciles(name, total):
    path = ROOT / "data" / "raw" / name
    if not path.exists():
        pytest.skip(f"{name} not present")
    df, status = pf.parse_table1(path)
    assert len(df) == 84
    last = df["period_end"].max()
    got = df[(df.line_code == "TOTAL_REVENUE") & (df.period_end == last)]["value_pkr_mn"].iloc[0]
    assert got == total
    wide = df.pivot(index="line_code", columns="period_end", values="value_pkr_mn")
    wide = wide.loc[[code for _, code in pf.EXPECTED]]
    assert all(ok for _, _, ok in pf.run_checks(wide))