#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "085efdad6570e25440beab781ef70e1f81605c12" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/fast_histogram/tests/test_histogram.py b/fast_histogram/tests/test_histogram.py
index f4c86a6..198f49b 100644
--- a/fast_histogram/tests/test_histogram.py
+++ b/fast_histogram/tests/test_histogram.py
@@ -201,3 +201,32 @@ def test_array_bins():
         histogram2d([1, 2, 3], [1, 2 ,3], bins=[edges, edges],
                     range=[(0, 10), (0, 10)])
     assert exc.value.args[0] == 'bins should be an iterable of two integers'
+
+
+def test_mixed_strides():
+
+    # Make sure all functions work properly when passed arrays with mismatched
+    # strides.
+
+    x = np.random.random((30, 20, 40, 50))[:, 10, :, 20]
+    y = np.random.random((30, 40, 50))[:, :, 10]
+    z = np.random.random((30, 10, 5, 80, 90))[:, 5, 2, ::2, 22]
+
+    assert x.shape == y.shape and x.shape == z.shape
+    assert x.strides != y.strides and y.strides != z.strides and z.strides != x.strides
+
+    result_1 = histogram1d(x, bins=10, range=(0, 1))
+    result_2, _ = np.histogram(x, bins=10, range=(0, 1))
+    np.testing.assert_equal(result_1, result_2)
+
+    result_3 = histogram1d(x, weights=y, bins=10, range=(0, 1))
+    result_4, _ = np.histogram(x, weights=y, bins=10, range=(0, 1))
+    np.testing.assert_equal(result_3, result_4)
+
+    result_5 = histogram2d(x, y, bins=(10, 10), range=[(0, 1), (0, 1)])
+    result_6, _, _ = np.histogram2d(x.ravel(), y.ravel(), bins=(10, 10), range=[(0, 1), (0, 1)])
+    np.testing.assert_equal(result_5, result_6)
+
+    result_7 = histogram2d(x, y, weights=z, bins=(10, 10), range=[(0, 1), (0, 1)])
+    result_8, _, _ = np.histogram2d(x.ravel(), y.ravel(), weights=z.ravel(), bins=(10, 10), range=[(0, 1), (0, 1)])
+    np.testing.assert_equal(result_7, result_8)
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_bbaedde3d317' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext --inplace --force
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -vv \
        'fast_histogram/tests/test_histogram.py::test_nd_arrays' \
        'fast_histogram/tests/test_histogram.py::test_list' \
        'fast_histogram/tests/test_histogram.py::test_non_contiguous' \
        'fast_histogram/tests/test_histogram.py::test_mixed_strides'
}
EOF_bbaedde3d317
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
