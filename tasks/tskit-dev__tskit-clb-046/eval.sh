#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "eb8b4aebe42f39f7e536a603e8cd25d9cf104e22" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/python/tests/test_highlevel.py b/python/tests/test_highlevel.py
index e76bb98..1014aa9 100644
--- a/python/tests/test_highlevel.py
+++ b/python/tests/test_highlevel.py
@@ -1887,6 +1887,18 @@ class TestTree(HighLevelTestCase):
             for tree in ts.trees():
                 self.verify_newick(tree)
 
+    def test_newick_large_times(self):
+        for n in [2, 10, 20, 100]:
+            ts = msprime.simulate(n, Ne=100e6, random_seed=1)
+            tree = ts.first()
+            for precision in [0, 1, 16]:
+                newick_py = tree.newick(
+                    node_labels={u: str(u + 1) for u in ts.samples()},
+                    precision=precision,
+                )
+                newick_c = tree.newick(precision=precision)
+                self.assertEqual(newick_c, newick_py)
+
     def test_as_dict_of_dicts(self):
         for ts in get_example_tree_sequences():
             tree = next(ts.trees())
diff --git a/python/tests/test_lowlevel.py b/python/tests/test_lowlevel.py
index 6bbad57..1679212 100644
--- a/python/tests/test_lowlevel.py
+++ b/python/tests/test_lowlevel.py
@@ -1841,10 +1841,15 @@ class TestTree(LowLevelTestCase):
         self.assertEqual(st.get_newick(0), b"1;")
         for bad_type in [None, "", [], {}]:
             self.assertRaises(TypeError, st.get_newick, precision=bad_type)
-            self.assertRaises(TypeError, st.get_newick, ts, time_scale=bad_type)
+            self.assertRaises(TypeError, st.get_newick, ts, buffer_size=bad_type)
         while st.next():
-            newick = st.get_newick(st.get_left_root())
+            u = st.get_left_root()
+            newick = st.get_newick(u)
             self.assertTrue(newick.endswith(b";"))
+            with self.assertRaises(ValueError):
+                st.get_newick(u, buffer_size=-1)
+            with self.assertRaises(_tskit.LibraryError):
+                st.get_newick(u, buffer_size=1)
 
     def test_index(self):
         for ts in self.get_example_tree_sequences():
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
