#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "3fb62360e61949a2405db0771ad89f1c9a2b25e4" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Tests/helper.py b/Tests/helper.py
index 65b1ca8b..989215ca 100644
--- a/Tests/helper.py
+++ b/Tests/helper.py
@@ -170,6 +170,41 @@ class PillowTestCase(unittest.TestCase):
             return Image.open(outfile)
         raise IOError()
 
+@unittest.skipIf(sys.platform.startswith('win32'), "requires Unix or MacOS")
+class PillowLeakTestCase(PillowTestCase):
+    # requires unix/osx
+    iterations = 100 # count
+    mem_limit = 512 # k
+    
+    def _get_mem_usage(self):
+        """
+        Gets the RUSAGE memory usage, returns in K. Encapsulates the difference
+        between OSX and Linux rss reporting
+
+        :returns; memory usage in kilobytes
+        """
+        
+        from resource import getpagesize, getrusage, RUSAGE_SELF
+        mem = getrusage(RUSAGE_SELF).ru_maxrss
+        if sys.platform == 'darwin':
+            # man 2 getrusage:
+            #     ru_maxrss    the maximum resident set size utilized (in bytes).
+            return mem / 1024 # Kb
+        else:
+            # linux
+            # man 2 getrusage
+            #        ru_maxrss (since Linux 2.6.32)
+            #  This is the maximum resident set size used (in  kilobytes). 
+            return mem # Kb
+
+    def _test_leak(self, core):
+        start_mem = self._get_mem_usage()
+        for cycle in range(self.iterations):
+            core()
+            mem = (self._get_mem_usage() - start_mem)
+            self.assertLess(mem, self.mem_limit,
+                            msg='memory usage limit exceeded in iteration %d' % cycle)
+
 
 # helpers
 
diff --git a/Tests/test_file_png.py b/Tests/test_file_png.py
index e7b74762..200c93b7 100644
--- a/Tests/test_file_png.py
+++ b/Tests/test_file_png.py
@@ -1,4 +1,4 @@
-from helper import unittest, PillowTestCase, hopper
+from helper import unittest, PillowTestCase, PillowLeakTestCase, hopper
 from PIL import Image, ImageFile, PngImagePlugin
 
 from io import BytesIO
@@ -7,9 +7,6 @@ import sys
 
 codecs = dir(Image.core)
 
-# For Truncated phng memory leak
-MEM_LIMIT = 2  # max increase in MB
-ITERATIONS = 100 # Leak is 56k/iteration, this will leak 5.6megs
 
 # sample png stream
 
@@ -539,26 +536,14 @@ class TestFilePng(PillowTestCase):
 
 
 @unittest.skipIf(sys.platform.startswith('win32'), "requires Unix or MacOS")
-class TestTruncatedPngPLeaks(PillowTestCase):
+class TestTruncatedPngPLeaks(PillowLeakTestCase):
+    mem_limit = 2*1024  # max increase in K
+    iterations = 100 # Leak is 56k/iteration, this will leak 5.6megs
 
     def setUp(self):
         if "zip_encoder" not in codecs or "zip_decoder" not in codecs:
             self.skipTest("zip/deflate support not available")
 
-    def _get_mem_usage(self):
-        from resource import getpagesize, getrusage, RUSAGE_SELF
-        mem = getrusage(RUSAGE_SELF).ru_maxrss
-        if sys.platform == 'darwin':
-            # man 2 getrusage:
-            #     ru_maxrss    the maximum resident set size utilized (in bytes).
-            return mem / 1024 / 1024 # megs
-        else:
-            # linux
-            # man 2 getrusage
-            #        ru_maxrss (since Linux 2.6.32)
-            #  This is the maximum resident set size used (in  kilobytes).
-            return mem / 1024 # megs
-
     def test_leak_load(self):
         with open('Tests/images/hopper.png', 'rb') as f:
             DATA = BytesIO(f.read(16 * 1024))
@@ -566,13 +551,13 @@ class TestTruncatedPngPLeaks(PillowTestCase):
         ImageFile.LOAD_TRUNCATED_IMAGES = True
         with Image.open(DATA) as im:
             im.load()
-        start_mem = self._get_mem_usage()
+
+        def core():
+            with Image.open(DATA) as im:
+                im.load()
+
         try:
-            for _ in range(ITERATIONS):
-                with Image.open(DATA) as im:
-                    im.load()
-                mem = (self._get_mem_usage() - start_mem)
-                self.assertLess(mem, MEM_LIMIT, msg='memory usage limit exceeded')
+            self._test_leak(core)
         finally:
             ImageFile.LOAD_TRUNCATED_IMAGES = False
 
