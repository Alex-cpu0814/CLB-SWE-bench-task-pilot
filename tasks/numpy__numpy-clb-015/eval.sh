#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "965ea2ff417bcb285beca5c36cd02a8790a3d8f6" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_regression.py b/numpy/core/tests/test_regression.py
index 944d053..c5289f6 100644
--- a/numpy/core/tests/test_regression.py
+++ b/numpy/core/tests/test_regression.py
@@ -436,6 +436,32 @@ class TestRegression(object):
 
         assert_raises(KeyError, np.lexsort, BuggySequence())
 
+    def test_lexsort_zerolen_custom_strides(self):
+        # Ticket #14228
+        xs = np.array([], dtype='i8')
+        assert xs.strides == (8,)
+        assert np.lexsort((xs,)).shape[0] == 0 # Works
+
+        xs.strides = (16,)
+        assert np.lexsort((xs,)).shape[0] == 0 # Was: MemoryError
+
+    def test_lexsort_zerolen_custom_strides_2d(self):
+        xs = np.array([], dtype='i8')
+
+        xs.shape = (0, 2)
+        xs.strides = (16, 16)
+        assert np.lexsort((xs,), axis=0).shape[0] == 0
+
+        xs.shape = (2, 0)
+        xs.strides = (16, 16)
+        assert np.lexsort((xs,), axis=0).shape[0] == 2
+
+    def test_lexsort_zerolen_element(self):
+        dt = np.dtype([])  # a void dtype with no fields
+        xs = np.empty(4, dt)
+
+        assert np.lexsort((xs,)).shape[0] == xs.shape[0]
+
     def test_pickle_py2_bytes_encoding(self):
         # Check that arrays and scalars pickled on Py2 are
         # unpickleable on Py3 using encoding='bytes'
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_682b7855c36f' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.8-dbg setup.py build_ext -i --force
}

run_project_tests() {
    python3.8-dbg -m pytest -vv \
        'numpy/core/tests/test_regression.py::TestRegression::test_lexsort' \
        'numpy/core/tests/test_regression.py::TestRegression::test_lexsort_invalid_sequence' \
        'numpy/core/tests/test_regression.py::TestRegression::test_lexsort_zerolen_custom_strides' \
        'numpy/core/tests/test_regression.py::TestRegression::test_lexsort_zerolen_custom_strides_2d'
}
EOF_682b7855c36f
cat > /benchmark/format_test_log.py <<'EOF_a6b100428c3f' || fail 'Cannot write /benchmark/format_test_log.py'
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
    r"^(?P<test_id>numpy/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED|LEAKED)(?:\s+\[.*\])?$"
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
            status = pytest_match.group("status")
            statuses[pytest_match.group("test_id")] = (
                "FAILED" if status == "LEAKED" else status
            )
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
EOF_a6b100428c3f
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
