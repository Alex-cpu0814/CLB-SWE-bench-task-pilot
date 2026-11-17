#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "eb8b4aebe42f39f7e536a603e8cd25d9cf104e22" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/python/tests/test_highlevel.py b/python/tests/test_highlevel.py
index e76bb98..1014aa9 100644
--- a/python/tests/test_highlevel.py
+++ b/python/tests/test_highlevel.py
@@ -1887,6 +1887,18 @@ class TestTree(HighLevelTestCase):
             for tree in ts.trees():
                 self.verify_newick(tree)
 
+    def test_newick_large_times(self):
+        for n in [2, 10, 20, 100]:
+            ts = msprime.simulate(n, Ne=100e6, random_seed=1)
+            tree = ts.first()
+            for precision in [0, 1, 16]:
+                newick_py = tree.newick(
+                    node_labels={u: str(u + 1) for u in ts.samples()},
+                    precision=precision,
+                )
+                newick_c = tree.newick(precision=precision)
+                self.assertEqual(newick_c, newick_py)
+
     def test_as_dict_of_dicts(self):
         for ts in get_example_tree_sequences():
             tree = next(ts.trees())
diff --git a/python/tests/test_lowlevel.py b/python/tests/test_lowlevel.py
index 6bbad57..1679212 100644
--- a/python/tests/test_lowlevel.py
+++ b/python/tests/test_lowlevel.py
@@ -1841,10 +1841,15 @@ class TestTree(LowLevelTestCase):
         self.assertEqual(st.get_newick(0), b"1;")
         for bad_type in [None, "", [], {}]:
             self.assertRaises(TypeError, st.get_newick, precision=bad_type)
-            self.assertRaises(TypeError, st.get_newick, ts, time_scale=bad_type)
+            self.assertRaises(TypeError, st.get_newick, ts, buffer_size=bad_type)
         while st.next():
-            newick = st.get_newick(st.get_left_root())
+            u = st.get_left_root()
+            newick = st.get_newick(u)
             self.assertTrue(newick.endswith(b";"))
+            with self.assertRaises(ValueError):
+                st.get_newick(u, buffer_size=-1)
+            with self.assertRaises(_tskit.LibraryError):
+                st.get_newick(u, buffer_size=1)
 
     def test_index(self):
         for ts in self.get_example_tree_sequences():
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_e80d1e45e019' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    (cd python && python setup.py build_ext --inplace)
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv \
        'python/tests/test_highlevel.py::TestTree::test_newick' \
        'python/tests/test_lowlevel.py::TestTree::test_newick_precision' \
        'python/tests/test_highlevel.py::TestTree::test_newick_large_times' \
        'python/tests/test_lowlevel.py::TestTree::test_newick_interface'
}
EOF_e80d1e45e019
cat > /benchmark/format_test_log.py <<'EOF_579e5171a672' || fail 'Cannot write /benchmark/format_test_log.py'
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
    r"^(?P<test_id>python/\S+)\s+"
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
EOF_579e5171a672
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
