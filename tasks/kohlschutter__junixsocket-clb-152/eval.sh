#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "4f7667c4655712fc7371c0dbab0de5bf785e5d3d" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/benchmark-tests/src/test/java/org/newsclub/net/unix/FileDescriptorCastRegressionTest.java b/benchmark-tests/src/test/java/org/newsclub/net/unix/FileDescriptorCastRegressionTest.java
new file mode 100644
index 000000000..a941a14b8
--- /dev/null
+++ b/benchmark-tests/src/test/java/org/newsclub/net/unix/FileDescriptorCastRegressionTest.java
@@ -0,0 +1,99 @@
+/*
+ * Focused regression harness for junixsocket issue #97.
+ *
+ * The test body follows the official upstream test introduced by commit
+ * 2f8f096b84fba1a, with only the forked-process helper adapted for the
+ * pre-refactor parent tree.
+ */
+package org.newsclub.net.unix;
+
+import java.io.BufferedReader;
+import java.io.FileDescriptor;
+import java.io.InputStreamReader;
+import java.lang.ProcessBuilder.Redirect;
+import java.nio.charset.StandardCharsets;
+import java.nio.file.Paths;
+import java.util.concurrent.TimeUnit;
+
+public final class FileDescriptorCastRegressionTest {
+  private static final String CLASS_NAME = FileDescriptorCastRegressionTest.class.getName();
+
+  private FileDescriptorCastRegressionTest() {
+    throw new IllegalStateException("No instances");
+  }
+
+  private static void testForkedVMRedirectStdin() throws Exception {
+    AFUNIXSocketAddress addr = AFUNIXSocketAddress.ofNewTempFile();
+    try (AFUNIXServerSocket serverSocket = AFUNIXServerSocket.bindOn(addr);
+        AFUNIXSocket clientConn = AFUNIXSocket.connectTo(addr);
+        AFUNIXSocket serverConn = serverSocket.accept()) {
+      if (!addr.getFile().delete()) {
+        throw new AssertionError("Could not unlink temporary socket path");
+      }
+
+      String javaCommand = Paths.get(System.getProperty("java.home"), "bin", "java").toString();
+      ProcessBuilder processBuilder = new ProcessBuilder(javaCommand, "-cp",
+          System.getProperty("java.class.path"), StdinSocketApp.class.getName());
+      processBuilder.redirectInput(FileDescriptorCast.using(clientConn.getFileDescriptor()).as(
+          Redirect.class));
+      processBuilder.redirectError(Redirect.INHERIT);
+      Process process = processBuilder.start();
+      try {
+        try (BufferedReader reader = new BufferedReader(new InputStreamReader(serverConn
+            .getInputStream(), StandardCharsets.UTF_8))) {
+          String firstLine = reader.readLine();
+          if (!"Hello world".equals(firstLine)) {
+            throw new AssertionError("Unexpected output: " + firstLine);
+          }
+          String extraLine = reader.readLine();
+          if (extraLine != null) {
+            throw new AssertionError("Unexpected extra output: " + extraLine);
+          }
+        }
+        if (!process.waitFor(30, TimeUnit.SECONDS)) {
+          throw new AssertionError("Forked VM did not terminate");
+        }
+        if (process.exitValue() != 0) {
+          throw new AssertionError("Forked VM exited with " + process.exitValue());
+        }
+      } finally {
+        process.destroyForcibly();
+      }
+    }
+  }
+
+  private static void testStdoutFileDescriptorCast() throws Exception {
+    FileDescriptor descriptor = FileDescriptorCast.using(FileDescriptor.out)
+        .as(FileDescriptor.class);
+    if (descriptor != FileDescriptor.out || !descriptor.valid()) {
+      throw new AssertionError("stdout file descriptor cast was not preserved");
+    }
+  }
+
+  private static boolean run(String methodName, CheckedRunnable test) {
+    try {
+      test.run();
+      System.out.println(methodName + " (" + CLASS_NAME + ") ... ok");
+      return true;
+    } catch (Throwable throwable) {
+      throwable.printStackTrace(System.out);
+      System.out.println(methodName + " (" + CLASS_NAME + ") ... ERROR");
+      return false;
+    }
+  }
+
+  public static void main(String[] args) {
+    boolean targetPassed = run("testForkedVMRedirectStdin",
+        FileDescriptorCastRegressionTest::testForkedVMRedirectStdin);
+    boolean controlPassed = run("testStdoutFileDescriptorCast",
+        FileDescriptorCastRegressionTest::testStdoutFileDescriptorCast);
+    if (!targetPassed || !controlPassed) {
+      System.exit(1);
+    }
+  }
+
+  @FunctionalInterface
+  private interface CheckedRunnable {
+    void run() throws Exception;
+  }
+}
diff --git a/benchmark-tests/src/test/java/org/newsclub/net/unix/StdinSocketApp.java b/benchmark-tests/src/test/java/org/newsclub/net/unix/StdinSocketApp.java
new file mode 100644
index 000000000..74b7cd189
--- /dev/null
+++ b/benchmark-tests/src/test/java/org/newsclub/net/unix/StdinSocketApp.java
@@ -0,0 +1,36 @@
+/*
+ * junixsocket
+ *
+ * Copyright 2009-2022 Christian Kohlschütter
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License");
+ * you may not use this file except in compliance with the License.
+ * You may obtain a copy of the License at
+ *
+ *     http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software
+ * distributed under the License is distributed on an "AS IS" BASIS,
+ * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+ * See the License for the specific language governing permissions and
+ * limitations under the License.
+ */
+package org.newsclub.net.unix;
+
+import java.io.FileDescriptor;
+import java.io.PrintStream;
+import java.nio.charset.StandardCharsets;
+
+/** A forked-VM helper used by the file-descriptor redirect regression test. */
+public final class StdinSocketApp {
+  private StdinSocketApp() {
+    throw new IllegalStateException("No instances");
+  }
+
+  public static void main(String[] args) throws Exception {
+    try (PrintStream out = new PrintStream(FileDescriptorCast.using(FileDescriptor.in)
+        .as(AFUNIXSocket.class).getOutputStream(), true, StandardCharsets.UTF_8.name())) {
+      out.println("Hello world");
+    }
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
