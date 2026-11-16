#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "fc6b387bc0c51b5b252712584580b4f0975498fb" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/ndimage/tests/test_ndimage.py b/scipy/ndimage/tests/test_ndimage.py
index bfe9161d..9c505ae7 100644
--- a/scipy/ndimage/tests/test_ndimage.py
+++ b/scipy/ndimage/tests/test_ndimage.py
@@ -32,11 +32,12 @@ from __future__ import division, print_function, absolute_import
 
 import warnings
 import math
+import sys
 
 import numpy
 from numpy import fft
 from numpy.testing import (assert_, assert_equal, assert_array_equal,
-        run_module_suite, assert_array_almost_equal, assert_almost_equal)
+        run_module_suite, assert_array_almost_equal, assert_almost_equal, dec)
 import scipy.ndimage as ndimage
 
 
@@ -1705,6 +1706,16 @@ class TestNdimage:
         assert_array_almost_equal(out, [[0, 0], [0, 4], [0, 7]])
         assert_array_almost_equal(out, ndimage.shift(data[:,::2], (1, 1)))
 
+    # do not run on 32 bit or windows (no sparse memory)
+    @dec.skipif('win32' in sys.platform or numpy.intp(0).itemsize < 8)
+    def test_map_coordinates_large_data(self):
+        # check crash on large data
+        n = 30000
+        a = numpy.empty(n**2, dtype=numpy.float32).reshape(n, n)
+        # fill the part we might read
+        a[n - 3:,n - 3:] = 0
+        ndimage.map_coordinates(a, [[n - 1.5], [n - 1.5]], order=1)
+
     def test_affine_transform01(self):
         data = numpy.array([1])
         for order in range(0, 6):
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
