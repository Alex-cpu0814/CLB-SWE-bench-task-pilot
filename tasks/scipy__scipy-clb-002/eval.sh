#!/bin/bash
set -uxo pipefail
set +x
ulimit -c 0
cd /testbed || exit 2
fail() {
    printf '%s\n' ">>>>> Tests Errored" "$1" >&2
    exit 2
}
[[ "$(git rev-parse HEAD)" == "ff177d92b79167eb5de593c9de41d3ceb97ab189" ]] || fail "Unexpected Base commit"
git apply --check --whitespace=nowarn - <<'CLB_TEST_PATCH'
diff --git a/scipy/ndimage/tests/test_interpolation.py b/scipy/ndimage/tests/test_interpolation.py
index 6563210..389c0ad 100644
--- a/scipy/ndimage/tests/test_interpolation.py
+++ b/scipy/ndimage/tests/test_interpolation.py
@@ -1107,19 +1107,45 @@ class TestNdimageInterpolation:
         out = ndimage.zoom(arr, zoom)
         assert_array_equal(out.shape, (4, 15, 29))
 
-    @pytest.mark.parametrize('zoom', [(1, 1), (8, 2), (8, 8)])
+    @pytest.mark.parametrize('zoom', [(1, 1), (3, 5), (8, 2), (8, 8)])
     @pytest.mark.parametrize('mode', ['nearest', 'constant', 'wrap', 'reflect',
                                       'mirror', 'grid-wrap', 'grid-mirror',
                                       'grid-constant'])
     def test_zoom_by_int_order0(self, zoom, mode):
         # order 0 zoom should be the same as replication via numpy.kron
+        # Note: This is not True for general x shapes when grid_mode is False,
+        #       but works here for all modes because the size ratio happens to
+        #       always be an integer when x.shape = (2, 2).
         x = numpy.array([[0, 1],
                          [2, 3]], dtype=float)
+        # x = numpy.arange(16, dtype=float).reshape(4, 4)
         assert_array_almost_equal(
             ndimage.zoom(x, zoom, order=0, mode=mode),
             numpy.kron(x, numpy.ones(zoom))
         )
 
