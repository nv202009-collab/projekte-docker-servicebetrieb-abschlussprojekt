#!/usr/bin/env python3
"""
Zweck: Auswertung von Docker-, Nginx-, WordPress- und MariaDB-Logs nach Schweregrad und Quelle
Autor: Natalija Vinogradov (Junior Systemadministratorin, Rheinblick Services GmbH)
Datum: 2026-11-25
Voraussetzungen: Python 3, laufender oder gestoppter Compose-Stack
Beispielaufruf: python3 skripte/07_log_report.py
"""

import datetime
import pathlib
import re
import subprocess
import sys
from collections import Counter

PROJECT_DIR = pathlib.Path(__file__).resolve().parent.parent
LOG_DIR = PROJECT_DIR / "logs"
SERVICES = ["reverse-proxy", "portal", "database"]


def collect_logs() -> dict[str, str]:
    logs = {}
    for svc in SERVICES:
        cmd = [
            "docker", "compose",
            "--env-file", str(PROJECT_DIR / "compose/.env"),
            "-f", str(PROJECT_DIR / "compose/docker-compose.yml"),
            "logs", "--no-color", "--tail=300", svc,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, check=False)
        logs[svc] = res.stdout + "\n" + res.stderr
    return logs


def analyze(logs: dict[str, str]) -> tuple[str, int]:
    severity_counts = Counter()
    source_counts = Counter()
    error_messages = Counter()

    patterns = {
        "CRITICAL/FATAL": re.compile(r"\b(emerg|alert|crit|fatal|panic)\b", re.I),
        "ERROR": re.compile(r"\b(error|err|failed|denied|refused|502|500)\b", re.I),
        "WARNING": re.compile(r"\b(warn|warning|deprecated|timeout)\b", re.I),
        "INFO": re.compile(r"\b(info|notice|ready|started|healthy)\b", re.I),
    }

    for svc, content in logs.items():
        for raw_line in content.splitlines():
            line = raw_line.strip()
            if not line:
                continue
            source_counts[svc] += 1
            matched = False
            for sev, pat in patterns.items():
                if pat.search(line):
                    severity_counts[sev] += 1
                    if sev in ("CRITICAL/FATAL", "ERROR", "WARNING"):
                        cleaned = re.sub(r"^[^|]+\|\s*", "", line)[:110]
                        error_messages[f"[{svc}] {cleaned}"] += 1
                    matched = True
                    break
            if not matched:
                severity_counts["OTHER"] += 1

    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "=== RHEINBLICK LOG-AUSWERTUNG (PYTHON 3) ===",
        f"Zeitstempel: {now}",
        "",
        "--- Zusammenfassung nach Schweregrad ---",
    ]
    for sev in ["CRITICAL/FATAL", "ERROR", "WARNING", "INFO", "OTHER"]:
        lines.append(f"  {sev:<16}: {severity_counts[sev]}")

    lines.append("\n--- Ausgewertete Zeilen pro Dienst ---")
    for svc in SERVICES:
        lines.append(f"  {svc:<16}: {source_counts[svc]}")

    lines.append("\n--- Haeufigste Fehler- und Warnmeldungen (Top 10) ---")
    if error_messages:
        for msg, count in error_messages.most_common(10):
            lines.append(f"  ({count}x) {msg}")
    else:
        lines.append("  Keine kritischen Fehler oder Warnungen gefunden.")

    exit_code = 1 if severity_counts["CRITICAL/FATAL"] > 0 else 0
    return "\n".join(lines) + "\n", exit_code


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help"):
        print("Verwendung: python3 skripte/07_log_report.py [--help]")
        return 0

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logs = collect_logs()
    report_text, code = analyze(logs)
    out_file = LOG_DIR / f"log_report_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    out_file.write_text(report_text, encoding="utf-8")
    print(report_text)
    print(f"Bericht gespeichert unter: {out_file}")
    return code


if __name__ == "__main__":
    sys.exit(main())
