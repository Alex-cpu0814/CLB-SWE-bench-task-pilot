#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "f6c82e695f5b6964daeec2c4e0bc449a89be892a" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tditest/testing/test-treeshr.ans b/tditest/testing/test-treeshr.ans
index df6b7e82c0ebe73d5e2a608d23e0fdea9e3d4bfa..f443686d66c54261f4dde23488ceda667330c55c 100644
--- a/tditest/testing/test-treeshr.ans
+++ b/tditest/testing/test-treeshr.ans
@@ -140,7 +140,7 @@ getnci(.subtree:a12,"parent_relationship")
 getnci(.subtree:a12,"get_flags")
 128LU
 getnci(.subtree:a12,"owner_id")
-4194368LU
+64LU
 getnci(.subtree:a12,"status")
 0LU
 getnci(.subtree:a12,"brother")
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
