#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "4afa84322f83b368dada7e3c6f64c3a17114aaa0" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/test_magnetic_symmetry.cpp b/test/test_magnetic_symmetry.cpp
index 39a972f..6973a91 100644
--- a/test/test_magnetic_symmetry.cpp
+++ b/test/test_magnetic_symmetry.cpp
@@ -300,6 +300,68 @@ TEST(test_magnetic_symmetry, test_spg_get_magnetic_dataset_type4) {
     spg_free_magnetic_dataset(dataset);
 }
 
+TEST(
+    test_magnetic_symmetry,
+    test_spg_get_symmetry_with_tensors_rough_symprec) {
+
+    // https://github.com/spglib/spglib/issues/186
+    double lattice[][3] = {  // column-wise!
+        {3.36017962, 1.70747655, -0.0117898},
+        {0.        , 3.84457132, -0.29501452},
+        {0.95244787, 0.37960516,  6.4450749},
+    };
+    double positions[][3] = {
+        {0.0, 0.0, 0.0},
+        {0.26737473, 0.2232512, 0.24199933},
+        {0.73262527, 0.7767488, 0.75800067},
+    };
+    int types[] = {0, 1, 1};
+    double tensors[] = {0.005, 0.002, 0.002};
+    int num_atoms = 3;
+    int max_size = num_atoms * 96;
+
+    double symprec = 1e-2;  // with high symprec
+    double mag_symprec = symprec;  // with high mag_symprec
+
+    int i, size;
+    int equivalent_atoms[3];
+    double primitive_lattice[3][3];
+    int(*rotations)[3][3];
+    double(*translations)[3];
+    int *spin_flips;
+    int *time_reversals;
+
+    rotations = (int(*)[3][3])malloc(sizeof(int[3][3]) * max_size);
+    translations = (double(*)[3])malloc(sizeof(double[3]) * max_size);
+    spin_flips = (int *)malloc(sizeof(int *) * max_size);
+    time_reversals = (int *)malloc(sizeof(int *) * max_size);
+
+    size = spg_get_symmetry(rotations, translations, max_size, lattice, positions, types, num_atoms, symprec);
+    ASSERT_EQ(size, 4);
+    show_symmetry_operations(rotations, translations, size);
+
+    size = spgms_get_symmetry_with_site_tensors(
+        rotations, translations, equivalent_atoms, primitive_lattice, spin_flips,
+        max_size, lattice, positions, types, tensors,
+        0 /* tensor_rank */ , num_atoms,
+        1 /* with_time_reversal */,
+        0 /* is_axial */,
+        symprec, -1 /* angle_tolerance */, mag_symprec);
+    ASSERT_EQ(size, 4);
+
+    for (i = 0; i < size; i++) {
+        time_reversals[i] = (1 - spin_flips[i]) / 2;
+    }
+    show_magnetic_symmetry_operations(rotations, translations, time_reversals, size);
+
+    free(rotations);
+    free(translations);
+    free(spin_flips);
+    free(time_reversals);
+}
+
+// TODO: test get_magnetic_dataset with distorted positions
+
 // ****************************************************************************
 // Local functions
 // ****************************************************************************
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
