#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "307ebed6ef6ba420b2165ddb2ec21dd9a37479df" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/modules/lwjgl/vulkan/src/test/java/org/lwjgl/vulkan/VkFramebufferCreateInfoTest.java b/modules/lwjgl/vulkan/src/test/java/org/lwjgl/vulkan/VkFramebufferCreateInfoTest.java
new file mode 100644
index 0000000..7a8a5dc
--- /dev/null
+++ b/modules/lwjgl/vulkan/src/test/java/org/lwjgl/vulkan/VkFramebufferCreateInfoTest.java
@@ -0,0 +1,68 @@
+/*
+ * Copyright LWJGL. All rights reserved.
+ * License terms: https://www.lwjgl.org/license
+ */
+package org.lwjgl.vulkan;
+
+import org.lwjgl.system.MemoryStack;
+import org.testng.annotations.Test;
+
+import java.lang.reflect.InvocationTargetException;
+import java.lang.reflect.Method;
+
+import static org.lwjgl.system.MemoryStack.stackPush;
+import static org.testng.Assert.assertEquals;
+import static org.testng.Assert.assertNull;
+
+public class VkFramebufferCreateInfoTest {
+
+    @Test
+    public void testNullAttachmentsPreserveAttachmentCount() {
+        try (MemoryStack stack = stackPush()) {
+            VkFramebufferCreateInfo info =
+                VkFramebufferCreateInfo.callocStack(stack);
+
+            info.flags(VK12.VK_FRAMEBUFFER_CREATE_IMAGELESS_BIT);
+
+            VkFramebufferCreateInfo.nattachmentCount(info.address(), 2);
+            info.pAttachments(null);
+
+            assertEquals(
+                info.attachmentCount(),
+                2,
+                "Setting pAttachments to NULL must not clear attachmentCount"
+            );
+            assertNull(
+                info.pAttachments(),
+                "pAttachments must remain NULL for an imageless framebuffer"
+            );
+        }
+    }
+
+    @Test
+    public void testNullAttachmentsPassGeneratedValidation() throws Throwable {
+        try (MemoryStack stack = stackPush()) {
+            VkFramebufferCreateInfo info =
+                VkFramebufferCreateInfo.callocStack(stack);
+
+            info.flags(VK12.VK_FRAMEBUFFER_CREATE_IMAGELESS_BIT);
+            info.pAttachments(null);
+
+            VkFramebufferCreateInfo.nattachmentCount(info.address(), 2);
+
+            try {
+                Method validate =
+                    VkFramebufferCreateInfo.class.getMethod(
+                        "validate",
+                        long.class
+                    );
+
+                validate.invoke(null, info.address());
+            } catch (NoSuchMethodException ignored) {
+                // A fixed generated binding may omit this validator.
+            } catch (InvocationTargetException e) {
+                throw e.getCause();
+            }
+        }
+    }
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
