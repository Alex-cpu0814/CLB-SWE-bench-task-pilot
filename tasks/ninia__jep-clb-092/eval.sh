#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "d14567567ac1281e978790b9170c981113de282f" ]] || fail 'Unexpected Base commit'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_3eca46c60d5d' || fail 'Cannot write /benchmark/case_adapter.sh'
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
    CASE_CLASSPATH="${CASE_CLASSPATH}:tests/lib/sqlitejdbc-v056.jar:tests/lib/fakenetty.jar"

    export LD_LIBRARY_PATH="/opt/python-3.5.3/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    local python_lib
    python_lib="$(find /opt/python-3.5.3/lib -maxdepth 1 -type f \
        \( -name 'libpython3.5m.so*' -o -name 'libpython3.5.so*' \) \
        | head -n 1)"
    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi
}

run_project_tests() {
    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /benchmark/run_tests_verbose.py
}
EOF_3eca46c60d5d
cat > /benchmark/format_test_log.py <<'EOF_8a58ff4098c6' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)

TEST_START_LINE = re.compile(r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. .*")

def normalize_status(raw_status):
    if raw_status == "ok":
        return "PASSED"
    if raw_status == "FAIL":
        return "FAILED"
    if raw_status == "ERROR":
        return "ERROR"
    if raw_status.startswith("skipped"):
        return "SKIPPED"
    return "UNKNOWN"

def parse_test_log(text):
    statuses = {}
    pending = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        match = TEST_LINE.match(line)
        if not match:
            if pending and (line in ("ok", "FAIL", "ERROR") or line.startswith("skipped")):
                statuses[pending] = normalize_status(line)
                pending = None
                continue
            start = TEST_START_LINE.match(line)
            if start:
                pending = "{}.{}".format(start.group("class"), start.group("method"))
            continue
        test_id = "{}.{}".format(match.group("class"), match.group("method"))
        statuses[test_id] = normalize_status(match.group("status"))
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_8a58ff4098c6
cat > /benchmark/run_tests_verbose.py <<'EOF_45eb350b559a' || fail 'Cannot write /benchmark/run_tests_verbose.py'
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
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
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
