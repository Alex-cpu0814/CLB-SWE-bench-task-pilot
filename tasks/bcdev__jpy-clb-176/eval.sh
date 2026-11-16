#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "20cdbb714300bdb2502d9ac44740c85c64cce691" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/src/test/python/jpy_array_test.py b/src/test/python/jpy_array_test.py
index 85f159e..431011e 100644
--- a/src/test/python/jpy_array_test.py
+++ b/src/test/python/jpy_array_test.py
@@ -98,6 +98,16 @@ class TestJavaArrays(unittest.TestCase):
         self.do_test_array_protocol('java.lang.Object', [None, None, None], [File('A'), 'B', 3])
 
 
+    # see https://github.com/bcdev/jpy/issues/52
+    def test_array_item_del(self):
+        Integer = jpy.get_type('java.lang.Integer')
+        a = jpy.array(Integer, 3)
+        try:
+            del a[1]
+        except RuntimeError as err:
+            self.assertEqual(err.args[0], 'cannot delete items of Java arrays')
+
+
     def do_test_basic_buffer_protocol(self, type, itemsize, values):
 
         a = jpy.array(type, 4)
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
