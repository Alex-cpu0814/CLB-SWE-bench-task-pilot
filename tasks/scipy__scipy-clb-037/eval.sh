#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "bf05e8d3412e2d96ab6735b6935e2a65f2620c30" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/scipy/ndimage/tests/test_regression.py b/scipy/ndimage/tests/test_regression.py
index a824679..28d7553 100644
--- a/scipy/ndimage/tests/test_regression.py
+++ b/scipy/ndimage/tests/test_regression.py
@@ -16,5 +16,19 @@ def test_zoom_output_shape():
     x = np.arange(12).reshape((3,4))
     ndimage.zoom(x, 2, output=np.zeros((6,8)))
 
+def test_ticket_742():
+    def SE(img, thresh=.7, size=4):
+        mask = img > thresh
+        rank = len(mask.shape)
+        la, co = ndimage.label(mask,
+                               ndimage.generate_binary_structure(rank, rank))
+        slices = ndimage.find_objects(la)
+
+    if np.dtype(np.intp) != np.dtype('i'):
+        shape=(3,1240,1240)
+        a = np.random.rand(np.product(shape)).reshape(shape)
+        # shouldn't crash
+        SE(a)
+
 if __name__ == "__main__":
     run_module_suite()
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_35252825b406' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    python3.8 setup.py build_ext -i || return $?
    # SciPy 0.10 converts Python sources into build/py3k. NumPy 1.17
    # no longer provides the historical lazy package loader.
    sed -i '/from numpy\._import_tools import PackageLoader/,/pkgload(verbose=SCIPY_IMPORT_VERBOSE,postpone=True)/d' \
        /testbed/build/py3k/scipy/__init__.py
}

run_project_tests() {
    cd /testbed/build/py3k || return $?
    python3.8 -m pytest -vv \
        'scipy/ndimage/tests/test_regression.py::test_byte_order_median' \
        'scipy/ndimage/tests/test_regression.py::test_zoom_output_shape' \
        'scipy/ndimage/tests/test_regression.py::test_ticket_742'
}
EOF_35252825b406
cat > /benchmark/format_test_log.py <<'EOF_499bbb31acab' || fail 'Cannot write /benchmark/format_test_log.py'
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
    r"^(?P<test_id>scipy/\S+)\s+"
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
EOF_499bbb31acab
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
