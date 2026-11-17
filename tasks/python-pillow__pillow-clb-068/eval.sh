#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "dc1664500be0135d83182d480af341d39b5c78d7" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Tests/test_image_convert.py b/Tests/test_image_convert.py
index fd3d39bc..4d40e43b 100644
--- a/Tests/test_image_convert.py
+++ b/Tests/test_image_convert.py
@@ -46,5 +46,67 @@ def test_16bit_workaround():
     im = Image.open('Tests/images/16bit.cropped.tif')
     _test_float_conversion(im.convert('I'))
     
+def test_rgba_p():
+    im = lena('RGBA')
+    im.putalpha(lena('L'))
 
+    converted = im.convert('P')
+    comparable = converted.convert('RGBA')
+
+    assert_image_similar(im, comparable, 20)
+               
+def test_trns_p():    
+    im = lena('P')
+    im.info['transparency']=0
+
+    f = tempfile('temp.png')
+
+    l = im.convert('L')
+    assert_equal(l.info['transparency'], 0) # undone
+    assert_no_exception(lambda: l.save(f))
+
+
+    rgb = im.convert('RGB')
+    assert_equal(rgb.info['transparency'], (0,0,0)) # undone
+    assert_no_exception(lambda: rgb.save(f))
+    
+def test_trns_l():
+    im = lena('L')
+    im.info['transparency'] = 128
+
+    f = tempfile('temp.png')
+    
+    rgb = im.convert('RGB')
+    assert_equal(rgb.info['transparency'], (128,128,128)) # undone
+    assert_no_exception(lambda: rgb.save(f))
+
+    p = im.convert('P')
+    assert_true('transparency' in p.info)
+    assert_no_exception(lambda: p.save(f))
+
+    p = assert_warning(UserWarning,
+                       lambda: im.convert('P', palette = Image.ADAPTIVE))
+    assert_false('transparency' in p.info)
+    assert_no_exception(lambda: p.save(f))
+
+    
+def test_trns_RGB():
+    im = lena('RGB')
+    im.info['transparency'] = im.getpixel((0,0))
+
+    f = tempfile('temp.png')
+        
+    l = im.convert('L')
+    assert_equal(l.info['transparency'], l.getpixel((0,0))) # undone
+    assert_no_exception(lambda: l.save(f))
+
+    p = im.convert('P')
+    assert_true('transparency' in p.info)
+    assert_no_exception(lambda: p.save(f))
     
+    p = assert_warning(UserWarning,
+                       lambda: im.convert('P', palette = Image.ADAPTIVE))
+    assert_false('transparency' in p.info)
+    assert_no_exception(lambda: p.save(f))
+
+
diff --git a/Tests/test_image_quantize.py b/Tests/test_image_quantize.py
index 70b5eb50..dbf68a25 100644
--- a/Tests/test_image_quantize.py
+++ b/Tests/test_image_quantize.py
@@ -19,4 +19,9 @@ def test_octree_quantize():
     im = im.quantize(100, Image.FASTOCTREE)
     assert_image(im, "P", im.size)
 
-    assert len(im.getcolors()) == 100
\ No newline at end of file
+    assert len(im.getcolors()) == 100
+
+def test_rgba_quantize():
+    im = lena('RGBA')
+    assert_no_exception(lambda: im.quantize())
+    assert_exception(Exception, lambda: im.quantize(method=0))
diff --git a/Tests/tester.py b/Tests/tester.py
index d4309e3e..f7e2c26c 100644
--- a/Tests/tester.py
+++ b/Tests/tester.py
@@ -121,9 +121,9 @@ def assert_no_exception(func):
 def assert_warning(warn_class, func):
     # note: this assert calls func three times!
     import warnings
-    def warn_error(message, category, **options):
+    def warn_error(message, category=UserWarning, **options):
         raise category(message)
-    def warn_ignore(message, category, **options):
+    def warn_ignore(message, category=UserWarning, **options):
         pass
     warn = warnings.warn
     result = None
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_e37ed43b062b' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext -i --force
}

run_project_tests() {
    python /benchmark/tester_case068_isolated.py \
        'Tests/test_image_convert.py::test_default' \
        'Tests/test_image_convert.py::test_8bit' \
        'Tests/test_image_quantize.py::test_octree_quantize' \
        'Tests/test_image_convert.py::test_rgba_p' \
        'Tests/test_image_convert.py::test_trns_p' \
        'Tests/test_image_convert.py::test_trns_l' \
        'Tests/test_image_convert.py::test_trns_RGB' \
        'Tests/test_image_quantize.py::test_rgba_quantize'
}
EOF_e37ed43b062b
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
cat > /benchmark/tester_case068_isolated.py <<'EOF_f82121cdecb7' || fail 'Cannot write /benchmark/tester_case068_isolated.py'
"""Execute original Pillow tester functions, count their assertions, preserve output."""
import ctypes
import importlib.util
import json
import pathlib
import resource
import signal
import subprocess
import sys
import traceback

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError('Could not disable dumpability')

def load(node):
    file, function = node.split('::')
    source = pathlib.Path(file)
    spec = importlib.util.spec_from_file_location('official_' + source.stem, source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, getattr(module, function)

if '--worker' in sys.argv:
    node = sys.argv[-1]
    module, function = load(node)
    import tester
    tester._target = module
    tester.run = None  # execute selected function here, avoid atexit rerunning all nodes
    tester._tests = []
    tester.success.count = tester.failure.count = 0
    try:
        function()
        for delayed, args in tester._tests:
            delayed(*args)
    except BaseException:
        traceback.print_exc(file=sys.stdout)
        tester.failure.count += 1
    counts = {'node': node, 'assertions_passed': tester.success.count,
              'assertions_failed': tester.failure.count}
    print('OFFICIAL_TESTER_COUNTS ' + json.dumps(counts), flush=True)
    passed = tester.success.count > 0 and tester.failure.count == 0
    print(node + (' PASSED' if passed else ' FAILED'), flush=True)
    sys.exit(0 if passed else 1)

nodes = [arg for arg in sys.argv[1:] if arg.startswith('Tests/') and '::' in arg]
assert nodes
if '--collect-only' in sys.argv:
    import tester
    tester.run = None
    for node in nodes:
        assert callable(load(node)[1])
        print(node + ' COLLECTED', flush=True)
    sys.exit(0)
failed = False
for node in nodes:
    print('ISOLATED_NODE_BEGIN ' + node, flush=True)
    process = subprocess.run([sys.executable, __file__, '--worker', node], timeout=120)
    result = {'node': node, 'returncode': process.returncode,
              'signal': signal.Signals(-process.returncode).name if process.returncode < 0 else None}
    print('ISOLATED_NODE_RESULT ' + json.dumps(result), flush=True)
    if process.returncode < 0:
        print(node + ' FAILED', flush=True)
    elif process.returncode not in (0, 1):
        raise RuntimeError('Unexpected official tester exit: ' + json.dumps(result))
    failed = failed or process.returncode != 0
sys.exit(1 if failed else 0)
EOF_f82121cdecb7
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
