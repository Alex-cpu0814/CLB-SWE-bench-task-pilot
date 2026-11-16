#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "e13278e712ac33c6110b5d48a8da0acfa7768b71" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/interpolate/tests/test_fitpack.py b/scipy/interpolate/tests/test_fitpack.py
index 7b90c36..c2179a4 100644
--- a/scipy/interpolate/tests/test_fitpack.py
+++ b/scipy/interpolate/tests/test_fitpack.py
@@ -459,6 +459,19 @@ def test_splev_der_k():
     assert_allclose(splev(x, (t, c, k), k), splev(x, tck2))
 
 
+def test_splprep_segfault():
+    # regression test for gh-3847: splprep segfaults if knots are specified
+    # for task=-1
+    t = np.arange(0, 1.1, 0.1)
+    x = np.sin(2*np.pi*t)
+    y = np.cos(2*np.pi*t)
+    tck, u = interpolate.splprep([x, y], s=0)
+    unew = np.arange(0, 1.01, 0.01)
+
+    uknots = tck[0]  # using the knots from the previous fitting
+    tck, u = interpolate.splprep([x, y], task=-1, t=uknots)  # here is the crash
+
+
 def test_bisplev_integer_overflow():
     np.random.seed(1)
 
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
