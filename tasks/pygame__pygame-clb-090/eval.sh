#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "6e5ca4a046fde6c21b0386281e25a83b3c8f9ba3" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/freetype_test.py b/test/freetype_test.py
index 9624be274..8aa5a4fd0 100644
--- a/test/freetype_test.py
+++ b/test/freetype_test.py
@@ -1257,6 +1257,66 @@ class FreeTypeFontTest(unittest.TestCase):
         s = 'M' * 100000  # Way too long for an SDL surface
         self.assertRaises(pygame.error, font.render, s, (0, 0, 0))
 
+    def test_issue_242(self):
+        """Issue #242: get_rect() uses 0 as default style"""
+
+        # Issue #242: freetype.Font.get_rect() ignores style defaults when
+        #             the style argument is not given
+        #
+        # The text boundary rectangle returned by freetype.Font.get_rect()
+        # should match the boundary of the same text rendered directly to a
+        # surface. This permits accurate text positioning. To work properly,
+        # get_rect() should calculate the text boundary to reflect text style,
+        # such as underline. Instead, it ignores the style settings for the
+        # Font object when the style argument is omitted.
+        # 
+        # When the style argument is not given, freetype.get_rect() uses
+        # unstyled text when calculating the boundary rectangle. This is
+        # because _ftfont_getrect(), in _freetype.c, set the default
+        # style to 0 rather than FT_STYLE_DEFAULT.
+        #
+        font = self._TEST_FONTS['sans']
+
+        # Try wide style on a wide character.
+        prev_style = font.wide
+        font.wide = True
+        try:
+            rect = font.get_rect('M', size=64)
+            surf, rrect = font.render(None, size=64)
+            self.assertEqual(rect, rrect)
+        finally:
+            font.wide = prev_style
+
+        # Try strong style on several wide characters.
+        prev_style = font.strong
+        font.strong = True
+        try:
+            rect = font.get_rect('Mm_', size=64)
+            surf, rrect = font.render(None, size=64)
+            self.assertEqual(rect, rrect)
+        finally:
+            font.strong = prev_style
+
+        # Try oblique style on a tall, narrow character.
+        prev_style = font.oblique
+        font.oblique = True
+        try:
+            rect = font.get_rect('|', size=64)
+            surf, rrect = font.render(None, size=64)
+            self.assertEqual(rect, rrect)
+        finally:
+            font.oblique = prev_style
+
+        # Try underline style on a glyphless character.
+        prev_style = font.underline
+        font.underline = True
+        try:
+            rect = font.get_rect('  ', size=64)
+            surf, rrect = font.render(None, size=64)
+            self.assertEqual(rect, rrect)
+        finally:
+            font.underline = prev_style
+
     def test_garbage_collection(self):
         """Check reference counting on returned new references"""
         def ref_items(seq):
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_6863cac7573d' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    bash -c 'python setup.py build --build-lib /testbed/build/local --build-temp /testbed/build/temp --force > /tmp/pygame-build-buffer.raw.log 2>&1; rc=$?; cat /tmp/pygame-build-buffer.raw.log; exit "$rc"' && cp lib/freesansbold.ttf /testbed/build/local/pygame/freesansbold.ttf
}

run_project_tests() {
    bash -c 'xvfb-run -a "$@"; rc=$?; exit "$rc"' -- python /benchmark/legacy_unittest090.py \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_get_rect' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_style' \
        'test/freetype_test.py::FreeTypeFontTest::test_freetype_Font_render_mono' \
        'test/freetype_test.py::FreeTypeFontTest::test_issue_242'
}
EOF_6863cac7573d
cat > /benchmark/format_test_log.py <<'EOF_fb38b443dc0a' || fail 'Cannot write /benchmark/format_test_log.py'
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
EOF_fb38b443dc0a
cat > /benchmark/legacy_unittest090.py <<'EOF_4999bf968bfd' || fail 'Cannot write /benchmark/legacy_unittest090.py'
"""Run unchanged upstream bundled-unittest methods with explicit process results."""
import argparse
import base64
import ctypes
import importlib
import json
import signal
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, '/testbed')
ctypes.CDLL(None).prctl(4, 0, 0, 0, 0)
parser = argparse.ArgumentParser()
parser.add_argument('--collect-only', action='store_true')
parser.add_argument('--child', action='store_true')
parser.add_argument('nodes', nargs='+')
args = parser.parse_args()

def load(node):
    file, classname, method = node.split('::')
    module = importlib.import_module(file[:-3].replace('/', '.'))
    cls = getattr(module, classname)
    assert callable(getattr(cls, method)), node
    loader = module.unittest.TestLoader()
    loader.testMethodPrefix = method
    suite = loader.loadTestsFromTestCase(cls)
    assert suite.countTestCases() == 1, node
    return module, suite

if args.collect_only:
    for node in args.nodes:
        load(node)
        print(node, flush=True)
    sys.exit(0)

if args.child:
    assert len(args.nodes) == 1
    node = args.nodes[0]
    module, suite = load(node)
    print('OFFICIAL_TEST_START ' + node, flush=True)
    result = module.unittest.TextTestRunner(stream=sys.stderr, verbosity=2).run(suite)
    assert result.testsRun == 1
    print('OFFICIAL_RESULT ' + json.dumps({'node': node, 'testsRun': result.testsRun,
        'failures': len(result.failures), 'errors': len(result.errors),
        'status': 'PASSED' if result.wasSuccessful() else 'FAILED'}), flush=True)
    sys.exit(0 if result.wasSuccessful() else 1)

failed = infrastructure = False
for node in args.nodes:
    child = subprocess.run([sys.executable, __file__, '--child', node], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    sys.stdout.buffer.write(child.stdout)
    sys.stderr.buffer.write(child.stderr)
    sys.stdout.flush()
    sys.stderr.flush()
    print('OFFICIAL_PROCESS_RECORD ' + json.dumps({'node': node, 'returncode': child.returncode,
        'stdout_base64': base64.b64encode(child.stdout).decode('ascii'),
        'stderr_base64': base64.b64encode(child.stderr).decode('ascii')}), flush=True)
    lines = child.stdout.decode('utf-8', errors='replace').splitlines()
    records = [json.loads(line[len('OFFICIAL_RESULT '):]) for line in lines if line.startswith('OFFICIAL_RESULT ')]
    if len(records) == 1 and records[0]['node'] == node and records[0]['testsRun'] == 1:
        status = records[0]['status']
        if child.returncode != (0 if status == 'PASSED' else 1):
            status = 'ERROR'
            infrastructure = True
    elif child.returncode in (-signal.SIGSEGV, -signal.SIGABRT) and 'OFFICIAL_TEST_START ' + node in lines:
        status = 'FAILED'
        print('OFFICIAL_NATIVE_FAILURE ' + json.dumps({'node': node, 'returncode': child.returncode,
            'signal': signal.Signals(-child.returncode).name}), flush=True)
    else:
        status = 'ERROR'
        infrastructure = True
        print('OFFICIAL_RESULT_MISSING ' + json.dumps({'node': node, 'returncode': child.returncode}), flush=True)
    print(node + ' ' + status, flush=True)
    failed |= status != 'PASSED'
sys.exit(2 if infrastructure else 1 if failed else 0)
EOF_4999bf968bfd
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
