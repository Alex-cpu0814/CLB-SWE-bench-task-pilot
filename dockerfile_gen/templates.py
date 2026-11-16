"""Shell templates for the standard and pilot CLB evaluation flows."""

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


PILOT_EVAL_SCRIPT = r'''#!/bin/bash
set -uxo pipefail
set +x
ulimit -c 0
cd /testbed || exit 2
fail() {
    printf '%s\n' ">>>>> Tests Errored" "$1" >&2
    exit 2
}
[[ "$(git rev-parse HEAD)" == "@BASE@" ]] || fail "Unexpected Base commit"
git apply --check --whitespace=nowarn - <<'CLB_TEST_PATCH'
@TEST@
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch does not apply"
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH'
@TEST@
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch application failed"
source /opt/clb-pilot/case_adapter.sh || fail "Cannot load the case adapter"
build_project || fail "Project build failed"
raw_log=$(mktemp) || fail "Cannot create a test log"
trap 'rm -f "$raw_log"' EXIT
run_project_tests >"$raw_log" 2>&1
test_status=$?
cat "$raw_log"
printf '%s\n' '>>>>> Start Test Output'
emit_results() {
    @NORMALIZE@ "$raw_log" || return 2
    return "$test_status"
}
emit_results
printf '%s\n' '>>>>> End Test Output'
exit "$test_status"
'''
