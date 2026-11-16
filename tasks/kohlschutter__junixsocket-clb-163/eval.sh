#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "90716d6008c5c9cfa8a061f3d23531acaea29777" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java
new file mode 100644
--- /dev/null
+++ b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java
@@ -0,0 +1,57 @@
+package org.newsclub.net.unix;
+
+import java.io.DataInputStream;
+import java.io.DataOutputStream;
+import java.io.File;
+import org.newsclub.net.unix.AFUNIXServerSocket;
+import org.newsclub.net.unix.AFUNIXSocket;
+import org.newsclub.net.unix.AFUNIXSocketAddress;
+
+/** Calls the real library loader and native bind; no simulated native failures. */
+public final class Issue81GlibcProbe {
+  public static void main(String[] args) throws Exception {
+    System.out.println("JAVA_STARTED=" + System.getProperty("java.version"));
+    if (args.length == 2 && "--library".equals(args[0])) {
+      System.load(args[1]);
+      System.setProperty("org.newsclub.net.unix.library.override", args[1]);
+    } else if (args.length != 0) {
+      throw new IllegalArgumentException("Expected no arguments or --library PATH");
+    }
+    if (!AFUNIXSocket.isSupported()) {
+      throw new AssertionError("AF_UNIX unavailable");
+    }
+    System.out.println("LOADER_COMPLETED=" + AFUNIXSocket.getLoadedLibrary());
+    for (int iteration = 0; iteration < 3; iteration++) {
+      File file = File.createTempFile("issue81-", ".sock");
+      if (!file.delete()) {
+        throw new AssertionError("Could not prepare socket pathname");
+      }
+      AFUNIXSocketAddress address = new AFUNIXSocketAddress(file);
+      System.out.println("BEFORE_BIND=" + iteration);
+      try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address)) {
+        System.out.println("AFTER_BIND=" + iteration);
+        server.setSoTimeout(3000);
+        try (AFUNIXSocket client = AFUNIXSocket.connectTo(address);
+             AFUNIXSocket accepted = server.accept()) {
+          client.setSoTimeout(3000);
+          accepted.setSoTimeout(3000);
+          int value = 0x1638100 + iteration;
+          new DataOutputStream(client.getOutputStream()).writeInt(value);
+          if (new DataInputStream(accepted.getInputStream()).readInt() != value) {
+            throw new AssertionError("Request corrupted");
+          }
+          new DataOutputStream(accepted.getOutputStream()).writeInt(~value);
+          if (new DataInputStream(client.getInputStream()).readInt() != ~value) {
+            throw new AssertionError("Response corrupted");
+          }
+        }
+      } finally {
+        if (file.exists() && !file.delete()) {
+          throw new AssertionError("Socket cleanup failed");
+        }
+      }
+      System.out.println("ROUNDTRIP_OK=" + iteration);
+    }
+    System.out.println("ISSUE81_PROBE_OK");
+  }
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
