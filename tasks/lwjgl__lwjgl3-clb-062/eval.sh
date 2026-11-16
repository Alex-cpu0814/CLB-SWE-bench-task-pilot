#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "2c8811383487cd827f375abdc534a5d40a174edc" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/modules/lwjgl/llvm/src/test/java/org/lwjgl/llvm/ClangCStringRegressionTest.java b/modules/lwjgl/llvm/src/test/java/org/lwjgl/llvm/ClangCStringRegressionTest.java
new file mode 100644
--- /dev/null
+++ b/modules/lwjgl/llvm/src/test/java/org/lwjgl/llvm/ClangCStringRegressionTest.java
@@ -0,0 +1,59 @@
+/* Issue-derived protected regression test. */
+package org.lwjgl.llvm;
+
+import org.lwjgl.system.MemoryStack;
+import java.nio.file.Files;
+import java.nio.file.Path;
+
+import static org.lwjgl.llvm.ClangIndex.*;
+import static org.lwjgl.system.MemoryStack.stackPush;
+import static org.lwjgl.system.MemoryUtil.*;
+
+public final class ClangCStringRegressionTest {
+    private static final String SOURCE = "/testbed/config/tests/clang_cstring_fixture.c";
+
+    public static void main(String[] args) {
+        if (args.length != 1 || !("direct".equals(args[0]) || "binding".equals(args[0]))) {
+            System.err.println("Usage: ClangCStringRegressionTest direct|binding");
+            System.exit(2);
+        }
+        try {
+            if (!Files.isRegularFile(Path.of(SOURCE))) {
+                throw new IllegalStateException("Missing source fixture: " + SOURCE);
+            }
+            long index = clang_createIndex(false, false);
+            if (index == NULL) {
+                throw new IllegalStateException("clang_createIndex returned NULL");
+            }
+            long tu = NULL;
+            try (MemoryStack stack = stackPush()) {
+                tu = clang_parseTranslationUnit(index, SOURCE, null, null, 0);
+                if (tu == NULL) {
+                    throw new IllegalStateException("clang_parseTranslationUnit returned NULL");
+                }
+                CXString spelling = clang_getTranslationUnitSpelling(tu, CXString.callocStack(stack));
+                String direct = memUTF8Safe(memGetAddress(spelling.address()));
+                if (!SOURCE.equals(direct)) {
+                    throw new IllegalStateException("CXString precondition failed: " + direct);
+                }
+                String actual = "direct".equals(args[0]) ? direct : clang_getCString(spelling);
+                System.out.println("test=" + args[0] + " expected=" + SOURCE + " actual=" + actual);
+                if (!SOURCE.equals(actual)) {
+                    System.err.println("[FAIL] String mismatch");
+                    System.exit(1);
+                }
+                System.out.println("[PASS] " + args[0]);
+                // clang_disposeString is also affected in Base. One string is reclaimed at process exit.
+            } finally {
+                if (tu != NULL) {
+                    clang_disposeTranslationUnit(tu);
+                }
+                clang_disposeIndex(index);
+            }
+        } catch (Throwable error) {
+            System.err.println("[ERROR] Setup or runtime failure");
+            error.printStackTrace();
+            System.exit(2);
+        }
+    }
+}
diff --git a/config/tests/clang_cstring_fixture.c b/config/tests/clang_cstring_fixture.c
new file mode 100644
--- /dev/null
+++ b/config/tests/clang_cstring_fixture.c
@@ -0,0 +1 @@
+int main(void) { return 0; }
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
