"""Shell templates for the standard and pilot CLB evaluation flows."""

from .constants import CONTAINER_WORKDIR, END_TEST_OUTPUT, START_TEST_OUTPUT, TEST_PATCH_DELIMITER

EVAL_SCRIPT = f"""#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {{
    printf '%s\\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}}

cd {CONTAINER_WORKDIR} || fail 'Cannot enter {CONTAINER_WORKDIR}'
[[ "$(git rev-parse HEAD)" == "@BASE@" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'{TEST_PATCH_DELIMITER}' || fail 'Test patch application failed'
@TEST@
{TEST_PATCH_DELIMITER}

mkdir -p /results || fail 'Cannot create test output directory'
@MOUNTS@build_project || fail 'Project build failed'
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
source /opt/clb-pilot/case_adapter.sh || fail "Cannot load the case adapter"
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
