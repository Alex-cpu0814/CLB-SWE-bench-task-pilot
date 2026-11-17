#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "bbf96b5cbb83fe9e4edef71d410d29460084d5fc" ]] || fail 'Unexpected Base commit'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_8c196d945fd4' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py clean >/dev/null 2>&1 || true
    python setup.py build || return 10

    CASE_NATIVE_LIB="$(find build -type f -name 'jep*.so' -print -quit)"
    [[ -n "${CASE_NATIVE_LIB}" ]] || return 11

    CASE_NATIVE_DIR="$(dirname "${CASE_NATIVE_LIB}")"
    ln -sf "$(basename "${CASE_NATIVE_LIB}")" "${CASE_NATIVE_DIR}/libjep.so"

    CASE_CLASSPATH="build/java/jep.jar"
    [[ -f "${CASE_CLASSPATH}" ]] || return 12

    for jar_file in \
        build/java/jep.test.jar \
        tests/lib/sqlitejdbc-v056.jar \
        tests/lib/fakenetty.jar
    do
        if [[ -f "${jar_file}" ]]; then
            CASE_CLASSPATH="${CASE_CLASSPATH}:${jar_file}"
        fi
    done

    export LD_LIBRARY_PATH="/opt/python-2.7.18/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    export PYTHONPATH="${PWD}/build/lib.linux-x86_64-2.7:${PWD}:${PYTHONPATH:-}"

    local python_lib
    python_lib="$(find /opt/python-2.7.18/lib -maxdepth 1 -type f \
        -name 'libpython2.7.so*' | head -n 1)"

    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi
}

run_project_tests() {
    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /benchmark/run_tests_verbose.py
}
EOF_8c196d945fd4
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
cat > /benchmark/run_tests_verbose.py <<'EOF_2d28fb72eff7' || fail 'Cannot write /benchmark/run_tests_verbose.py'
from __future__ import print_function

import sys
import unittest


if __name__ == '__main__':
    suite = unittest.TestLoader().discover('tests')
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.stdout.flush()
    sys.stderr.flush()
    # JEP 3.2 treats any Python SystemExit as an embedding exception,
    # including SystemExit(0). Return naturally on success instead.
    if not result.wasSuccessful():
        raise AssertionError("test suite failed")
EOF_2d28fb72eff7
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
