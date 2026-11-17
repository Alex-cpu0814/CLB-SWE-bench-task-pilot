#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "427e278dc2402aca025cacd58a80eb4eaa8c4832" ]] || fail 'Unexpected Base commit'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_d3a73056d0bc' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    local flags=(
        -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.egl=false
        -Dbinding.glfw=false -Dbinding.jawt=false -Dbinding.jemalloc=false
        -Dbinding.lmdb=false -Dbinding.lz4=false -Dbinding.nanovg=false
        -Dbinding.nfd=false -Dbinding.nuklear=false -Dbinding.odbc=false
        -Dbinding.openal=false -Dbinding.opencl=false -Dbinding.opengl=false
        -Dbinding.opengles=false -Dbinding.openvr=false -Dbinding.par=false
        -Dbinding.remotery=false -Dbinding.rpmalloc=false -Dbinding.sse=false
        -Dbinding.stb=false -Dbinding.tinyexr=false -Dbinding.tinyfd=false
        -Dbinding.tootle=false -Dbinding.vma=false -Dbinding.vulkan=false
        -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false
    )
    if ! C_INCLUDE_PATH=/testbed/modules/lwjgl/core/src/main/c/dyncall \
        ant -Dbuild.offline=true "${flags[@]}" compile-templates compile; then
        return 1
    fi

    mkdir -p bin/classes/test
    javac -cp "bin/classes/lwjgl/core:bin/libs/java/jsr305.jar:bin/libs/java/testng.jar" \
        -d bin/classes/test \
        modules/lwjgl/core/src/test/java/org/lwjgl/system/MemoryUtilTest.java || return 1
}

run_project_tests() {
    local cp="bin/classes/lwjgl/core:bin/classes/test:bin/libs/java/testng.jar:bin/libs/java/jcommander.jar"
    local native="bin/libs:bin/libs/linux/x64"
    local raw=/tmp/testng.raw.log

    java -ea -Dorg.lwjgl.util.Debug=true -Dorg.lwjgl.util.DebugAllocator=true \
        -Djava.library.path="${native}" -cp "${cp}" \
        org.testng.TestNG -verbose 2 -testclass org.lwjgl.system.MemoryUtilTest >"${raw}" 2>&1
    local status=$?
    cat "${raw}"

    # Keep the complete TestNG log while emitting stable unittest-shaped lines
    # consumed by the generic evaluator.
    if grep -q '^PASSED: testTextDecoding' "${raw}"; then
        echo 'testTextDecoding (org.lwjgl.system.MemoryUtilTest) ... ok'
    else
        echo 'testTextDecoding (org.lwjgl.system.MemoryUtilTest) ... FAIL'
    fi
    if grep -q '^PASSED: testUTF8' "${raw}"; then
        echo 'testUTF8 (org.lwjgl.system.MemoryUtilTest) ... ok'
    else
        echo 'testUTF8 (org.lwjgl.system.MemoryUtilTest) ... FAIL'
    fi
    return "${status}"
}
EOF_d3a73056d0bc
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
