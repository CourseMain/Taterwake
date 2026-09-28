#!/usr/bin/env bash
# Python supplies portable timeouts and bounded concurrency on macOS and Linux.
set -eu
cd "$(dirname "$0")/.."
exec python3 - "$@" <<'PY'
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser(description="Run isolated Godot suites; logs in artifacts/test-results.")
parser.add_argument("-j", type=int, default=4, help="parallel suites (default: 4)")
parser.add_argument("--timeout", type=float, default=180, help="seconds per suite (default: 180)")
parser.add_argument("suites", nargs="*", help="optional test names or paths; default: all test_*.gd except *_browser.*")
args = parser.parse_args()
if args.j < 1 or args.timeout <= 0:
    parser.error("-j and --timeout must be positive")
engine = shutil.which(os.environ.get("GODOT_BIN", "godot"))
if not engine:
    parser.error("Godot not found; set GODOT_BIN to an executable path")
suites = sorted(p for p in Path("tests").glob("test_*.gd") if "_browser." not in p.name)
if args.suites:
    selected = {Path(name).stem for name in args.suites}
    unknown = selected - {p.stem for p in suites}
    if unknown:
        parser.error("unknown suites: " + ", ".join(sorted(unknown)))
    suites = [p for p in suites if p.stem in selected]
logs = Path("artifacts/test-results")
logs.mkdir(parents=True, exist_ok=True)
summary_re = re.compile(r"^[^:\n]+: ([0-9]+ checks?, )?([0-9]+) failures?", re.MULTILINE)
error_re = re.compile(r"^\s*(?:SCRIPT ERROR|ERROR|USER ERROR|Parse Error):", re.MULTILINE)

def execute(command, log):
    try:
        with log.open("w") as output:
            result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=args.timeout)
        return result.returncode, False
    except subprocess.TimeoutExpired:
        return None, True
    except OSError as error:
        log.write_text(str(error))
        return None, False

if not Path(".godot/imported").is_dir():
    log = logs / "import.log"
    code, timed_out = execute([engine, "--headless", "--path", ".", "--editor", "--quit"], log)
    if timed_out or code != 0 or error_re.search(log.read_text(errors="replace")):
        print(f"{'TIMEOUT' if timed_out else 'ERRORS'} project import | {log}")
        sys.exit(1)

def run(suite):
    log = logs / (suite.stem + ".log")
    code, timed_out = execute([engine, "--headless", "--path", ".", "--script", "res://" + suite.as_posix(), "--", "--integration-test"], log)
    output = log.read_text(errors="replace")
    summaries = list(summary_re.finditer(output))
    summary = " | ".join(match.group(0) for match in summaries) or "no suite summary"
    if timed_out:
        status = "TIMEOUT"
    elif any(int(match.group(2)) for match in summaries):
        status = "FAIL"
    elif code is None or not summaries or error_re.search(output):
        status = "ERRORS"
    elif code != 0:
        status = "FAIL"
    else:
        status = "PASS"
    return {"suite": suite.stem, "status": status, "summary": summary, "exit_code": code, "log": str(log)}

results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=args.j) as pool:
    for result in pool.map(run, suites):
        results.append(result)
        print(f"{result['status']:7} {result['suite']} | {result['summary']}", flush=True)
(logs / "results.json").write_text(json.dumps(results, indent=2) + "\n")
counts = {status: sum(r['status'] == status for r in results) for status in ("PASS", "FAIL", "TIMEOUT", "ERRORS")}
print("Total: " + ", ".join(f"{count} {status}" for status, count in counts.items()) + f" | logs: {logs}")
sys.exit(0 if results and all(r['status'] == "PASS" for r in results) else 1)
PY
