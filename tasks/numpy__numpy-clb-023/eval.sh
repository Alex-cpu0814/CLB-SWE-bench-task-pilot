#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "70b773e4015b4fbb61bc1f7bdffc9cc789d58e94" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_multiarray.py b/numpy/core/tests/test_multiarray.py
index 77534c1..241f8e4 100644
--- a/numpy/core/tests/test_multiarray.py
+++ b/numpy/core/tests/test_multiarray.py
@@ -7729,6 +7729,8 @@ class TestWritebackIfCopy(object):
         # uses arr_insert
         np.place(a, a>2, [44, 55])
         assert_equal(a, np.array([[0, 44], [1, 55], [2, 44]]))
+        # hit one of the failing paths
+        assert_raises(ValueError, np.place, a, a>20, [])
 
     def test_put_noncontiguous(self):
         a = np.arange(6).reshape(2,3).T # force non-c-contiguous
CLB_TEST_PATCH

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
