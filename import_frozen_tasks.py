"""Import additional tasks from the frozen CLB release into this task repository."""

import argparse
import ast
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
FROZEN_PILOT_IDS = {"clb-pyc-002", "clb-javac-093", "clb-javac-175"}
TEST_KEYS = ("FAIL_TO_PASS", "PASS_TO_PASS")

EVAL_SCRIPT = """#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "@BASE@" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
@TEST@
CLB_TEST_PATCH

mkdir -p /results || fail 'Cannot create test output directory'
@MOUNTS@build_project || fail 'Project build failed'
run_project_tests >/results/tests.raw.log 2>&1
test_status=$?
cat /results/tests.raw.log

parser_python=$(command -v python || command -v python3 || command -v python2.7) \\
    || fail 'Cannot find Python for test log conversion'
printf '%s\\n' '>>>>> Start Test Output'
PYTHONIOENCODING=utf-8 "$parser_python" /benchmark/format_test_log.py /results/tests.raw.log \\
    || fail 'Cannot convert test output'
(exit "$test_status")
printf '%s\\n' '>>>>> End Test Output'
exit "$test_status"
"""

FORMAT_LOG = """
if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
"""

FORMAT_UNITTEST_LOG = """
if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    labels = {'PASSED': 'ok', 'FAILED': 'FAIL', 'ERROR': 'ERROR', 'SKIPPED': 'skipped'}
    for test_id, status in sorted(statuses.items()):
        if status in labels:
            print(u'{} ... {}'.format(test_id, labels[status]))
"""


def read_json(path):
    return json.loads(path.read_bytes())


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def release_instance_id(row):
    legacy_id = row["instance_id"]
    match = re.fullmatch(r"clb-(?:pyc|javac)-(\d{3})", legacy_id)
    if not match:
        raise ValueError(f"Unexpected frozen instance ID: {legacy_id}")
    repo_slug = row["repo"].lower().replace("/", "__")
    return f"{repo_slug}-clb-{match.group(1)}"


def evaluation_image(name):
    return f"swebench/sweb.eval.x86_64.{name.replace('__', '_1776_')}:latest"


def extract_function(source, name):
    for node in ast.parse(source).body:
        if isinstance(node, ast.FunctionDef) and node.name == name:
            return ast.get_source_segment(source, node)
    raise ValueError(f"Missing function {name}")


def format_test_log(legacy_evaluator, legacy_status_function, unittest_log):
    """Reuse the test-output parser without its Docker or grading code."""
    source = legacy_evaluator.read_text(encoding="utf-8-sig")
    sections = [
        '"""Convert test results to the SWE-bench status-first log format."""',
        "import io\nimport re\nimport sys",
    ]
    for node in ast.parse(source).body:
        if isinstance(node, ast.Import) and any(alias.name == "json" for alias in node.names):
            sections.append("import json")
        if isinstance(node, ast.Assign) and any(
            isinstance(name, ast.Name) and name.id in {"TEST_LINE", "TEST_START_LINE", "PYTEST_LINE"}
            for name in node.targets
        ):
            sections.append(ast.get_source_segment(source, node))
    parser = extract_function(source, "parse_test_log")
    # A compiled pattern's fullmatch is unavailable in Python 2.7 containers.
    parser = parser.replace(
        "match = PYTEST_LINE.fullmatch(line)\n        if match:",
        "match = PYTEST_LINE.match(line)\n        if match and match.end() == len(line):",
    )
    if "normalize_status(" in parser:
        sections.append(legacy_status_function)
    sections.extend((parser, FORMAT_UNITTEST_LOG if unittest_log else FORMAT_LOG))
    return "\n\n".join(sections).encode("utf-8")


