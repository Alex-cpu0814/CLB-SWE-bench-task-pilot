#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "e26f569b1f3e28d935327b7dfc4cb10e722a9d09" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/freetype_test.py b/test/freetype_test.py
index d885ed68f..2648ce66b 100644
--- a/test/freetype_test.py
+++ b/test/freetype_test.py
@@ -1311,7 +1311,7 @@ class FreeTypeFontTest(unittest.TestCase):
         prev_style = font.underline
         font.underline = True
         try:
-            rect = font.get_rect('  ', size=64)
+            rect = font.get_rect(' ', size=64)
             surf, rrect = font.render(None, size=64)
             self.assertEqual(rect, rrect)
         finally:
@@ -1340,6 +1340,18 @@ class FreeTypeFontTest(unittest.TestCase):
             font.underline_adjustment = adj
             s, r = font.render("Amazon", size=19)
 
+    def test_issue_243(self):
+        """Issue Y: trailing space ignored in boundary calculation"""
+
+        # Issue #243: For a string with trailing spaces, freetype ignores the
+        # last space in boundary calculations
+        #
+        font = self._TEST_FONTS['fixed']
+        r1 = font.get_rect(" ", size=64)
+        self.assertTrue(r1.width > 1)
+        r2 = font.get_rect("  ", size=64)
+        self.assertEqual(r2.width, 2 * r1.width)
+
     def test_garbage_collection(self):
         """Check reference counting on returned new references"""
         def ref_items(seq):
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
