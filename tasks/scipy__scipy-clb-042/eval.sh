#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "8c7973148c5dea4a28e0e082f8c1f182313b72c1" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/signal/tests/test_bsplines.py b/scipy/signal/tests/test_bsplines.py
index 57524eb..4d77918 100644
--- a/scipy/signal/tests/test_bsplines.py
+++ b/scipy/signal/tests/test_bsplines.py
@@ -4,9 +4,11 @@ from numpy import array
 from numpy.testing import (assert_equal,
                            assert_allclose, assert_array_equal,
                            assert_almost_equal)
+import pytest
 from pytest import raises
 
 import scipy.signal.bsplines as bsp
+from scipy import signal
 
 
 class TestBSplines(object):
@@ -226,3 +228,33 @@ class TestBSplines(object):
                       7.32718426, 7.874, 7.81016848, 7.433, 7.03980488, 6.759,
                       6.71900226, 6.203, 4.49418159])
         assert_allclose(bsp.qspline1d_eval(cj, newx, dx=dx, x0=x[0]), newy)
+
+
+def test_sepfir2d_invalid_filter():
+    filt = np.array([1.0, 2.0, 4.0, 2.0, 1.0])
+    image = np.random.rand(7, 9)
+    # No error for odd lengths
+    signal.sepfir2d(image, filt, filt[2:])
+
+    # Row or column filter must be odd
+    with pytest.raises(ValueError, match="odd length"):
+        signal.sepfir2d(image, filt, filt[1:])
+    with pytest.raises(ValueError, match="odd length"):
+        signal.sepfir2d(image, filt[1:], filt)
+
+    # Filters must be 1-dimensional
+    with pytest.raises(ValueError, match="object too deep"):
+        signal.sepfir2d(image, filt.reshape(1, -1), filt)
+    with pytest.raises(ValueError, match="object too deep"):
+        signal.sepfir2d(image, filt, filt.reshape(1, -1))
+
+def test_sepfir2d_invalid_image():
+    filt = np.array([1.0, 2.0, 4.0, 2.0, 1.0])
+    image = np.random.rand(8, 8)
+
+    # Image must be 2 dimensional
+    with pytest.raises(ValueError, match="object too deep"):
+        signal.sepfir2d(image.reshape(4, 4, 4), filt, filt)
+
+    with pytest.raises(ValueError, match="object of too small depth"):
+        signal.sepfir2d(image[0], filt, filt)
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
