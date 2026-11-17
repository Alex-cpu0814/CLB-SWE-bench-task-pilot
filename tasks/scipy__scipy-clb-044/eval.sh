#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "fc6b387bc0c51b5b252712584580b4f0975498fb" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/ndimage/tests/test_ndimage.py b/scipy/ndimage/tests/test_ndimage.py
index bfe9161d..9c505ae7 100644
--- a/scipy/ndimage/tests/test_ndimage.py
+++ b/scipy/ndimage/tests/test_ndimage.py
@@ -32,11 +32,12 @@ from __future__ import division, print_function, absolute_import
 
 import warnings
 import math
+import sys
 
 import numpy
 from numpy import fft
 from numpy.testing import (assert_, assert_equal, assert_array_equal,
-        run_module_suite, assert_array_almost_equal, assert_almost_equal)
+        run_module_suite, assert_array_almost_equal, assert_almost_equal, dec)
 import scipy.ndimage as ndimage
 
 
@@ -1705,6 +1706,16 @@ class TestNdimage:
         assert_array_almost_equal(out, [[0, 0], [0, 4], [0, 7]])
         assert_array_almost_equal(out, ndimage.shift(data[:,::2], (1, 1)))
 
+    # do not run on 32 bit or windows (no sparse memory)
+    @dec.skipif('win32' in sys.platform or numpy.intp(0).itemsize < 8)
+    def test_map_coordinates_large_data(self):
+        # check crash on large data
+        n = 30000
+        a = numpy.empty(n**2, dtype=numpy.float32).reshape(n, n)
+        # fill the part we might read
+        a[n - 3:,n - 3:] = 0
+        ndimage.map_coordinates(a, [[n - 1.5], [n - 1.5]], order=1)
+
     def test_affine_transform01(self):
         data = numpy.array([1])
         for order in range(0, 6):
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_6ee3f8b7e8a1' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.6 setup.py build_ext -i
}

run_project_tests() {
    python3.6 -m pytest -c /dev/null -vv \
        'scipy/ndimage/tests/test_ndimage.py::TestNdimage::test_map_coordinates01' \
        'scipy/ndimage/tests/test_ndimage.py::TestNdimage::test_map_coordinates02' \
        'scipy/ndimage/tests/test_ndimage.py::TestNdimage::test_map_coordinates_large_data'
}
EOF_6ee3f8b7e8a1
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
