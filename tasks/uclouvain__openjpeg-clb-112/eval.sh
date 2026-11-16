#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "4f5ec07c315872bdee0885be085ebf57cede2db9" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/tests/compare_images.c b/tests/compare_images.c
index cb1b1301..b28d4957 100644
--- a/tests/compare_images.c
+++ b/tests/compare_images.c
@@ -85,7 +85,7 @@ static void compare_images_help_display(void)
   fprintf(stdout,"\n");
   fprintf(stdout,"  -b \t REQUIRED \t filename to the reference/baseline PGX/TIF/PNM image \n");
   fprintf(stdout,"  -t \t REQUIRED \t filename to the test PGX/TIF/PNM image\n");
-  fprintf(stdout,"  -n \t REQUIRED \t number of component of the image (used to generate correct filename)\n");
+  fprintf(stdout,"  -n \t REQUIRED \t number of component of the image (used to generate correct filename, not used when both input files are TIF)\n");
   fprintf(stdout,"  -m \t OPTIONAL \t list of MSE tolerances, separated by : (size must correspond to the number of component) of \n");
   fprintf(stdout,"  -p \t OPTIONAL \t list of PEAK tolerances, separated by : (size must correspond to the number of component) \n");
   fprintf(stdout,"  -s \t OPTIONAL \t 1 or 2 filename separator to take into account PGX/PNM image with different components, "
@@ -279,8 +279,6 @@ static opj_image_t* readImageFromFileTIF(const char* filename, int nbFilenamePGX
     return NULL;
     }
 
-  /* \postconditions */
-  assert( image_read->numcomps == 1 || image_read->numcomps == 3 );
   return image_read;
 }
 
diff --git a/tests/nonregression/CMakeLists.txt b/tests/nonregression/CMakeLists.txt
index 2527f8cb..5ce37c81 100644
--- a/tests/nonregression/CMakeLists.txt
+++ b/tests/nonregression/CMakeLists.txt
@@ -353,6 +353,26 @@ foreach(OPJ_TEST_CMD_LINE ${OPJ_TEST_CMD_LINE_LIST})
                 )		
             endif()
           endif(JPYLYZER_EXECUTABLE)
+          
+          # If lossless compression (simple test is 4 arguments), decompress & compare
+          list(LENGTH CMD_ARG_LIST_2 ARG_COUNT)
+          if (ARG_COUNT EQUAL 4)
+            # can we compare with the input image ?
+            if (${INPUT_FILENAME_NAME} MATCHES "\\.tif$")
+              add_test(NAME NR-ENC-${INPUT_FILENAME_NAME}-${IT_TEST_ENC}-lossless-decode
+                COMMAND opj_decompress -i ${OUTPUT_FILENAME} -o ${OUTPUT_FILENAME}.lossless.tif
+                )
+              set_tests_properties(NR-ENC-${INPUT_FILENAME_NAME}-${IT_TEST_ENC}-lossless-decode PROPERTIES 
+                DEPENDS NR-ENC-${INPUT_FILENAME_NAME}-${IT_TEST_ENC}-encode
+                )
+              add_test(NAME NR-ENC-${INPUT_FILENAME_NAME}-${IT_TEST_ENC}-lossless-compare
+                COMMAND compare_images -b ${INPUT_FILENAME} -t ${OUTPUT_FILENAME}.lossless.tif -n 1 -d
+                )
+              set_tests_properties(NR-ENC-${INPUT_FILENAME_NAME}-${IT_TEST_ENC}-lossless-compare PROPERTIES 
+                DEPENDS NR-ENC-${INPUT_FILENAME_NAME}-${IT_TEST_ENC}-lossless-decode
+                )	
+            endif()
+          endif()
       endif()
 
     # DECODER TEST SUITE
diff --git a/tests/nonregression/test_suite.ctest.in b/tests/nonregression/test_suite.ctest.in
index 6f9bba83..7e3a35a8 100644
--- a/tests/nonregression/test_suite.ctest.in
+++ b/tests/nonregression/test_suite.ctest.in
@@ -134,6 +134,9 @@ opj_compress -i @INPUT_NR_PATH@/pngsuite/ftp0n2c08.png -o @TEMP_PATH@/ftp0n2c08.
 opj_compress -i @INPUT_NR_PATH@/pngsuite/ftp0n3p08.png -o @TEMP_PATH@/ftp0n3p08.png.jp2
 opj_compress -i @INPUT_NR_PATH@/pngsuite/ftp1n3p08.png -o @TEMP_PATH@/ftp1n3p08.png.jp2
 
+# issue 571 Lossless is not lossless on linux x86
+opj_compress -i @INPUT_NR_PATH@/issue571.tif -o @TEMP_PATH@/issue571.tif.j2k
+
 # DECODER TEST SUITE
 opj_decompress -i  @INPUT_NR_PATH@/Bretagne2.j2k -o @TEMP_PATH@/Bretagne2.j2k.pgx
 opj_decompress -i  @INPUT_NR_PATH@/_00042.j2k -o @TEMP_PATH@/_00042.j2k.pgx
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
