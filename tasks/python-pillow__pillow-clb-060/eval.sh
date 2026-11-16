#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "d0612030a0ba7aed533e1f9115bbf4bd1019f48e" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Tests/test_image.py b/Tests/test_image.py
index 3fa071b..30d093e 100644
--- a/Tests/test_image.py
+++ b/Tests/test_image.py
@@ -524,7 +524,7 @@ class TestImage:
 
         # Arrange
         target_file = "Tests/images/linear_gradient.png"
-        for mode in ["L", "P"]:
+        for mode in ["L", "P", "I", "F"]:
 
             # Act
             im = Image.linear_gradient(mode)
@@ -550,7 +550,7 @@ class TestImage:
 
         # Arrange
         target_file = "Tests/images/radial_gradient.png"
-        for mode in ["L", "P"]:
+        for mode in ["L", "P", "I", "F"]:
 
             # Act
             im = Image.radial_gradient(mode)
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
