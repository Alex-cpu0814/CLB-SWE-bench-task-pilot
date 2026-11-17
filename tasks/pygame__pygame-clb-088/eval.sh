#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "cd173f0ebf77e2b652de1a20a5f3eccf78e8cf12" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/surface_test.py b/test/surface_test.py
index 19f30d83f..4bf24c907 100644
--- a/test/surface_test.py
+++ b/test/surface_test.py
@@ -165,6 +165,15 @@ class SurfaceTypeTest(unittest.TestCase):
         self.assertEqual(bound_rect.width, 31)
         self.assertEqual(bound_rect.height, 31)
 
+        # Issue #180
+        pygame.display.init()
+        try:
+            surf = pygame.Surface((4, 1), 0, 8)
+            surf.fill((255, 255, 255))
+            surf.get_bounding_rect()  # Segfault.
+        finally:
+            pygame.quit()
+
     def test_copy(self):
 
         # __doc__ (as of 2008-06-25) for pygame.surface.Surface.copy:
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_7dfd97fd00de' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    bash -c 'python setup.py build --build-lib /testbed/build/local --build-temp /testbed/build/temp --force > /tmp/pygame-build-buffer.raw.log 2>&1; rc=$?; cat /tmp/pygame-build-buffer.raw.log; exit "$rc"' && cp lib/freesansbold.ttf /testbed/build/local/pygame/freesansbold.ttf
}

run_project_tests() {
    python /benchmark/legacy_unittest088.py \
        'test/surface_test.py::SurfaceTypeTest::test_copy' \
        'test/surface_test.py::SurfaceTypeTest::test_get_bytesize' \
        'test/surface_test.py::SurfaceTypeTest::test_get_rect' \
        'test/surface_test.py::SurfaceTypeTest::test_get_bounding_rect'
}
EOF_7dfd97fd00de
cat > /benchmark/format_test_log.py <<'EOF_fb38b443dc0a' || fail 'Cannot write /benchmark/format_test_log.py'
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
    r"^(?P<test_id>test/\S+)\s+"
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
EOF_fb38b443dc0a
cat > /benchmark/legacy_unittest088.py <<'EOF_4999bf968bfd' || fail 'Cannot write /benchmark/legacy_unittest088.py'
"""Run unchanged upstream bundled-unittest methods with explicit process results."""
import argparse
import base64
import ctypes
import importlib
import json
import signal
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, '/testbed')
ctypes.CDLL(None).prctl(4, 0, 0, 0, 0)
parser = argparse.ArgumentParser()
parser.add_argument('--collect-only', action='store_true')
parser.add_argument('--child', action='store_true')
parser.add_argument('nodes', nargs='+')
args = parser.parse_args()

def load(node):
    file, classname, method = node.split('::')
    module = importlib.import_module(file[:-3].replace('/', '.'))
    cls = getattr(module, classname)
    assert callable(getattr(cls, method)), node
    loader = module.unittest.TestLoader()
    loader.testMethodPrefix = method
    suite = loader.loadTestsFromTestCase(cls)
    assert suite.countTestCases() == 1, node
    return module, suite

if args.collect_only:
    for node in args.nodes:
        load(node)
        print(node, flush=True)
    sys.exit(0)

if args.child:
    assert len(args.nodes) == 1
    node = args.nodes[0]
    module, suite = load(node)
    print('OFFICIAL_TEST_START ' + node, flush=True)
    result = module.unittest.TextTestRunner(stream=sys.stderr, verbosity=2).run(suite)
    assert result.testsRun == 1
    print('OFFICIAL_RESULT ' + json.dumps({'node': node, 'testsRun': result.testsRun,
        'failures': len(result.failures), 'errors': len(result.errors),
        'status': 'PASSED' if result.wasSuccessful() else 'FAILED'}), flush=True)
    sys.exit(0 if result.wasSuccessful() else 1)

failed = infrastructure = False
for node in args.nodes:
    child = subprocess.run([sys.executable, __file__, '--child', node], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    sys.stdout.buffer.write(child.stdout)
    sys.stderr.buffer.write(child.stderr)
    sys.stdout.flush()
    sys.stderr.flush()
    print('OFFICIAL_PROCESS_RECORD ' + json.dumps({'node': node, 'returncode': child.returncode,
        'stdout_base64': base64.b64encode(child.stdout).decode('ascii'),
        'stderr_base64': base64.b64encode(child.stderr).decode('ascii')}), flush=True)
    lines = child.stdout.decode('utf-8', errors='replace').splitlines()
    records = [json.loads(line[len('OFFICIAL_RESULT '):]) for line in lines if line.startswith('OFFICIAL_RESULT ')]
    if len(records) == 1 and records[0]['node'] == node and records[0]['testsRun'] == 1:
        status = records[0]['status']
        if child.returncode != (0 if status == 'PASSED' else 1):
            status = 'ERROR'
            infrastructure = True
    elif child.returncode in (-signal.SIGSEGV, -signal.SIGABRT) and 'OFFICIAL_TEST_START ' + node in lines:
        status = 'FAILED'
        print('OFFICIAL_NATIVE_FAILURE ' + json.dumps({'node': node, 'returncode': child.returncode,
            'signal': signal.Signals(-child.returncode).name}), flush=True)
    else:
        status = 'ERROR'
        infrastructure = True
        print('OFFICIAL_RESULT_MISSING ' + json.dumps({'node': node, 'returncode': child.returncode}), flush=True)
    print(node + ' ' + status, flush=True)
    failed |= status != 'PASSED'
sys.exit(2 if infrastructure else 1 if failed else 0)
EOF_4999bf968bfd
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
mkdir -p /results || fail 'Cannot create test output directory'
build_project || fail 'Project build failed'
run_project_tests >/results/tests.raw.log 2>&1
test_status=$?
cat /results/tests.raw.log

parser_python=$(command -v python || command -v python3 || command -v python2.7) \
    || fail 'Cannot find Python for test log conversion'
printf '%s\n' '>>>>> Start Test Output'
PYTHONIOENCODING=utf-8 "$parser_python" /benchmark/format_test_log.py /results/tests.raw.log \
    || fail 'Cannot convert test output'
(exit "$test_status")
printf '%s\n' '>>>>> End Test Output'
exit "$test_status"
