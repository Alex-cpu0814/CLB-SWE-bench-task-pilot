#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "965ea2ff417bcb285beca5c36cd02a8790a3d8f6" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
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
