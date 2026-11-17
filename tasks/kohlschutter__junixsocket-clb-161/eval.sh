#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "1df1513c64079a5100cdc2a372558e1f77849c0f" ]] || fail 'Unexpected Base commit'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_e9dd44a796b4' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    mvn -B -o -Prelease-native \
        -pl junixsocket-native-common,junixsocket-native-custom -am clean install \
        -Dmaven.test.skip=true \
        '-Djunixsocket.native.clang.c.options=-Wall -Wextra -Wno-reserved-id-macro -Wno-undef -Wno-cast-qual -Wno-disabled-macro-expansion -Wno-language-extension-token -Wno-gnu-auto-type -Wno-c++11-extensions -Wno-c++98-compat -Wno-empty-translation-unit -Wno-gnu-empty-initializer -Werror-implicit-function-declaration -Wint-conversion -Wno-unused-command-line-argument -fno-strict-overflow -finline-functions -fwrapv -fPIC -fvisibility=hidden -fno-common -Os -std=gnu11 -Djunixsocket_use_poll_for_read' \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default
}

run_project_tests() {
    local control_status target_status
    local report_dir=/testbed/junixsocket-common/target/surefire-reports

    rm -rf "${report_dir}"
    mvn -B -o -f junixsocket-common/pom.xml test \
        '-Dtest=SoTimeoutTest#issue14Pass'
    control_status=$?
    python3 /benchmark/report_surefire.py "${report_dir}"
    if [[ "${control_status}" -ne 0 ]]; then
        return "${control_status}"
    fi

    rm -rf "${report_dir}"
    timeout --signal=TERM --kill-after=5s 30s \
        mvn -B -o -f junixsocket-common/pom.xml test \
        '-Dtest=SoTimeoutTest#testSocketTimeoutException'
    target_status=$?
    if [[ "${target_status}" -eq 124 || "${target_status}" -eq 137 ]]; then
        printf '%s\n' \
            'testSocketTimeoutException (org.newsclub.net.unix.SoTimeoutTest) ... ERROR'
        return 1
    fi
    python3 /benchmark/report_surefire.py "${report_dir}"
    return "${target_status}"
}
EOF_e9dd44a796b4
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
cat > /benchmark/report_surefire.py <<'EOF_9596d4de326e' || fail 'Cannot write /benchmark/report_surefire.py'
#!/usr/bin/env python3
"""Emit Maven Surefire XML results in the evaluator's stable line format."""

import pathlib
import sys
import xml.etree.ElementTree as ET


def main():
    report_dir = pathlib.Path(sys.argv[1])
    found = 0
    for path in sorted(report_dir.glob("TEST-*.xml")):
        root = ET.parse(path).getroot()
        for case in root.iter("testcase"):
            class_name = case.get("classname", "unknown")
            method = case.get("name", "unknown")
            if case.find("failure") is not None:
                status = "FAIL"
            elif case.find("error") is not None:
                status = "ERROR"
            elif case.find("skipped") is not None:
                status = "skipped"
            else:
                status = "ok"
            print(f"{method} ({class_name}) ... {status}")
            found += 1
    if found == 0:
        print("No Surefire test results found", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF_9596d4de326e
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
