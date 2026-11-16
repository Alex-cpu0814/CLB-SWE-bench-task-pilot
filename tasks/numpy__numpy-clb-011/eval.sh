#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "2acfd9851b6a5246e5e5e3faa97c9e728e88f8a9" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_multiarray.py b/numpy/core/tests/test_multiarray.py
index c4f1368..bf1fcc7 100644
--- a/numpy/core/tests/test_multiarray.py
+++ b/numpy/core/tests/test_multiarray.py
@@ -2161,6 +2161,8 @@ class TestMethods:
         msg = "Test real searchsorted with nans, side='r'"
         b = a.searchsorted(a, side='r')
         assert_equal(b, np.arange(1, 4), msg)
+        # check keyword arguments
+        a.searchsorted(v=1)
         # check double complex
         a = np.zeros(9, dtype=np.complex128)
         a.real += [0, 0, 1, 1, 0, 1, np.nan, np.nan, np.nan]
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
