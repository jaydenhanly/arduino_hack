#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENGINE="${SUMMER_BIN:-/Applications/Summer.app/Contents/MacOS/Summer}"
if [[ ! -x "$ENGINE" ]]; then
  echo "Set SUMMER_BIN to the installed Summer executable." >&2
  exit 1
fi
command -v python3 >/dev/null || { echo "Python 3 is required." >&2; exit 1; }
OUT_ROOT="${OUT_DIR:-$PROJECT_DIR/builds/checks/roadmap}"
mkdir -p "$OUT_ROOT"
OUT="$(mktemp -d "$OUT_ROOT/run-XXXXXXXX")"
echo "Fresh roadmap evidence: $OUT"

python3 - "$PROJECT_DIR" "$ENGINE" "$OUT" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

project, engine, output = sys.argv[1:]
output = Path(output)
error_pattern = re.compile(r"SCRIPT ERROR[:|]|(?:^|\n)\s*ERROR[:|]|Parse Error:|Compile Error:|Failed to load script|Assertion failed", re.I)
summary = {"started_unix": time.time(), "model_enabled": False, "checks": {},
           "coverage": {"full_run": "Input-driven continuous runs; no gameplay fixtures or invulnerability",
                        "coordinator": "Checkpoint construction and lifecycle fixtures",
                        "presentation": "Optional rendered layout/emotion/checkpoint fixtures"}}

def execute(name, command, timeout, marker=None, env=None, cwd=project):
    log_path = output / (name + ".log")
    result = {"command": command, "log": str(log_path), "passed": False}
    try:
        with log_path.open("w") as log:
            completed = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                                       timeout=timeout, env=env)
        text = log_path.read_text(errors="replace")
        result["exit_code"] = completed.returncode
        result["runtime_errors"] = error_pattern.findall(text)
        result["passed"] = completed.returncode == 0 and not result["runtime_errors"] and (marker is None or marker in text)
        if marker:
            result["completion_marker"] = marker in text
    except subprocess.TimeoutExpired:
        result["error"] = f"Timed out after {timeout}s"
    except OSError as error:
        result["error"] = str(error)
    summary["checks"][name] = result
    print(f"{'PASS' if result['passed'] else 'FAIL'} {name}: {log_path}", flush=True)
    if not result["passed"]:
        print(log_path.read_text(errors="replace")[-5000:], flush=True)
    return result["passed"]

execute("import", [engine, "--headless", "--disable-crash-handler", "--path", project, "--import"], 90)
for name, relative, marker in [
    ("early_stages", "tests/roadmap/early_stage_probe.gd", "EARLY_STAGE_PROBE checks="),
    ("late_stages", "tests/roadmap/late_stage_probe.gd", "LATE_STAGE_PROBE_OK"),
    ("ai_unit", "tests/ai/unit.gd", "PIXEL_AI_UNIT_OK"),
    ("coordinator", "tests/roadmap/coordinator_probe.gd", "COORDINATOR_CHECKS"),
]:
    if not (Path(project) / relative).is_file():
        summary["checks"][name] = {"passed": False, "error": f"Missing required probe: {relative}"}
        print(f"FAIL {name}: missing {relative}", flush=True)
        continue
    execute(name, [engine, "--headless", "--disable-crash-handler", "--path", project,
                   "--script", relative], 90, marker)

rendered = output / "rendered"
environment = os.environ.copy()
environment.update(SUMMER_BIN=engine, OUT_DIR=str(rendered), MAX_SECONDS=os.environ.get("MAX_SECONDS", "180"))
execute("full_run", ["bash", "tests/autopilot/run.sh", str(Path(project) / "tests/roadmap/full_run_probe.gd")],
        int(environment["MAX_SECONDS"]) + 120, env=environment)
try:
    data = json.loads((rendered / "results.json").read_text())
    reports = data.get("reports", {})
    invalid = [key for key, value in reports.items() if value is False or
               ("timeout" in key and value is True)]
    required = ["all_scenarios_completed", "death_real_tail_collision", "death_replay", "pause_cancel_title"]
    for profile in ("normal_dialogue", "demo_dialogue", "demo_skip_conversation", "demo_skip_payoff"):
        required += [profile + "_" + stage + "_real_objective" for stage in ("snake", "maze", "frogger", "asteroids")]
        required += [profile + "_replay_fresh", profile + "_replay_screen"]
    invalid += [key for key in required if reports.get(key) is not True]
    frames = data.get("frames", [])
    frames_valid = bool(frames) and all((rendered / frame).is_file() and (rendered / frame).stat().st_size > 1000 for frame in frames)
    logs_clean = all(not error_pattern.search(log.read_text(errors="replace")) for log in rendered.glob("*.log"))
    summary["checks"]["rendered_evidence"] = {
        "passed": bool(data.get("finished") and not data.get("errors_seen") and not data.get("frame_warnings")
                       and not reports.get("error") and not invalid and frames_valid and logs_clean),
        "results": str(rendered / "results.json"), "invalid_checks": sorted(set(invalid)),
        "frames": len(frames), "logs_clean": logs_clean,
    }
except (OSError, ValueError, TypeError) as error:
    summary["checks"]["rendered_evidence"] = {"passed": False, "error": str(error)}

if os.environ.get("ROADMAP_PRESENTATION", "1") == "1":
    presentation = output / "presentation"
    environment.update(OUT_DIR=str(presentation), MAX_SECONDS="90")
    execute("presentation", ["bash", "tests/autopilot/run.sh", str(Path(project) / "tests/roadmap/presentation_probe.gd")],
            210, env=environment)
    try:
        data = json.loads((presentation / "results.json").read_text())
        reports = data.get("reports", {})
        frames = data.get("frames", [])
        required_frames = ["01_title.jpg", "conversation_maximum_text.jpg"]
        required_frames += ["emotion_" + emotion + ".jpg" for emotion in ("curious", "excited", "worried", "surprised", "proud")]
        required_frames += ["stage_" + stage + ".jpg" for stage in ("snake", "maze", "frogger", "asteroids")]
        complete = all(frame in frames and (presentation / frame).is_file() and
                       (presentation / frame).stat().st_size > 1000 for frame in required_frames)
        clean = all(not error_pattern.search(log.read_text(errors="replace")) for log in presentation.glob("*.log"))
        summary["checks"]["presentation_evidence"] = {
            "passed": bool(data.get("finished") and not data.get("errors_seen") and not data.get("frame_warnings")
                           and not reports.get("error") and not any("timeout" in key and value is True for key, value in reports.items())
                           and all(value is not False for value in reports.values()) and complete and clean),
            "results": str(presentation / "results.json"), "frames": len(frames), "logs_clean": clean,
        }
    except (OSError, ValueError, TypeError) as error:
        summary["checks"]["presentation_evidence"] = {"passed": False, "error": str(error)}

if os.environ.get("RELEASE_PACK"):
    release_pack = str(Path(os.environ["RELEASE_PACK"]).resolve())
    summary["release_pack"] = release_pack
    with tempfile.TemporaryDirectory(prefix="pixel-shift-release-") as isolated:
        execute("release_pack", [engine, "--headless", "--disable-crash-handler", "--main-pack", release_pack,
                                 "--script", str(Path(project) / "tests/autopilot/release_check.gd")],
                60, marker='"release_feature": true', cwd=isolated)

summary["finished_unix"] = time.time()
summary["passed"] = all(check["passed"] for check in summary["checks"].values())
(output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(f"{'PASS' if summary['passed'] else 'FAIL'} roadmap acceptance: {output / 'summary.json'}", flush=True)
sys.exit(0 if summary["passed"] else 1)
PY
