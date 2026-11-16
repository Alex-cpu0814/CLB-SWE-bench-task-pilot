FROM yutu0814/clb.base.x86_64.lwjgl_1776_lwjgl3-clb-074:latest@sha256:b44598bbab33b72ad28c9e23a9b635689fbe9ba38391f551fa2fede76f82da8d

COPY --chmod=0644 <<'EOF_e676ef7a9dbb' /benchmark/case_adapter.sh
#!/usr/bin/env bash
build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null \
        && command -v gcc >/dev/null && command -v java >/dev/null \
        && command -v javac >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed
}
run_project_tests() {
    python3 /benchmark/test_runner.py /testbed /results \
        > /results/runner.stdout.log 2> /results/runner.stderr.log
    local status=$?
    cat /results/runner.stdout.log
    return "$status"
}
EOF_e676ef7a9dbb

COPY --chmod=0644 <<'EOF_7d3d93d421ca' /benchmark/build_project.py
"""Compile the candidate's exact-commit Pointer.java against protected stubs."""
import json
from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1] if len(sys.argv) > 1 else "/testbed").resolve()
if repo != Path("/testbed") or not (repo / "build.xml").is_file():
    raise SystemExit("Expected isolated /testbed LWJGL checkout")

source = repo / "modules/core/src/main/java/org/lwjgl/system/Pointer.java"
test_root = repo / "config/tests/case074"
classes = repo / "bin/classes/benchmark"
classes.mkdir(parents=True, exist_ok=True)
command = [
    "javac", "-source", "8", "-target", "8", "-encoding", "UTF-8",
    "-d", str(classes),
    str(test_root / "org/lwjgl/PointerBuffer.java"),
    str(test_root / "org/lwjgl/system/MemoryAccess.java"),
    str(test_root / "org/lwjgl/system/MemoryUtil.java"),
    str(test_root / "org/lwjgl/system/AllocatorProbe.java"),
    str(source),
]
print(json.dumps({"phase": "source_build", "command": command}), flush=True)
raise SystemExit(subprocess.run(command, cwd=repo).returncode)
EOF_7d3d93d421ca

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

COPY --chmod=0644 <<'EOF_045191abc7e0' /benchmark/test_runner.py
"""Run 64-bit allocator-selection and pointer-width controls in separate JVMs."""
import json
from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
if repo != Path("/testbed") or out != Path("/results"):
    raise SystemExit("Unexpected evaluation paths")
test_root = repo / "config/tests/case074"
classes = repo / "bin/classes/benchmark"

builds = [
    ["gcc", "-std=c11", "-shared", "-fPIC", "-I/opt/java/openjdk/include",
     "-I/opt/java/openjdk/include/linux", "-o", str(out / "libpointerprobe.so"),
     str(test_root / "pointer_size.c")],
    ["gcc", "-std=c11", "-shared", "-fPIC", "-o", str(out / "libjemalloc.so"),
     str(test_root / "jemalloc_stub.c")],
    ["javac", "-source", "8", "-target", "8", "-encoding", "UTF-8",
     "-cp", str(classes), "-d", str(classes),
     str(test_root / "org/lwjgl/system/PointerInitializationProbe.java")],
]
with (out / "test-compilation.private.log").open("wb") as log:
    for command in builds:
        result = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            print(json.dumps({"phase": "test_compilation", "exit_code": result.returncode,
                              "infrastructure_error": True, "tests": {}}))
            raise SystemExit(2)

tests = {}
for mode in ("pointerWidth", "allocatorSelection"):
    command = [
        "java", "-Djava.library.path=" + str(out),
        "-XX:ErrorFile=" + str(out / "hs_err-%p.log"),
        "-cp", str(classes), "org.lwjgl.system.PointerInitializationProbe", mode,
    ]
    with (out / (mode + ".private.log")).open("wb") as log:
        try:
            result = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=60)
        except subprocess.TimeoutExpired:
            print(json.dumps({"phase": "runtime", "infrastructure_error": True,
                              "reason": "timeout", "tests": tests}))
            raise SystemExit(2)
    status = "passed" if result.returncode == 0 else "failed" if result.returncode == 1 else "error"
    tests["org.lwjgl.system.PointerInitializationProbe::" + mode] = {
        "status": status, "exit_code": result.returncode,
    }

report = {"oracle_type": "runtime_behavior", "phase": "runtime",
          "infrastructure_error": any(item["status"] == "error" for item in tests.values()),
          "tests": tests}
(out / "sanitized_results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
raise SystemExit(2 if report["infrastructure_error"] else
                 0 if all(item["status"] == "passed" for item in tests.values()) else 1)
EOF_045191abc7e0
RUN git -C /testbed clean -fdx -e bin
