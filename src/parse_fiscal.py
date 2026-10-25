import re
import sys
from calendar import monthrange
from datetime import date
from pathlib import Path

import pandas as pd
import pdfplumber

# (normalised label as printed in Table 1, line_code), in table order
EXPECTED = [
    ("total revenue", "TOTAL_REVENUE"),
    ("tax revenue", "TAX_REVENUE"),
    ("federal", "TAX_FEDERAL"),
    ("provincial", "TAX_PROVINCIAL"),
    ("non-tax", "NONTAX_REVENUE"),
    ("federal", "NONTAX_FEDERAL"),
    ("provincial", "NONTAX_PROVINCIAL"),
    ("total expenditure", "TOTAL_EXPENDITURE"),
    ("current expenditure", "CURRENT_EXPENDITURE"),
    ("of which : mark-up payments", "MARKUP_PAYMENTS"),
    ("defence", "DEFENCE"),
    ("development expenditure & net lending", "DEV_EXP_NET_LENDING"),
    ("statistical discrepancy", "STAT_DISCREPANCY"),
    ("overall budget balance", "OVERALL_BALANCE"),
    ("primary balance", "PRIMARY_BALANCE"),
    ("financing", "FINANCING_TOTAL"),
    ("external (net)", "FIN_EXTERNAL"),
    ("domestic (net)", "FIN_DOMESTIC"),
    ("non-bank", "FIN_NONBANK"),
    ("bank", "FIN_BANK"),
    ("privatization proceeds", "FIN_PRIVATIZATION"),
]

# (name, lhs, [(code, sign), ...]) : lhs must equal the signed sum within TOL
CHECKS = [
    ("revenue = tax + non-tax", "TOTAL_REVENUE", [("TAX_REVENUE", 1), ("NONTAX_REVENUE", 1)]),
    ("tax = federal + provincial", "TAX_REVENUE", [("TAX_FEDERAL", 1), ("TAX_PROVINCIAL", 1)]),
    ("non-tax = federal + provincial", "NONTAX_REVENUE", [("NONTAX_FEDERAL", 1), ("NONTAX_PROVINCIAL", 1)]),
    ("expenditure = current + development + discrepancy", "TOTAL_EXPENDITURE",
     [("CURRENT_EXPENDITURE", 1), ("DEV_EXP_NET_LENDING", 1), ("STAT_DISCREPANCY", 1)]),
    ("overall balance = revenue - expenditure", "OVERALL_BALANCE",
     [("TOTAL_REVENUE", 1), ("TOTAL_EXPENDITURE", -1)]),
    ("primary balance = overall balance + mark-up", "PRIMARY_BALANCE",
     [("OVERALL_BALANCE", 1), ("MARKUP_PAYMENTS", 1)]),
    ("financing = -overall balance", "FINANCING_TOTAL", [("OVERALL_BALANCE", -1)]),
    ("financing = external + domestic", "FINANCING_TOTAL", [("FIN_EXTERNAL", 1), ("FIN_DOMESTIC", 1)]),
    ("domestic = non-bank + bank + privatization", "FIN_DOMESTIC",
     [("FIN_NONBANK", 1), ("FIN_BANK", 1), ("FIN_PRIVATIZATION", 1)]),
]

MONTHS = {"sept.": 9, "dec.": 12, "march.": 3, "june.": 6}
VAL = re.compile(r"^-?[\d,]+$|^-$")
TOL = 2  # published figures can differ by rounding; PKR million


def extract_table1_text(pdf_path):
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            if "Table 1" in text and "Total Revenue" in text and "Mark-up" in text:
                return text
    raise RuntimeError("Table 1 not found in the PDF")


def normalise(label):
    s = re.sub(r"\s+", " ", label.strip().lower())
    s = re.sub(r"^(\d\.\s*|\([a-c]\)\s*)", "", s)    # "1. " or "(a) "
    s = re.sub(r"\s*\([a-c+]+\)$", "", s)            # trailing "(a+b)"
    return s


def split_line(line):
    line = re.sub(r"(\d)\s+,", r"\1,", line)         # repairs "4 ,065"
    toks = line.split()
    if len(toks) < 5 or not all(VAL.match(t) for t in toks[-4:]):
        return None
    vals = [0 if t == "-" else int(t.replace(",", "")) for t in toks[-4:]]
    return " ".join(toks[:-4]), vals


def parse_table1(pdf_path):
    text = extract_table1_text(pdf_path)
    lines = text.splitlines() 
    if not re.search(r"in\s+million\s+of\s+pakistan\s+rupees", text, re.I):
        raise RuntimeError("Unit check failed: header does not say 'In Million of Pakistan Rupees'")

    status = "PROVISIONAL" if any(l.strip().lower() == "provisional" for l in lines) else "FINAL"

    m = re.search(r"Fiscal Operations,\s*(\d{4})-(\d{2})", text)
    if not m:
        raise RuntimeError("Could not read the fiscal year from the title")
    fiscal_year = int(m.group(1)) + 1                # 2025-26 -> 2026

    header = next(l for l in lines if l.strip().startswith("July-"))
    month_tokens = re.findall(r"July-(\w+\.)", header)
    months = [MONTHS[t.lower()] for t in month_tokens]
    if len(months) != 4:
        raise RuntimeError(f"Expected 4 period columns, found {months}")
    period_ends = []
    for mo in months:
        year = fiscal_year - 1 if mo >= 7 else fiscal_year
        period_ends.append(date(year, mo, monthrange(year, mo)[1]))

    records, idx = [], 0
    for line in lines:
        if line.strip().startswith("Memo Items"):
            break
        parsed = split_line(line)
        if parsed is None:
            continue
        label, vals = parsed
        if idx >= len(EXPECTED):
            raise RuntimeError(f"Unexpected extra row: {label!r}")
        exp_label, code = EXPECTED[idx]
        got = normalise(label)
        if got != exp_label:
            raise RuntimeError(f"Row {idx + 1}: expected {exp_label!r}, got {got!r}")
        for pe, v in zip(period_ends, vals):
            records.append((fiscal_year, pe, code, v))
        idx += 1
    if idx != len(EXPECTED):
        raise RuntimeError(f"Found {idx} rows, expected {len(EXPECTED)}")

    df = pd.DataFrame(records, columns=["fiscal_year", "period_end", "line_code", "value_pkr_mn"])
    return df, status


def run_checks(wide):
    results = []
    for name, lhs, parts in CHECKS:
        rhs = sum(sign * wide.loc[code] for code, sign in parts)
        worst = int((wide.loc[lhs] - rhs).abs().max())
        ok = worst <= TOL
        print(f"{'OK  ' if ok else 'FAIL'} {name}: max difference {worst:,}")
        results.append((name, worst, ok))
    return results


if __name__ == "__main__":
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("data/raw/july_june_2025_26.pdf")
    df, status = parse_table1(path)
    print(f"file: {path.name} | status: {status} | values parsed: {len(df)}")
    wide = df.pivot(index="line_code", columns="period_end", values="value_pkr_mn")
    wide = wide.loc[[code for _, code in EXPECTED]]
    print(wide.to_string(formatters={c: "{:,}".format for c in wide.columns}))
    print()
    results = run_checks(wide)
    failures = [r for r in results if not r[2]]
    print(f"\n{len(CHECKS) - len(failures)} of {len(CHECKS)} checks passed")
    if failures:
        sys.exit(1)