#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "2c007161cff7ba12023ae48dd28a7856c0c6da3d" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
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
