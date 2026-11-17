#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "bc2edaf0242736c2a2940104eebc6aed5a3ad9e6" ]] || fail 'Unexpected Base commit'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_a18a1ebf5933' || fail 'Cannot write /benchmark/case_adapter.sh'
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
        jep.Run runtests.py
}
EOF_a18a1ebf5933
cat > /benchmark/format_test_log.py <<'EOF_74e140e46b15' || fail 'Cannot write /benchmark/format_test_log.py'
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
                if pending.startswith("tests."):
                    pending = pending[len("tests."):]
            continue
        test_id = "{}.{}".format(match.group("class"), match.group("method"))
        if test_id.startswith("tests."):
            test_id = test_id[len("tests."):]
        statuses[test_id] = normalize_status(match.group("status"))
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_74e140e46b15
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
