#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "fc2518ba6b11fc52b0ff477b9e83576be90562d8" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_multiarray.py b/numpy/core/tests/test_multiarray.py
index 2edcc68..86a8cff 100644
--- a/numpy/core/tests/test_multiarray.py
+++ b/numpy/core/tests/test_multiarray.py
@@ -845,6 +845,13 @@ class TestCreation:
         assert_raises(ValueError, np.zeros, shape, dtype=np.int8)
         assert_raises(ValueError, np.ones, shape, dtype=np.int8)
 
+    @pytest.mark.skipif(np.dtype(np.intp).itemsize != 8,
+                        reason="malloc may not fail on 32 bit systems")
+    def test_malloc_fails(self):
+        # This test is guaranteed to fail due to a too large allocation
+        with assert_raises(np.core._exceptions._ArrayMemoryError):
+            np.empty(np.iinfo(np.intp).max, dtype=np.uint8)
+
     def test_zeros(self):
         types = np.typecodes['AllInteger'] + np.typecodes['AllFloat']
         for dt in types:
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
