FROM yutu0814/clb.base.x86_64.ultrajson_1776_ultrajson-clb-071:latest@sha256:1360b4e409af17a90319f15a59f1d3af12cc75c5c0aade43f712b4d06eeb6587

COPY --chmod=0644 <<'EOF_23e2a2c73180' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext -i --force
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'tests/test_ujson.py::test_encode_dict_conversion' \
        'tests/test_ujson.py::test_encode_list_conversion' \
        'tests/test_ujson.py::test_decode_from_unicode' \
        'tests/test_ujson.py::test_encode_indent[{\n    "obj": 31337\n}]' \
        'tests/test_ujson.py::test_encode_indent[{}]' \
        'tests/test_ujson.py::test_encode_indent[[]]' \
        'tests/test_ujson.py::test_encode_indent[{\n    "a": {}\n}]' \
        'tests/test_ujson.py::test_encode_indent[[\n    []\n]]'
}
EOF_23e2a2c73180

COPY --chmod=0644 <<'EOF_ffa92133cbb0' /benchmark/format_test_log.py
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
    r"^(?P<test_id>tests/.+?)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[.*\])?$"
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
            statuses[pytest_match.group("test_id")] = pytest_match.group("status")
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
    labels = {'PASSED': 'ok', 'FAILED': 'FAIL', 'ERROR': 'ERROR', 'SKIPPED': 'skipped'}
    for test_id, status in sorted(statuses.items()):
        if status in labels:
            print(u'{} ... {}'.format(test_id, labels[status]))
EOF_ffa92133cbb0

COPY --chmod=0644 <<'EOF_df4aa13b0e5b' /benchmark/pytest_no_dump.py
"""Run official pytest nodes without producing host-side Linux/WSL core dumps."""
import ctypes
import resource
import sys

import pytest

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError("Could not disable process dumpability")
sys.exit(pytest.main(sys.argv[1:]))
EOF_df4aa13b0e5b
