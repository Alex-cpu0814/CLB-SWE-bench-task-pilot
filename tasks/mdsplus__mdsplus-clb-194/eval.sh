#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "a73d6e87149698e49026e3bf8055efc6bbe71d90" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tditest/testing/test-treeshr.ans b/tditest/testing/test-treeshr.ans
index dd8bccbc1..60452431a 100644
--- a/tditest/testing/test-treeshr.ans
+++ b/tditest/testing/test-treeshr.ans
@@ -18,6 +18,12 @@ getnci('?ember','fullpath')
 "\\MAIN::TOP:MEMBER"
 getnci('%ember','fullpath')
 ["\\MAIN::TOP:MEMBER"]
+getnci('\n','fullpath')
+%TREE-W-NNF, Node Not Found
+%TDI Error in GETNCI("\n", "fullpath")
+%TDI Error in EVALUATE(GETNCI("\n", "fullpath"))
+%TDI Error in EXECUTE("getnci('\\n','fullpath')")
+
 _tim=getnci(member,'time_inserted')
 49776423271761650QU
 date_time(_tim)
diff --git a/tditest/testing/test-treeshr.tdi b/tditest/testing/test-treeshr.tdi
index 4712199cf..9d6510c2d 100644
--- a/tditest/testing/test-treeshr.tdi
+++ b/tditest/testing/test-treeshr.tdi
@@ -9,6 +9,7 @@ getnci(member,'length')
 getnci(member,'on')
 getnci('?ember','fullpath')
 getnci('%ember','fullpath')
+getnci('\n','fullpath')
 _tim=getnci(member,'time_inserted')
 date_time(_tim)
 .subtree:a12:name
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_d2b168f3892b' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    make -C /build
    make -C /build install
}

run_one_tdi_test() {
    local test_name="$1"
    local status
    local test_dir=/build/tditest/testing

    rm -f "${test_dir}/${test_name}.log" "${test_dir}/${test_name}.trs" "${test_dir}/test-suite.log"
    make -C "${test_dir}" check TESTS="${test_name}.tdi"
    status=$?
    if [[ "${status}" -eq 0 ]]; then
        printf '%s (MDSplus.tditest) ... ok\n' "${test_name}"
    else
        printf '%s (MDSplus.tditest) ... FAIL\n' "${test_name}"
    fi
    return "${status}"
}

run_project_tests() {
    local control_status=0
    local target_status=0

    run_one_tdi_test test-tdishr || control_status=$?
    run_one_tdi_test test-treeshr || target_status=$?
    [[ "${control_status}" -eq 0 && "${target_status}" -eq 0 ]]
}
EOF_d2b168f3892b
cat > /benchmark/format_test_log.py <<'EOF_8a58ff4098c6' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)

TEST_START_LINE = re.compile(r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. .*")

def normalize_status(raw_status):
    if raw_status == "ok":
        return "PASSED"
    if raw_status == "FAIL":
        return "FAILED"
    if raw_status == "ERROR":
        return "ERROR"
    if raw_status.startswith("skipped"):
        return "SKIPPED"
    return "UNKNOWN"

def parse_test_log(text):
    statuses = {}
    pending = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        match = TEST_LINE.match(line)
        if not match:
            if pending and (line in ("ok", "FAIL", "ERROR") or line.startswith("skipped")):
                statuses[pending] = normalize_status(line)
                pending = None
                continue
            start = TEST_START_LINE.match(line)
            if start:
                pending = "{}.{}".format(start.group("class"), start.group("method"))
            continue
        test_id = "{}.{}".format(match.group("class"), match.group("method"))
        statuses[test_id] = normalize_status(match.group("status"))
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_8a58ff4098c6
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
mkdir -p /results || fail 'Cannot create test output directory'
build_project || fail 'Project build failed'
run_project_tests >/results/tests.raw.log 2>&1
test_status=$?
cat /results/tests.raw.log

parser_python=$(command -v python || command -v python3 || command -v python2.7) \
    || fail 'Cannot find Python for test log conversion'
printf '%s\n' '>>>>> Start Test Output'
PYTHONIOENCODING=utf-8 "$parser_python" /benchmark/format_test_log.py /results/tests.raw.log \
    || fail 'Cannot convert test output'
(exit "$test_status")
printf '%s\n' '>>>>> End Test Output'
exit "$test_status"
