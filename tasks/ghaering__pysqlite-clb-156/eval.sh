#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "d7c44a6b62ccf27ae2a006d32dc25cd49ca45320" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/lib/test/hooks.py b/lib/test/hooks.py
index e7cd49d..60adb5b 100644
--- a/lib/test/hooks.py
+++ b/lib/test/hooks.py
@@ -152,10 +152,31 @@ class ProgressTests(unittest.TestCase):
         con.execute("select 1 union select 2 union select 3").fetchall()
         self.assertEqual(action, 0, "progress handler was not cleared")
 
+class LimitTests(unittest.TestCase):
+    def CheckGetLimit(self):
+        """
+        Test that the get limit method return something useful.
+        """
+        con = sqlite.connect(":memory:")
+        val = con.get_limit(sqlite.SQLITE_LIMIT_VARIABLE_NUMBER)
+        self.assertTrue(val > 0)
+
+    def CheckSetLimit(self):
+        """
+        Test that the set limit method actally changes limits.
+        """
+        con = sqlite.connect(":memory:")
+        oldval = con.get_limit(sqlite.SQLITE_LIMIT_VARIABLE_NUMBER)
+        con.set_limit(sqlite.SQLITE_LIMIT_VARIABLE_NUMBER, oldval - 1)
+        newval = con.get_limit(sqlite.SQLITE_LIMIT_VARIABLE_NUMBER)
+
+        self.assertEqual(newval, oldval - 1)
+
 def suite():
     collation_suite = unittest.makeSuite(CollationTests, "Check")
     progress_suite = unittest.makeSuite(ProgressTests, "Check")
-    return unittest.TestSuite((collation_suite, progress_suite))
+    limit_suite = unittest.makeSuite(LimitTests, "Check")
+    return unittest.TestSuite((collation_suite, progress_suite, limit_suite))
 
 def test():
     runner = unittest.TextTestRunner()
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
