#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "7e58cea7c2551d0b590eff3959341ee823ec43c1" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/src/test/python/jpy_overload_test.py b/src/test/python/jpy_overload_test.py
index 5df06e9..84d5569 100644
--- a/src/test/python/jpy_overload_test.py
+++ b/src/test/python/jpy_overload_test.py
@@ -99,9 +99,10 @@ class TestStaticMethodOverloads(unittest.TestCase):
         String = jpy.get_type('java.lang.String')
         Arrays = jpy.get_type('java.util.Arrays')
         a = jpy.array(String, ['A', 'B', 'C'])
+        #jpy.diag.flags = jpy.diag.F_METH
         s = Arrays.toString(a)
-        print("Arrays.toString: " + str(type(Arrays.toString)))
-        self.assertEqual(str(s), '[A,B,C]')
+        #jpy.diag.flags = 0
+        self.assertEqual(str(s), '[A, B, C]')
 
 
 
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
