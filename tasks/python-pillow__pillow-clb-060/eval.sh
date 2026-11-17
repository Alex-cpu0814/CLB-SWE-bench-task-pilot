#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "d0612030a0ba7aed533e1f9115bbf4bd1019f48e" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Tests/test_image.py b/Tests/test_image.py
index 3fa071b..30d093e 100644
--- a/Tests/test_image.py
+++ b/Tests/test_image.py
@@ -524,7 +524,7 @@ class TestImage:
 
         # Arrange
         target_file = "Tests/images/linear_gradient.png"
-        for mode in ["L", "P"]:
+        for mode in ["L", "P", "I", "F"]:
 
             # Act
             im = Image.linear_gradient(mode)
@@ -550,7 +550,7 @@ class TestImage:
 
         # Arrange
         target_file = "Tests/images/radial_gradient.png"
-        for mode in ["L", "P"]:
+        for mode in ["L", "P", "I", "F"]:
 
             # Act
             im = Image.radial_gradient(mode)
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_f31757e7fe14' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext -i --force
}

run_project_tests() {
    python /benchmark/pytest_case060_isolated.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_image.py::TestImage::test_linear_gradient_wrong_mode' \
        'Tests/test_image.py::TestImage::test_radial_gradient_wrong_mode' \
        'Tests/test_image.py::TestImage::test_linear_gradient' \
        'Tests/test_image.py::TestImage::test_radial_gradient'
}
EOF_f31757e7fe14
cat > /benchmark/format_test_log.py <<'EOF_9e31086cf35d' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

import json

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
        if "ISOLATED_NODE_RESULT " in line:
            process = json.loads(line.split("ISOLATED_NODE_RESULT ", 1)[1])
            if (process.get("returncode") == -11
                    and process.get("signal") == "SIGSEGV"
                    and process.get("node", "").startswith("Tests/")):
                statuses[process["node"]] = "FAILED"
                pending = None
                continue
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
EOF_9e31086cf35d
cat > /benchmark/pytest_case060_isolated.py <<'EOF_79d442f391a4' || fail 'Cannot write /benchmark/pytest_case060_isolated.py'
"""Run unchanged official nodes in separate processes, preserving native crash evidence."""
import ctypes
import json
import resource
import signal
import subprocess
import sys

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError('Could not disable process dumpability')
args = sys.argv[1:]
nodes = [x for x in args if x.startswith('Tests/') and '::' in x]
options = [x for x in args if x not in nodes]
if '--collect-only' in args:
    sys.exit(subprocess.call([sys.executable, '/benchmark/pytest_no_dump.py'] + args))
failed = False
for node in nodes:
    print('ISOLATED_NODE_BEGIN ' + node, flush=True)
    result = subprocess.run([sys.executable, '/benchmark/pytest_no_dump.py'] + options + [node])
    details = {'node': node, 'returncode': result.returncode, 'signal': signal.Signals(-result.returncode).name if result.returncode < 0 else None}
    print('ISOLATED_NODE_RESULT ' + json.dumps(details), flush=True)
    if result.returncode < 0:
        print(node + ' FAILED (official test process terminated by ' + details['signal'] + ')', flush=True)
    elif result.returncode != 0 and result.returncode != 1:
        raise RuntimeError('Unexpected pytest process exit: ' + json.dumps(details))
    failed = failed or result.returncode != 0
sys.exit(1 if failed else 0)
EOF_79d442f391a4
cat > /benchmark/pytest_no_dump.py <<'EOF_df4aa13b0e5b' || fail 'Cannot write /benchmark/pytest_no_dump.py'
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