diff --git a/Tests/test_font_leaks.py b/Tests/test_font_leaks.py
new file mode 100644
index 00000000..70933923
--- /dev/null
+++ b/Tests/test_font_leaks.py
@@ -0,0 +1,34 @@
+from __future__ import division
+from helper import unittest, PillowLeakTestCase
+import sys
+from PIL import Image, features, ImageDraw, ImageFont
+
+@unittest.skipIf(sys.platform.startswith('win32'), "requires Unix or MacOS")
+class TestTTypeFontLeak(PillowLeakTestCase):
+    # fails at iteration 3 in master
+    iterations = 10
+    mem_limit = 4096 #k
+
+    def _test_font(self, font):
+        im = Image.new('RGB', (255,255), 'white')
+        draw = ImageDraw.ImageDraw(im)
+        self._test_leak(lambda: draw.text((0, 0), "some text "*1024, #~10k
+                                          font=font, fill="black"))
+            
+    @unittest.skipIf(not features.check('freetype2'), "Test requires freetype2")
+    def test_leak(self):
+        ttype = ImageFont.truetype('Tests/fonts/FreeMono.ttf', 20)
+        self._test_font(ttype)
+
+class TestDefaultFontLeak(TestTTypeFontLeak):
+    # fails at iteration 37 in master
+    iterations = 100
+    mem_limit = 1024 #k
+    
+    def test_leak(self):
+        default_font = ImageFont.load_default()
+        self._test_font(default_font)
+
+
+if __name__ == '__main__':
+    unittest.main()
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_e7adefd32e2d' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext -i --force
}

run_project_tests() {
    python /benchmark/unittest_case066_isolated.py \
        'Tests/test_imagefont.py::TestImageFont::test_default_font' \
        'Tests/test_file_png.py::TestFilePng::test_sanity' \
        'Tests/test_font_leaks.py::TestTTypeFontLeak::test_leak' \
        'Tests/test_font_leaks.py::TestDefaultFontLeak::test_leak'
}
EOF_e7adefd32e2d
cat > /benchmark/format_test_log.py <<'EOF_7a0cb1177257' || fail 'Cannot write /benchmark/format_test_log.py'
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
    r"^(?P<test_id>Tests/\S+)\s+"
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
EOF_7a0cb1177257
cat > /benchmark/unittest_case066_isolated.py <<'EOF_8d74581f31e3' || fail 'Cannot write /benchmark/unittest_case066_isolated.py'
"""Run original legacy unittest cases in fresh processes without changing tests."""
import ctypes
import importlib.util
import json
import pathlib
import resource
import signal
import subprocess
import sys
import unittest

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError('Could not disable dumpability')

def load(node):
    file, cls, method = node.split('::')
    source = pathlib.Path(file)
    spec = importlib.util.spec_from_file_location('official_' + source.stem, source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    case = getattr(module, cls)(method)
    assert isinstance(case, unittest.TestCase)
    return unittest.TestSuite([case])

if '--worker' in sys.argv:
    node = sys.argv[-1]
    result = unittest.TextTestRunner(stream=sys.stdout, verbosity=2).run(load(node))
    assert result.testsRun == 1
    status = 'SKIPPED' if result.skipped else ('PASSED' if result.wasSuccessful() else 'FAILED')
    print(node + ' ' + status, flush=True)
    sys.exit(0 if result.wasSuccessful() else 1)

nodes = [arg for arg in sys.argv[1:] if arg.startswith('Tests/') and '::' in arg]
assert nodes
if '--collect-only' in sys.argv:
    for node in nodes:
        assert load(node).countTestCases() == 1
        print(node + ' COLLECTED', flush=True)
    sys.exit(0)
failed = False
for node in nodes:
    print('ISOLATED_NODE_BEGIN ' + node, flush=True)
    process = subprocess.run([sys.executable, __file__, '--worker', node], timeout=120)
    result = {'node': node, 'returncode': process.returncode, 'signal': signal.Signals(-process.returncode).name if process.returncode < 0 else None}
    print('ISOLATED_NODE_RESULT ' + json.dumps(result), flush=True)
    if process.returncode < 0:
        print(node + ' FAILED', flush=True)
    elif process.returncode not in (0, 1):
        raise RuntimeError('Unexpected unittest exit: ' + json.dumps(result))
    failed = failed or process.returncode != 0
sys.exit(1 if failed else 0)
EOF_8d74581f31e3
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
