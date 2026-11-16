#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "427e278dc2402aca025cacd58a80eb4eaa8c4832" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/modules/lwjgl/core/src/test/java/org/lwjgl/system/MemoryUtilTest.java b/modules/lwjgl/core/src/test/java/org/lwjgl/system/MemoryUtilTest.java
index b187f5489..36f8a1673 100644
--- a/modules/lwjgl/core/src/test/java/org/lwjgl/system/MemoryUtilTest.java
+++ b/modules/lwjgl/core/src/test/java/org/lwjgl/system/MemoryUtilTest.java
@@ -11,6 +11,7 @@ import org.testng.annotations.*;
 import java.nio.*;
 import java.nio.charset.*;
 import java.util.*;
+import java.util.function.*;
 
 import static org.lwjgl.system.Checks.*;
 import static org.lwjgl.system.MemoryUtil.*;
@@ -234,6 +235,54 @@ public class MemoryUtilTest {
         }
     }
 
+    public void testTextDecoding() {
+        testTextDecoding(MemoryUtil::memASCII, MemoryUtil::memASCII, MemoryUtil::memASCII, 1);
+        testTextDecoding(MemoryUtil::memUTF8, MemoryUtil::memUTF8, MemoryUtil::memUTF8, 1);
+        testTextDecoding(MemoryUtil::memUTF16, MemoryUtil::memUTF16, MemoryUtil::memUTF16, 2);
+    }
+
+    @FunctionalInterface
+    private interface TextEncoder {
+        ByteBuffer apply(String text, boolean nullTerminated);
+    }
+
+    @FunctionalInterface
+    private interface TextDecoder {
+        String apply(ByteBuffer buffer, int length, int offset);
+    }
+
+    private static void testTextDecoding(TextEncoder encoder, Function<ByteBuffer, String> decoder, TextDecoder decoderUnsafe, int bpc) {
+        ByteBuffer encoded = encoder.apply("one two three", false);
+
+        assertEquals(encoded.position(), 0);
+        assertEquals(encoded.remaining(), 13 * bpc);
+
+        encoded.limit(13 * bpc);
+        encoded.position(0 * bpc);
+        assertEquals(decoder.apply(encoded), "one two three");
+
+        encoded.limit(3 * bpc);
+        encoded.position(0 * bpc);
+        assertEquals(decoder.apply(encoded), "one");
+
+        encoded.limit(7 * bpc);
+        encoded.position(4 * bpc);
+        assertEquals(decoder.apply(encoded), "two");
+
+        encoded.limit(13 * bpc);
+        encoded.position(8 * bpc);
+        assertEquals(decoder.apply(encoded), "three");
+
+        encoded.clear();
+
+        assertEquals(decoderUnsafe.apply(encoded, 13, 0 * bpc), "one two three");
+        assertEquals(decoderUnsafe.apply(encoded, 3, 0 * bpc), "one");
+        assertEquals(decoderUnsafe.apply(encoded, 3, 4 * bpc), "two");
+        assertEquals(decoderUnsafe.apply(encoded, 5, 8 * bpc), "three");
+
+        memFree(encoded);
+    }
+
     public void testUTF8() {
         // null-termination
         ByteBuffer bytes = memUTF8("");
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
