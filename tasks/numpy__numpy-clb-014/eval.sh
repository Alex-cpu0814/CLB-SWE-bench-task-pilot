#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "495d352bf325f44d78001f059d625123e49f027e" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_dtype.py b/numpy/core/tests/test_dtype.py
index f60eab6..f5ca775 100644
--- a/numpy/core/tests/test_dtype.py
+++ b/numpy/core/tests/test_dtype.py
@@ -419,6 +419,31 @@ class TestRecord(object):
         assert_raises(ValueError, np.dtype,
                 {'formats': ['i4', 'i4'], 'f0': ('i4', 0), 'f1':('i4', 4)})
 
+    def test_fieldless_views(self):
+        a = np.zeros(2, dtype={'names':[], 'formats':[], 'offsets':[], 
+                               'itemsize':8})
+        assert_raises(ValueError, a.view, np.dtype([]))
+
+        d = np.dtype((np.dtype([]), 10))
+        assert_equal(d.shape, (10,))
+        assert_equal(d.itemsize, 0)
+        assert_equal(d.base, np.dtype([]))
+
+        arr = np.fromiter((() for i in range(10)), [])
+        assert_equal(arr.dtype, np.dtype([]))
+        assert_raises(ValueError, np.frombuffer, b'', dtype=[])
+        assert_equal(np.frombuffer(b'', dtype=[], count=2),
+                     np.empty(2, dtype=[]))
+
+        assert_raises(ValueError, np.dtype, ([], 'f8'))
+        assert_raises(ValueError, np.zeros(1, dtype='i4').view, [])
+
+        assert_equal(np.zeros(2, dtype=[]) == np.zeros(2, dtype=[]),
+                     np.ones(2, dtype=bool))
+
+        assert_equal(np.zeros((1, 2), dtype=[]) == a,
+                     np.ones((1, 2), dtype=bool))
+
 
 class TestSubarray(object):
     def test_single_subarray(self):
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_e39f7732a671' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.8-dbg setup.py build_ext -i --force
}

run_project_tests() {
    python3.8-dbg -m pytest -vv \
        'numpy/core/tests/test_dtype.py::TestRecord::test_partial_dict' \
        'numpy/core/tests/test_dtype.py::TestSubarray::test_single_subarray' \
        'numpy/core/tests/test_dtype.py::TestRecord::test_fieldless_views'
}
EOF_e39f7732a671
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
