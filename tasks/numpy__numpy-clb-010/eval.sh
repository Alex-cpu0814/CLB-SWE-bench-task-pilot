#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "5e8ad11b75245caf2d158eacf369b011ef262795" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_multiarray.py b/numpy/core/tests/test_multiarray.py
index f36c27c..a698370 100644
--- a/numpy/core/tests/test_multiarray.py
+++ b/numpy/core/tests/test_multiarray.py
@@ -1582,6 +1582,11 @@ class TestMethods:
         # gh-12031, caused SEGFAULT
         assert_raises(TypeError, oned.choose,np.void(0), [oned])
 
+        out = np.array(0)
+        ret = np.choose(np.array(1), [10, 20, 30], out=out)
+        assert out is ret
+        assert_equal(out[()], 20)
+
         # gh-6272 check overlap on out
         x = np.arange(5)
         y = np.choose([0,0,0], [x[:3], x[:3], x[:3]], out=x[1:4], mode='wrap')
@@ -1658,7 +1663,7 @@ class TestMethods:
             out = np.zeros_like(arr)
             res = arr.round(*round_args, out=out)
             assert_equal(out, expected)
-            assert_equal(out, res)
+            assert out is res
 
         check_round(np.array([1.2, 1.5]), [1, 2])
         check_round(np.array(1.5), 2)
@@ -3023,6 +3028,10 @@ class TestMethods:
         assert_equal(b.trace(0, 1, 2), [3, 11])
         assert_equal(b.trace(offset=1, axis1=0, axis2=2), [1, 3])
 
+        out = np.array(1)
+        ret = a.trace(out=out)
+        assert ret is out
+
     def test_trace_subclass(self):
         # The class would need to overwrite trace to ensure single-element
         # output also has the right subclass.
@@ -4126,6 +4135,13 @@ class TestArgmax:
         a.argmax(-1, out=out)
         assert_equal(out, a.argmax(-1))
 
+    @pytest.mark.parametrize('ndim', [0, 1])
+    def test_ret_is_out(self, ndim):
+        a = np.ones((4,) + (3,)*ndim)
+        out = np.empty((3,)*ndim, dtype=np.intp)
+        ret = a.argmax(axis=0, out=out)
+        assert ret is out
+
     def test_argmax_unicode(self):
         d = np.zeros(6031, dtype='<U9')
         d[5942] = "as"
@@ -4275,6 +4291,13 @@ class TestArgmin:
         a.argmin(-1, out=out)
         assert_equal(out, a.argmin(-1))
 
+    @pytest.mark.parametrize('ndim', [0, 1])
+    def test_ret_is_out(self, ndim):
+        a = np.ones((4,) + (3,)*ndim)
+        out = np.empty((3,)*ndim, dtype=np.intp)
+        ret = a.argmin(axis=0, out=out)
+        assert ret is out
+
     def test_argmin_unicode(self):
         d = np.ones(6031, dtype='<U9')
         d[6001] = "0"
@@ -4552,6 +4575,16 @@ class TestTake:
         y = np.take(x, [1, 2, 3], out=x[2:5], mode='wrap')
         assert_equal(y, np.array([1, 2, 3]))
 
+    @pytest.mark.parametrize('shape', [(1, 2), (1,), ()])
+    def test_ret_is_out(self, shape):
+        # 0d arrays should not be an exception to this rule
+        x = np.arange(5)
+        inds = np.zeros(shape, dtype=np.intp)
+        out = np.zeros(shape, dtype=x.dtype)
+        ret = np.take(x, inds, out=out)
+        assert ret is out
+
+
 class TestLexsort:
     @pytest.mark.parametrize('dtype',[
         np.uint8, np.uint16, np.uint32, np.uint64,
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_9927b901b70f' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.8-dbg setup.py build_ext -i --force
}

run_project_tests() {
    python3.8-dbg -m pytest -vv \
        numpy/core/tests/test_multiarray.py::TestMethods::test_choose \
        numpy/core/tests/test_multiarray.py::TestMethods::test_round \
        numpy/core/tests/test_multiarray.py::TestMethods::test_trace \
        numpy/core/tests/test_multiarray.py::TestArgmax::test_ret_is_out \
        numpy/core/tests/test_multiarray.py::TestArgmin::test_ret_is_out \
        numpy/core/tests/test_multiarray.py::TestTake::test_ret_is_out \
        numpy/core/tests/test_multiarray.py::TestTake::test_clip \
        numpy/core/tests/test_multiarray.py::TestArgmax::test_output_shape \
        numpy/core/tests/test_multiarray.py::TestMethods::test_trace_subclass
}
EOF_9927b901b70f
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
