#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "4f5ec07c315872bdee0885be085ebf57cede2db9" ]] || fail 'Unexpected Base commit'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_c4b3a63160a3' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

readonly OPJ_BUILD_DIR=/opt/openjpeg-build
readonly OPJ_DATA_DIR=/opt/openjpeg-data
readonly OPJ_INPUT="${OPJ_DATA_DIR}/input/nonregression/issue571.tif"
readonly OPJ_OUTPUT=/tmp/issue571.tif.j2k
readonly OPJ_ROUNDTRIP=/tmp/issue571.lossless.tif

build_project() {
    cmake -S /testbed -B "${OPJ_BUILD_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS=-m32 \
        -DCMAKE_EXE_LINKER_FLAGS=-m32 \
        -DCMAKE_SHARED_LINKER_FLAGS=-m32 \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_CODEC=ON \
        -DBUILD_THIRDPARTY=ON \
        -DBUILD_TESTING=ON \
        -DOPJ_DATA_ROOT="${OPJ_DATA_DIR}" || return 1
    cmake --build "${OPJ_BUILD_DIR}" --parallel "$(nproc)"
}

run_project_tests() {
    local encode_status=1
    local decode_status=1
    local compare_status=1

    rm -f "${OPJ_OUTPUT}" "${OPJ_ROUNDTRIP}"

    "${OPJ_BUILD_DIR}/bin/opj_compress" -i "${OPJ_INPUT}" -o "${OPJ_OUTPUT}"
    encode_status=$?
    if [[ "${encode_status}" -eq 0 ]]; then
        echo 'encode_issue571 (openjpeg.issue571) ... ok'
        "${OPJ_BUILD_DIR}/bin/opj_decompress" -i "${OPJ_OUTPUT}" -o "${OPJ_ROUNDTRIP}"
        decode_status=$?
    else
        echo 'encode_issue571 (openjpeg.issue571) ... FAIL'
        echo 'decode_issue571 (openjpeg.issue571) ... skipped encode failed'
    fi

    if [[ "${decode_status}" -eq 0 ]]; then
        echo 'decode_issue571 (openjpeg.issue571) ... ok'
        "${OPJ_BUILD_DIR}/bin/compare_images" \
            -b "${OPJ_INPUT}" -t "${OPJ_ROUNDTRIP}" -n 1 -d
        compare_status=$?
    elif [[ "${encode_status}" -eq 0 ]]; then
        echo 'decode_issue571 (openjpeg.issue571) ... FAIL'
    fi

    if [[ "${compare_status}" -eq 0 ]]; then
        echo 'lossless_roundtrip (openjpeg.issue571) ... ok'
    else
        echo 'lossless_roundtrip (openjpeg.issue571) ... FAIL'
    fi
    return "${compare_status}"
}
EOF_c4b3a63160a3
cat > /benchmark/format_test_log.py <<'EOF_8a58ff4098c6' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)

TEST_START_LINE = re.compile(r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. .*")

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
EOF_8a58ff4098c6
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
