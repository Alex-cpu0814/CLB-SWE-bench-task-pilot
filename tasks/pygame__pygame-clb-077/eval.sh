#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "c09d677a6c1c2e814683576035f13c6a07d64f67" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/draw_test.py b/test/draw_test.py
index 8ad7d0d18..b80884495 100644
--- a/test/draw_test.py
+++ b/test/draw_test.py
@@ -4950,6 +4950,34 @@ class DrawRectMixin(object):
 
             self.assertNotEqual(color_at_pt, self.color)
 
+    def test_rect__draw_line_width(self):
+        surface = pygame.Surface((100, 100))
+        color = pygame.Color(255, 255, 255)
+        rect_width = 80
+        rect_height = 50
+        line_width = 10
+        pygame.draw.rect(
+            surface, color, pygame.Rect(0, 0, rect_width, rect_height), line_width
+        )
+        for i in range(line_width):
+            self.assertEqual(surface.get_at((i, i)), color)
+            self.assertEqual(surface.get_at((rect_width - i - 1, i)), color)
+            self.assertEqual(surface.get_at((i, rect_height - i - 1)), color)
+            self.assertEqual(
+                surface.get_at((rect_width - i - 1, rect_height - i - 1)), color
+            )
+        self.assertEqual(surface.get_at((line_width, line_width)), (0, 0, 0))
+        self.assertEqual(
+            surface.get_at((rect_width - line_width - 1, line_width)), (0, 0, 0)
+        )
+        self.assertEqual(
+            surface.get_at((line_width, rect_height - line_width - 1)), (0, 0, 0)
+        )
+        self.assertEqual(
+            surface.get_at((rect_width - line_width - 1, rect_height - line_width - 1)),
+            (0, 0, 0),
+        )
+
     def test_rect__bounding_rect(self):
         """Ensures draw rect returns the correct bounding rect.
 
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
