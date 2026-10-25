import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
log = ROOT / "logs" / "alerts.log"
log.parent.mkdir(exist_ok=True)

msg = " ".join(sys.argv[1:]) or "pipeline failed"
with open(log, "a", encoding="utf-8") as f:
    f.write(f"{datetime.now().isoformat(timespec='seconds')} ALERT {msg}\n")
print("alert written")