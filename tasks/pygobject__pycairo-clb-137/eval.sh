#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "9ebff889d4c68927ab1c152b6ae7c8327283b6ed" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/test_surface.py b/tests/test_surface.py
index d5287c2..7938e4d 100644
--- a/tests/test_surface.py
+++ b/tests/test_surface.py
@@ -69,6 +69,10 @@ def test_surface_set_device_scale():
     ret = surface.set_device_scale(5.0, 3.0)
     assert ret is None
 
+    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 100, 100)
+    with pytest.raises(cairo.Error):
+        surface.set_device_scale(1, 0)
+
 
 @pytest.mark.skipif(not cairo.HAS_PNG_FUNCTIONS, reason="not png support")
 def test_image_surface_create_for_data_array():
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
