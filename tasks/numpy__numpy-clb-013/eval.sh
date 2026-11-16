#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "663b161074580a340201da1765e3618c086ff8dc" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/lib/tests/test_index_tricks.py b/numpy/lib/tests/test_index_tricks.py
index a5cdda0..dbe445c 100644
--- a/numpy/lib/tests/test_index_tricks.py
+++ b/numpy/lib/tests/test_index_tricks.py
@@ -175,6 +175,24 @@ class TestRavelUnravelIndex(object):
         assert_raises_regex(
             ValueError, "out of bounds", np.unravel_index, [1], ())
 
+    @pytest.mark.parametrize("mode", ["clip", "wrap", "raise"])
+    def test_empty_array_ravel(self, mode):
+        res = np.ravel_multi_index(
+                    np.zeros((3, 0), dtype=np.intp), (2, 1, 0), mode=mode)
+        assert(res.shape == (0,))
+
+        with assert_raises(ValueError):
+            np.ravel_multi_index(
+                    np.zeros((3, 1), dtype=np.intp), (2, 1, 0), mode=mode)
+
+    def test_empty_array_unravel(self):
+        res = np.unravel_index(np.zeros(0, dtype=np.intp), (2, 1, 0))
+        # res is a tuple of three empty arrays
+        assert(len(res) == 3)
+        assert(all(a.shape == (0,) for a in res))
+
+        with assert_raises(ValueError):
+            np.unravel_index([1], (2, 1, 0))
 
 class TestGrid(object):
     def test_basic(self):
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
