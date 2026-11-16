#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "76b6f57a27f31cdefc23444f91611a00c9b4332d" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
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