+    @pytest.mark.parametrize('shape', [(2, 3), (4, 4)])
+    @pytest.mark.parametrize('zoom', [(1, 1), (3, 5), (8, 2), (8, 8)])
+    @pytest.mark.parametrize('mode', ['nearest', 'reflect', 'mirror',
+                                      'grid-wrap', 'grid-constant'])
+    def test_zoom_grid_by_int_order0(self, shape, zoom, mode):
+        # When grid_mode is True,  order 0 zoom should be the same as
+        # replication via numpy.kron. The only exceptions to this are the
+        # non-grid modes 'constant' and 'wrap'.
+        x = numpy.arange(numpy.prod(shape), dtype=float).reshape(shape)
+        assert_array_almost_equal(
+            ndimage.zoom(x, zoom, order=0, mode=mode, grid_mode=True),
+            numpy.kron(x, numpy.ones(zoom))
+        )
+
+    @pytest.mark.parametrize('mode', ['constant', 'wrap'])
+    def test_zoom_grid_mode_warnings(self, mode):
+        # Warn on use of non-grid modes when grid_mode is True
+        x = numpy.arange(9, dtype=float).reshape((3, 3))
+        with pytest.warns(UserWarning,
+                          match="It is recommended to use mode"):
+            ndimage.zoom(x, 2, mode=mode, grid_mode=True),
+
     @pytest.mark.parametrize('order', range(0, 6))
     def test_rotate01(self, order):
         data = numpy.array([[0, 0, 0, 0],
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch does not apply"
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH'
diff --git a/scipy/ndimage/tests/test_interpolation.py b/scipy/ndimage/tests/test_interpolation.py
index 6563210..389c0ad 100644
--- a/scipy/ndimage/tests/test_interpolation.py
+++ b/scipy/ndimage/tests/test_interpolation.py
@@ -1107,19 +1107,45 @@ class TestNdimageInterpolation:
         out = ndimage.zoom(arr, zoom)
         assert_array_equal(out.shape, (4, 15, 29))
 
-    @pytest.mark.parametrize('zoom', [(1, 1), (8, 2), (8, 8)])
+    @pytest.mark.parametrize('zoom', [(1, 1), (3, 5), (8, 2), (8, 8)])
     @pytest.mark.parametrize('mode', ['nearest', 'constant', 'wrap', 'reflect',
                                       'mirror', 'grid-wrap', 'grid-mirror',
                                       'grid-constant'])
     def test_zoom_by_int_order0(self, zoom, mode):
         # order 0 zoom should be the same as replication via numpy.kron
+        # Note: This is not True for general x shapes when grid_mode is False,
+        #       but works here for all modes because the size ratio happens to
+        #       always be an integer when x.shape = (2, 2).
         x = numpy.array([[0, 1],
                          [2, 3]], dtype=float)
+        # x = numpy.arange(16, dtype=float).reshape(4, 4)
         assert_array_almost_equal(
             ndimage.zoom(x, zoom, order=0, mode=mode),
             numpy.kron(x, numpy.ones(zoom))
         )
 
+    @pytest.mark.parametrize('shape', [(2, 3), (4, 4)])
+    @pytest.mark.parametrize('zoom', [(1, 1), (3, 5), (8, 2), (8, 8)])
+    @pytest.mark.parametrize('mode', ['nearest', 'reflect', 'mirror',
+                                      'grid-wrap', 'grid-constant'])
+    def test_zoom_grid_by_int_order0(self, shape, zoom, mode):
+        # When grid_mode is True,  order 0 zoom should be the same as
+        # replication via numpy.kron. The only exceptions to this are the
+        # non-grid modes 'constant' and 'wrap'.
+        x = numpy.arange(numpy.prod(shape), dtype=float).reshape(shape)
+        assert_array_almost_equal(
+            ndimage.zoom(x, zoom, order=0, mode=mode, grid_mode=True),
+            numpy.kron(x, numpy.ones(zoom))
+        )
+
+    @pytest.mark.parametrize('mode', ['constant', 'wrap'])
+    def test_zoom_grid_mode_warnings(self, mode):
+        # Warn on use of non-grid modes when grid_mode is True
+        x = numpy.arange(9, dtype=float).reshape((3, 3))
+        with pytest.warns(UserWarning,
+                          match="It is recommended to use mode"):
+            ndimage.zoom(x, 2, mode=mode, grid_mode=True),
+
     @pytest.mark.parametrize('order', range(0, 6))
     def test_rotate01(self, order):
         data = numpy.array([[0, 0, 0, 0],
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch application failed"
mkdir -p /opt/clb-pilot || fail 'Cannot create evaluation fixture directory'
cat > /opt/clb-pilot/case_adapter.sh <<'EOF_9bb3a887e4a9' || fail 'Cannot write /opt/clb-pilot/case_adapter.sh'
#!/usr/bin/env bash

# Case-specific build and test functions sourced by run_evaluation.sh.

build_project() {
    python setup.py build_ext -i
}

run_project_tests() {
    python -m pytest -vv -W ignore::DeprecationWarning \
        scipy/ndimage/tests/test_interpolation.py
}
EOF_9bb3a887e4a9
cat > /opt/clb-pilot/normalize_results.py <<'EOF_c05e792222b6' || fail 'Cannot write /opt/clb-pilot/normalize_results.py'
"""Translate CLB test result lines to the upstream status-first format."""

import io
import re
import sys


PYTEST = re.compile(
    r"^(scipy/\S.*?)\s+(PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[\s*\d+%\])?$"
)
UNITTEST = re.compile(r"^(\S+) \(([^)]+)\) \.\.\.(?: (.*))?$")


def statuses(lines, mode):
    pending = None
    mapping = {"ok": "PASSED", "FAIL": "FAILED", "ERROR": "ERROR", "skipped": "SKIPPED"}
    for raw in lines:
        line = raw.strip()
        if mode == "pytest":
            result = PYTEST.match(line)
            if result:
                yield result.group(2), result.group(1)
            continue
        result = UNITTEST.match(line)
        if result:
            method, test_class, line = result.groups()
            if mode == "jep" and test_class.startswith("tests."):
                test_class = test_class[len("tests."):]
            pending = test_class + "." + method
            line = line or ""
        if pending and line:
            status = mapping.get("skipped" if line.startswith("skipped") else line)
            if status:
                yield status, pending
                pending = None


if __name__ == "__main__":
    with io.open(sys.argv[2], encoding="utf-8", errors="replace") as stream:
        for status, test_id in statuses(stream, sys.argv[1]):
            print("{} {}".format(status, test_id))
EOF_c05e792222b6
source /opt/clb-pilot/case_adapter.sh || fail "Cannot load the case adapter"
build_project || fail "Project build failed"
raw_log=$(mktemp) || fail "Cannot create a test log"
trap 'rm -f "$raw_log"' EXIT
run_project_tests >"$raw_log" 2>&1
test_status=$?
cat "$raw_log"
printf '%s\n' '>>>>> Start Test Output'
emit_results() {
    python /opt/clb-pilot/normalize_results.py pytest "$raw_log" || return 2
    return "$test_status"
}
emit_results
printf '%s\n' '>>>>> End Test Output'
exit "$test_status"
