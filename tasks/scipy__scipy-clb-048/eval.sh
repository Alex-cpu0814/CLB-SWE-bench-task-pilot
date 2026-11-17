#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "018986cb0260881827c6ef33cd2d804f54e39c85" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/signal/tests/test_signaltools.py b/scipy/signal/tests/test_signaltools.py
index 2b5cc6a0..bd64fcff 100644
--- a/scipy/signal/tests/test_signaltools.py
+++ b/scipy/signal/tests/test_signaltools.py
@@ -1062,6 +1062,17 @@ class TestMedFilt:
         assert_equal(signal.medfilt(in_typed).dtype, dtype)
         assert_equal(signal.medfilt2d(in_typed).dtype, dtype)
 
+    @pytest.mark.parametrize('dtype', [np.bool_, np.cfloat, np.cdouble,
+                                       np.clongdouble, np.float16,])
+    def test_invalid_dtypes(self, dtype):
+        in_typed = np.array(self.IN, dtype=dtype)
+        with pytest.raises(ValueError, match="order_filterND"):
+            signal.medfilt(in_typed)
+
+        with pytest.raises(ValueError, match="order_filterND"):
+            signal.medfilt2d(in_typed)
+
+
     def test_none(self):
         # gh-1651, trac #1124. Ensure this does not segfault.
         with pytest.warns(UserWarning):
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_88d0fd028000' || fail 'Cannot write /benchmark/case_adapter.sh'
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
cat > /benchmark/format_test_log.py <<'EOF_499bbb31acab' || fail 'Cannot write /benchmark/format_test_log.py'
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
cat > /benchmark/pytest_case048_isolated.py <<'EOF_37b91596f41a' || fail 'Cannot write /benchmark/pytest_case048_isolated.py'
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
