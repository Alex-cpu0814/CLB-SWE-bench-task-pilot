FROM yutu0814/clb.base.x86_64.uclouvain_1776_openjpeg-clb-112:latest@sha256:4a430d91af964c217ec712915e674c51abb807646b75882f2a637ee1977daecc

COPY --chmod=0644 <<'EOF_c4b3a63160a3' /benchmark/case_adapter.sh
#!/usr/bin/env bash

readonly OPJ_BUILD_DIR=/opt/openjpeg-build
readonly OPJ_DATA_DIR=/opt/openjpeg-data
readonly OPJ_INPUT="${OPJ_DATA_DIR}/input/nonregression/issue571.tif"
readonly OPJ_OUTPUT=/tmp/issue571.tif.j2k
readonly OPJ_ROUNDTRIP=/tmp/issue571.lossless.tif

build_project() {
    cmake -S /testbed -B "${OPJ_BUILD_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS=-m32 \
        -DCMAKE_EXE_LINKER_FLAGS=-m32 \
        -DCMAKE_SHARED_LINKER_FLAGS=-m32 \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_CODEC=ON \
        -DBUILD_THIRDPARTY=ON \
        -DBUILD_TESTING=ON \
        -DOPJ_DATA_ROOT="${OPJ_DATA_DIR}" || return 1
    cmake --build "${OPJ_BUILD_DIR}" --parallel "$(nproc)"
}

run_project_tests() {
    local encode_status=1
    local decode_status=1
    local compare_status=1

    rm -f "${OPJ_OUTPUT}" "${OPJ_ROUNDTRIP}"

    "${OPJ_BUILD_DIR}/bin/opj_compress" -i "${OPJ_INPUT}" -o "${OPJ_OUTPUT}"
    encode_status=$?
    if [[ "${encode_status}" -eq 0 ]]; then
        echo 'encode_issue571 (openjpeg.issue571) ... ok'
        "${OPJ_BUILD_DIR}/bin/opj_decompress" -i "${OPJ_OUTPUT}" -o "${OPJ_ROUNDTRIP}"
        decode_status=$?
    else
        echo 'encode_issue571 (openjpeg.issue571) ... FAIL'
        echo 'decode_issue571 (openjpeg.issue571) ... skipped encode failed'
    fi

    if [[ "${decode_status}" -eq 0 ]]; then
        echo 'decode_issue571 (openjpeg.issue571) ... ok'
        "${OPJ_BUILD_DIR}/bin/compare_images" \
            -b "${OPJ_INPUT}" -t "${OPJ_ROUNDTRIP}" -n 1 -d
        compare_status=$?
    elif [[ "${encode_status}" -eq 0 ]]; then
        echo 'decode_issue571 (openjpeg.issue571) ... FAIL'
    fi

    if [[ "${compare_status}" -eq 0 ]]; then
        echo 'lossless_roundtrip (openjpeg.issue571) ... ok'
    else
        echo 'lossless_roundtrip (openjpeg.issue571) ... FAIL'
    fi
    return "${compare_status}"
}
EOF_c4b3a63160a3

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
