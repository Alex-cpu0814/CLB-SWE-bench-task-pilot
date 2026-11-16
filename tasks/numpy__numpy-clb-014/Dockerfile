FROM yutu0814/clb.base.x86_64.numpy_1776_numpy-clb-014:latest@sha256:a074017c1ebfe6adf757e72e61f6d1adc10bca8cbfda0931b9fece832e952535

COPY --chmod=0644 <<'EOF_e39f7732a671' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    python3.8-dbg setup.py build_ext -i --force
}

run_project_tests() {
    python3.8-dbg -m pytest -vv \
        'numpy/core/tests/test_dtype.py::TestRecord::test_partial_dict' \
        'numpy/core/tests/test_dtype.py::TestSubarray::test_single_subarray' \
        'numpy/core/tests/test_dtype.py::TestRecord::test_fieldless_views'
}
EOF_e39f7732a671

COPY --chmod=0644 <<'EOF_a6b100428c3f' /benchmark/format_test_log.py
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)

TEST_START_LINE = re.compile(r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. .*")

PYTEST_LINE = re.compile(
    r"^(?P<test_id>numpy/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED|LEAKED)(?:\s+\[.*\])?$"
)

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
        pytest_match = PYTEST_LINE.match(line)
        if pytest_match:
            status = pytest_match.group("status")
            statuses[pytest_match.group("test_id")] = (
                "FAILED" if status == "LEAKED" else status
            )
            pending = None
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
EOF_a6b100428c3f