def task_files(row, record, dataset, evaluator_root, legacy_status_function, base_image):
    name = release_instance_id(row)
    case = evaluator_root / "cases" / record["case"]
    config = read_json(case / "evaluator/case_config.json")
    grading = read_json(case / "grading/expected_tests.json")
    tests = {key: row[key] for key in TEST_KEYS}
    if row["base_commit"] != config["base_commit"] or any(grading[key] != tests[key] for key in TEST_KEYS):
        raise ValueError(f"Frozen data and evaluator disagree for {name}")

    dockerfile = f"FROM {base_image}\nCOPY runtime/ /benchmark/\n"
    if record["case"] == "javac_case_075":
        dockerfile += "RUN ln -s /opt/clb-deps /benchmark/dependencies\n"
    if record["case"] == "javac_case_200":
        # The frozen checkout is owned by the image user, while the harness runs as root.
        dockerfile += "USER root\nRUN git config --system --add safe.directory /testbed\n"
    runner = case / "evaluator/run_evaluation.sh"
    if runner.is_file():
        # Reset/clean happens before the official harness applies the candidate.
        clean = "-fdx -e bin" if "git clean -fdx -e bin" in runner.read_text(encoding="utf-8") else "-fdx"
        dockerfile += f"RUN git -C /testbed clean {clean}\n"
    mounts = ""
    if record["case"] == "javac_case_170":
        mounts = (
            "mkdir -p /case-noexec /case-exec || fail 'Cannot create test mountpoints'\n"
            "mount -t tmpfs -o rw,noexec,nosuid,size=64m tmpfs /case-noexec "
            "|| fail 'Cannot create noexec test mount'\n"
            "mount -t tmpfs -o rw,exec,nosuid,size=64m tmpfs /case-exec "
            "|| fail 'Cannot create executable test mount'\n"
        )
    test_text = row["test_patch"].replace("\r\n", "\n").rstrip("\n")
    if not test_text or "CLB_TEST_PATCH" in test_text.splitlines():
        raise ValueError(f"Cannot embed test patch for {name}")
    script = EVAL_SCRIPT.replace("@BASE@", row["base_commit"]).replace("@MOUNTS@", mounts)
    script = script.replace("@TEST@", test_text)
    # The upstream Django parser preserves spaces inside test IDs.
    unittest_log = any(any(char.isspace() for char in node) for nodes in tests.values() for node in nodes)
    files = {
        "task.yaml": json_bytes({
            "instance_id": name, "repo": row["repo"], "base_commit": row["base_commit"],
            "version": "clb-v1-pilot", "split": "test", "datasets": [dataset],
            "cohort": row["cohort"], "image": evaluation_image(name),
            "log_parser": "parse_log_django" if unittest_log else "parse_log_pytest_v2",
            "eval_type": "pass_and_fail",
        }),
        "tests.json": json_bytes(tests),
        "problem_statement.md": row["problem_statement"].encode("utf-8"),
        "gold.patch": row["patch"].encode("utf-8"),
        "test.patch": row["test_patch"].encode("utf-8"),
        "Dockerfile": dockerfile.encode("utf-8"),
        ".dockerignore": b"*\n!Dockerfile\n!runtime/\n!runtime/**\n",
        "eval.sh": script.encode("utf-8"),
        "runtime/format_test_log.py": format_test_log(
            case / "evaluator/evaluate_model_patch.py", legacy_status_function, unittest_log
        ),
    }
    for asset in config["runtime_assets"]:
        target = asset["target"].removeprefix("/benchmark/")
        if asset["target"] != f"/benchmark/{target}" or not re.fullmatch(r"[\w.-]+", target):
            raise ValueError(f"Unexpected runtime asset path for {name}: {asset['target']}")
        path = f"runtime/{target}"
        if path in files:
            raise ValueError(f"Duplicate runtime asset for {name}: {path}")
        files[path] = (case / asset["source"]).read_bytes()
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frozen_release", type=Path)
    parser.add_argument("-i", "--instance", action="append", help="Select by release or frozen ID (repeatable)")
    parser.add_argument("--check", action="store_true", help="Compare expected files without writing")
    args = parser.parse_args()
    release = args.frozen_release.resolve()
    evaluator = release / "evaluation"
    rows = [json.loads(line) for line in (release / "dataset/test.jsonl").read_bytes().splitlines() if line]
    records = {r["instance_id"]: r for r in read_json(evaluator / "index.json")["cases"]}
    rows_by_id = {row["instance_id"]: row for row in rows}
    if len(rows_by_id) != len(rows) or rows_by_id.keys() != records.keys():
        parser.error("The frozen dataset and evaluator index must contain the same unique instances")
    frozen_by_release = {release_instance_id(row): row["instance_id"] for row in rows}
    if len(frozen_by_release) != len(rows):
        parser.error("Release instance IDs must be unique")
    base_images = read_json(ROOT / "base-images.json")
    if base_images.keys() != frozen_by_release.keys():
        parser.error("Base image manifest must cover every release instance")
    for name, reference in base_images.items():
        slug = name.replace("__", "_1776_")
        prefix = f"yutu0814/clb.base.x86_64.{slug}:latest@sha256:"
        if not reference.startswith(prefix) or not re.fullmatch(r"[0-9a-f]{64}", reference[len(prefix):]):
            parser.error(f"Invalid pinned Base image for {name}")
    selected = {frozen_by_release.get(name, name) for name in args.instance or rows_by_id}
    if unknown := selected - rows_by_id.keys():
        parser.error(f"Unknown instances: {', '.join(sorted(unknown))}")
    status_function = extract_function(
        (release / "harness/case_evaluator.py").read_text(encoding="utf-8"), "normalize_status"
    )
    dataset, = read_json(ROOT / "sweb.yaml")["datasets"]
    updates = {}
    for frozen_id in sorted(selected):
        row = rows_by_id[frozen_id]
        name = release_instance_id(row)
        base_image = base_images[name]
        if frozen_id in FROZEN_PILOT_IDS:
            files = {
                field: row[key].encode("utf-8") for field, key in
                (("problem_statement.md", "problem_statement"), ("gold.patch", "patch"), ("test.patch", "test_patch"))
            }
            metadata_path = ROOT / "tasks" / name / "task.yaml"
            if not metadata_path.is_file():
                parser.error(f"Missing pilot metadata: {metadata_path}")
            metadata = read_json(metadata_path)
            if metadata.get("instance_id") != name or metadata.get("image") != evaluation_image(name):
                parser.error(f"Incorrect pilot instance ID or image: {metadata_path}")
            dockerfile = metadata_path.with_name("Dockerfile")
            if not dockerfile.is_file() or not dockerfile.read_bytes().startswith(f"FROM {base_image}\n".encode()):
                parser.error(f"Incorrect pilot Base image: {dockerfile}")
        else:
            files = task_files(row, records[frozen_id], dataset, evaluator, status_function, base_image)
        for filename, expected in files.items():
            target = ROOT / "tasks" / name / filename
            if target.is_file() and target.read_bytes() == expected:
                continue
            if args.check or frozen_id in FROZEN_PILOT_IDS or target.exists():
                parser.error(f"Missing or different file: {target}")
            updates[target] = expected
    for target, expected in updates.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(expected)
    print(f"Checked {len(selected)} instances, wrote {len(updates)} files.")


if __name__ == "__main__":
    main()
