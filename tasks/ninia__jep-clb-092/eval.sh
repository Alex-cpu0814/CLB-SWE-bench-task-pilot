#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "d14567567ac1281e978790b9170c981113de282f" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/src/jep/test/TestCompiledScript.java b/src/jep/test/TestCompiledScript.java
new file mode 100644
index 0000000..6f297f8
--- /dev/null
+++ b/src/jep/test/TestCompiledScript.java
@@ -0,0 +1,34 @@
+package jep.test;
+
+import java.lang.IllegalStateException;
+import java.lang.Boolean;
+
+import jep.Jep;
+import jep.JepConfig;
+import jep.JepException;
+
+/**
+ * Tests that a compiled script can be loaded by Jep.runscript()
+ * 
+ * Created: May 2017
+ * 
+ * @author Ben Steffensmeier
+ */
+public class TestCompiledScript {
+
+    public static void main(String[] args) throws JepException{
+        JepConfig config = new JepConfig();
+        config.addIncludePaths(".");
+        Jep jep = new Jep(config);
+        jep.eval("import py_compile");
+        jep.eval("py_compile.compile(file='build/testScript.py', cfile='build/testScript.pyc')");
+        jep.eval(null);
+        jep.runScript("build/testScript.pyc");
+        Object result = jep.getValue("isGood()");
+        jep.close();
+        if(!Boolean.TRUE.equals(result)){
+            throw new IllegalStateException("isGood() returned " + result);
+        }
+    }
+
+}
diff --git a/tests/test_run_script.py b/tests/test_run_script.py
new file mode 100644
index 0000000..d406d60
--- /dev/null
+++ b/tests/test_run_script.py
@@ -0,0 +1,26 @@
+import unittest
+import os
+import os.path
+
+from tests.jep_pipe import jep_pipe
+from tests.jep_pipe import build_java_process_cmd
+
+
+class TestRunScript(unittest.TestCase):
+
+    def setUp(self):
+        with open('build/testScript.py', 'w') as testScript:
+            testScript.write("def isGood():\n")
+            testScript.write("    return True\n")
+        
+
+    def test_compiledScript(self):
+        jep_pipe(build_java_process_cmd('jep.test.TestCompiledScript'))
+
+
+    def tearDown(self):
+        if os.path.exists('build/testScript.py'):
+            os.remove('build/testScript.py')
+        if os.path.exists('build/testScript.pyc'):
+            os.remove('build/testScript.pyc')
+
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
