FROM yutu0814/clb.base.x86_64.lwjgl_1776_lwjgl3-clb-069:latest@sha256:4c3e81308492f51476d57f3b6d5ada60fd184926c43d2bf9610e3978f42a730e

COPY --chmod=0644 <<'EOF_d3a73056d0bc' /benchmark/case_adapter.sh
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

COPY --chmod=0644 <<'EOF_8a58ff4098c6' /benchmark/format_test_log.py
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
RUN git -C /testbed clean -fdx -e bin
