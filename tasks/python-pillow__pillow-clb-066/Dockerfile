FROM yutu0814/clb.base.x86_64.python-pillow_1776_pillow-clb-066:latest@sha256:7920e3b809a64939f0f576c3801ab0906722f6e94da7f28296e3b6a202189c21

COPY --chmod=0644 <<'EOF_e7adefd32e2d' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext -i --force
}

run_project_tests() {
    python /benchmark/unittest_case066_isolated.py \
        'Tests/test_imagefont.py::TestImageFont::test_default_font' \
        'Tests/test_file_png.py::TestFilePng::test_sanity' \
        'Tests/test_font_leaks.py::TestTTypeFontLeak::test_leak' \
        'Tests/test_font_leaks.py::TestDefaultFontLeak::test_leak'
}
EOF_e7adefd32e2d

COPY --chmod=0644 <<'EOF_7a0cb1177257' /benchmark/format_test_log.py
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
    r"^(?P<test_id>Tests/\S+)\s+"
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
EOF_7a0cb1177257

COPY --chmod=0644 <<'EOF_8d74581f31e3' /benchmark/unittest_case066_isolated.py
"""Run original legacy unittest cases in fresh processes without changing tests."""
import ctypes
import importlib.util
import json
import pathlib
import resource
import signal
import subprocess
import sys
import unittest

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError('Could not disable dumpability')

def load(node):
    file, cls, method = node.split('::')
    source = pathlib.Path(file)
    spec = importlib.util.spec_from_file_location('official_' + source.stem, source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    case = getattr(module, cls)(method)
    assert isinstance(case, unittest.TestCase)
    return unittest.TestSuite([case])

if '--worker' in sys.argv:
    node = sys.argv[-1]
    result = unittest.TextTestRunner(stream=sys.stdout, verbosity=2).run(load(node))
    assert result.testsRun == 1
    status = 'SKIPPED' if result.skipped else ('PASSED' if result.wasSuccessful() else 'FAILED')
    print(node + ' ' + status, flush=True)
    sys.exit(0 if result.wasSuccessful() else 1)

nodes = [arg for arg in sys.argv[1:] if arg.startswith('Tests/') and '::' in arg]
assert nodes
if '--collect-only' in sys.argv:
    for node in nodes:
        assert load(node).countTestCases() == 1
        print(node + ' COLLECTED', flush=True)
    sys.exit(0)
failed = False
for node in nodes:
    print('ISOLATED_NODE_BEGIN ' + node, flush=True)
    process = subprocess.run([sys.executable, __file__, '--worker', node], timeout=120)
    result = {'node': node, 'returncode': process.returncode, 'signal': signal.Signals(-process.returncode).name if process.returncode < 0 else None}
    print('ISOLATED_NODE_RESULT ' + json.dumps(result), flush=True)
    if process.returncode < 0:
        print(node + ' FAILED', flush=True)
    elif process.returncode not in (0, 1):
        raise RuntimeError('Unexpected unittest exit: ' + json.dumps(result))
    failed = failed or process.returncode != 0
sys.exit(1 if failed else 0)
EOF_8d74581f31e3
