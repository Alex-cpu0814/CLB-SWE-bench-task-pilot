FROM yutu0814/clb.base.x86_64.mdsplus_1776_mdsplus-clb-200:latest@sha256:540d1b56d89a81f690d9cafa09dc5f2310d58d20c3fd6d7d0b213e6cd8ba44b5

COPY --chmod=0644 <<'EOF_797165c2f5a2' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    cd /testbed
    ./bootstrap
    cd /build
    NOF77=yes /testbed/configure --prefix=/usr/local/mdsplus --disable-java
    make
    make install
}

run_one_tdi_test() {
    local test_name="$1"
    local display_name="$2"
    local status
    local test_dir=/build/tditest/testing

    rm -f "${test_dir}/${test_name}.log" "${test_dir}/${test_name}.trs" "${test_dir}/test-suite.log"
    make -C "${test_dir}" check TESTS="${test_name}.tdi"
    status=$?
    if [[ "${status}" -eq 0 ]]; then
        printf '%s (MDSplus.tditest) ... ok\n' "${display_name}"
    else
        printf '%s (MDSplus.tditest) ... FAIL\n' "${display_name}"
    fi
    return "${status}"
}

run_project_tests() {
    local control_status=0
    local target_status=0

    run_one_tdi_test test-tdishr test-tdishr || control_status=$?
    run_one_tdi_test test-treeshr test-treeshr-owner-id || target_status=$?
    [[ "${control_status}" -eq 0 && "${target_status}" -eq 0 ]]
}

EOF_797165c2f5a2

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
USER root
RUN git config --system --add safe.directory /testbed
RUN git -C /testbed clean -fdx
