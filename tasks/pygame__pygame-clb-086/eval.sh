#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "5f1d4528b46d7f3c368db6e1c395ffb0ae83623d" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/draw_test.py b/test/draw_test.py
index a08d3c551..e38fda05a 100644
--- a/test/draw_test.py
+++ b/test/draw_test.py
@@ -466,7 +466,6 @@ class DrawPolygonTest(unittest.TestCase):
             for y in range(10):
                 if (x in range(2, 5) and y <7) or (y in range(2, 5) and x < 7):
                     # we are on the border of the cross:
-                    # FIXME currently the test fails here for (0, 4), (1, 4), (5, 4) and (6, 4)
                     self.assertEqual(self.surface.get_at((x, y)), GREEN, msg=str((x, y)))
                 else:
                     # we are outside
@@ -510,7 +509,6 @@ class DrawPolygonTest(unittest.TestCase):
         pygame.draw.rect(self.surface, RED, (0, 0, 20, 20), 0)
         pygame.draw.polygon(self.surface, GREEN, path_data, 0)
         for x in range(4, rect.width-5 +1):
-            # FIXME known to fail
             self.assertEqual(self.surface.get_at((x, 4)), GREEN)  # upper inner
 
 
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
