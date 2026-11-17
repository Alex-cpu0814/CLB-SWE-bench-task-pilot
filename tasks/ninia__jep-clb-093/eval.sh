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
mkdir -p /opt/clb-pilot || fail 'Cannot create evaluation fixture directory'
cat > /opt/clb-pilot/case_adapter.sh <<'EOF_8d58bd27b32d' || fail 'Cannot write /opt/clb-pilot/case_adapter.sh'
#!/usr/bin/env bash

# Case-specific build and test functions sourced by run_evaluation.sh.

build_project() {
    python setup.py clean >/dev/null 2>&1 || true
    python setup.py build

    CASE_NATIVE_LIB="$(find build -type f -name 'jep*.so' -print -quit)"
    [[ -n "${CASE_NATIVE_LIB}" ]] || return 10
    CASE_NATIVE_DIR="$(dirname "${CASE_NATIVE_LIB}")"
    ln -sf "$(basename "${CASE_NATIVE_LIB}")" "${CASE_NATIVE_DIR}/libjep.so"

    CASE_PROJECT_VERSION="$(python -c "ns={}; exec(open('jep/version.py').read(), ns); print(ns['VERSION'])")" \
        || return 11
    CASE_CLASSPATH="build/java/jep-${CASE_PROJECT_VERSION}.jar"
    CASE_CLASSPATH="${CASE_CLASSPATH}:build/java/jep.test-${CASE_PROJECT_VERSION}.jar"
    for CASE_JAR in tests/lib/*.jar; do
        [[ -f "${CASE_JAR}" ]] && CASE_CLASSPATH="${CASE_CLASSPATH}:${CASE_JAR}"
    done

    export LD_LIBRARY_PATH="/opt/anaconda3/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    local python_lib
    python_lib="$(find /opt/anaconda3/lib -maxdepth 1 -type f \
        \( -name 'libpython3.5m.so*' -o -name 'libpython3.5.so*' \) \
        | head -n 1)"
    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi
}

run_project_tests() {
    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /opt/clb-pilot/run_tests_verbose.py
}
EOF_8d58bd27b32d
cat > /opt/clb-pilot/normalize_results.py <<'EOF_c05e792222b6' || fail 'Cannot write /opt/clb-pilot/normalize_results.py'
"""Translate CLB test result lines to the upstream status-first format."""

import io
import re
import sys


PYTEST = re.compile(
    r"^(scipy/\S.*?)\s+(PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[\s*\d+%\])?$"
)
UNITTEST = re.compile(r"^(\S+) \(([^)]+)\) \.\.\.(?: (.*))?$")


def statuses(lines, mode):
    pending = None
    mapping = {"ok": "PASSED", "FAIL": "FAILED", "ERROR": "ERROR", "skipped": "SKIPPED"}
    for raw in lines:
        line = raw.strip()
        if mode == "pytest":
            result = PYTEST.match(line)
            if result:
                yield result.group(2), result.group(1)
            continue
        result = UNITTEST.match(line)
        if result:
            method, test_class, line = result.groups()
            if mode == "jep" and test_class.startswith("tests."):
                test_class = test_class[len("tests."):]
            pending = test_class + "." + method
            line = line or ""
        if pending and line:
            status = mapping.get("skipped" if line.startswith("skipped") else line)
            if status:
                yield status, pending
                pending = None


if __name__ == "__main__":
    with io.open(sys.argv[2], encoding="utf-8", errors="replace") as stream:
        for status, test_id in statuses(stream, sys.argv[1]):
            print("{} {}".format(status, test_id))
EOF_c05e792222b6
cat > /opt/clb-pilot/run_tests_verbose.py <<'EOF_45eb350b559a' || fail 'Cannot write /opt/clb-pilot/run_tests_verbose.py'
from __future__ import print_function

import sys
import unittest


if __name__ == '__main__':
    suite = unittest.TestLoader().discover('tests')
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.stdout.flush()
    sys.stderr.flush()
    raise SystemExit(0 if result.wasSuccessful() else 1)
EOF_45eb350b559a
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
