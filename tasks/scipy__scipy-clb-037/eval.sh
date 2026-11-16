#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "bf05e8d3412e2d96ab6735b6935e2a65f2620c30" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/ndimage/tests/test_regression.py b/scipy/ndimage/tests/test_regression.py
index a824679..28d7553 100644
--- a/scipy/ndimage/tests/test_regression.py
+++ b/scipy/ndimage/tests/test_regression.py
@@ -16,5 +16,19 @@ def test_zoom_output_shape():
     x = np.arange(12).reshape((3,4))
     ndimage.zoom(x, 2, output=np.zeros((6,8)))
 
+def test_ticket_742():
+    def SE(img, thresh=.7, size=4):
+        mask = img > thresh
+        rank = len(mask.shape)
+        la, co = ndimage.label(mask,
+                               ndimage.generate_binary_structure(rank, rank))
+        slices = ndimage.find_objects(la)
+
+    if np.dtype(np.intp) != np.dtype('i'):
+        shape=(3,1240,1240)
+        a = np.random.rand(np.product(shape)).reshape(shape)
+        # shouldn't crash
+        SE(a)
+
 if __name__ == "__main__":
     run_module_suite()
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
