FROM yutu0814/clb.base.x86_64.pygobject_1776_pycairo-clb-137:latest@sha256:e8b08c1b3ed4005b361437d1fe2e1170778340f1b4895632222667ab8395c995

COPY --chmod=0644 <<'EOF_eaaa84ae0c29' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext --inplace --force
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -vv \
        'tests/test_surface.py::test_surface_get_device_scale' \
        'tests/test_surface.py::test_surface_get_content' \
        'tests/test_surface.py::test_surface_get_format' \
        'tests/test_surface.py::test_surface_set_device_scale'
}
EOF_eaaa84ae0c29

COPY --chmod=0644 <<'EOF_c1d968746dbb' /benchmark/format_test_log.py
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
    r"^(?P<test_id>tests/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[.*\])?$"
)

def parse_test_log(text):
    # Official wrapper owns terminal statuses after checking true child results.
    # Human-readable bundled-unittest output is retained but is not a second ID.
    statuses = {}
    for line in text.splitlines():
        match = PYTEST_LINE.match(line)
        if match and match.end() == len(line):
            statuses[match.group("test_id")] = match.group("status")
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_c1d968746dbb

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
