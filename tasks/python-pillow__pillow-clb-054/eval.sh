#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "c683f048eb117c572b8b4eee47a324aca165fea1" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Tests/test_image_filter.py b/Tests/test_image_filter.py
index cfe46b6..a2ef228 100644
--- a/Tests/test_image_filter.py
+++ b/Tests/test_image_filter.py
@@ -24,6 +24,7 @@ from .helper import assert_image_equal, hopper
         ImageFilter.ModeFilter,
         ImageFilter.GaussianBlur,
         ImageFilter.GaussianBlur(5),
+        ImageFilter.BoxBlur(0),
         ImageFilter.BoxBlur(5),
         ImageFilter.UnsharpMask,
         ImageFilter.UnsharpMask(10),
@@ -173,3 +174,14 @@ def test_consistency_5x5(mode):
                 Image.merge(mode, source[: len(mode)]).filter(kernel),
                 Image.merge(mode, reference[: len(mode)]),
             )
+
+
+def test_invalid_box_blur_filter():
+    with pytest.raises(ValueError):
+        ImageFilter.BoxBlur(-2)
+
+    im = hopper()
+    box_blur_filter = ImageFilter.BoxBlur(2)
+    box_blur_filter.radius = -2
+    with pytest.raises(ValueError):
+        im.filter(box_blur_filter)
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
