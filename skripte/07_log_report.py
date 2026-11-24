#!/usr/bin/env python3
from pathlib import Path
from datetime import datetime, timezone

out_dir = Path("skripte/logs")
out_dir.mkdir(parents=True, exist_ok=True)
report = out_dir / f"status_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.txt"
report.write_text("Rheinblick Portal Betriebsbericht erstellt.\n", encoding="utf-8")
print(report)
