#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "9c589d1cb5dc81552aa8ee72694cb830bed099c6" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/test_ujson.py b/tests/test_ujson.py
index 9123254..0c2f4cd 100644
--- a/tests/test_ujson.py
+++ b/tests/test_ujson.py
@@ -249,6 +249,13 @@ def test_encode_to_utf8():
     assert dec == json.loads(enc)
 
 
+def test_encode_indent():
+    test_input = '{\n    "obj": 31337\n}'
+    obj = ujson.decode(test_input)
+    output = ujson.encode(obj, indent=4)
+    assert test_input == output
+
+
 def test_decode_from_unicode():
     test_input = '{"obj": 31337}'
     dec1 = ujson.decode(test_input)
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
