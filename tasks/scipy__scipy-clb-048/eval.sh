#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "018986cb0260881827c6ef33cd2d804f54e39c85" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/signal/tests/test_signaltools.py b/scipy/signal/tests/test_signaltools.py
index 2b5cc6a0..bd64fcff 100644
--- a/scipy/signal/tests/test_signaltools.py
+++ b/scipy/signal/tests/test_signaltools.py
@@ -1062,6 +1062,17 @@ class TestMedFilt:
         assert_equal(signal.medfilt(in_typed).dtype, dtype)
         assert_equal(signal.medfilt2d(in_typed).dtype, dtype)
 
+    @pytest.mark.parametrize('dtype', [np.bool_, np.cfloat, np.cdouble,
+                                       np.clongdouble, np.float16,])
+    def test_invalid_dtypes(self, dtype):
+        in_typed = np.array(self.IN, dtype=dtype)
+        with pytest.raises(ValueError, match="order_filterND"):
+            signal.medfilt(in_typed)
+
+        with pytest.raises(ValueError, match="order_filterND"):
+            signal.medfilt2d(in_typed)
+
+
     def test_none(self):
         # gh-1651, trac #1124. Ensure this does not segfault.
         with pytest.warns(UserWarning):
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
