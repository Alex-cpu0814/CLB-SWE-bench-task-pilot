#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "b65b21c397381351965bf3f590054d2bccdd03d2" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_multiarray.py b/numpy/core/tests/test_multiarray.py
index 50a0205..ccfbe35 100644
--- a/numpy/core/tests/test_multiarray.py
+++ b/numpy/core/tests/test_multiarray.py
@@ -946,6 +946,26 @@ class TestSummarization(TestCase):
         assert repr(A) == reprA
 
 
+class TestChoose(TestCase):
+    def setUp(self):
+        self.x = 2*ones((3,),dtype=int)
+        self.y = 3*ones((3,),dtype=int)
+        self.x2 = 2*ones((2,3), dtype=int)
+        self.y2 = 3*ones((2,3), dtype=int)        
+        self.ind = [0,0,1]
+
+    def test_basic(self):
+        A = np.choose(self.ind, (self.x, self.y))
+        assert_equal(A, [2,2,3])
+
+    def test_broadcast1(self):
+        A = np.choose(self.ind, (self.x2, self.y2))
+        assert_equal(A, [[2,2,3],[2,2,3]])
+    
+    def test_broadcast2(self):
+        A = np.choose(self.ind, (self.x, self.y2))
+        assert_equal(A, [[2,2,3],[2,2,3]])
+        
 
 if __name__ == "__main__":
     run_module_suite()
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
