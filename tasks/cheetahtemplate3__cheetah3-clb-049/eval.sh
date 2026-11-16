#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "c86628cad04edc5167f9a9c8999abc62c6558e7b" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Cheetah/Tests/SyntaxAndOutput.py b/Cheetah/Tests/SyntaxAndOutput.py
index c6fa39d..a2ee63c 100755
--- a/Cheetah/Tests/SyntaxAndOutput.py
+++ b/Cheetah/Tests/SyntaxAndOutput.py
@@ -3049,6 +3049,12 @@ class GetVar(OutputTest):               # Template.getVar()
         self.verify("$getVar('$bogus',  1234)",
                     "1234")
 
+    def test6(self):
+        """$getVar('$') raises ValueError
+        """
+        with self.assertRaises(ValueError):
+            self.verify("$getVar('$')", "never get here")
+
 
 class MiscComplexSyntax(OutputTest):
     def test1(self):
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
