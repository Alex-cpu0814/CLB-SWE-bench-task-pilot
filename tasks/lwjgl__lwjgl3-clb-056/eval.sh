#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "307ebed6ef6ba420b2165ddb2ec21dd9a37479df" ]] || fail 'Unexpected Base commit'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_d401b2cbe3af' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null && command -v ant >/dev/null && command -v gcc >/dev/null && command -v java >/dev/null && command -v javac >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed --offline
}

run_project_tests() {
    python3 /benchmark/test_runner.py /testbed /results > /results/runner.stdout.log 2>/results/runner.stderr.log
    local status=$?
    python3 - "${status}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path('/results')
path = root / 'sanitized_results.json'
if path.is_file():
    report = json.loads(path.read_text(encoding='utf-8'))
    mapping = {'PASS': 'passed', 'FAIL': 'failed', 'SKIP': 'skipped'}
    tests = {name: {'status': mapping.get(item['status'], 'error')} for name, item in report['nodes'].items()}
    print(json.dumps({'oracle_type': 'runtime_behavior', 'phase': report['phase'], 'collected': report['collected'], 'infrastructure_error': report['infrastructure_error'], 'tests': tests}))
else:
    lines = (root / 'runner.stdout.log').read_text(encoding='utf-8', errors='replace').splitlines()
    report = {}
    for line in lines:
        try:
            report = json.loads(line)
        except ValueError:
            continue
    print(json.dumps({'oracle_type': 'runtime_behavior', 'tests': {}, 'diagnostic': report}))

code = int(sys.argv[1])
if code == 2:
    # Tools were checked before the current build. A candidate that breaks
    # compilation, library inputs, loading or test collection is unresolved.
    # Timeouts and failures outside the known execution phases remain infra.
    phase = report.get('phase')
    if phase in {'fixture_compilation', 'test_compilation', 'dynamic_loading', 'collection', 'call'} and report.get('category') != 'timeout':
        sys.exit(1)
    sys.exit(2)
sys.exit(code if code in (0, 1) else 2)
PY
}
EOF_d401b2cbe3af
cat > /benchmark/build_project.py <<'EOF_25a38b49d466' || fail 'Cannot write /benchmark/build_project.py'
"""Cold standard Ant build: regenerate bindings and compile current Java/JNI sources."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", nargs="?", default="/testbed")
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    if repo != Path("/testbed") or not (repo / "build.xml").is_file():
        raise SystemExit("Expected the isolated /testbed checkout")
    names = sorted({
        item.attrib.get("name", item.attrib.get("property", ""))
        for item in ET.parse(repo / "config/build-bindings.xml").iter()
        if item.attrib.get("name", item.attrib.get("property", "")).startswith("binding.")
    } - {"binding.DISABLE_CHECKS"})
    flags = ["-D" + name + "=" + ("true" if name == "binding.vulkan" else "false") for name in names]
    # Remove dynamic outputs so no Base binary or Maven native library can mask candidate changes.
    for library in (repo / "bin/libs/native").rglob("*.so"):
        library.unlink()
    command = ["ant", "-Dbuild.type=release/3.3.0",
               "-Dbuild.offline=" + ("true" if args.offline else "false"),
               *flags, "clean-kotlin", "clean-java", "clean-native", "compile-templates", "compile-native"]
    print(json.dumps({"phase": "standard_ant_build", "enabled_modules": ["core", "vulkan"],
                      "cold_rebuild": True, "command": command}), flush=True)
    result = subprocess.run(command, cwd=repo)
    if result.returncode:
        return result.returncode
    native = repo / "bin/libs/native/linux/x64/org/lwjgl/liblwjgl.so"
    if not native.is_file():
        raise SystemExit("Current JNI library was not built")
    print(json.dumps({"current_native_library": str(native),
                      "sha256": hashlib.sha256(native.read_bytes()).hexdigest()}), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF_25a38b49d466
cat > /benchmark/format_test_log.py <<'EOF_284a4c0f196d' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

import json

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
        if line.startswith("{"):
            try:
                report = json.loads(line)
            except ValueError:
                continue
            if report.get("oracle_type") in ("runtime_behavior", "compilation") and isinstance(report.get("tests"), dict):
                mapping = {"passed": "PASSED", "failed": "FAILED", "error": "ERROR", "skipped": "SKIPPED"}
                for test_id, item in report["tests"].items():
                    if isinstance(item, dict):
                        statuses[test_id] = mapping.get(item.get("status"), "UNKNOWN")
            continue
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
EOF_284a4c0f196d
cat > /benchmark/test_runner.py <<'EOF_ce03aacdc4ef' || fail 'Cannot write /benchmark/test_runner.py'
"""Execute protected F2P and the existing Vulkan test through TestNG XMLReporter."""
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

repo, out = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
classes = ["org.lwjgl.vulkan.VkFramebufferCreateInfoTest", "org.lwjgl.vulkan.VulkanTest"]
expected = {
    classes[0] + "::testNullAttachmentsPreserveAttachmentCount",
    classes[0] + "::testNullAttachmentsPassGeneratedValidation",
    classes[1] + "::testParse",
}


def execute(command, phase):
    with (out / (phase + ".private.log")).open("wb") as log:
        try:
            process = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        except subprocess.TimeoutExpired:
            print(json.dumps({"phase": phase, "category": "timeout", "infrastructure_error": True}))
            sys.exit(2)
    if phase != "testng" and process.returncode:
        print(json.dumps({"phase": phase, "exit_code": process.returncode, "infrastructure_error": True}))
        sys.exit(2)
    return process.returncode


cp = ":".join(str(repo / path) for path in [
    "bin/classes/test", "bin/classes/lwjgl/core", "bin/classes/lwjgl/vulkan", "bin/libs/java/*",
])
dest = repo / "bin/classes/test"
dest.mkdir(parents=True, exist_ok=True)
sources = [repo / ("modules/lwjgl/vulkan/src/test/java/" + name.replace(".", "/") + ".java") for name in classes]
execute(["javac", "-encoding", "UTF-8", "-cp", cp, "-d", str(dest), *map(str, sources)], "test_compilation")
native = repo / "bin/libs/native/linux/x64/org/lwjgl"
if not (native / "liblwjgl.so").is_file():
    print(json.dumps({"phase": "dynamic_loading", "infrastructure_error": True, "category": "missing_current_native_library"}))
    sys.exit(2)
code = execute([
    "java", "-Dorg.lwjgl.librarypath=" + str(native), "-Dorg.lwjgl.vulkan.explicitInit=true",
    "-cp", cp, "org.testng.TestNG", "-usedefaultlisteners", "false",
    "-listener", "org.testng.reporters.XMLReporter", "-testclass", ",".join(classes),
    "-d", str(out / "testng"), "-verbose", "0",
], "testng")
xml = out / "testng/testng-results.xml"
if not xml.is_file():
    print(json.dumps({"phase": "collection", "category": "missing_testng_results", "infrastructure_error": True}))
    sys.exit(2)
nodes, configurations = {}, []
for cls in ET.parse(xml).findall(".//class"):
    for method in cls.findall("test-method"):
        exception = method.find("exception")
        item = {"status": method.attrib["status"],
                "exception_type": exception.get("class") if exception is not None else None}
        if method.get("is-config") == "true":
            configurations.append(item)
        else:
            name = cls.attrib["name"] + "::" + method.attrib["name"]
            if name in nodes:
                raise RuntimeError("Duplicate test ID: " + name)
            nodes[name] = item
infra = set(nodes) != expected or code not in (0, 1) or any(
    item["status"] == "SKIP" for item in nodes.values()
) or any(item["status"] != "PASS" for item in configurations)
report = dict(phase="call", exit_code=code, infrastructure_error=infra, collected=expected.issubset(nodes),
              nodes=nodes, configuration_outcomes=configurations, native_library=str(native / "liblwjgl.so"),
              skipped=any(item["status"] == "SKIP" for item in nodes.values()), xfail=False)
(out / "sanitized_results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
sys.exit(2 if infra else (0 if all(item["status"] == "PASS" for item in nodes.values()) else 1))
EOF_ce03aacdc4ef
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
