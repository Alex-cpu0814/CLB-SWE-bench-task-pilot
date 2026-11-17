#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "1fa5a394949cad836a104d8e5093f734d26ff8e1" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/config/tests/case074/org/lwjgl/PointerBuffer.java b/config/tests/case074/org/lwjgl/PointerBuffer.java
new file mode 100644
--- /dev/null
+++ b/config/tests/case074/org/lwjgl/PointerBuffer.java
@@ -0,0 +1,4 @@
+package org.lwjgl;
+
+/** Needed only by the upstream Pointer.java Javadoc and import. */
+public final class PointerBuffer {}
diff --git a/config/tests/case074/org/lwjgl/system/MemoryAccess.java b/config/tests/case074/org/lwjgl/system/MemoryAccess.java
new file mode 100644
--- /dev/null
+++ b/config/tests/case074/org/lwjgl/system/MemoryAccess.java
@@ -0,0 +1,10 @@
+package org.lwjgl.system;
+
+/** Focused replacement for the large upstream class. */
+final class MemoryAccess {
+    static {
+        System.load("/results/libpointerprobe.so");
+    }
+
+    static native int getPointerSize();
+}
diff --git a/config/tests/case074/org/lwjgl/system/MemoryUtil.java b/config/tests/case074/org/lwjgl/system/MemoryUtil.java
new file mode 100644
--- /dev/null
+++ b/config/tests/case074/org/lwjgl/system/MemoryUtil.java
@@ -0,0 +1,13 @@
+package org.lwjgl.system;
+
+/** Keeps the upstream initialization dependency relevant to issue #115. */
+final class MemoryUtil {
+    static {
+        System.load("/results/libpointerprobe.so");
+        AllocatorProbe.initialize();
+    }
+
+    static native int memGetPointerSize();
+
+    static void initialize() {}
+}
diff --git a/config/tests/case074/org/lwjgl/system/AllocatorProbe.java b/config/tests/case074/org/lwjgl/system/AllocatorProbe.java
new file mode 100644
--- /dev/null
+++ b/config/tests/case074/org/lwjgl/system/AllocatorProbe.java
@@ -0,0 +1,19 @@
+package org.lwjgl.system;
+
+/** Mimics the exact architecture choice in the pinned jemalloc Kotlin template. */
+final class AllocatorProbe {
+    static String attempted;
+    static boolean loaded;
+
+    static void initialize() {
+        String name = Pointer.BITS64 ? "jemalloc" : "jemalloc32";
+        attempted = "lib" + name + ".so";
+        try {
+            System.loadLibrary(name);
+            loaded = true;
+        } catch (UnsatisfiedLinkError error) {
+            loaded = false;
+        }
+        System.out.println("attempted_library=" + attempted + " loaded=" + loaded);
+    }
+}
diff --git a/config/tests/case074/org/lwjgl/system/PointerInitializationProbe.java b/config/tests/case074/org/lwjgl/system/PointerInitializationProbe.java
new file mode 100644
--- /dev/null
+++ b/config/tests/case074/org/lwjgl/system/PointerInitializationProbe.java
@@ -0,0 +1,29 @@
+package org.lwjgl.system;
+
+/** Protected issue-derived tests, run in separate JVMs. */
+public final class PointerInitializationProbe {
+    public static void main(String[] args) {
+        if (args.length != 1)
+            throw new IllegalArgumentException("Expected one test mode");
+        if (!System.getProperty("os.arch").contains("64"))
+            throw new AssertionError("A 64-bit JVM is required");
+
+        int size = Pointer.POINTER_SIZE;
+        MemoryUtil.initialize();
+        System.out.println("pointer_size=" + size + " bits64=" + Pointer.BITS64);
+        System.out.println("attempted_library=" + AllocatorProbe.attempted
+                + " loaded=" + AllocatorProbe.loaded);
+
+        if (size != 8 || !Pointer.BITS64)
+            throw new AssertionError("Native pointer width is incorrect");
+        if ("pointerWidth".equals(args[0])) {
+            System.out.println("[PASS] pointerWidth");
+            return;
+        }
+        if (!"allocatorSelection".equals(args[0]))
+            throw new IllegalArgumentException("Unknown mode: " + args[0]);
+        if (!"libjemalloc.so".equals(AllocatorProbe.attempted) || !AllocatorProbe.loaded)
+            throw new AssertionError("64-bit JVM selected the wrong jemalloc library");
+        System.out.println("[PASS] allocatorSelection");
+    }
+}
diff --git a/config/tests/case074/pointer_size.c b/config/tests/case074/pointer_size.c
new file mode 100644
--- /dev/null
+++ b/config/tests/case074/pointer_size.c
@@ -0,0 +1,14 @@
+#include <jni.h>
+
+/* Same JNI signatures and sizeof(void *) result as the two pinned C revisions. */
+JNIEXPORT jint JNICALL Java_org_lwjgl_system_MemoryUtil_memGetPointerSize(JNIEnv *env, jclass clazz) {
+    (void)env;
+    (void)clazz;
+    return (jint)sizeof(void *);
+}
+
+JNIEXPORT jint JNICALL Java_org_lwjgl_system_MemoryAccess_getPointerSize(JNIEnv *env, jclass clazz) {
+    (void)env;
+    (void)clazz;
+    return (jint)sizeof(void *);
+}
diff --git a/config/tests/case074/jemalloc_stub.c b/config/tests/case074/jemalloc_stub.c
new file mode 100644
--- /dev/null
+++ b/config/tests/case074/jemalloc_stub.c
@@ -0,0 +1,2 @@
+/* A loadable 64-bit library to make the wrong 32-bit selection observable. */
+int jemalloc_probe_stub(void) { return 64; }
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_e676ef7a9dbb' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash
build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null \
        && command -v gcc >/dev/null && command -v java >/dev/null \
        && command -v javac >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed
}
run_project_tests() {
    python3 /benchmark/test_runner.py /testbed /results \
        > /results/runner.stdout.log 2> /results/runner.stderr.log
    local status=$?
    cat /results/runner.stdout.log
    return "$status"
}
EOF_e676ef7a9dbb
cat > /benchmark/build_project.py <<'EOF_7d3d93d421ca' || fail 'Cannot write /benchmark/build_project.py'
"""Compile the candidate's exact-commit Pointer.java against protected stubs."""
import json
from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1] if len(sys.argv) > 1 else "/testbed").resolve()
if repo != Path("/testbed") or not (repo / "build.xml").is_file():
    raise SystemExit("Expected isolated /testbed LWJGL checkout")

