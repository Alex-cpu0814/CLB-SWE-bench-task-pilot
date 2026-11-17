#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "e13278e712ac33c6110b5d48a8da0acfa7768b71" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/interpolate/tests/test_fitpack.py b/scipy/interpolate/tests/test_fitpack.py
index 7b90c36..c2179a4 100644
--- a/scipy/interpolate/tests/test_fitpack.py
+++ b/scipy/interpolate/tests/test_fitpack.py
@@ -459,6 +459,19 @@ def test_splev_der_k():
     assert_allclose(splev(x, (t, c, k), k), splev(x, tck2))
 
 
+def test_splprep_segfault():
+    # regression test for gh-3847: splprep segfaults if knots are specified
+    # for task=-1
+    t = np.arange(0, 1.1, 0.1)
+    x = np.sin(2*np.pi*t)
+    y = np.cos(2*np.pi*t)
+    tck, u = interpolate.splprep([x, y], s=0)
+    unew = np.arange(0, 1.01, 0.01)
+
+    uknots = tck[0]  # using the knots from the previous fitting
+    tck, u = interpolate.splprep([x, y], task=-1, t=uknots)  # here is the crash
+
+
 def test_bisplev_integer_overflow():
     np.random.seed(1)
 
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_89fb8eabf8a5' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.8 setup.py build_ext -i
}

run_project_tests() {
    python3.8 -m pytest -c /dev/null -vv \
        'scipy/interpolate/tests/test_fitpack.py::test_dblint' \
        'scipy/interpolate/tests/test_fitpack.py::test_splev_der_k' \
        'scipy/interpolate/tests/test_fitpack.py::test_splprep_segfault'
}
EOF_89fb8eabf8a5
cat > /benchmark/format_test_log.py <<'EOF_499bbb31acab' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)

TEST_START_LINE = re.compile(r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. .*")

PYTEST_LINE = re.compile(
    r"^(?P<test_id>scipy/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[.*\])?$"
)

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
        pytest_match = PYTEST_LINE.match(line)
        if pytest_match:
            statuses[pytest_match.group("test_id")] = pytest_match.group("status")
            pending = None
            continue
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
EOF_499bbb31acab
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
