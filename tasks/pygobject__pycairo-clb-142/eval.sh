#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "cd6b840aeab1515343a71a997b0a2ce48fce6d82" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/test_surface.py b/tests/test_surface.py
index 8aec540..00253c5 100644
--- a/tests/test_surface.py
+++ b/tests/test_surface.py
@@ -2,6 +2,7 @@
 
 import io
 import os
+import sys
 import array
 import tempfile
 import struct
@@ -10,6 +11,15 @@ import cairo
 import pytest
 
 
+def test_image_surface_get_data_refcount():
+    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 10, 10)
+    assert sys.getrefcount(surface) == 2
+    d = surface.get_data()
+    assert sys.getrefcount(surface) == 3
+    del d
+    assert sys.getrefcount(surface) == 2
+
+
 def test_surface_get_content():
     surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 10, 10)
     assert surface.get_content() == cairo.Content.COLOR_ALPHA
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
