#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "eeea4de31f9c8f4496f5695ee0258040b401f0b4" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/test_api.py b/tests/test_api.py
index 20bb058..bc9ca03 100644
--- a/tests/test_api.py
+++ b/tests/test_api.py
@@ -61,6 +61,16 @@ def test_matrix():
     m.scale(1.5, 2.5)
     m.translate(10, 20)
 
+    with pytest.raises(TypeError):
+        m * 42
+
+    with pytest.raises(TypeError):
+        m + 42
+
+    assert m != 42
+    assert m == m
+    assert m != cairo.Matrix()
+
 
 def test_path():
     # AttributeError: 'module' object has no attribute 'Path'
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
