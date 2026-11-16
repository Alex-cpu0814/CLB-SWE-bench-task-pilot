#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "b780969870a9dd8b42b88c8317679e125b5e2aae" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/test_surface.py b/tests/test_surface.py
index 7f69f96..1d222b7 100644
--- a/tests/test_surface.py
+++ b/tests/test_surface.py
@@ -242,6 +242,15 @@ def test_script_surface():
     assert b"paint" in f.getvalue()
 
 
+def test_script_device_device_ref():
+    f = io.BytesIO()
+    dev = cairo.ScriptDevice(f)
+    surface = cairo.ScriptSurface(dev, cairo.Content.COLOR_ALPHA, 42, 10)
+    del dev
+    for i in range(10):
+        surface.get_device()
+
+
 def test_script_surface_create_for_target():
     # paint the script proxy
     f = io.BytesIO()
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
