#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "6798c87caf25cedf0cef19245e7db1656aed8602" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Tests/test_image.py b/Tests/test_image.py
index c4e6f8a..2d661a9 100644
--- a/Tests/test_image.py
+++ b/Tests/test_image.py
@@ -149,10 +149,11 @@ class TestImage:
             assert im.mode == "RGB"
             assert im.size == (128, 128)
 
-            temp_file = str(tmp_path / "temp.jpg")
-            if os.path.exists(temp_file):
-                os.remove(temp_file)
-            im.save(Path(temp_file))
+            for ext in (".jpg", ".jp2"):
+                temp_file = str(tmp_path / ("temp." + ext))
+                if os.path.exists(temp_file):
+                    os.remove(temp_file)
+                im.save(Path(temp_file))
 
     def test_fp_name(self, tmp_path):
         temp_file = str(tmp_path / "temp.jpg")
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
