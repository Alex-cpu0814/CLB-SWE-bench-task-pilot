#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "9529e47630be8f2345fd3d54302f248ce309d8cd" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/integrate/tests/test_integrate.py b/scipy/integrate/tests/test_integrate.py
index aa8620e..22d5bba 100644
--- a/scipy/integrate/tests/test_integrate.py
+++ b/scipy/integrate/tests/test_integrate.py
@@ -805,3 +805,31 @@ def test_odeint_bad_shapes():
     # shape of array returned by badjac(x, t) is not correct.
     assert_raises(RuntimeError, odeint, sys1, [10, 10], [0, 1], Dfun=badjac)
 
+
+def test_repeated_t_values():
+    """Regression test for gh-8217."""
+
+    def func(x, t):
+        return -0.25*x
+
+    t = np.zeros(10)
+    sol = odeint(func, [1.], t)
+    assert_array_equal(sol, np.ones((len(t), 1)))
+
+    tau = 4*np.log(2)
+    t = [0]*9 + [tau, 2*tau, 2*tau, 3*tau]
+    sol = odeint(func, [1, 2], t, rtol=1e-12, atol=1e-12)
+    expected_sol = np.array([[1.0, 2.0]]*9 +
+                            [[0.5, 1.0],
+                             [0.25, 0.5],
+                             [0.25, 0.5],
+                             [0.125, 0.25]])
+    assert_allclose(sol, expected_sol)
+
+    # Edge case: empty t sequence.
+    sol = odeint(func, [1.], [])
+    assert_array_equal(sol, np.array([], dtype=np.float64).reshape((0, 1)))
+
+    # t values are not monotonic.
+    assert_raises(ValueError, odeint, func, [1.], [0, 1, 0.5, 0])
+    assert_raises(ValueError, odeint, func, [1, 2, 3], [0, -1, -2, 3])
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_4ac3309ac469' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.8 setup.py build_ext -i
}

run_project_tests() {
    python3.8 -m pytest -vv \
        'scipy/integrate/tests/test_integrate.py::test_odeint_trivial_time' \
        'scipy/integrate/tests/test_integrate.py::test_odeint_bad_shapes' \
        'scipy/integrate/tests/test_integrate.py::test_repeated_t_values'
}
EOF_4ac3309ac469
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
