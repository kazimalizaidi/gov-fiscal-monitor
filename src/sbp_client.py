import io
import os

import pandas as pd
import requests
from dotenv import load_dotenv

load_dotenv()

BASE_URL = "https://easydata.sbp.org.pk/api/v1/series/{series_id}/data"
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
REQUIRED = ["Series Key", "Observation Date", "Observation Value", "Observation Status"]


def fetch_series(series_id, start_date, end_date, timeout=60):
    """Fetch one EasyData series. Dates are YYYY-MM-DD, both ends inclusive."""
    key = os.getenv("EASYDATA_API_KEY")
    if not key:
        raise RuntimeError("EASYDATA_API_KEY is missing from .env")

    params = {"api_key": key, "start_date": start_date,
              "end_date": end_date, "format": "csv"}
    try:
        r = requests.get(BASE_URL.format(series_id=series_id), params=params,
                         headers=HEADERS, timeout=timeout)
        r.raise_for_status()
    except requests.exceptions.RequestException as e:
        status = getattr(e.response, "status_code", "no response")
        # 'from None' hides the original error, whose text contains the key
        raise RuntimeError(
            f"EasyData request failed for {series_id} (status: {status})"
        ) from None

    cols = ["series_code", "obs_date", "value", "status"]
    if not r.text.strip():
        return pd.DataFrame(columns=cols)

    df = pd.read_csv(io.StringIO(r.text))
    missing = [c for c in REQUIRED if c not in df.columns]
    if missing:
        raise RuntimeError(f"Unexpected response format, missing columns: {missing}")
    if (df["Series Key"] != series_id).any():
        raise RuntimeError("Response contains a different series than requested")

    out = pd.DataFrame({
        "series_code": df["Series Key"],
        "obs_date": pd.to_datetime(df["Observation Date"]).dt.date,
        "value": pd.to_numeric(df["Observation Value"], errors="raise"),
        "status": df["Observation Status"],
    })
    return out.sort_values("obs_date").reset_index(drop=True)


if __name__ == "__main__":
    df = fetch_series("TS_GP_IR_REPOMR_D.ORR", "2026-10-01", "2026-10-21")
    print(df.shape)
    print(df.dtypes)
    print(df.head(3).to_string())
    print(df.tail(3).to_string())
    print("duplicate dates:", df["obs_date"].duplicated().sum())
    print("status values:", df["status"].unique().tolist())