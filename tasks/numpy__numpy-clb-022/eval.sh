#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "99953e494aa3be5ae8385d8461b9e4dfbeec43ec" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/numpy/core/tests/test_multiarray.py b/numpy/core/tests/test_multiarray.py
index a67a291..77534c1 100644
--- a/numpy/core/tests/test_multiarray.py
+++ b/numpy/core/tests/test_multiarray.py
@@ -7009,12 +7009,11 @@ class TestArrayAttributeDeletion(object):
             assert_raises(AttributeError, delattr, a, s)
 
 
-def test_array_interface():
-    # Test scalar coercion within the array interface
+class TestArrayInterface():
     class Foo(object):
         def __init__(self, value):
             self.value = value
-            self.iface = {'typestr': '=f8'}
+            self.iface = {'typestr': 'f8'}
 
         def __float__(self):
             return float(self.value)
@@ -7023,22 +7022,39 @@ def test_array_interface():
         def __array_interface__(self):
             return self.iface
 
+
     f = Foo(0.5)
-    assert_equal(np.array(f), 0.5)
-    assert_equal(np.array([f]), [0.5])
-    assert_equal(np.array([f, f]), [0.5, 0.5])
-    assert_equal(np.array(f).dtype, np.dtype('=f8'))
-    # Test various shape definitions
-    f.iface['shape'] = ()
-    assert_equal(np.array(f), 0.5)
-    f.iface['shape'] = None
-    assert_raises(TypeError, np.array, f)
-    f.iface['shape'] = (1, 1)
-    assert_equal(np.array(f), [[0.5]])
-    f.iface['shape'] = (2,)
-    assert_raises(ValueError, np.array, f)
-
-    # test scalar with no shape
+
+    @pytest.mark.parametrize('val, iface, expected', [
+        (f, {}, 0.5),
+        ([f], {}, [0.5]),
+        ([f, f], {}, [0.5, 0.5]),
+        (f, {'shape': ()}, 0.5),
+        (f, {'shape': None}, TypeError),
+        (f, {'shape': (1, 1)}, [[0.5]]),
+        (f, {'shape': (2,)}, ValueError),
+        (f, {'strides': ()}, 0.5),
+        (f, {'strides': (2,)}, ValueError),
+        (f, {'strides': 16}, TypeError),
+        ])
+    def test_scalar_interface(self, val, iface, expected):
+        # Test scalar coercion within the array interface
+        self.f.iface = {'typestr': 'f8'}
+        self.f.iface.update(iface)
+        if HAS_REFCOUNT:
+            pre_cnt = sys.getrefcount(np.dtype('f8'))
+        if isinstance(expected, type):
+            assert_raises(expected, np.array, val)
+        else:
+            result = np.array(val)
+            assert_equal(np.array(val), expected)
+            assert result.dtype == 'f8'
+            del result
+        if HAS_REFCOUNT:
+            post_cnt = sys.getrefcount(np.dtype('f8'))
+            assert_equal(pre_cnt, post_cnt)
+
+def test_interface_no_shape():
     class ArrayLike(object):
         array = np.array(1)
         __array_interface__ = array.__array_interface__
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
