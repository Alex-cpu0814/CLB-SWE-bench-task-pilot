#!/bin/bash
set -uxo pipefail
set +x
ulimit -c 0
cd /testbed || exit 2
fail() {
    printf '%s\n' ">>>>> Tests Errored" "$1" >&2
    exit 2
}
[[ "$(git rev-parse HEAD)" == "2a159927761424440f7dbd7674992e4b5273a459" ]] || fail "Unexpected Base commit"
git apply --check --whitespace=nowarn - <<'CLB_TEST_PATCH'
diff --git a/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java b/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
index 76e3a6d..9bfa373 100644
--- a/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
+++ b/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
@@ -31,6 +31,7 @@
 package org.eclipse.jetty.unixdomain.server;
 
 import static org.hamcrest.MatcherAssert.assertThat;
+import static org.junit.jupiter.api.Assertions.assertArrayEquals;
 import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
 import static org.junit.jupiter.api.Assertions.assertEquals;
 import static org.junit.jupiter.api.Assertions.assertNotNull;
@@ -45,6 +46,7 @@ import java.net.SocketException;
 import java.nio.file.Files;
 import java.nio.file.Path;
 import java.util.Objects;
+import java.util.Random;
 import java.util.concurrent.TimeUnit;
 
 import org.eclipse.jetty.client.HttpClient;
@@ -75,6 +77,7 @@ import org.newsclub.net.unix.AFUNIXSocketAddress;
 import org.newsclub.net.unix.jetty.AFSocketClientConnector;
 import org.newsclub.net.unix.jetty.AFSocketServerConnector;
 
+import jakarta.servlet.ServletOutputStream;
 import jakarta.servlet.http.HttpServletRequest;
 import jakarta.servlet.http.HttpServletResponse;
 
@@ -317,4 +320,43 @@ public class UnixDomainTest {
     }
     return ret.toString();
   }
+
+  @Test
+  public void testLargeBody() throws Exception {
+    String uri = "http://localhost:1234/path";
+
+    byte[] payload = new byte[512 * 1024]; // 512k
+    Random random = new Random();
+    for (int i = 0, n = payload.length; i < n; i++) {
+      payload[i] = (byte) (random.nextInt() & 0xFF);
+    }
+
+    start(new AbstractHandler() {
+      @Override
+      public void handle(String target, Request jettyRequest, HttpServletRequest request,
+          HttpServletResponse response) throws IOException {
+        jettyRequest.setHandled(true);
+
+        response.setContentType(" application/octet-stream");
+        try (ServletOutputStream out = response.getOutputStream()) {
+          out.write(payload);
+        }
+      }
+    });
+
+    // ClientConnector clientConnector = ClientConnector.forUnixDomain(unixDomainPath);
+    ClientConnector clientConnector = AFSocketClientConnector.withSocketAddress(AFUNIXSocketAddress
+        .of(unixDomainPath));
+    HttpClient httpClient = new HttpClient(new HttpClientTransportDynamic(clientConnector));
+    httpClient.start();
+    try {
+      ContentResponse response = httpClient.newRequest(uri).timeout(5, TimeUnit.SECONDS).send();
+
+      assertEquals(HttpStatus.OK_200, response.getStatus());
+      byte[] data = response.getContent();
+      assertArrayEquals(payload, data);
+    } finally {
+      httpClient.stop();
+    }
+  }
 }
\ No newline at end of file
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch does not apply"
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH'
diff --git a/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java b/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
index 76e3a6d..9bfa373 100644
--- a/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
+++ b/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
@@ -31,6 +31,7 @@
 package org.eclipse.jetty.unixdomain.server;
 
 import static org.hamcrest.MatcherAssert.assertThat;
+import static org.junit.jupiter.api.Assertions.assertArrayEquals;
 import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
 import static org.junit.jupiter.api.Assertions.assertEquals;
 import static org.junit.jupiter.api.Assertions.assertNotNull;
@@ -45,6 +46,7 @@ import java.net.SocketException;
 import java.nio.file.Files;
 import java.nio.file.Path;
 import java.util.Objects;
+import java.util.Random;
 import java.util.concurrent.TimeUnit;
 
 import org.eclipse.jetty.client.HttpClient;
@@ -75,6 +77,7 @@ import org.newsclub.net.unix.AFUNIXSocketAddress;
 import org.newsclub.net.unix.jetty.AFSocketClientConnector;
 import org.newsclub.net.unix.jetty.AFSocketServerConnector;
 
+import jakarta.servlet.ServletOutputStream;
 import jakarta.servlet.http.HttpServletRequest;
 import jakarta.servlet.http.HttpServletResponse;
 
@@ -317,4 +320,43 @@ public class UnixDomainTest {
     }
     return ret.toString();
   }
+
+  @Test
+  public void testLargeBody() throws Exception {
+    String uri = "http://localhost:1234/path";
+
+    byte[] payload = new byte[512 * 1024]; // 512k
+    Random random = new Random();
+    for (int i = 0, n = payload.length; i < n; i++) {
+      payload[i] = (byte) (random.nextInt() & 0xFF);
+    }
+
+    start(new AbstractHandler() {
+      @Override
+      public void handle(String target, Request jettyRequest, HttpServletRequest request,
+          HttpServletResponse response) throws IOException {
+        jettyRequest.setHandled(true);
+
+        response.setContentType(" application/octet-stream");
+        try (ServletOutputStream out = response.getOutputStream()) {
+          out.write(payload);
+        }
+      }
+    });
+
+    // ClientConnector clientConnector = ClientConnector.forUnixDomain(unixDomainPath);
+    ClientConnector clientConnector = AFSocketClientConnector.withSocketAddress(AFUNIXSocketAddress
+        .of(unixDomainPath));
+    HttpClient httpClient = new HttpClient(new HttpClientTransportDynamic(clientConnector));
+    httpClient.start();
+    try {
+      ContentResponse response = httpClient.newRequest(uri).timeout(5, TimeUnit.SECONDS).send();
+
+      assertEquals(HttpStatus.OK_200, response.getStatus());
+      byte[] data = response.getContent();
+      assertArrayEquals(payload, data);
+    } finally {
+      httpClient.stop();
+    }
+  }
 }
\ No newline at end of file
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch application failed"
source /opt/clb-pilot/case_adapter.sh || fail "Cannot load the case adapter"
build_project || fail "Project build failed"
raw_log=$(mktemp) || fail "Cannot create a test log"
trap 'rm -f "$raw_log"' EXIT
run_project_tests >"$raw_log" 2>&1
test_status=$?
cat "$raw_log"
printf '%s\n' '>>>>> Start Test Output'
emit_results() {
    python3 /opt/clb-pilot/normalize_results.py unittest "$raw_log" || return 2
    return "$test_status"
}
emit_results
printf '%s\n' '>>>>> End Test Output'
exit "$test_status"
