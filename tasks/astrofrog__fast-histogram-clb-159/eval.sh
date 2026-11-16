#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "085efdad6570e25440beab781ef70e1f81605c12" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
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
