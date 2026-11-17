#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "f6c82e695f5b6964daeec2c4e0bc449a89be892a" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tditest/testing/test-treeshr.ans b/tditest/testing/test-treeshr.ans
index df6b7e82c0ebe73d5e2a608d23e0fdea9e3d4bfa..f443686d66c54261f4dde23488ceda667330c55c 100644
--- a/tditest/testing/test-treeshr.ans
+++ b/tditest/testing/test-treeshr.ans
@@ -140,7 +140,7 @@ getnci(.subtree:a12,"parent_relationship")
 getnci(.subtree:a12,"get_flags")
 128LU
 getnci(.subtree:a12,"owner_id")
-4194368LU
+64LU
 getnci(.subtree:a12,"status")
 0LU
 getnci(.subtree:a12,"brother")
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_797165c2f5a2' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    cd /testbed
    ./bootstrap
    cd /build
    NOF77=yes /testbed/configure --prefix=/usr/local/mdsplus --disable-java
    make
    make install
}

run_one_tdi_test() {
    local test_name="$1"
    local display_name="$2"
    local status
    local test_dir=/build/tditest/testing

    rm -f "${test_dir}/${test_name}.log" "${test_dir}/${test_name}.trs" "${test_dir}/test-suite.log"
    make -C "${test_dir}" check TESTS="${test_name}.tdi"
    status=$?
    if [[ "${status}" -eq 0 ]]; then
        printf '%s (MDSplus.tditest) ... ok\n' "${display_name}"
    else
        printf '%s (MDSplus.tditest) ... FAIL\n' "${display_name}"
    fi
    return "${status}"
}

run_project_tests() {
    local control_status=0
    local target_status=0

    run_one_tdi_test test-tdishr test-tdishr || control_status=$?
    run_one_tdi_test test-treeshr test-treeshr-owner-id || target_status=$?
    [[ "${control_status}" -eq 0 && "${target_status}" -eq 0 ]]
}

EOF_797165c2f5a2
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
