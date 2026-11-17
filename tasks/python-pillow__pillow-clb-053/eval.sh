#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "09605ff48e582fda6870a2c4c519650321f3f8de" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Tests/images/imagedraw_rectangle_I.png b/Tests/images/imagedraw_rectangle_I.png
index 4e94f6943dd8eaac1d3be2b930b835358f1caaf9..a75f12c2e98f417e662f2661eab980b45b61cde1 100644
GIT binary patch
delta 102
zcmdnWxP@_oidD6zi(^Q|oVT}j@-`TVusS+?xo;%mkkXypn)XS5|Jl7d3_x%o{o2RL
zk9X7`yK1#D=Yq82<NO@|GZW)Y6@Q<(XkGsTq~yVWzZzDKgmXM=r9fOyS3j3^P6<r_
D-wi6M

delta 108
zcmdnOxRr5&ifxUji(^Q|oVT}j@-{f|FgQAtxbOYq&gjx!5tgC0{mofhUj`sJkpArB
z#N6Hgdp6hB*Bq5rd~7{U{oIeHiG}hL>qQh_PhD7E_X4Eu!GAut`79dQRy$UJxSp<l
JF6*2UngF_EET{kg

diff --git a/Tests/test_imagedraw.py b/Tests/test_imagedraw.py
index ca62354..1650cfa 100644
--- a/Tests/test_imagedraw.py
+++ b/Tests/test_imagedraw.py
@@ -586,6 +586,18 @@ def test_point(points):
     assert_image_equal_tofile(im, "Tests/images/imagedraw_point.png")
 
 
+def test_point_I16():
+    # Arrange
+    im = Image.new("I;16", (1, 1))
+    draw = ImageDraw.Draw(im)
+
+    # Act
+    draw.point((0, 0), fill=0x1234)
+
+    # Assert
+    assert im.getpixel((0, 0)) == 0x1234
+
+
 @pytest.mark.parametrize("points", POINTS)
 def test_polygon(points):
     # Arrange
@@ -732,7 +744,7 @@ def test_rectangle_I16(bbox):
     draw = ImageDraw.Draw(im)
 
     # Act
-    draw.rectangle(bbox, fill="black", outline="green")
+    draw.rectangle(bbox, outline=0xFFFF)
 
     # Assert
     assert_image_equal_tofile(im.convert("I"), "Tests/images/imagedraw_rectangle_I.png")
diff --git a/Tests/test_imagefont.py b/Tests/test_imagefont.py
index 02622e7..343ecda 100644
--- a/Tests/test_imagefont.py
+++ b/Tests/test_imagefont.py
@@ -141,7 +141,9 @@ def test_I16(font):
     draw = ImageDraw.Draw(im)
 
     txt = "Hello World!"
-    draw.text((10, 10), txt, font=font)
+    draw.text((10, 10), txt, fill=0xFFFE, font=font)
+
+    assert im.getpixel((12, 14)) == 0xFFFE
 
     target = "Tests/images/transparent_background_text_L.png"
     assert_image_similar_tofile(im.convert("L"), target, 0.01)
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_f26499a7a0eb' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext -i --force
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_imagedraw.py::test_sanity' \
        'Tests/test_imagefont.py::test_font_properties[Layout.BASIC]' \
        'Tests/test_imagedraw.py::test_point_I16' \
        'Tests/test_imagefont.py::test_I16[Layout.BASIC]'
}
EOF_f26499a7a0eb
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
