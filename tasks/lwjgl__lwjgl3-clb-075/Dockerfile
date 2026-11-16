FROM yutu0814/clb.base.x86_64.lwjgl_1776_lwjgl3-clb-075:latest@sha256:bab94a09875465ffbfb542746dfbc2c29205057939b1e1eb2a36fd0b86925984

COPY --chmod=0644 <<'EOF_506932a5033e' /benchmark/case_adapter.sh
#!/usr/bin/env bash
build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null \
        && command -v gcc >/dev/null && command -v java >/dev/null \
        && command -v javac >/dev/null && command -v ant >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed
}
run_project_tests() {
    python3 /benchmark/test_runner.py /testbed /results \
        > /results/runner.stdout.log 2> /results/runner.stderr.log
    local status=$?
    cat /results/runner.stdout.log
    return "$status"
}
EOF_506932a5033e

COPY --chmod=0644 <<'EOF_f0f4d08004df' /benchmark/build_project.py
"""Build candidate sources with the original complete Ant/Kotlin/JNI targets."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


repo = Path(sys.argv[1] if len(sys.argv) > 1 else "/testbed").resolve()
if repo != Path("/testbed") or not (repo / "build.xml").is_file():
    raise SystemExit("Expected isolated /testbed LWJGL checkout")

manifest = json.loads(Path("/benchmark/upstream_tests.json").read_text())
for relative, digest in manifest["source_sha256"].items():
    if hashlib.sha256((repo / relative).read_bytes()).hexdigest() != digest:
        raise SystemExit("Protected upstream test changed: " + relative)
deps = Path("/benchmark/dependencies")
libs = repo / "libs"
libs.mkdir(exist_ok=True)
for name in ("jcommander.jar", "testng.jar"):
    shutil.copyfile(deps / name, libs / name)
shutil.copytree(deps / "kotlinc", libs / "kotlinc", dirs_exist_ok=True)
(libs / "touch.txt").touch()
(libs / "linux/x64").mkdir(parents=True, exist_ok=True)
shutil.copyfile("/usr/lib/x86_64-linux-gnu/libffi.a", libs / "linux/x64/libffi.a")
command = ["ant", "-noinput", "-Dbuild.offline=true", "compile-templates",
           "compile-native", "compile-tests"]
print(json.dumps({"phase": "full_ant_build", "command": command}), flush=True)
result = subprocess.run(command, cwd=repo)
if result.returncode:
    raise SystemExit(result.returncode)
test = repo / "config/tests/case075/org/lwjgl/system/OriginalApiRegressionTest.java"
classes = repo / "bin/Regression"
classes.mkdir(parents=True, exist_ok=True)
raise SystemExit(subprocess.run([
    "javac", "-source", "8", "-target", "8", "-encoding", "UTF-8",
    "-cp", str(repo / "bin/Core"), "-d", str(classes), str(test),
], cwd=repo).returncode)
EOF_f0f4d08004df

COPY --chmod=0644 <<'EOF_284a4c0f196d' /benchmark/format_test_log.py
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

COPY --chmod=0644 <<'EOF_ef689049b41d' /benchmark/test_runner.py
"""Run original MemoryUtil API and native allocator controls in isolated JVMs."""
import json
from pathlib import Path
import subprocess
import sys
import shutil
from upstream_results import parse_upstream_results


repo = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
if repo != Path("/testbed") or out != Path("/results"):
    raise SystemExit("Unexpected evaluation paths")

classes = str(repo / "bin/Core") + ":" + str(repo / "bin/Regression")
tests = {}
for mode in ("nullBufferNoOp", "mallocFree", "callocFree", "reallocNullFree",
             "unknownPointerRejected", "bufferFree"):
    command = [
        "java", "-Djava.library.path=" + str(repo / "libs"),
        "-Dorg.lwjgl.system.allocator=system",
        "-Dorg.lwjgl.util.DebugAllocator=true",
        "-XX:ErrorFile=" + str(out / "hs_err-%p.log"),
        "-cp", classes, "org.lwjgl.system.OriginalApiRegressionTest", mode,
    ]
    with (out / (mode + ".private.log")).open("wb") as log:
        try:
            result = subprocess.run(command, cwd=repo, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=60)
        except subprocess.TimeoutExpired:
            print(json.dumps({"phase": "runtime", "infrastructure_error": True,
                              "reason": "timeout", "tests": tests}))
            raise SystemExit(2)
    status = "passed" if result.returncode == 0 else "failed" if result.returncode == 1 else "error"
    tests["org.lwjgl.system.OriginalApiRegressionTest::" + mode] = {
        "status": status, "exit_code": result.returncode,
    }

# The original Ant task may exit zero even when TestNG has failures.
manifest = json.loads(Path("/benchmark/upstream_tests.json").read_text())
xml = repo / "bin/HTML/tests/testng-results.xml"
if xml.exists():
    xml.unlink()
with (out / "upstream-tests.private.log").open("wb") as log:
    try:
        upstream = subprocess.run([
            "ant", "-noinput", "-Dbuild.offline=true",
            "-Djvmargs=-Dorg.lwjgl.system.allocator=system -XX:ErrorFile=/results/upstream-hs_err-%p.log",
            "tests",
        ], cwd=repo, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        upstream_exit = upstream.returncode
    except subprocess.TimeoutExpired:
        upstream_exit = -1
upstream_tests, upstream_details, upstream_ok = parse_upstream_results(
    xml, manifest["test_ids"], upstream_exit)
if xml.is_file():
    shutil.copyfile(xml, out / "upstream-testng-results.xml")
tests.update(upstream_tests)
(out / "upstream-suite.json").write_text(json.dumps(upstream_details, indent=2) + "\n")
report = {"oracle_type": "runtime_behavior", "phase": "runtime",
          "upstream_suite": upstream_details, "upstream_suite_passed": upstream_ok,
          "infrastructure_error": any(item["status"] == "error" for item in tests.values()),
          "tests": tests}
(out / "sanitized_results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
raise SystemExit(2 if report["infrastructure_error"] else
                 0 if upstream_ok and all(item["status"] == "passed" for item in tests.values()) else 1)
EOF_ef689049b41d

COPY --chmod=0644 <<'EOF_9750dfc04e54' /benchmark/upstream_results.py
"""Read original TestNG XML without treating missing/skipped tests as passes."""
from pathlib import Path
import xml.etree.ElementTree as ET


def parse_upstream_results(path, expected_ids, ant_exit_code):
    tests = {name: {"status": "missing"} for name in expected_ids}
    details = {"ant_exit_code": ant_exit_code, "configuration_failures": 0,
               "expected_tests": len(expected_ids), "report_valid": False}
    try:
        root = ET.parse(Path(path)).getroot()
        if root.tag != "testng-results":
            raise ValueError("Unexpected TestNG XML root")
    except (OSError, ET.ParseError, ValueError) as error:
        details["reason"] = str(error)
        return tests, details, False
    details.update(root.attrib)
    details["report_valid"] = True
    seen = set()
    duplicates = []
    for cls in root.findall(".//class"):
        for method in cls.findall("test-method"):
            status = method.get("status")
            if method.get("is-config") == "true":
                if status != "PASS":
                    details["configuration_failures"] += 1
                continue
            name = cls.get("name", "") + "::" + method.get("name", "")
            if name in seen:
                duplicates.append(name)
                tests[name] = {"status": "failed", "reason": "duplicate_test_id"}
                continue
            seen.add(name)
            tests[name] = {"status": {"PASS": "passed", "FAIL": "failed",
                                       "SKIP": "skipped"}.get(status, "failed")}
    details["duplicate_ids"] = duplicates
    details["missing_ids"] = sorted(set(expected_ids) - seen)
    details["unexpected_ids"] = sorted(seen - set(expected_ids))
    ok = (ant_exit_code == 0 and not details["configuration_failures"]
          and not duplicates and not details["missing_ids"] and not details["unexpected_ids"]
          and root.get("total") == root.get("passed") == str(len(expected_ids))
          and root.get("failed") == root.get("skipped") == "0"
          and all(item["status"] == "passed" for item in tests.values()))
    return tests, details, ok
EOF_9750dfc04e54

COPY --chmod=0644 <<'EOF_bf2ebb77fe1c' /benchmark/upstream_tests.json
{
  "base_commit": "f40cd981a1ff81e3da603059a062728ee33ddf02",
  "test_source": "original_upstream_base_checkout",
  "test_ids": [
    "org.lwjgl.opencl.CLTest::testContext",
    "org.lwjgl.opencl.CLTest::testEventCallback",
    "org.lwjgl.opencl.CLTest::testLifecycle",
    "org.lwjgl.opencl.CLTest::testMemObjectDestructor",
    "org.lwjgl.opencl.CLTest::testNativeKernel",
    "org.lwjgl.opencl.CLTest::testSubBuffer",
    "org.lwjgl.system.APIBufferTest::testAlignment",
    "org.lwjgl.system.APIBufferTest::testReset",
    "org.lwjgl.system.APIBufferTest::testStack",
    "org.lwjgl.system.APIBufferTest::testStackAlignment",
    "org.lwjgl.system.MemoryUtilTest::testAddress",
    "org.lwjgl.system.MemoryUtilTest::testDirectAccess",
    "org.lwjgl.system.MemoryUtilTest::testJNINewBuffer",
    "org.lwjgl.system.MemoryUtilTest::testMemCopy",
    "org.lwjgl.system.MemoryUtilTest::testMemSet",
    "org.lwjgl.system.MemoryUtilTest::testNewBuffer",
    "org.lwjgl.system.StructTest::testStructConstructor",
    "org.lwjgl.system.StructTest::testStructInstance",
    "org.lwjgl.system.StructTest::testStructLayout",
    "org.lwjgl.system.libffi.LibFFITest::testLibFFI",
    "org.lwjgl.system.simd.SSETest::testControlRegister"
  ],
  "source_sha256": {
    "config/tests.xml": "11bfbf3e4d27191515a694e7ecae7b6df2eb7bb3ed7f500a256ac8ddc4088016",
    "config/tests_linux.xml": "b1931985e7b766271bcc295ff7fded30f86d07f2786ed4d47ca912cb1d1dc33f",
    "config/tests_macosx.xml": "a8781a459e015da6e1d4ee7e4bc5fb6fee54f8eb160e00d5f9c172fbb8356d7d",
    "config/tests_windows.xml": "dd9edc888f44a9da360c673b1d63f288457b86cb7a56fbf3b6e213e49a9bda78",
    "modules/core/src/test/java/org/lwjgl/demo/glfw/Events.java": "7c68a08bdf9309f852fa4fbd5321a6047f2df66fbb1e490e19f2d69e76ac5745",
    "modules/core/src/test/java/org/lwjgl/demo/glfw/Gears.java": "77bbdcf4af2f5f2b9517cf4fa3eee47c375f24b46e81bb24d6fd9492b2a1891a",
    "modules/core/src/test/java/org/lwjgl/demo/glfw/MultipleWindows.java": "6bd975c8467e6c657df9b166c8a02b067f269ec4c242dfc87b26f4ec03c714b0",
    "modules/core/src/test/java/org/lwjgl/demo/glfw/Threads.java": "77bd9ff883c1fc7935d7f33b6f3a1480e9658a08b35973b33afb926f87d3aeb4",
    "modules/core/src/test/java/org/lwjgl/demo/openal/ALCDemo.java": "44b46f6833a5145cc4a303fef8eb6cdaf9f5e4bfaea05784462bc7cba9c4a689",
    "modules/core/src/test/java/org/lwjgl/demo/openal/EFXTest.java": "7d947cd6b36f80d15f48807bf270458a0648bcc97dcc8a167ee8c47bd90fb7b8",
    "modules/core/src/test/java/org/lwjgl/demo/openal/EFXUtil.java": "4085aa3e9857e59ff823aeed0557fe937c15a307c4cb828bd3b574cf94a8843e",
    "modules/core/src/test/java/org/lwjgl/demo/openal/OpenALInfo.java": "4e433959b807dfc1c308c775b94956efa6d6b1a2d0f1092f2665b23143c53006",
    "modules/core/src/test/java/org/lwjgl/demo/opencl/CLDemo.java": "20ef49f7e7a846c20308b36c1740ffa867fc3922cdfacb3903e080bd9255fcd8",
    "modules/core/src/test/java/org/lwjgl/demo/opencl/CLGLInteropDemo.java": "2c7b8ffebcbded8b902623caa7091ae1591d5923df9a2216cb821c3e0ae048df",
    "modules/core/src/test/java/org/lwjgl/demo/opencl/Mandelbrot.java": "ee183409a71231730c2ee68a1702dedba2ce7ab3c270a040660bc8c9e258cc45",
    "modules/core/src/test/java/org/lwjgl/demo/opengl/AbstractGears.java": "0c87bc5e972151f25f672b2a4eee784849abb51700cb3de6d9cfd6de66f49bfb",
    "modules/core/src/test/java/org/lwjgl/demo/ovr/HelloLibOVR.java": "358667fde4b18c0acbce26238b5df653d55c1d53c8761414a9b130f3d47db70a",
    "modules/core/src/test/java/org/lwjgl/demo/stb/EasyFont.java": "03ad73945a6c107af48547719c6003557f235fb0a351dadd149eda6de002faea",
    "modules/core/src/test/java/org/lwjgl/demo/stb/FontDemo.java": "4b13db43e4e38c277b857c3d8bf9349dea75dbdf539c8f45c0c5e4ee3dadc665",
    "modules/core/src/test/java/org/lwjgl/demo/stb/Image.java": "f00fab7ba25bf6cba9898991feaf3b7a8809a3e0dc528c7a5a20ff5ec6288f97",
    "modules/core/src/test/java/org/lwjgl/demo/stb/Truetype.java": "59bbd2af1b697c774caf98a38f705976328abb4abf770bfbd6e2e2512d792f65",
    "modules/core/src/test/java/org/lwjgl/demo/stb/TruetypeOversample.java": "27ed9de5c3c33865a79f0c91b4acc7ffaa03d301fe069139eac6f8a97e7dc644",
    "modules/core/src/test/java/org/lwjgl/demo/stb/Vorbis.java": "14422d66ff21cb409413d2f17832ea268fafec3def48a6ab029171f683ed74f7",
    "modules/core/src/test/java/org/lwjgl/demo/util/ClosureGC.java": "78296583e2e9154c30dc448f1d744e6cd90f2bbee41b7ba78ee41af6801b5c63",
    "modules/core/src/test/java/org/lwjgl/demo/util/IOUtil.java": "6c5f6994d8efbcf6e3ec0fb710822fc13564eb0719491f97bbab8e5ae4c73603",
    "modules/core/src/test/java/org/lwjgl/opencl/CLTest.java": "e383457fd0ba766b5578e2f12757cee829ab6593d8a40bb9d0dc91723e890386",
    "modules/core/src/test/java/org/lwjgl/system/APIBufferTest.java": "9beeaf4b4e37e372faaa6781c2f9da1a346f8b62796bfb4819da294d545821fe",
    "modules/core/src/test/java/org/lwjgl/system/MemoryUtilTest.java": "7dafd4d7699bfc53202b92abbdd2917c2fcfe251bacb57eec712188804cdc870",
    "modules/core/src/test/java/org/lwjgl/system/StructTest.java": "04c550f53b612a8df81500c26996c2451670d14aba42ba218b4b689ba132252a",
    "modules/core/src/test/java/org/lwjgl/system/libffi/LibFFITest.java": "69fa8ce5e51ff6b657321f0412b5f201998b1bf7e28285ca4f291e9f85c66229",
    "modules/core/src/test/java/org/lwjgl/system/simd/SSETest.java": "2ee7b4580530aebcaaeea95137f0fc84c36f40061f093d538f6f31bff20a3200",
    "modules/core/src/test/java/org/lwjgl/system/windows/LibraryTest.java": "88db5248c761931f7c39aef4f8d69248390c08e31371ceaaedbce0a4c2bd81cf",
    "modules/core/src/test/java/org/lwjgl/system/windows/WindowsPlatformTest.java": "6dea25612bd11f832d0fe74a50240c237c2e5fc6b30443aa07a6791910e68ddd",
    "modules/core/src/test/java/org/lwjgl/system/windows/WindowsTest.java": "7c848991f70d624d8aa54bed5e7506d9c5078016fda66df367934175f58c3b50",
    "modules/core/src/test/resources/demo/Mandelbrot.cl": "28014b2f6e61b166e04946087fb716e78966b242b5ca0368474db732a49cd565",
    "modules/core/src/test/resources/demo/cursor.png": "9589ee5bbaf157513f1d4da473d29cf475f2be99297f715f417501b50e2a9954",
    "modules/core/src/test/resources/lwjgl16.png": "79375fc0b3295ad3b7a0f2401d60cc91e6cdd2a445220ee2a80eddf4d4303ee5",
    "modules/core/src/test/resources/lwjgl32.png": "07343cbe82ab914380580f71c9f86d46abc160f6516472b42f6297df259ac443"
  }
}
EOF_bf2ebb77fe1c
RUN ln -s /opt/clb-deps /benchmark/dependencies
RUN git -C /testbed clean -fdx -e bin
