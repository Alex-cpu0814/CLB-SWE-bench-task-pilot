#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "b1ab138dd6d492c7547e24d0b117aeafb112613d" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/src/jep/test/TestClassLoaderMethodCache.java b/src/jep/test/TestClassLoaderMethodCache.java
new file mode 100644
index 0000000..0000000
--- /dev/null
+++ b/src/jep/test/TestClassLoaderMethodCache.java
@@ -0,0 +1,99 @@
+package jep.test;
+
+import java.io.File;
+import java.io.FileWriter;
+import java.net.URL;
+import java.net.URLClassLoader;
+
+import javax.tools.JavaCompiler;
+import javax.tools.ToolProvider;
+
+import jep.Jep;
+
+/** Regression test for per-ClassLoader Java method caches. */
+public class TestClassLoaderMethodCache {
+
+    public static void main(String[] args) throws Exception {
+        File root = makeTempDirectory();
+        try {
+            File first = compileVariant(root, "first");
+            File second = compileVariant(root, "second");
+            URLClassLoader firstLoader = new URLClassLoader(
+                    new URL[] { first.toURI().toURL() },
+                    TestClassLoaderMethodCache.class.getClassLoader());
+            URLClassLoader secondLoader = new URLClassLoader(
+                    new URL[] { second.toURI().toURL() },
+                    TestClassLoaderMethodCache.class.getClassLoader());
+            try {
+                runVariant(firstLoader, "first", "first");
+                runVariant(secondLoader, "second", "second");
+            } finally {
+                firstLoader.close();
+                secondLoader.close();
+            }
+            System.out.println("CLASSLOADER_CACHE_OK");
+        } finally {
+            deleteRecursively(root);
+        }
+    }
+
+    private static void runVariant(ClassLoader loader, String method,
+            String expected) throws Exception {
+        Jep jep = new Jep(false, ".", loader);
+        try {
+            jep.eval("from jep import forName");
+            jep.eval("Sample = forName('cacheprobe.Sample')");
+            jep.eval("result = Sample()." + method + "()");
+            Object value = jep.getValue("result");
+            if (!expected.equals(value)) {
+                throw new AssertionError("unexpected result: " + value);
+            }
+        } finally {
+            jep.close();
+        }
+    }
+
+    private static File compileVariant(File root, String method)
+            throws Exception {
+        File sourceRoot = new File(root, method + "/src/cacheprobe");
+        File outputRoot = new File(root, method + "/classes");
+        if (!sourceRoot.mkdirs() || !outputRoot.mkdirs()) {
+            throw new IllegalStateException("could not create test directories");
+        }
+        File source = new File(sourceRoot, "Sample.java");
+        FileWriter writer = new FileWriter(source);
+        try {
+            writer.write("package cacheprobe; public class Sample { "
+                    + "public String " + method + "() { return \"" + method
+                    + "\"; } }");
+        } finally {
+            writer.close();
+        }
+        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
+        if (compiler == null || compiler.run(null, null, null, "-d",
+                outputRoot.getAbsolutePath(), source.getAbsolutePath()) != 0) {
+            throw new AssertionError("could not compile cache probe");
+        }
+        return outputRoot;
+    }
+
+    private static File makeTempDirectory() throws Exception {
+        File file = File.createTempFile("jep-cache", "dir");
+        if (!file.delete() || !file.mkdirs()) {
+            throw new IllegalStateException("could not create temp directory");
+        }
+        return file;
+    }
+
+    private static void deleteRecursively(File file) {
+        if (file.isDirectory()) {
+            File[] children = file.listFiles();
+            if (children != null) {
+                for (File child : children) {
+                    deleteRecursively(child);
+                }
+            }
+        }
+        file.delete();
+    }
+}
diff --git a/tests/__init__.py b/tests/__init__.py
index eea0c94..0000000 100644
--- a/tests/__init__.py
+++ b/tests/__init__.py
@@ -11,3 +11,4 @@ from .test_compare import *
 from .test_dir import *
 from .test_numpy import *
 
+from .test_classloader_method_cache import *
diff --git a/tests/jep_pipe.py b/tests/jep_pipe.py
new file mode 100644
index 0000000..0000000
--- /dev/null
+++ b/tests/jep_pipe.py
@@ -0,0 +1,31 @@
+from __future__ import print_function
+
+import subprocess
+from subprocess import PIPE
+
+
+def jep_pipe(argv):
+    process = subprocess.Popen(argv, stdout=PIPE, stderr=PIPE)
+    stdout, stderr = process.communicate()
+    if process.returncode != 0:
+        raise AssertionError(
+            "child process failed with exit code {0}\nstdout:\n{1}\nstderr:\n{2}".format(
+                process.returncode,
+                stdout.decode("utf-8", "replace"),
+                stderr.decode("utf-8", "replace")
+            )
+        )
+    return stdout
+
+
+def build_java_process_cmd(java_test_name):
+    from java.lang import System
+
+    classpath = System.getProperty("java.class.path")
+    library_path = "-Djava.library.path=" + System.getProperty(
+        "java.library.path"
+    )
+
+    return [
+        "java", "-ea", "-cp", classpath, library_path, java_test_name
+    ]
diff --git a/tests/test_classloader_method_cache.py b/tests/test_classloader_method_cache.py
new file mode 100644
index 0000000..0000000
--- /dev/null
+++ b/tests/test_classloader_method_cache.py
@@ -0,0 +1,15 @@
+from __future__ import print_function
+
+import unittest
+
+from tests.jep_pipe import build_java_process_cmd, jep_pipe
+
+
+class TestClassLoaderMethodCache(unittest.TestCase):
+
+    def test_classloader_method_cache(self):
+        stdout = jep_pipe(
+            build_java_process_cmd("jep.test.TestClassLoaderMethodCache")
+        )
+        if b"CLASSLOADER_CACHE_OK" not in stdout:
+            raise AssertionError("classloader cache marker missing")
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_285f220e91db' || fail 'Cannot write /benchmark/case_adapter.sh'
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

    export LD_LIBRARY_PATH="/opt/python-3.4.10/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    local python_lib
    python_lib="$(find /opt/python-3.4.10/lib -maxdepth 1 -type f \
        \( -name 'libpython3.4m.so*' -o -name 'libpython3.4.so*' \) \
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
EOF_285f220e91db
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
