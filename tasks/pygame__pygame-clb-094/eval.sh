#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "2d7786bc2453561a696281299104f95814e676b3" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/surface_test.py b/test/surface_test.py
index a0fa54d11..1224ced53 100644
--- a/test/surface_test.py
+++ b/test/surface_test.py
@@ -1527,6 +1527,42 @@ class SurfaceBlendTest (unittest.TestCase):
                                      (dst.get_at((x, y)), tst.get_at((x, y)),
                                       x, y))
 
+
+
+
+    def test_blit_blend_big_rect(self):
+        """ test that an oversized rect works ok.
+        """
+        color = (1, 2, 3, 255)
+        area = (1, 1, 30, 30)
+        s1 = pygame.Surface((4, 4), 0, 32)
+        r = s1.fill(special_flags=pygame.BLEND_ADD, color=color, rect=area)
+        self.assertEquals(pygame.Rect((1, 1, 3, 3)), r)
+        self.assert_(s1.get_at((0, 0)) == (0, 0, 0, 255))
+        self.assert_(s1.get_at((1, 1)) == color)
+
+
+        black = pygame.Color("black")
+        red = pygame.Color("red")
+        self.assertNotEqual(black, red)
+
+        surf = pygame.Surface((10, 10), 0, 32)
+        surf.fill(black)
+        subsurf = surf.subsurface(pygame.Rect(0, 1, 10, 8))
+        self.assertEqual(surf.get_at((0, 0)), black)
+        self.assertEqual(surf.get_at((0, 9)), black)
+
+        subsurf.fill(red, (0, -1, 10, 1), pygame.BLEND_RGB_ADD)
+        self.assertEqual(surf.get_at((0, 0)), black)
+        self.assertEqual(surf.get_at((0, 9)), black)
+
+        subsurf.fill(red, (0, 8, 10, 1), pygame.BLEND_RGB_ADD)
+        self.assertEqual(surf.get_at((0, 0)), black)
+        self.assertEqual(surf.get_at((0, 9)), black)
+
+
+
+
     def test_GET_PIXELVALS(self):
         # surface.h GET_PIXELVALS bug regarding whether of not
         # a surface has per-pixel alpha. Looking at the Amask
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
