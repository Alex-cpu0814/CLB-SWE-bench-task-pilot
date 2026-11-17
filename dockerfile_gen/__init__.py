"""Generate Dockerfile and eval.sh for CLB tasks."""

import argparse
import re
from importlib.resources import files
from pathlib import Path

from yaml import YAMLError

from . import java_c, python_c
from .constants import CONTAINER_WORKDIR, END_TEST_OUTPUT, START_TEST_OUTPUT, TEST_PATCH_DELIMITER
from .utils import prepare_test_patch, write_inline


EVAL_SCRIPT = f"""#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {{
    printf '%s\\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}}

cd {CONTAINER_WORKDIR} || fail 'Cannot enter {CONTAINER_WORKDIR}'
[[ "$(git rev-parse HEAD)" == "@BASE@" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'{TEST_PATCH_DELIMITER}' || fail 'Test patch application failed'
@TEST@
{TEST_PATCH_DELIMITER}

@ASSETS@source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
mkdir -p /results || fail 'Cannot create test output directory'
@SETUP@build_project || fail 'Project build failed'
run_project_tests >/results/tests.raw.log 2>&1
test_status=$?
cat /results/tests.raw.log

parser_python=$(command -v python || command -v python3 || command -v python2.7) \\
    || fail 'Cannot find Python for test log conversion'
printf '%s\\n' '{START_TEST_OUTPUT}'
PYTHONIOENCODING=utf-8 "$parser_python" /benchmark/format_test_log.py /results/tests.raw.log \\
    || fail 'Cannot convert test output'
(exit "$test_status")
printf '%s\\n' '{END_TEST_OUTPUT}'
exit "$test_status"
"""


PILOT_EVAL_SCRIPT = rf'''#!/bin/bash
set -uxo pipefail
set +x
ulimit -c 0
cd {CONTAINER_WORKDIR} || exit 2
fail() {{
    printf '%s\n' ">>>>> Tests Errored" "$1" >&2
    exit 2
}}
[[ "$(git rev-parse HEAD)" == "@BASE@" ]] || fail "Unexpected Base commit"
git apply --check --whitespace=nowarn - <<'{TEST_PATCH_DELIMITER}'
@TEST@
{TEST_PATCH_DELIMITER}
[[ "$?" == 0 ]] || fail "Test patch does not apply"
git apply --whitespace=nowarn - <<'{TEST_PATCH_DELIMITER}'
@TEST@
{TEST_PATCH_DELIMITER}
[[ "$?" == 0 ]] || fail "Test patch application failed"
@ASSETS@source /opt/clb-pilot/case_adapter.sh || fail "Cannot load the case adapter"
build_project || fail "Project build failed"
raw_log=$(mktemp) || fail "Cannot create a test log"
trap 'rm -f "$raw_log"' EXIT
run_project_tests >"$raw_log" 2>&1
test_status=$?
cat "$raw_log"
printf '%s\n' '{START_TEST_OUTPUT}'
emit_results() {{
    @NORMALIZE@ "$raw_log" || return 2
    return "$test_status"
}}
emit_results
printf '%s\n' '{END_TEST_OUTPUT}'
exit "$test_status"
'''


def render_files(instance_id, cohort, base_commit, image, test_patch):
    """Render the shared image recipe and evaluation script from task metadata."""
    if not isinstance(base_commit, str) or not re.fullmatch("[0-9a-f]{40}", base_commit):
        raise ValueError(f"Invalid Base commit for {instance_id}")
    test = prepare_test_patch(instance_id, test_patch)

    if cohort in python_c.COHORTS:
        language = python_c
    elif cohort in java_c.COHORTS:
        language = java_c
    else:
        raise ValueError(f"Unknown cohort for {instance_id}: {cohort}")

    pilot_normalizer = language.PILOT_NORMALIZERS.get(instance_id)
    if pilot_normalizer:
        asset_dir = "/opt/clb-pilot"
        script = PILOT_EVAL_SCRIPT.replace("@NORMALIZE@", pilot_normalizer)
    else:
        asset_dir = "/benchmark"
        script = EVAL_SCRIPT.replace("@SETUP@", java_c.EVAL_SETUP.get(instance_id, ""))

    project = instance_id.rsplit("-clb-", 1)[0]
    build = language.BUILD_OVERRIDES.get(instance_id, language.BUILD_BY_PROJECT[project])
    test_commands = language.TEST_COMMANDS[instance_id]
    adapter = f"#!/usr/bin/env bash\n{build}run_project_tests() {{\n{test_commands}"
    dockerfile = java_c.DOCKERFILE_OVERRIDES.get(instance_id, f"FROM {image}\n")
    assets = [f"mkdir -p {asset_dir} || fail 'Cannot create evaluation fixture directory'\n"]
    assets.append(write_inline(adapter, f"{asset_dir}/case_adapter.sh"))

    fixtures = files(__package__) / "fixtures"
    sources = language.PROJECT_FIXTURES.get(project, ()) + language.INSTANCE_FIXTURES.get(instance_id, ())
    for source in sorted(sources, key=lambda path: path.rsplit("/", 1)[-1]):
        fixture = fixtures.joinpath(*source.split("/"))
        assets.append(write_inline(fixture.read_text(encoding="utf-8"), f"{asset_dir}/{fixture.name}"))

    script = script.replace("@BASE@", base_commit).replace("@TEST@", test).replace("@ASSETS@", "".join(assets))
    return {"Dockerfile": dockerfile.encode("utf-8"), "eval.sh": script.encode("utf-8")}


def main():
    from .tasks import plan_updates, write_generated

    parser = argparse.ArgumentParser(description="Generate or verify CLB's checked-in Dockerfile and eval.sh files.")
    parser.add_argument("task_repo", nargs="?", default=Path.cwd(), type=Path)
    parser.add_argument("--instance_ids", nargs="+", default=[], help="Select tasks by instance ID")
    parser.add_argument("-i", "--instance", action="append", default=[], help="Select one instance (repeatable)")
    parser.add_argument("--check", action="store_true", help="Report missing or stale generated files")
    args = parser.parse_args()

    try:
        task_count, updates = plan_updates(args.task_repo, args.instance_ids + args.instance)
    except (OSError, KeyError, ValueError, YAMLError) as exc:
        parser.error(str(exc))

    if args.check:
        for path in updates:
            print(f"Missing or stale: {path.relative_to(args.task_repo)}")
        print(f"Checked {task_count} tasks, {len(updates)} files differ.")
        return int(bool(updates))

    write_generated(updates)
    print(f"Generated files for {task_count} tasks, wrote {len(updates)} files.")
    return 0
