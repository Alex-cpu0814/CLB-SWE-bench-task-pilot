#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "2c007161cff7ba12023ae48dd28a7856c0c6da3d" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/modules/lwjgl/openvr/src/test/java/org/lwjgl/openvr/VRCompositorNullGamePoseTest.java b/modules/lwjgl/openvr/src/test/java/org/lwjgl/openvr/VRCompositorNullGamePoseTest.java
new file mode 100644
--- /dev/null
+++ b/modules/lwjgl/openvr/src/test/java/org/lwjgl/openvr/VRCompositorNullGamePoseTest.java
@@ -0,0 +1,65 @@
+package org.lwjgl.openvr;
+
+import org.lwjgl.PointerBuffer;
+import org.lwjgl.system.MemoryUtil;
+
+public final class VRCompositorNullGamePoseTest {
+    private static native long stubFunction();
+    private static native int callCount();
+    private static native long renderAddress();
+    private static native int renderCount();
+    private static native long gameAddress();
+    private static native int gameCount();
+
+    private static int run(String mode) {
+        if (!("nullGamePose".equals(mode) || "nonNullGamePose".equals(mode))) {
+            System.err.println("Usage: VRCompositorNullGamePoseTest nullGamePose|nonNullGamePose");
+            return 2;
+        }
+        PointerBuffer table = null;
+        TrackedDevicePose.Buffer render = null;
+        TrackedDevicePose.Buffer game = null;
+        try {
+            System.load("/results/libvrprobe.so");
+            table = MemoryUtil.memCallocPointer(128);
+            render = TrackedDevicePose.calloc(1);
+            if ("nonNullGamePose".equals(mode)) {
+                game = TrackedDevicePose.calloc(2);
+            }
+            table.put(2, stubFunction());
+            OpenVR.VRCompositor = new OpenVR.IVRCompositor(MemoryUtil.memAddress(table));
+            int result;
+            try {
+                result = VRCompositor.VRCompositor_WaitGetPoses(render, game);
+            } catch (NullPointerException error) {
+                System.err.println("[FAIL] " + mode + ": NPE before native call; calls=" + callCount());
+                error.printStackTrace(System.err);
+                return 1;
+            }
+            long expectedGameAddress = game == null ? 0 : game.address();
+            int expectedGameCount = game == null ? 0 : game.remaining();
+            System.out.printf("[NATIVE] mode=%s result=%d calls=%d renderAddress=%d renderCount=%d gameAddress=%d gameCount=%d%n",
+                mode, result, callCount(), renderAddress(), renderCount(), gameAddress(), gameCount());
+            if (result != 418 || callCount() != 1 || renderAddress() != render.address()
+                    || renderCount() != 1 || gameAddress() != expectedGameAddress
+                    || gameCount() != expectedGameCount) {
+                System.err.println("[FAIL] " + mode + ": native argument mismatch");
+                return 1;
+            }
+            System.out.println("[PASS] " + mode);
+            return 0;
+        } catch (Throwable error) {
+            System.err.println("[ERROR] " + mode + ": setup or runtime failure");
+            error.printStackTrace(System.err);
+            return 2;
+        } finally {
+            if (game != null) game.free();
+            if (render != null) render.free();
+            if (table != null) MemoryUtil.memFree(table);
+        }
+    }
+
+    public static void main(String[] args) {
+        System.exit(run(args.length == 1 ? args[0] : ""));
+    }
+}
diff --git a/config/tests/vrprobe.c b/config/tests/vrprobe.c
new file mode 100644
--- /dev/null
+++ b/config/tests/vrprobe.c
@@ -0,0 +1,44 @@
+#include <jni.h>
+#include <stdint.h>
+
+static int last_calls;
+static uintptr_t last_render_address;
+static uint32_t last_render_count;
+static uintptr_t last_game_address;
+static uint32_t last_game_count;
+
+static int wait_get_poses_stub(void *render, uint32_t render_count, void *game, uint32_t game_count) {
+    ++last_calls;
+    last_render_address = (uintptr_t)render;
+    last_render_count = render_count;
+    last_game_address = (uintptr_t)game;
+    last_game_count = game_count;
+    return 418;
+}
+
+#define JNI_PROBE(name) Java_org_lwjgl_openvr_VRCompositorNullGamePoseTest_##name
+
+JNIEXPORT jlong JNICALL JNI_PROBE(stubFunction)(JNIEnv *env, jclass cls) {
+    (void)env; (void)cls;
+    return (jlong)(intptr_t)&wait_get_poses_stub;
+}
+JNIEXPORT jint JNICALL JNI_PROBE(callCount)(JNIEnv *env, jclass cls) {
+    (void)env; (void)cls;
+    return last_calls;
+}
+JNIEXPORT jlong JNICALL JNI_PROBE(renderAddress)(JNIEnv *env, jclass cls) {
+    (void)env; (void)cls;
+    return (jlong)last_render_address;
+}
+JNIEXPORT jint JNICALL JNI_PROBE(renderCount)(JNIEnv *env, jclass cls) {
+    (void)env; (void)cls;
+    return (jint)last_render_count;
+}
+JNIEXPORT jlong JNICALL JNI_PROBE(gameAddress)(JNIEnv *env, jclass cls) {
+    (void)env; (void)cls;
+    return (jlong)last_game_address;
+}
+JNIEXPORT jint JNICALL JNI_PROBE(gameCount)(JNIEnv *env, jclass cls) {
+    (void)env; (void)cls;
+    return (jint)last_game_count;
+}
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
cat > /benchmark/build_project.py <<'EOF_f7a437d386fa' || fail 'Cannot write /benchmark/build_project.py'
"""Compile the candidate's generated OpenVR Java binding from the Base checkout."""
import json
from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1] if len(sys.argv) > 1 else "/testbed").resolve()
if repo != Path("/testbed") or not (repo / "build.xml").is_file():
    raise SystemExit("Expected isolated /testbed LWJGL checkout")

