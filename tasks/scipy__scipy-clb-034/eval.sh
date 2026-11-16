#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "9529e47630be8f2345fd3d54302f248ce309d8cd" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
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
