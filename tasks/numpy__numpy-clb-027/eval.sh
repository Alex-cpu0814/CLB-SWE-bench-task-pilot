#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "0fd5f2506bf2f41b023392c945312e5a1a3eb819" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/lib/tests/test_index_tricks.py b/numpy/lib/tests/test_index_tricks.py
index 3246f68..028bba3 100644
--- a/numpy/lib/tests/test_index_tricks.py
+++ b/numpy/lib/tests/test_index_tricks.py
@@ -77,6 +77,26 @@ class TestRavelUnravelIndex(object):
             [[3, 6, 6], [4, 5, 1]])
         assert_equal(np.unravel_index(1621, (6, 7, 8, 9)), [3, 1, 4, 1])
 
+    def test_empty_indices(self):
+        msg1 = 'indices must be integral: the provided empty sequence was'
+        msg2 = 'only int indices permitted'
+        assert_raises_regex(TypeError, msg1, np.unravel_index, [], (10, 3, 5))
+        assert_raises_regex(TypeError, msg1, np.unravel_index, (), (10, 3, 5))
+        assert_raises_regex(TypeError, msg2, np.unravel_index, np.array([]),
+                            (10, 3, 5))
+        assert_equal(np.unravel_index(np.array([],dtype=int), (10, 3, 5)),
+                     [[], [], []])
+        assert_raises_regex(TypeError, msg1, np.ravel_multi_index, ([], []),
+                            (10, 3))
+        assert_raises_regex(TypeError, msg1, np.ravel_multi_index, ([], ['abc']),
+                            (10, 3))
+        assert_raises_regex(TypeError, msg2, np.ravel_multi_index,
+                    (np.array([]), np.array([])), (5, 3))
+        assert_equal(np.ravel_multi_index(
+                (np.array([], dtype=int), np.array([], dtype=int)), (5, 3)), [])
+        assert_equal(np.ravel_multi_index(np.array([[], []], dtype=int),
+                     (5, 3)), [])
+
     def test_big_indices(self):
         # ravel_multi_index for big indices (issue #7546)
         if np.intp == np.int64:
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_61ace800bf60' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.8-dbg setup.py build_ext -i --force
}

run_project_tests() {
    python3.8-dbg -m pytest -vv -o markers=slow \
        'numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_big_indices' \
        'numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_dtypes' \
        'numpy/lib/tests/test_index_tricks.py::TestRavelUnravelIndex::test_empty_indices'
}
EOF_61ace800bf60
cat > /benchmark/format_test_log.py <<'EOF_a6b100428c3f' || fail 'Cannot write /benchmark/format_test_log.py'
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
    r"^(?P<test_id>numpy/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED|LEAKED)(?:\s+\[.*\])?$"
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
            status = pytest_match.group("status")
            statuses[pytest_match.group("test_id")] = (
                "FAILED" if status == "LEAKED" else status
            )
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
EOF_a6b100428c3f
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
