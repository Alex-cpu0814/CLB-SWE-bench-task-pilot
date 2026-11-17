#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "afee8cfba448e8c6c100afc6015d31c6aa37e172" ]] || fail 'Unexpected Base commit'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_fcaacd0fec29' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext --inplace --force
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -vv \
        'tests/test_pattern.py::test_raster_source' \
        'tests/test_pattern.py::test_cmp_hash' \
        'tests/test_pattern.py::test_get_extend' \
        'tests/test_pattern.py::test_get_filter'
}
EOF_fcaacd0fec29
cat > /benchmark/format_test_log.py <<'EOF_c1d968746dbb' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)

TEST_START_LINE = re.compile(r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. .*")

PYTEST_LINE = re.compile(
    r"^(?P<test_id>tests/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[.*\])?$"
)

def parse_test_log(text):
    # Official wrapper owns terminal statuses after checking true child results.
    # Human-readable bundled-unittest output is retained but is not a second ID.
    statuses = {}
    for line in text.splitlines():
        match = PYTEST_LINE.match(line)
        if match and match.end() == len(line):
            statuses[match.group("test_id")] = match.group("status")
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_c1d968746dbb
cat > /benchmark/pytest_no_dump.py <<'EOF_df4aa13b0e5b' || fail 'Cannot write /benchmark/pytest_no_dump.py'
"""Run official pytest nodes without producing host-side Linux/WSL core dumps."""
import ctypes
import resource
import sys

import pytest

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError("Could not disable process dumpability")
sys.exit(pytest.main(sys.argv[1:]))
EOF_df4aa13b0e5b
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
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