source = repo / "modules/core/src/main/java/org/lwjgl/system/Pointer.java"
test_root = repo / "config/tests/case074"
classes = repo / "bin/classes/benchmark"
classes.mkdir(parents=True, exist_ok=True)
command = [
    "javac", "-source", "8", "-target", "8", "-encoding", "UTF-8",
    "-d", str(classes),
    str(test_root / "org/lwjgl/PointerBuffer.java"),
    str(test_root / "org/lwjgl/system/MemoryAccess.java"),
    str(test_root / "org/lwjgl/system/MemoryUtil.java"),
    str(test_root / "org/lwjgl/system/AllocatorProbe.java"),
    str(source),
]
print(json.dumps({"phase": "source_build", "command": command}), flush=True)
raise SystemExit(subprocess.run(command, cwd=repo).returncode)
EOF_7d3d93d421ca
cat > /benchmark/format_test_log.py <<'EOF_284a4c0f196d' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

import json

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
        if line.startswith("{"):
            try:
                report = json.loads(line)
            except ValueError:
                continue
            if report.get("oracle_type") in ("runtime_behavior", "compilation") and isinstance(report.get("tests"), dict):
                mapping = {"passed": "PASSED", "failed": "FAILED", "error": "ERROR", "skipped": "SKIPPED"}
                for test_id, item in report["tests"].items():
                    if isinstance(item, dict):
                        statuses[test_id] = mapping.get(item.get("status"), "UNKNOWN")
            continue
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
EOF_284a4c0f196d
cat > /benchmark/test_runner.py <<'EOF_045191abc7e0' || fail 'Cannot write /benchmark/test_runner.py'
"""Run 64-bit allocator-selection and pointer-width controls in separate JVMs."""
import json
from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
if repo != Path("/testbed") or out != Path("/results"):
    raise SystemExit("Unexpected evaluation paths")
test_root = repo / "config/tests/case074"
classes = repo / "bin/classes/benchmark"

builds = [
    ["gcc", "-std=c11", "-shared", "-fPIC", "-I/opt/java/openjdk/include",
     "-I/opt/java/openjdk/include/linux", "-o", str(out / "libpointerprobe.so"),
     str(test_root / "pointer_size.c")],
    ["gcc", "-std=c11", "-shared", "-fPIC", "-o", str(out / "libjemalloc.so"),
     str(test_root / "jemalloc_stub.c")],
    ["javac", "-source", "8", "-target", "8", "-encoding", "UTF-8",
     "-cp", str(classes), "-d", str(classes),
     str(test_root / "org/lwjgl/system/PointerInitializationProbe.java")],
]
with (out / "test-compilation.private.log").open("wb") as log:
    for command in builds:
        result = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            print(json.dumps({"phase": "test_compilation", "exit_code": result.returncode,
                              "infrastructure_error": True, "tests": {}}))
            raise SystemExit(2)

tests = {}
for mode in ("pointerWidth", "allocatorSelection"):
    command = [
        "java", "-Djava.library.path=" + str(out),
        "-XX:ErrorFile=" + str(out / "hs_err-%p.log"),
        "-cp", str(classes), "org.lwjgl.system.PointerInitializationProbe", mode,
    ]
    with (out / (mode + ".private.log")).open("wb") as log:
        try:
            result = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=60)
        except subprocess.TimeoutExpired:
            print(json.dumps({"phase": "runtime", "infrastructure_error": True,
                              "reason": "timeout", "tests": tests}))
            raise SystemExit(2)
    status = "passed" if result.returncode == 0 else "failed" if result.returncode == 1 else "error"
    tests["org.lwjgl.system.PointerInitializationProbe::" + mode] = {
        "status": status, "exit_code": result.returncode,
    }

report = {"oracle_type": "runtime_behavior", "phase": "runtime",
          "infrastructure_error": any(item["status"] == "error" for item in tests.values()),
          "tests": tests}
(out / "sanitized_results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
raise SystemExit(2 if report["infrastructure_error"] else
                 0 if all(item["status"] == "passed" for item in tests.values()) else 1)
EOF_045191abc7e0
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
