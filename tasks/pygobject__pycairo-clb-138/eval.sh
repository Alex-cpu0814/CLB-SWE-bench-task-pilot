#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "afee8cfba448e8c6c100afc6015d31c6aa37e172" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/test_pattern.py b/tests/test_pattern.py
index ff538df..4263516 100644
--- a/tests/test_pattern.py
+++ b/tests/test_pattern.py
@@ -2,6 +2,52 @@ import cairo
 import pytest
 
 
+def test_raster_source():
+    pattern = cairo.RasterSourcePattern(cairo.Content.COLOR, 2, 2)
+    assert isinstance(pattern, cairo.RasterSourcePattern)
+    assert issubclass(cairo.RasterSourcePattern, cairo.Pattern)
+
+    was_called = []
+
+    def acquire_callback(pattern, target, extents):
+        surface = target.create_similar_image(
+            cairo.FORMAT_ARGB32, extents.width, extents.height)
+        surface.set_device_offset(extents.x, extents.y)
+        context = cairo.Context(surface)
+        context.set_source_rgb(1, 0, 0)
+        context.paint()
+        was_called.append("acquire")
+        return surface
+
+    def release_callback(surface):
+        was_called.append("release")
+        return None
+
+    pattern.set_acquire(None, release_callback)
+    assert pattern.get_acquire() == (None, release_callback)
+
+    pattern.set_acquire(acquire_callback, None)
+    assert pattern.get_acquire() == (acquire_callback, None)
+
+    pattern.set_acquire(None, None)
+    assert pattern.get_acquire() == (None, None)
+
+    pattern.set_acquire(acquire_callback, release_callback)
+    assert pattern.get_acquire() == (acquire_callback, release_callback)
+
+    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 10, 10)
+    context = cairo.Context(surface)
+    context.set_source(pattern)
+    context.paint()
+    assert was_called == ["acquire", "release"]
+
+    with pytest.raises(TypeError):
+        pattern.set_acquire(None, object())
+
+    with pytest.raises(TypeError):
+        pattern.set_acquire(object(), None)
+
+
 def test_cmp_hash():
     surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 10, 10)
     context = cairo.Context(surface)
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
