#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "71c90cdb76cd8b12a0969f5d6314315bd0223c28" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/freetype_test.py b/test/freetype_test.py
index e0b8803ff..34dc48726 100644
--- a/test/freetype_test.py
+++ b/test/freetype_test.py
@@ -126,7 +126,7 @@ class FreeTypeFontTest(unittest.TestCase):
         self.assertRaises(OverflowError, ft.Font, file=None, size=-1)
 
         f = ft.Font(None, size=24)
-        self.assert_(f.height > 0)
+        self.assertTrue(f.height > 0)
         self.assertRaises(IOError, f.__init__,
                           os.path.join(FONTDIR, 'nonexistant.ttf'))
 
@@ -1423,6 +1423,26 @@ class FreeTypeFontTest(unittest.TestCase):
         self.assertRaises(pygame.error, f.render_to,
                           null_surface, (0, 0), "Crash!", size=12)
 
+    def test_issue_565(self):
+        """get_metrics supporting rotation/styles/size"""
+
+        tests = [
+            {'method': 'size', 'value': 36, 'msg': 'metrics same for size'},
+            {'method': 'rotation', 'value': 90, 'msg': 'metrics same for rotation'},
+            {'method': 'oblique', 'value': True, 'msg': 'metrics same for oblique'}
+        ]
+        text = "|"
+
+        def run_test(method, value, msg):
+            font = ft.Font(self._sans_path, size=24)
+            before = font.get_metrics(text)
+            font.__setattr__(method, value)
+            after = font.get_metrics(text)
+            self.assertNotEqual(before, after, msg)
+
+        for test in tests:
+            run_test(*test.values())
+
 
 class FreeTypeTest(unittest.TestCase):
 
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_338d213b8e8c' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    bash -c 'python setup.py build --build-lib /testbed/build/local --build-temp /testbed/build/temp --force > /tmp/pygame-build-buffer.raw.log 2>&1; rc=$?; cat /tmp/pygame-build-buffer.raw.log; exit "$rc"' && cp src_py/freesansbold.ttf /testbed/build/local/pygame/freesansbold.ttf
}

run_project_tests() {
    bash -c 'xvfb-run -a "$@"; rc=$?; exit "$rc"' -- python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_size' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_scalable' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_fixed_width' \
        'test/freetype_test.py::FreeTypeFontTest::test_issue_565'
}
EOF_338d213b8e8c
cat > /benchmark/format_test_log.py <<'EOF_c7734a8368ee' || fail 'Cannot write /benchmark/format_test_log.py'
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
    r"^(?P<test_id>test/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[.*\])?$"
)

def normalize_status(raw_status):
    if raw_status == "ok":
        return "PASSED"
    if raw_status == "FAIL":
        return "FAILED"
    if raw_status == "ERROR":
        return "ERROR"
    if raw_status.startswith("skipped"):
        return "SKIPPED"
    return "UNKNOWN"

def parse_test_log(text):
    statuses = {}
    pending = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        pytest_match = PYTEST_LINE.match(line)
        if pytest_match:
            statuses[pytest_match.group("test_id")] = pytest_match.group("status")
            pending = None
            continue
        match = TEST_LINE.match(line)
        if not match:
            if pending and (line in ("ok", "FAIL", "ERROR") or line.startswith("skipped")):
                statuses[pending] = normalize_status(line)
                pending = None
                continue
            start = TEST_START_LINE.match(line)
            if start:
                pending = "{}.{}".format(start.group("class"), start.group("method"))
            continue
        test_id = "{}.{}".format(match.group("class"), match.group("method"))
        statuses[test_id] = normalize_status(match.group("status"))
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_c7734a8368ee
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
