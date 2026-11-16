FROM yutu0814/clb.base.x86_64.scipy_1776_scipy-clb-048:latest@sha256:97f6daf7dd9b7191aed4378f4524155c64be05be530069d1192bd9050df2a0d7

COPY --chmod=0644 <<'EOF_88d0fd028000' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    touch scipy/signal/sigtoolsmodule.c && CFLAGS="-O0 -g -fsanitize=bounds -fno-sanitize-recover=bounds" LDFLAGS="-fsanitize=bounds" python setup.py build_ext -i
}

run_project_tests() {
    UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 python /benchmark/pytest_case048_isolated.py \
        'scipy/signal/tests/test_signaltools.py::TestMedFilt::test_basic' \
        'scipy/signal/tests/test_signaltools.py::TestMedFilt::test_none' \
        'scipy/signal/tests/test_signaltools.py::TestMedFilt::test_invalid_dtypes[float16]'
}
EOF_88d0fd028000

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

COPY --chmod=0644 <<'EOF_37b91596f41a' /benchmark/pytest_case048_isolated.py
"""Run each official pytest node separately, preserving fatal sanitizer diagnostics."""
import os
import re
import subprocess
import sys


def main():
    failures = 0
    for node in sys.argv[1:]:
        print("BENCHMARK_NODE_START " + node, flush=True)
        command = [sys.executable, "/benchmark/pytest_no_dump.py", "-c", "/dev/null",
                   "--rootdir=/testbed", "-p", "no:cacheprovider", "-vv", "-s", node]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                env=os.environ.copy())
        output = result.stdout.decode("utf-8", errors="replace")
        print(output, end="" if output.endswith("\n") else "\n", flush=True)
        # A zero exit alone cannot establish that the expected node ran and passed.
        passed = result.returncode == 0 and re.search(
            r"^" + re.escape(node) + r"\s+PASSED(?:\s+\[.*\])?$", output, re.MULTILINE)
        status = "PASSED" if passed else "FAILED"
        print("BENCHMARK_NODE_EXIT {} {}".format(node, result.returncode), flush=True)
        print("{} {}".format(node, status), flush=True)
        failures += not passed
    return int(bool(failures))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("At least one official pytest node is required")
    sys.exit(main())
EOF_37b91596f41a

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
