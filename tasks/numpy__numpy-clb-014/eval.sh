#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "495d352bf325f44d78001f059d625123e49f027e" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
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
