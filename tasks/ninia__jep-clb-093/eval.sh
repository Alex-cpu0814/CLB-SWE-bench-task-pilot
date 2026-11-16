#!/bin/bash
set -uxo pipefail
set +x
ulimit -c 0
cd /testbed || exit 2
fail() {
    printf '%s\n' ">>>>> Tests Errored" "$1" >&2
    exit 2
}
[[ "$(git rev-parse HEAD)" == "9eeb14c4c8b2d0e49feece90a6e330826b49c7dd" ]] || fail "Unexpected Base commit"
git apply --check --whitespace=nowarn - <<'CLB_TEST_PATCH'
diff --git a/src/jep/test/TestVersionUnsafe.java b/src/jep/test/TestVersionUnsafe.java
new file mode 100644
index 0000000..0000000
--- /dev/null
+++ b/src/jep/test/TestVersionUnsafe.java
@@ -0,0 +1,14 @@
+package jep.test;
+
+import jep.Jep;
+
+/** Starts and closes the native interpreter through the standard JEP path. */
+public class TestVersionUnsafe {
+
+    public static void main(String[] args) throws Exception {
+        Jep jep = new Jep(false);
+        jep.close();
+    }
+
+}
+
diff --git a/tests/test_version_unsafe.py b/tests/test_version_unsafe.py
new file mode 100644
index 0000000..0000000
--- /dev/null
+++ b/tests/test_version_unsafe.py
@@ -0,0 +1,39 @@
+from __future__ import print_function
+
+import glob
+import os
+import unittest
+
+from tests.jep_pipe import build_java_process_cmd
+from tests.jep_pipe import jep_pipe
+
+
+class TestVersionUnsafe(unittest.TestCase):
+
+    def test_version_unsafe(self):
+        build_libs = [
+            path for path in glob.glob(os.path.join('build', 'lib*'))
+            if os.path.isdir(os.path.join(path, 'jep'))
+        ]
+        self.assertEqual(len(build_libs), 1, build_libs)
+
+        old_pythonpath = os.environ.get('PYTHONPATH')
+        os.environ['PYTHONPATH'] = (
+            os.path.abspath(build_libs[0]) + os.pathsep
+            + (old_pythonpath or '')
+        )
+        try:
+            jep_pipe(build_java_process_cmd('jep.test.TestVersionUnsafe'))
+        except AssertionError as error:
+            output = str(error)
+            if ('free(): invalid next size' in output
+                    or 'corrupted size vs. prev_size' in output
+                    or 'sysmalloc: Assertion' in output):
+                self.fail('Base revision reproduced the Issue 79 allocator failure:\n%s'
+                          % output)
+            raise
+        finally:
+            if old_pythonpath is None:
+                os.environ.pop('PYTHONPATH', None)
+            else:
+                os.environ['PYTHONPATH'] = old_pythonpath
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch does not apply"
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH'
diff --git a/src/jep/test/TestVersionUnsafe.java b/src/jep/test/TestVersionUnsafe.java
new file mode 100644
index 0000000..0000000
--- /dev/null
+++ b/src/jep/test/TestVersionUnsafe.java
@@ -0,0 +1,14 @@
+package jep.test;
+
+import jep.Jep;
+
+/** Starts and closes the native interpreter through the standard JEP path. */
+public class TestVersionUnsafe {
+
+    public static void main(String[] args) throws Exception {
+        Jep jep = new Jep(false);
+        jep.close();
+    }
+
+}
+
diff --git a/tests/test_version_unsafe.py b/tests/test_version_unsafe.py
new file mode 100644
index 0000000..0000000
--- /dev/null
+++ b/tests/test_version_unsafe.py
@@ -0,0 +1,39 @@
+from __future__ import print_function
+
+import glob
+import os
+import unittest
+
+from tests.jep_pipe import build_java_process_cmd
+from tests.jep_pipe import jep_pipe
+
+
+class TestVersionUnsafe(unittest.TestCase):
+
+    def test_version_unsafe(self):
+        build_libs = [
+            path for path in glob.glob(os.path.join('build', 'lib*'))
+            if os.path.isdir(os.path.join(path, 'jep'))
+        ]
+        self.assertEqual(len(build_libs), 1, build_libs)
+
+        old_pythonpath = os.environ.get('PYTHONPATH')
+        os.environ['PYTHONPATH'] = (
+            os.path.abspath(build_libs[0]) + os.pathsep
+            + (old_pythonpath or '')
+        )
+        try:
+            jep_pipe(build_java_process_cmd('jep.test.TestVersionUnsafe'))
+        except AssertionError as error:
+            output = str(error)
+            if ('free(): invalid next size' in output
+                    or 'corrupted size vs. prev_size' in output
+                    or 'sysmalloc: Assertion' in output):
+                self.fail('Base revision reproduced the Issue 79 allocator failure:\n%s'
+                          % output)
+            raise
+        finally:
+            if old_pythonpath is None:
+                os.environ.pop('PYTHONPATH', None)
+            else:
+                os.environ['PYTHONPATH'] = old_pythonpath
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch application failed"
source /opt/clb-pilot/case_adapter.sh || fail "Cannot load the case adapter"
build_project || fail "Project build failed"
raw_log=$(mktemp) || fail "Cannot create a test log"
trap 'rm -f "$raw_log"' EXIT
run_project_tests >"$raw_log" 2>&1
test_status=$?
cat "$raw_log"
printf '%s\n' '>>>>> Start Test Output'
emit_results() {
    python /opt/clb-pilot/normalize_results.py jep "$raw_log" || return 2
    return "$test_status"
}
emit_results
printf '%s\n' '>>>>> End Test Output'
exit "$test_status"
