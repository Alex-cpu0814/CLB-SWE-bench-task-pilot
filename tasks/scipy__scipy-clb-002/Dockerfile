FROM yutu0814/clb.base.x86_64.scipy_1776_scipy-clb-002:latest@sha256:e3ed1ee056df1b5f199dc4d1dc88f17286f8e814ad0d3d301e789589dfbfb24c

COPY --chmod=0644 <<'EOF_9bb3a887e4a9' /opt/clb-pilot/case_adapter.sh
#!/usr/bin/env bash

# Case-specific build and test functions sourced by run_evaluation.sh.

build_project() {
    python setup.py build_ext -i
}

run_project_tests() {
    python -m pytest -vv -W ignore::DeprecationWarning \
        scipy/ndimage/tests/test_interpolation.py
}
EOF_9bb3a887e4a9

COPY --chmod=0644 <<'EOF_c05e792222b6' /opt/clb-pilot/normalize_results.py
"""Translate CLB test result lines to the upstream status-first format."""

import io
import re
import sys


PYTEST = re.compile(
    r"^(scipy/\S.*?)\s+(PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[\s*\d+%\])?$"
)
UNITTEST = re.compile(r"^(\S+) \(([^)]+)\) \.\.\.(?: (.*))?$")


def statuses(lines, mode):
    pending = None
    mapping = {"ok": "PASSED", "FAIL": "FAILED", "ERROR": "ERROR", "skipped": "SKIPPED"}
    for raw in lines:
        line = raw.strip()
        if mode == "pytest":
            result = PYTEST.match(line)
            if result:
                yield result.group(2), result.group(1)
            continue
        result = UNITTEST.match(line)
        if result:
            method, test_class, line = result.groups()
            if mode == "jep" and test_class.startswith("tests."):
                test_class = test_class[len("tests."):]
            pending = test_class + "." + method
            line = line or ""
        if pending and line:
            status = mapping.get("skipped" if line.startswith("skipped") else line)
            if status:
                yield status, pending
                pending = None


if __name__ == "__main__":
    with io.open(sys.argv[2], encoding="utf-8", errors="replace") as stream:
        for status, test_id in statuses(stream, sys.argv[1]):
            print("{} {}".format(status, test_id))
EOF_c05e792222b6
