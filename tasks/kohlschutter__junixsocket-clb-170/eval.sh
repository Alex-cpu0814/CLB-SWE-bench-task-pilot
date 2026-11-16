#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "71a134bce58a22fb17a7a14f00799196c0c71a60" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/benchmark-tests/org/newsclub/net/unix/NoexecProbe.java b/benchmark-tests/org/newsclub/net/unix/NoexecProbe.java
new file mode 100644
--- /dev/null
+++ b/benchmark-tests/org/newsclub/net/unix/NoexecProbe.java
@@ -0,0 +1,82 @@
+package org.newsclub.net.unix;
+
+import java.io.DataInputStream;
+import java.io.DataOutputStream;
+import java.io.File;
+import java.nio.charset.StandardCharsets;
+import java.nio.file.Files;
+import java.nio.file.Path;
+import java.nio.file.Paths;
+import java.util.LinkedHashSet;
+import java.util.Set;
+
+/** Uses the unchanged automatic loader and real AF_UNIX sockets. */
+public final class NoexecProbe {
+  public static void main(String[] args) throws Exception {
+    System.out.println("JAVA=" + System.getProperty("java.version"));
+    System.out.println("LOADER_ORIGIN=" + NativeLibraryLoader.class.getProtectionDomain()
+        .getCodeSource().getLocation());
+    for (String directory : new String[] {System.getProperty("java.io.tmpdir"), System.getProperty("user.home"), System.getProperty("user.dir")}) {
+      Path test = Files.createTempFile(Paths.get(directory), "writable-", ".txt");
+      try {
+        Files.write(test, new byte[] {1, 2, 3});
+        if (Files.readAllBytes(test).length != 3) {
+          throw new AssertionError("File I/O control failed");
+        }
+      } finally {
+        Files.delete(test);
+      }
+      System.out.println("WRITABLE=" + directory);
+    }
+    for (String line : Files.readAllLines(Paths.get("/proc/self/mountinfo"), StandardCharsets.UTF_8)) {
+      String[] columns = line.split(" ");
+      if (columns.length > 5 && (columns[4].equals("/case-noexec") || columns[4].equals("/case-exec"))) {
+        System.out.println("MOUNT=" + columns[4] + " " + columns[5]);
+      }
+    }
+    System.out.println("BEFORE_SOCKET");
+    for (int iteration = 0; iteration < 3; iteration++) {
+      File file = File.createTempFile("case170-", ".sock", new File(System.getProperty("user.dir")));
+      if (!file.delete()) {
+        throw new AssertionError("Could not prepare socket pathname");
+      }
+      AFUNIXSocketAddress address = AFUNIXSocketAddress.of(file);
+      try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address)) {
+        server.setSoTimeout(3000);
+        try (AFUNIXSocket client = AFUNIXSocket.connectTo(address);
+             AFUNIXSocket accepted = server.accept()) {
+          client.setSoTimeout(3000);
+          accepted.setSoTimeout(3000);
+          int value = 0x17014000 + iteration;
+          new DataOutputStream(client.getOutputStream()).writeInt(value);
+          if (new DataInputStream(accepted.getInputStream()).readInt() != value) {
+            throw new AssertionError("Request payload mismatch");
+          }
+          new DataOutputStream(accepted.getOutputStream()).writeInt(~value);
+          if (new DataInputStream(client.getInputStream()).readInt() != ~value) {
+            throw new AssertionError("Response payload mismatch");
+          }
+        }
+      } finally {
+        if (file.exists() && !file.delete()) {
+          throw new AssertionError("Socket cleanup failed");
+        }
+      }
+      System.out.println("ROUNDTRIP_OK=" + iteration);
+    }
+    Set<String> mapped = new LinkedHashSet<String>();
+    for (String line : Files.readAllLines(Paths.get("/proc/self/maps"), StandardCharsets.UTF_8)) {
+      if (line.contains("junixsocket-native") && line.contains(".so")) {
+        String[] columns = line.split("\\s+", 6);
+        mapped.add(columns[5]);
+      }
+    }
+    for (String path : mapped) {
+      System.out.println("NATIVE_MAPPING=" + path);
+    }
+    if (mapped.isEmpty()) {
+      throw new AssertionError("No real native library mapping found");
+    }
+    System.out.println("NOEXEC_PROBE_OK");
+  }
+}
CLB_TEST_PATCH

mkdir -p /results || fail 'Cannot create test output directory'
mkdir -p /case-noexec /case-exec || fail 'Cannot create test mountpoints'
mount -t tmpfs -o rw,noexec,nosuid,size=64m tmpfs /case-noexec || fail 'Cannot create noexec test mount'
mount -t tmpfs -o rw,exec,nosuid,size=64m tmpfs /case-exec || fail 'Cannot create executable test mount'
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
