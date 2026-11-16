FROM yutu0814/clb.base.x86_64.ghaering_1776_pysqlite-clb-156:latest@sha256:8b2bcaa9d01fd6d7d8d9c7188699d3b88328d98eeffbf0fe755738bcb0bcf31e

COPY --chmod=0644 <<'EOF_8df2d575e122' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    python2.7 setup.py build_ext --force build_py --force
}

run_project_tests() {
    python2.7 /benchmark/pysqlite_unittest_nodes.py \
        'lib/test/hooks.py::CollationTests::CheckCreateCollationNotCallable' \
        'lib/test/hooks.py::ProgressTests::CheckProgressHandlerUsed' \
        'lib/test/hooks.py::ProgressTests::CheckCancelOperation' \
        'lib/test/hooks.py::LimitTests::CheckGetLimit' \
        'lib/test/hooks.py::LimitTests::CheckSetLimit'
}
EOF_8df2d575e122

COPY --chmod=0644 <<'EOF_86374ab4ee03' /benchmark/format_test_log.py
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
    r"^(?P<test_id>lib/\S+)\s+"
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
EOF_86374ab4ee03

COPY --chmod=0644 <<'EOF_ded51a817fc4' /benchmark/pysqlite_unittest_nodes.py
"""Execute complete upstream unittest cases without rewriting their bodies (Python2 compatible)."""
from __future__ import print_function
import ctypes
import importlib
import resource
import sys
import unittest

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError('Could not disable process dumpability')
collect = '--collect-only' in sys.argv[1:]
nodes = [n for n in sys.argv[1:] if n != '--collect-only']
if not nodes or len(nodes) != len(set(nodes)):
    raise ValueError('Unique original unittest node IDs required')
suite = unittest.TestSuite()
node_by_test = {}
for node in nodes:
    path, cls, method = node.split('::')
    if not path.startswith('lib/test/') or not path.endswith('.py') or not method.startswith('Check'):
        raise ValueError('Expected original pysqlite Check method')
    module = importlib.import_module('pysqlite2.test.' + path[len('lib/test/'):-3])
    if not module.__file__.startswith('/testbed/build/lib.linux-x86_64-2.7/pysqlite2/test/'):
        raise RuntimeError('Unexpected original module path')
    case = getattr(module, cls)(method)
    node_by_test[case.id()] = node
    suite.addTest(case)
if collect:
    for node in nodes:
        print(node)
    sys.exit(0)

class CanonicalResult(unittest.TextTestResult):
    def record(self, case, status):
        print(node_by_test[case.id()] + ' ' + status)
        sys.stdout.flush()
    def addSuccess(self, case):
        unittest.TextTestResult.addSuccess(self, case)
        self.record(case, 'PASSED')
    def addFailure(self, case, err):
        unittest.TextTestResult.addFailure(self, case, err)
        self.record(case, 'FAILED')
    def addError(self, case, err):
        unittest.TextTestResult.addError(self, case, err)
        self.record(case, 'ERROR')
    def addSkip(self, case, reason):
        unittest.TextTestResult.addSkip(self, case, reason)
        self.record(case, 'SKIPPED')

result = unittest.TextTestRunner(stream=sys.stdout, verbosity=2, resultclass=CanonicalResult).run(suite)
sys.exit(0 if result.wasSuccessful() else 1)
EOF_ded51a817fc4
