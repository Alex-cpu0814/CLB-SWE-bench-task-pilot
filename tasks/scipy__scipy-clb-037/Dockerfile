FROM yutu0814/clb.base.x86_64.scipy_1776_scipy-clb-037:latest@sha256:38f50501f942d7d6fc5a5e80b08741c6cf762820815f59cb9205ea3f9bc53a5c

COPY --chmod=0644 <<'EOF_35252825b406' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    python3.8 setup.py build_ext -i || return $?
    # SciPy 0.10 converts Python sources into build/py3k. NumPy 1.17
    # no longer provides the historical lazy package loader.
    sed -i '/from numpy\._import_tools import PackageLoader/,/pkgload(verbose=SCIPY_IMPORT_VERBOSE,postpone=True)/d' \
        /testbed/build/py3k/scipy/__init__.py
}

run_project_tests() {
    cd /testbed/build/py3k || return $?
    python3.8 -m pytest -vv \
        'scipy/ndimage/tests/test_regression.py::test_byte_order_median' \
        'scipy/ndimage/tests/test_regression.py::test_zoom_output_shape' \
        'scipy/ndimage/tests/test_regression.py::test_ticket_742'
}
EOF_35252825b406

COPY --chmod=0644 <<'EOF_499bbb31acab' /benchmark/format_test_log.py
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
    r"^(?P<test_id>scipy/\S+)\s+"
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
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_499bbb31acab
