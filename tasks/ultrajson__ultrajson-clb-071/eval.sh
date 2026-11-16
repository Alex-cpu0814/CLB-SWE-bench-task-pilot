#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "f26f9679f1b9d7fa2d0488e1e7b1256d9391a85f" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/test_ujson.py b/tests/test_ujson.py
index b11e5d2..9d37b47 100644
--- a/tests/test_ujson.py
+++ b/tests/test_ujson.py
@@ -249,11 +249,21 @@ def test_encode_to_utf8():
     assert dec == json.loads(enc)
 
 
-def test_encode_indent():
-    test_input = '{\n    "obj": 31337\n}'
+@pytest.mark.parametrize(
+    "test_input",
+    [
+        '{\n    "obj": 31337\n}',
+        "{}",
+        "[]",
+        '{\n    "a": {}\n}',
+        "[\n    []\n]",
+    ],
+)
+def test_encode_indent(test_input):
     obj = ujson.decode(test_input)
     output = ujson.encode(obj, indent=4)
     assert test_input == output
+    assert output == json.dumps(obj, indent=4)
 
 
 def test_decode_from_unicode():
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