source = repo / "modules/lwjgl/openvr/src/generated/java/org/lwjgl/openvr/VRCompositor.java"
classes = repo / "bin/classes/benchmark"
classes.mkdir(parents=True, exist_ok=True)
command = [
    "javac", "-source", "8", "-target", "8", "-encoding", "UTF-8",
    "-cp", "/opt/benchmark/lib/*", "-d", str(classes), str(source),
]
print(json.dumps({"phase": "source_build", "command": command}), flush=True)
raise SystemExit(subprocess.run(command, cwd=repo).returncode)
EOF_f7a437d386fa
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
cat > /benchmark/test_runner.py <<'EOF_57941f2eef16' || fail 'Cannot write /benchmark/test_runner.py'
"""Run the issue-derived null test and non-null regression control in separate JVMs."""
import json
from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
if repo != Path("/testbed") or out != Path("/results"):
    raise SystemExit("Unexpected evaluation paths")
source = repo / "modules/lwjgl/openvr/src/test/java/org/lwjgl/openvr/VRCompositorNullGamePoseTest.java"
native = repo / "config/tests/vrprobe.c"
classes = out / "test-classes"
classes.mkdir(parents=True, exist_ok=True)

builds = [
    ["gcc", "-shared", "-fPIC", "-O2", "-I/opt/java/openjdk/include",
     "-I/opt/java/openjdk/include/linux", "-o", str(out / "libvrprobe.so"), str(native)],
    ["javac", "-source", "8", "-target", "8", "-encoding", "UTF-8",
     "-cp", str(repo / "bin/classes/benchmark") + ":/opt/benchmark/lib/*",
     "-d", str(classes), str(source)],
]
with (out / "test-compilation.private.log").open("wb") as log:
    for command in builds:
        result = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            print(json.dumps({"phase": "test_compilation", "exit_code": result.returncode,
                              "infrastructure_error": True, "tests": {}}))
            raise SystemExit(2)

tests = {}
for mode in ("nonNullGamePose", "nullGamePose"):
    command = [
        "java", "-XX:ErrorFile=" + str(out / "hs_err-%p.log"),
        "-cp", str(classes) + ":" + str(repo / "bin/classes/benchmark") + ":/opt/benchmark/lib/*",
        "org.lwjgl.openvr.VRCompositorNullGamePoseTest", mode,
    ]
    with (out / (mode + ".private.log")).open("wb") as log:
        try:
            result = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT, timeout=60)
        except subprocess.TimeoutExpired:
            print(json.dumps({"phase": "runtime", "infrastructure_error": True,
                              "reason": "timeout", "tests": tests}))
            raise SystemExit(2)
    status = "passed" if result.returncode == 0 else "failed" if result.returncode == 1 else "error"
    tests["org.lwjgl.openvr.VRCompositorNullGamePoseTest::" + mode] = {
        "status": status, "exit_code": result.returncode,
    }

report = {"oracle_type": "runtime_behavior", "phase": "runtime",
          "infrastructure_error": any(item["status"] == "error" for item in tests.values()),
          "tests": tests}
(out / "sanitized_results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
raise SystemExit(2 if report["infrastructure_error"] else
                 0 if all(item["status"] == "passed" for item in tests.values()) else 1)
EOF_57941f2eef16
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
