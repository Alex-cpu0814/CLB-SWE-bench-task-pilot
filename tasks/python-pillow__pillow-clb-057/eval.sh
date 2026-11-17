#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "f0679aff4d43dbd595b98501dc7a8420550bf4e8" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/Tests/images/negative_layer_count.psd b/Tests/images/negative_layer_count.psd
new file mode 100644
index 0000000000000000000000000000000000000000..b111c2d5675ab2eec3bf2df52d2af603e006d2a3
GIT binary patch
literal 5492
zcmeHKO=uHA7=4?hq{hTl%%O;f98ym$h*rt5u0koK5Yh;(dT_Iwq@meO*iDdtN5N~U
z2Y(<~_29*`UOjjf1i>E=Z{E~{q6ej}Z)R;1O4EZ72<y%=GjG1X`R02wgk;tH5)^nX
z!pV?*9AQrsK9p4#7Q<iUDiJT*n&mV#yKLzl2u<X))Ewr>D6Z>y!BC_&{8_Filxe9~
zwrA<-nTDXqRZ=WNo1)is(}|n_Osi!V=GFA_%Eff_Bce#+0H%=8bf<YXpU-&#_8Nb@
z_RjQbM#S37Vjo$;C_6fjlcvp_-n3i9SBTGCZ8ZhHO`OtKHC9S_OgwEfLE^VUUh?oK
zfvXaS2$8ajg>yVxia1^E!=*l~ui7SUW@(c#OpEbD%N{laz9z6)Z!<U91Z(lKbzzBf
zhW!}kv4BP7kwyt^)KEtYGn_3-92BTm2lyYA{&{+p=v9MGkMn52geLtVIG_z%ueMI*
z)JZ8);wmuq!F9h)0nwYl*1GHdy6?JM4}kD{;F;C)Z)^hD@073iWSM(F@;dP3c~4fl
z1w6e0OuplN)8szlPKGKK;OiqGu>u@<3B)dWb)!z`@$d~$WUX>9fID}A<5kAKJmB2p
zbl9oezBYgB2ORv({?p~S)5s3rjoe+?5I2t_X;(JH&9)l0>53&&+V+U4n!Z-G8*P#-
zZ0c>RM%^TP3@U4`V+~c<WS~v<3~8g+ZR$nFyPLOvM7%!k%r+<s={P4x4r4j3Q)bM*
z3?_t_d1~mO%>6yx?wu7L#}{80{`h$3e8C4o{@|m_Cm1j?T3iN<j20ik8yPh|0!9Kx
khWD#AdbRzxjQsOEGCZz>$p3Q%x^D0V6&OMVeDZJo54vN9CIA2c

literal 0
HcmV?d00001

diff --git a/Tests/test_file_psd.py b/Tests/test_file_psd.py
index bf2a5fe..f50fe13 100644
--- a/Tests/test_file_psd.py
+++ b/Tests/test_file_psd.py
@@ -57,9 +57,10 @@ def test_n_frames():
         assert im.n_frames == 1
         assert not im.is_animated
 
-    with Image.open(test_file) as im:
-        assert im.n_frames == 2
-        assert im.is_animated
+    for path in [test_file, "Tests/images/negative_layer_count.psd"]:
+        with Image.open(path) as im:
+            assert im.n_frames == 2
+            assert im.is_animated
 
 
 def test_eoferror():
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_615b39940c89' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python setup.py build_ext -i --force
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'Tests/test_file_psd.py::test_sanity' \
        'Tests/test_file_psd.py::test_eoferror' \
        'Tests/test_file_psd.py::test_n_frames'
}
EOF_615b39940c89
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
