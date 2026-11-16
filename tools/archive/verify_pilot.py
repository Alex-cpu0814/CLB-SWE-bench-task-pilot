"""Run the three controls through the pinned, unmodified SWE-bench harness."""

import argparse
import hashlib
import json
import os
from pathlib import Path

from swebench import __version__
from swebench.harness.constants import FAIL_TO_PASS, PASS_TO_PASS
from swebench.harness.grading import get_logs_eval, parse_test_exit_code
from swebench.harness.run_evaluation import run_instances
from swebench.harness.utils import make_test_spec
from swebench.task.repo import load_task_repo


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().with_name("fixtures")
CONTROL_MODELS = {"base": "clb-base", "gold": "gold", "history": "clb-historical-candidates"}


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def result_dir(root, run, phase, name):
    return root / "logs/evaluation" / f"{run}-{phase}" / CONTROL_MODELS[phase] / name


def collect(root, prefix, phase, tasks, provenance, archived):
    results = []
    for task in tasks:
        name = task["instance_id"]
        directory = result_dir(root, prefix, phase, name)
        log = directory / "test_output.txt"
        report = directory / "report.json"
        if not report.is_file() or not log.is_file():
            raise RuntimeError(f"{name} {phase}: incomplete upstream evaluation under {directory}")
        entry = read_json(report)[name]
        statuses, valid = get_logs_eval(make_test_spec(task), str(log))
        log_text = log.read_text(encoding="utf-8", errors="replace")
        test_exit_code = parse_test_exit_code(log_text)
        expected_ids = set(task[FAIL_TO_PASS]) | set(task[PASS_TO_PASS])
        missing = sorted(expected_ids - statuses.keys())
        passed = {key: sum(statuses.get(test) == "PASSED" for test in task[key])
                  for key in (FAIL_TO_PASS, PASS_TO_PASS)}
        unexpected_errors = sorted(
            test for test, status in statuses.items()
            if status in {"FAILED", "ERROR"} and test not in expected_ids
        )
        strict_resolved = (valid and test_exit_code == 0 and not unexpected_errors
                           and all(passed[k] == len(task[k]) for k in passed))
        expected_resolution = phase == "gold" or (
            phase == "history" and provenance[name]["source_expected_outcome"] == "resolved"
        )
        base_control_ok = phase != "base" or (
            all(statuses.get(test) in {"FAILED", "ERROR"} for test in task[FAIL_TO_PASS])
            and passed[PASS_TO_PASS] == len(task[PASS_TO_PASS])
        )
        # The archived Jep Base control aborts during embedded CPython initialization.
        # Require the historical heap-corruption signature as well as the abort code.
        known_base_abort = (phase == "base" and name == "ninia__jep-clb-093"
                            and test_exit_code == 134 and "free(): invalid next size" in log_text)
        original = archived[name][phase]
        differences = {
            test: {"clb": status, "swebench": statuses.get(test, "MISSING")}
            for key in (FAIL_TO_PASS, PASS_TO_PASS)
            for test, status in original[key].items()
            if statuses.get(test, "MISSING") != status
        }
        matches = (valid and not missing and base_control_ok
                   and entry["resolved"] == strict_resolved == expected_resolution)
        results.append({
            "instance_id": name, "control": phase, "resolved": entry["resolved"],
            "strict_resolved": strict_resolved, "expected_resolved": expected_resolution,
            "test_log_valid": valid, "test_exit_code": test_exit_code,
            "matches_clb": matches or (known_base_abort and not entry["resolved"]),
            "historical_base_abort_reproduced": known_base_abort,
            "archived_clb_grading": original["source"],
            "test_status_differences": differences,
            "fail_to_pass_passed": passed[FAIL_TO_PASS], "fail_to_pass_total": len(task[FAIL_TO_PASS]),
            "pass_to_pass_passed": passed[PASS_TO_PASS], "pass_to_pass_total": len(task[PASS_TO_PASS]),
            "missing_tests": missing, "unexpected_errors": unexpected_errors,
            "test_statuses": {test: statuses.get(test, "MISSING") for test in sorted(expected_ids)},
            "report": str(report.relative_to(root)),
        })
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--resume", action="store_true", help="Reuse reports from this specific pilot run")
    args = parser.parse_args()
    if __version__ != "5.0.2":
        parser.error("Run python -m pip install -e . to install the pinned SWE-bench version")
    if not args.run_id.isascii() or not args.run_id.replace("-", "").isalnum():
        parser.error("Use a run id with ASCII letters, digits, and hyphens")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if not args.resume and any((output / "logs/evaluation" / f"{args.run_id}-{phase}").exists()
                               for phase in CONTROL_MODELS):
        parser.error("Use a fresh run id or explicitly resume this run")
    os.chdir(output)
    candidates = {row["instance_id"]: row for row in map(
        json.loads, (FIXTURES / "historical_predictions.jsonl").read_text(encoding="utf-8").splitlines()
    )}
    tasks = load_task_repo(ROOT, instance_ids=list(candidates))
    provenance = {row["instance_id"]: row for row in read_json(FIXTURES / "provenance.json")}
    archived = read_json(FIXTURES / "clb_grading.json")
    for name, row in candidates.items():
        if hashlib.sha256(row["model_patch"].encode()).hexdigest() != provenance[name]["candidate_sha256"]:
            raise RuntimeError(f"Historical patch changed: {name}")

    all_results = []
    for phase, model in CONTROL_MODELS.items():
        print(f"Running {phase} controls on {len(tasks)} tasks", flush=True)
        predictions = {
            task["instance_id"]: {
                "instance_id": task["instance_id"], "model_name_or_path": model,
                "model_patch": (task["patch"] if phase == "gold" else
                                candidates[task["instance_id"]]["model_patch"] if phase == "history" else ""),
            }
            for task in tasks
        }
        pending = [
            task for task in tasks
            if not (result_dir(output, args.run_id, phase, task["instance_id"]) / "report.json").is_file()
        ]
        if pending:
            run_instances(predictions, pending, 1, f"{args.run_id}-{phase}", 1800,
                          skip_patch=phase == "base", task_repo=str(ROOT))
        all_results.extend(collect(output, args.run_id, phase, tasks, provenance, archived))
        report_path = output / f"{args.run_id}-comparison.json"
        report_path.write_text(json.dumps(all_results, indent=2) + "\n", encoding="utf-8")
        for row in all_results[-len(tasks):]:
            print(f"{row['instance_id']} {phase}: resolved={row['resolved']} "
                  f"F2P={row['fail_to_pass_passed']}/{row['fail_to_pass_total']} "
                  f"P2P={row['pass_to_pass_passed']}/{row['pass_to_pass_total']}", flush=True)
    return 0 if all(row["matches_clb"] and not row["test_status_differences"]
                    for row in all_results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
