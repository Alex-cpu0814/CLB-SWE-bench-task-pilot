#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "0fd5f2506bf2f41b023392c945312e5a1a3eb819" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/lib/tests/test_index_tricks.py b/numpy/lib/tests/test_index_tricks.py
index 3246f68..028bba3 100644
--- a/numpy/lib/tests/test_index_tricks.py
+++ b/numpy/lib/tests/test_index_tricks.py
@@ -77,6 +77,26 @@ class TestRavelUnravelIndex(object):
             [[3, 6, 6], [4, 5, 1]])
         assert_equal(np.unravel_index(1621, (6, 7, 8, 9)), [3, 1, 4, 1])
 
+    def test_empty_indices(self):
+        msg1 = 'indices must be integral: the provided empty sequence was'
+        msg2 = 'only int indices permitted'
+        assert_raises_regex(TypeError, msg1, np.unravel_index, [], (10, 3, 5))
+        assert_raises_regex(TypeError, msg1, np.unravel_index, (), (10, 3, 5))
+        assert_raises_regex(TypeError, msg2, np.unravel_index, np.array([]),
+                            (10, 3, 5))
+        assert_equal(np.unravel_index(np.array([],dtype=int), (10, 3, 5)),
+                     [[], [], []])
+        assert_raises_regex(TypeError, msg1, np.ravel_multi_index, ([], []),
+                            (10, 3))
+        assert_raises_regex(TypeError, msg1, np.ravel_multi_index, ([], ['abc']),
+                            (10, 3))
+        assert_raises_regex(TypeError, msg2, np.ravel_multi_index,
+                    (np.array([]), np.array([])), (5, 3))
+        assert_equal(np.ravel_multi_index(
+                (np.array([], dtype=int), np.array([], dtype=int)), (5, 3)), [])
+        assert_equal(np.ravel_multi_index(np.array([[], []], dtype=int),
+                     (5, 3)), [])
+
     def test_big_indices(self):
         # ravel_multi_index for big indices (issue #7546)
         if np.intp == np.int64:
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
