#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "76b6f57a27f31cdefc23444f91611a00c9b4332d" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/fast_histogram/tests/test_histogram.py b/fast_histogram/tests/test_histogram.py
index 2215f02..0771e6a 100644
--- a/fast_histogram/tests/test_histogram.py
+++ b/fast_histogram/tests/test_histogram.py
@@ -85,3 +85,21 @@ def test_2d_compare_with_numpy(size, nx, xmin, xmax, ny, ymin, ymax, weights):
                        range=((xmin, xmax), (ymin, ymax)))
 
     np.testing.assert_equal(fast, reference)
+
+
+def test_nd_arrays():
+
+    x = np.random.random(1000)
+
+    result_1d = histogram1d(x, bins=10, range=(0, 1))
+    result_3d = histogram1d(x.reshape((10, 10, 10)), bins=10, range=(0, 1))
+
+    np.testing.assert_equal(result_1d, result_3d)
+
+    y = np.random.random(1000)
+
+    result_1d = histogram2d(x, y, bins=(10, 10), range=[(0, 1), (0, 1)])
+    result_3d = histogram2d(x.reshape((10, 10, 10)), y.reshape((10, 10, 10)),
+                            bins=(10, 10), range=[(0, 1), (0, 1)])
+
+    np.testing.assert_equal(result_1d, result_3d)
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_1cfe82b34801' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext --inplace --force
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -vv -p no:warnings --hypothesis-show-statistics \
        'fast_histogram/tests/test_histogram.py::test_1d_compare_with_numpy' \
        'fast_histogram/tests/test_histogram.py::test_2d_compare_with_numpy' \
        'fast_histogram/tests/test_histogram.py::test_nd_arrays'
}
EOF_1cfe82b34801
cat > /benchmark/format_test_log.py <<'EOF_aea07e469297' || fail 'Cannot write /benchmark/format_test_log.py'
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
    r"^(?P<test_id>fast_histogram/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[.*\])?$"
)

def parse_test_log(text):
    # Official wrapper owns terminal statuses after checking true child results.
    # Human-readable bundled-unittest output is retained but is not a second ID.
    statuses = {}
    for line in text.splitlines():
        match = PYTEST_LINE.match(line)
        if match and match.end() == len(line):
            statuses[match.group("test_id")] = match.group("status")
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_aea07e469297
cat > /benchmark/pytest_no_dump.py <<'EOF_df4aa13b0e5b' || fail 'Cannot write /benchmark/pytest_no_dump.py'
"""Run official pytest nodes without producing host-side Linux/WSL core dumps."""
import ctypes
import resource
import sys

import pytest

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError("Could not disable process dumpability")
sys.exit(pytest.main(sys.argv[1:]))
EOF_df4aa13b0e5b
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
