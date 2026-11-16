#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "bc2edaf0242736c2a2940104eebc6aed5a3ad9e6" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/src/jep/test/TestNoneDictionary.java b/src/jep/test/TestNoneDictionary.java
new file mode 100644
index 0000000..b4db6e1
--- /dev/null
+++ b/src/jep/test/TestNoneDictionary.java
@@ -0,0 +1,37 @@
+package jep.test;
+
+import java.util.Map;
+
+import jep.Jep;
+
+/**
+ * Regression test for Issue #40: Python None keys and values must survive
+ * conversion to a Java Map as Java null references.
+ */
+public class TestNoneDictionary {
+
+    public static void test() throws Exception {
+        Jep jep = null;
+        try {
+            jep = new Jep(false, ".");
+            jep.eval("x = {'value_none': None, None: 'key_none'}");
+            Map<?, ?> result = (Map<?, ?>) jep.getValue("x");
+            if (result == null) {
+                throw new AssertionError("dictionary converted to null");
+            }
+            if (result.size() != 2) {
+                throw new AssertionError("expected 2 entries, got " + result.size());
+            }
+            if (result.get("value_none") != null) {
+                throw new AssertionError("None value was not converted to Java null");
+            }
+            if (!"key_none".equals(result.get(null))) {
+                throw new AssertionError("None key was not converted to Java null");
+            }
+        } finally {
+            if (jep != null) {
+                jep.close();
+            }
+        }
+    }
+}
diff --git a/runtests.py b/runtests.py
index 2ac7d77..0e1a0a2 100644
--- a/runtests.py
+++ b/runtests.py
@@ -9,5 +9,5 @@ sys.path.insert(0, '')
 
 if __name__ == '__main__':
     try:
-        unittest.main(module='tests')
+        unittest.main(module='tests', verbosity=2)
     except SystemExit:
         pass
diff --git a/tests/__init__.py b/tests/__init__.py
index 8fd4d2b..0b1c9e2 100644
--- a/tests/__init__.py
+++ b/tests/__init__.py
@@ -14,0 +15,1 @@
+from .test_none_dictionary import *
diff --git a/tests/test_none_dictionary.py b/tests/test_none_dictionary.py
new file mode 100644
index 0000000..c5f4a2e
--- /dev/null
+++ b/tests/test_none_dictionary.py
@@ -0,0 +1,13 @@
+from __future__ import print_function
+
+import unittest
+
+import jep
+
+TestNoneDictionary = jep.findClass('jep.test.TestNoneDictionary')
+
+
+class TestNoneDictionaryRegression(unittest.TestCase):
+
+    def test_none_dictionary(self):
+        TestNoneDictionary.test()
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
