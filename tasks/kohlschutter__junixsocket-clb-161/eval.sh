#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "1df1513c64079a5100cdc2a372558e1f77849c0f" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java b/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
index 00be130..c173164 100644
--- a/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
+++ b/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
@@ -18,12 +18,15 @@
 package org.newsclub.net.unix;
 
 import static org.junit.jupiter.api.Assertions.assertFalse;
+import static org.junit.jupiter.api.Assertions.assertThrows;
 import static org.junit.jupiter.api.Assertions.assertTrue;
 
+import java.io.File;
 import java.io.IOException;
 import java.io.InputStream;
 import java.net.Socket;
 import java.net.SocketException;
+import java.net.SocketTimeoutException;
 import java.util.concurrent.Semaphore;
 import java.util.concurrent.TimeUnit;
 
@@ -100,4 +103,24 @@ public class SoTimeoutTest extends SocketTestBase {
       }
     }
   }
+
+  @Test
+  public void testSocketTimeoutException() throws Exception {
+    final File tempFile = newTempFile();
+    final AFUNIXSocketAddress address = AFUNIXSocketAddress.of(tempFile);
+    try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address);
+        AFUNIXSocket client = AFUNIXSocket.connectTo(address)) {
+
+      final AFUNIXSocket socket = server.accept();
+      socket.setSoTimeout(500);
+      byte[] buf = new byte[socket.getReceiveBufferSize()];
+      InputStream in = socket.getInputStream();
+
+      assertThrows(SocketTimeoutException.class, () -> {
+        in.read(buf);
+      });
+    } finally {
+      tempFile.delete();
+    }
+  }
 }
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
