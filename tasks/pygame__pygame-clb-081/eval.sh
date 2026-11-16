#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "71c90cdb76cd8b12a0969f5d6314315bd0223c28" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/freetype_test.py b/test/freetype_test.py
index e0b8803ff..34dc48726 100644
--- a/test/freetype_test.py
+++ b/test/freetype_test.py
@@ -126,7 +126,7 @@ class FreeTypeFontTest(unittest.TestCase):
         self.assertRaises(OverflowError, ft.Font, file=None, size=-1)
 
         f = ft.Font(None, size=24)
-        self.assert_(f.height > 0)
+        self.assertTrue(f.height > 0)
         self.assertRaises(IOError, f.__init__,
                           os.path.join(FONTDIR, 'nonexistant.ttf'))
 
@@ -1423,6 +1423,26 @@ class FreeTypeFontTest(unittest.TestCase):
         self.assertRaises(pygame.error, f.render_to,
                           null_surface, (0, 0), "Crash!", size=12)
 
+    def test_issue_565(self):
+        """get_metrics supporting rotation/styles/size"""
+
+        tests = [
+            {'method': 'size', 'value': 36, 'msg': 'metrics same for size'},
+            {'method': 'rotation', 'value': 90, 'msg': 'metrics same for rotation'},
+            {'method': 'oblique', 'value': True, 'msg': 'metrics same for oblique'}
+        ]
+        text = "|"
+
+        def run_test(method, value, msg):
+            font = ft.Font(self._sans_path, size=24)
+            before = font.get_metrics(text)
+            font.__setattr__(method, value)
+            after = font.get_metrics(text)
+            self.assertNotEqual(before, after, msg)
+
+        for test in tests:
+            run_test(*test.values())
+
 
 class FreeTypeTest(unittest.TestCase):
 
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
