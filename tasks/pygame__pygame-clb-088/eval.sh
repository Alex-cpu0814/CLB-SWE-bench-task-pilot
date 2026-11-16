#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "cd173f0ebf77e2b652de1a20a5f3eccf78e8cf12" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/surface_test.py b/test/surface_test.py
index 19f30d83f..4bf24c907 100644
--- a/test/surface_test.py
+++ b/test/surface_test.py
@@ -165,6 +165,15 @@ class SurfaceTypeTest(unittest.TestCase):
         self.assertEqual(bound_rect.width, 31)
         self.assertEqual(bound_rect.height, 31)
 
+        # Issue #180
+        pygame.display.init()
+        try:
+            surf = pygame.Surface((4, 1), 0, 8)
+            surf.fill((255, 255, 255))
+            surf.get_bounding_rect()  # Segfault.
+        finally:
+            pygame.quit()
+
     def test_copy(self):
 
         # __doc__ (as of 2008-06-25) for pygame.surface.Surface.copy:
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
