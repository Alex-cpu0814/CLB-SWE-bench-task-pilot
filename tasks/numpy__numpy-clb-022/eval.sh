#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "99953e494aa3be5ae8385d8461b9e4dfbeec43ec" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_multiarray.py b/numpy/core/tests/test_multiarray.py
index a67a291..77534c1 100644
--- a/numpy/core/tests/test_multiarray.py
+++ b/numpy/core/tests/test_multiarray.py
@@ -7009,12 +7009,11 @@ class TestArrayAttributeDeletion(object):
             assert_raises(AttributeError, delattr, a, s)
 
 
-def test_array_interface():
-    # Test scalar coercion within the array interface
+class TestArrayInterface():
     class Foo(object):
         def __init__(self, value):
             self.value = value
-            self.iface = {'typestr': '=f8'}
+            self.iface = {'typestr': 'f8'}
 
         def __float__(self):
             return float(self.value)
@@ -7023,22 +7022,39 @@ def test_array_interface():
         def __array_interface__(self):
             return self.iface
 
+
     f = Foo(0.5)
-    assert_equal(np.array(f), 0.5)
-    assert_equal(np.array([f]), [0.5])
-    assert_equal(np.array([f, f]), [0.5, 0.5])
-    assert_equal(np.array(f).dtype, np.dtype('=f8'))
-    # Test various shape definitions
-    f.iface['shape'] = ()
-    assert_equal(np.array(f), 0.5)
-    f.iface['shape'] = None
-    assert_raises(TypeError, np.array, f)
-    f.iface['shape'] = (1, 1)
-    assert_equal(np.array(f), [[0.5]])
-    f.iface['shape'] = (2,)
-    assert_raises(ValueError, np.array, f)
-
-    # test scalar with no shape
+
+    @pytest.mark.parametrize('val, iface, expected', [
+        (f, {}, 0.5),
+        ([f], {}, [0.5]),
+        ([f, f], {}, [0.5, 0.5]),
+        (f, {'shape': ()}, 0.5),
+        (f, {'shape': None}, TypeError),
+        (f, {'shape': (1, 1)}, [[0.5]]),
+        (f, {'shape': (2,)}, ValueError),
+        (f, {'strides': ()}, 0.5),
+        (f, {'strides': (2,)}, ValueError),
+        (f, {'strides': 16}, TypeError),
+        ])
+    def test_scalar_interface(self, val, iface, expected):
+        # Test scalar coercion within the array interface
+        self.f.iface = {'typestr': 'f8'}
+        self.f.iface.update(iface)
+        if HAS_REFCOUNT:
+            pre_cnt = sys.getrefcount(np.dtype('f8'))
+        if isinstance(expected, type):
+            assert_raises(expected, np.array, val)
+        else:
+            result = np.array(val)
+            assert_equal(np.array(val), expected)
+            assert result.dtype == 'f8'
+            del result
+        if HAS_REFCOUNT:
+            post_cnt = sys.getrefcount(np.dtype('f8'))
+            assert_equal(pre_cnt, post_cnt)
+
+def test_interface_no_shape():
     class ArrayLike(object):
         array = np.array(1)
         __array_interface__ = array.__array_interface__
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_178c084955be' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.8-dbg setup.py build_ext -i --force
}

run_project_tests() {
    python3.8-dbg -m pytest -vv -o markers=slow \
        'numpy/core/tests/test_multiarray.py::test_interface_no_shape' \
        'numpy/core/tests/test_multiarray.py::test_array_interface_itemsize' \
        'numpy/core/tests/test_multiarray.py::TestArrayInterface::test_scalar_interface[val6-iface6-ValueError]' \
        'numpy/core/tests/test_multiarray.py::TestArrayInterface::test_scalar_interface[val8-iface8-ValueError]' \
        'numpy/core/tests/test_multiarray.py::TestArrayInterface::test_scalar_interface[val9-iface9-TypeError]'
}
EOF_178c084955be
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
