#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "bbf96b5cbb83fe9e4edef71d410d29460084d5fc" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/test_exceptions.py b/tests/test_exceptions.py
index bbe13e8..af49482 100644
--- a/tests/test_exceptions.py
+++ b/tests/test_exceptions.py
@@ -24,3 +24,56 @@ class TestExceptions(unittest.TestCase):
         except Exception as ex:
             # because it's not a checked exception, mapped exceptions doesn't apply here (all Runtime)            
             self.assertIn('java.lang.NullPointerException', str(ex.message))
+
+
+# the tests below verify that specific java exceptions map to python errors,
+# enabling more precise except blocks when python encounters a java error
+
+    def test_import_error(self):
+        try:
+            from java.lang import ArrayList
+        except ImportError as ex:
+            pass
+
+    def test_index_error(self):
+        x = jep.jarray(3, Integer)
+        try:
+            i = x[5]
+        except IndexError as ex:
+            pass
+
+    def test_io_error(self):
+        try:
+            FileInputStream('asdf')
+        except IOError as ex:
+            pass
+
+    def test_type_error(self):
+        try:
+            from java.util import Collections, ArrayList
+            x = ArrayList()
+            c = Collections.checkedList(x, Integer)
+            c.add(Integer(5))
+            c.add(String("5"))
+        except TypeError as ex:
+            pass
+
+    def test_value_err(self):
+        try:
+            from java.lang import System
+            System.getProperty('', '')
+        except ValueError as ex:
+            pass
+
+    def test_arithmetic_error(self):
+        try:
+            from java.math import BigDecimal
+            d = BigDecimal(3.14159)
+            zero = BigDecimal(0.0)
+            x = d.divide(zero)
+        except ArithmeticError as ex:
+            pass
+        
+    # TODO come up with a way to test MemoryError and AssertionError given
+    # I coded support for that.
+
diff --git a/tests/test_import.py b/tests/test_import.py
index 24a8ac8..d00569e 100644
--- a/tests/test_import.py
+++ b/tests/test_import.py
@@ -18,7 +18,7 @@ class TestImport(unittest.TestCase):
         importer = JepImporter()
         mod = importer.load_module('java.lang')
         mod.Integer
-        self.assertRaises(AttributeError, mod.__getattr__, 'asdf')
+        self.assertRaises(ImportError, mod.__getattr__, 'asdf')
 
     def test_restricted_classloader(self):
         # should use the supplied classloader for hooks
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
