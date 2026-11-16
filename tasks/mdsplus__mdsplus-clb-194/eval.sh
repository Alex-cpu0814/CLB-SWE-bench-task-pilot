#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "a73d6e87149698e49026e3bf8055efc6bbe71d90" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tditest/testing/test-treeshr.ans b/tditest/testing/test-treeshr.ans
index dd8bccbc1..60452431a 100644
--- a/tditest/testing/test-treeshr.ans
+++ b/tditest/testing/test-treeshr.ans
@@ -18,6 +18,12 @@ getnci('?ember','fullpath')
 "\\MAIN::TOP:MEMBER"
 getnci('%ember','fullpath')
 ["\\MAIN::TOP:MEMBER"]
+getnci('\n','fullpath')
+%TREE-W-NNF, Node Not Found
+%TDI Error in GETNCI("\n", "fullpath")
+%TDI Error in EVALUATE(GETNCI("\n", "fullpath"))
+%TDI Error in EXECUTE("getnci('\\n','fullpath')")
+
 _tim=getnci(member,'time_inserted')
 49776423271761650QU
 date_time(_tim)
diff --git a/tditest/testing/test-treeshr.tdi b/tditest/testing/test-treeshr.tdi
index 4712199cf..9d6510c2d 100644
--- a/tditest/testing/test-treeshr.tdi
+++ b/tditest/testing/test-treeshr.tdi
@@ -9,6 +9,7 @@ getnci(member,'length')
 getnci(member,'on')
 getnci('?ember','fullpath')
 getnci('%ember','fullpath')
+getnci('\n','fullpath')
 _tim=getnci(member,'time_inserted')
 date_time(_tim)
 .subtree:a12:name
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
