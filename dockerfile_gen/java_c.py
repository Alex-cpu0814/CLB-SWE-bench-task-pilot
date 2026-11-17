"""Generation settings for the two Java–C cohorts."""

COHORTS = {"java_author11", "java_upstream11"}
PILOT_NORMALIZERS = {
    "ninia__jep-clb-093": "python /opt/clb-pilot/normalize_results.py jep",
    "kohlschutter__junixsocket-clb-175": "python3 /opt/clb-pilot/normalize_results.py unittest",
}


EVAL_SETUP = {
    "lwjgl__lwjgl3-clb-075": (
        "ln -sfnT /opt/clb-deps /benchmark/dependencies || fail 'Cannot link build dependencies'\n"
    ),
    "kohlschutter__junixsocket-clb-170": (
        "mkdir -p /case-noexec /case-exec || fail 'Cannot create test mountpoints'\n"
        "mount -t tmpfs -o rw,noexec,nosuid,size=64m tmpfs /case-noexec "
        "|| fail 'Cannot create noexec test mount'\n"
        "mount -t tmpfs -o rw,exec,nosuid,size=64m tmpfs /case-exec "
        "|| fail 'Cannot create executable test mount'\n"
    ),
}


# Default build commands for each upstream project.
BUILD_BY_PROJECT = {
    "kohlschutter__junixsocket": r"""build_project() {
    python3 /benchmark/build_project.py
}
""",
    "lwjgl__lwjgl3": r"""build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null \
        && command -v gcc >/dev/null && command -v java >/dev/null \
        && command -v javac >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed
}
""",
    "mdsplus__mdsplus": r"""
build_project() {
    make -C /build
    make -C /build install
}

run_one_tdi_test() {
    local test_name="$1"
    local status
    local test_dir=/build/tditest/testing

    rm -f "${test_dir}/${test_name}.log" "${test_dir}/${test_name}.trs" "${test_dir}/test-suite.log"
    make -C "${test_dir}" check TESTS="${test_name}.tdi"
    status=$?
    if [[ "${status}" -eq 0 ]]; then
        printf '%s (MDSplus.tditest) ... ok\n' "${test_name}"
    else
        printf '%s (MDSplus.tditest) ... FAIL\n' "${test_name}"
    fi
    return "${status}"
}

""",
    "ninia__jep": r"""
# Case-specific build and test functions sourced by run_evaluation.sh.

build_project() {
    python setup.py clean >/dev/null 2>&1 || true
    python setup.py build

    CASE_NATIVE_LIB="$(find build -type f -name 'jep*.so' -print -quit)"
    [[ -n "${CASE_NATIVE_LIB}" ]] || return 10
    CASE_NATIVE_DIR="$(dirname "${CASE_NATIVE_LIB}")"
    ln -sf "$(basename "${CASE_NATIVE_LIB}")" "${CASE_NATIVE_DIR}/libjep.so"

    CASE_PROJECT_VERSION="$(python -c "ns={}; exec(open('jep/version.py').read(), ns); print(ns['VERSION'])")" \
        || return 11
    CASE_CLASSPATH="build/java/jep-${CASE_PROJECT_VERSION}.jar"
    CASE_CLASSPATH="${CASE_CLASSPATH}:build/java/jep.test-${CASE_PROJECT_VERSION}.jar"
    for CASE_JAR in tests/lib/*.jar; do
        [[ -f "${CASE_JAR}" ]] && CASE_CLASSPATH="${CASE_CLASSPATH}:${CASE_JAR}"
    done

    export LD_LIBRARY_PATH="/opt/anaconda3/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    local python_lib
    python_lib="$(find /opt/anaconda3/lib -maxdepth 1 -type f \
        \( -name 'libpython3.5m.so*' -o -name 'libpython3.5.so*' \) \
        | head -n 1)"
    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi
}

""",
    "uclouvain__openjpeg": r"""
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

""",
}


JEP_BUILD_WITH_ANNOTATIONS = r"""
# Case-specific build and test functions sourced by run_evaluation.sh.

build_project() {
    python setup.py clean >/dev/null 2>&1 || true
    python setup.py build

    CASE_NATIVE_LIB="$(find build -type f -name 'jep*.so' -print -quit)"
    [[ -n "${CASE_NATIVE_LIB}" ]] || return 10
    CASE_NATIVE_DIR="$(dirname "${CASE_NATIVE_LIB}")"
    ln -sf "$(basename "${CASE_NATIVE_LIB}")" "${CASE_NATIVE_DIR}/libjep.so"

    CASE_PROJECT_VERSION="$(python -c "ns={}; exec(open('jep/version.py').read(), ns); print(ns['VERSION'])")" \
        || return 11
    CASE_CLASSPATH="build/java/jep-${CASE_PROJECT_VERSION}.jar"
    CASE_CLASSPATH="${CASE_CLASSPATH}:build/java/jep.test-${CASE_PROJECT_VERSION}.jar"
    CASE_CLASSPATH="${CASE_CLASSPATH}:tests/lib/sqlitejdbc-v056.jar:tests/lib/fakenetty.jar"

    export LD_LIBRARY_PATH="/opt/python-3.4.10/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    local python_lib
    python_lib="$(find /opt/python-3.4.10/lib -maxdepth 1 -type f \
        \( -name 'libpython3.4m.so*' -o -name 'libpython3.4.so*' \) \
        | head -n 1)"
    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi
}

"""


# Builds that differ from their project's default.
BUILD_OVERRIDES = {
    "kohlschutter__junixsocket-clb-150": r"""
build_project() {
    mvn -B -o -Puse-snapshots,release-native \
        -pl junixsocket-native-custom -am clean install \
        -DskipTests \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default
}

""",
    "kohlschutter__junixsocket-clb-152": r"""
build_project() {
    mvn -B -o -Prelease-native \
        -pl junixsocket-native-common,junixsocket-native-custom -am clean install \
        -Dmaven.test.skip=true \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default \
        && mvn -B -o -f junixsocket-common/pom.xml package -Dmaven.test.skip=true
}

""",
    "kohlschutter__junixsocket-clb-160": r"""
build_project() {
    mvn -B -o -Prelease-native \
        -pl junixsocket-native-common,junixsocket-native-custom -am clean install \
        -Dmaven.test.skip=true \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default
}

""",
    "kohlschutter__junixsocket-clb-161": r"""
build_project() {
    mvn -B -o -Prelease-native \
        -pl junixsocket-native-common,junixsocket-native-custom -am clean install \
        -Dmaven.test.skip=true \
        '-Djunixsocket.native.clang.c.options=-Wall -Wextra -Wno-reserved-id-macro -Wno-undef -Wno-cast-qual -Wno-disabled-macro-expansion -Wno-language-extension-token -Wno-gnu-auto-type -Wno-c++11-extensions -Wno-c++98-compat -Wno-empty-translation-unit -Wno-gnu-empty-initializer -Werror-implicit-function-declaration -Wint-conversion -Wno-unused-command-line-argument -fno-strict-overflow -finline-functions -fwrapv -fPIC -fvisibility=hidden -fno-common -Os -std=gnu11 -Djunixsocket_use_poll_for_read' \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default
}

""",
    "kohlschutter__junixsocket-clb-175": r"""
build_project() {
    mvn -B -o -Prelease-native \
        -pl junixsocket-native-custom,junixsocket-jetty -am clean install \
        -DskipTests \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default
}

""",
    "lwjgl__lwjgl3-clb-056": r"""
build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null && command -v ant >/dev/null && command -v gcc >/dev/null && command -v java >/dev/null && command -v javac >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed --offline
}

""",
    "lwjgl__lwjgl3-clb-062": r"""build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null && command -v ant >/dev/null && command -v gcc >/dev/null && command -v java >/dev/null && command -v javac >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed
}
""",
    "lwjgl__lwjgl3-clb-069": r"""
build_project() {
    local flags=(
        -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.egl=false
        -Dbinding.glfw=false -Dbinding.jawt=false -Dbinding.jemalloc=false
        -Dbinding.lmdb=false -Dbinding.lz4=false -Dbinding.nanovg=false
        -Dbinding.nfd=false -Dbinding.nuklear=false -Dbinding.odbc=false
        -Dbinding.openal=false -Dbinding.opencl=false -Dbinding.opengl=false
        -Dbinding.opengles=false -Dbinding.openvr=false -Dbinding.par=false
        -Dbinding.remotery=false -Dbinding.rpmalloc=false -Dbinding.sse=false
        -Dbinding.stb=false -Dbinding.tinyexr=false -Dbinding.tinyfd=false
        -Dbinding.tootle=false -Dbinding.vma=false -Dbinding.vulkan=false
        -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false
    )
    if ! C_INCLUDE_PATH=/testbed/modules/lwjgl/core/src/main/c/dyncall \
        ant -Dbuild.offline=true "${flags[@]}" compile-templates compile; then
        return 1
    fi

    mkdir -p bin/classes/test
    javac -cp "bin/classes/lwjgl/core:bin/libs/java/jsr305.jar:bin/libs/java/testng.jar" \
        -d bin/classes/test \
        modules/lwjgl/core/src/test/java/org/lwjgl/system/MemoryUtilTest.java || return 1
}

""",
    "lwjgl__lwjgl3-clb-075": r"""build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null \
        && command -v gcc >/dev/null && command -v java >/dev/null \
        && command -v javac >/dev/null && command -v ant >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed
}
""",
    "mdsplus__mdsplus-clb-200": r"""
build_project() {
    cd /testbed
    ./bootstrap
    cd /build
    NOF77=yes /testbed/configure --prefix=/usr/local/mdsplus --disable-java
    make
    make install
}

run_one_tdi_test() {
    local test_name="$1"
    local display_name="$2"
    local status
    local test_dir=/build/tditest/testing

    rm -f "${test_dir}/${test_name}.log" "${test_dir}/${test_name}.trs" "${test_dir}/test-suite.log"
    make -C "${test_dir}" check TESTS="${test_name}.tdi"
    status=$?
    if [[ "${status}" -eq 0 ]]; then
        printf '%s (MDSplus.tditest) ... ok\n' "${display_name}"
    else
        printf '%s (MDSplus.tditest) ... FAIL\n' "${display_name}"
    fi
    return "${status}"
}

""",
    "ninia__jep-clb-092": r"""
# Case-specific build and test functions sourced by run_evaluation.sh.

build_project() {
    python setup.py clean >/dev/null 2>&1 || true
    python setup.py build

    CASE_NATIVE_LIB="$(find build -type f -name 'jep*.so' -print -quit)"
    [[ -n "${CASE_NATIVE_LIB}" ]] || return 10
    CASE_NATIVE_DIR="$(dirname "${CASE_NATIVE_LIB}")"
    ln -sf "$(basename "${CASE_NATIVE_LIB}")" "${CASE_NATIVE_DIR}/libjep.so"

    CASE_PROJECT_VERSION="$(python -c "ns={}; exec(open('jep/version.py').read(), ns); print(ns['VERSION'])")" \
        || return 11
    CASE_CLASSPATH="build/java/jep-${CASE_PROJECT_VERSION}.jar"
    CASE_CLASSPATH="${CASE_CLASSPATH}:build/java/jep.test-${CASE_PROJECT_VERSION}.jar"
    CASE_CLASSPATH="${CASE_CLASSPATH}:tests/lib/sqlitejdbc-v056.jar:tests/lib/fakenetty.jar"

    export LD_LIBRARY_PATH="/opt/python-3.5.3/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    local python_lib
    python_lib="$(find /opt/python-3.5.3/lib -maxdepth 1 -type f \
        \( -name 'libpython3.5m.so*' -o -name 'libpython3.5.so*' \) \
        | head -n 1)"
    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi
}

""",
    "ninia__jep-clb-097": JEP_BUILD_WITH_ANNOTATIONS,
    "ninia__jep-clb-099": JEP_BUILD_WITH_ANNOTATIONS,
    "ninia__jep-clb-100": r"""
build_project() {
    python setup.py clean >/dev/null 2>&1 || true
    python setup.py build || return 10

    CASE_NATIVE_LIB="$(find build -type f -name 'jep*.so' -print -quit)"
    [[ -n "${CASE_NATIVE_LIB}" ]] || return 11

    CASE_NATIVE_DIR="$(dirname "${CASE_NATIVE_LIB}")"
    ln -sf "$(basename "${CASE_NATIVE_LIB}")" "${CASE_NATIVE_DIR}/libjep.so"

    CASE_CLASSPATH="build/java/jep.jar"
    [[ -f "${CASE_CLASSPATH}" ]] || return 12

    for jar_file in \
        build/java/jep.test.jar \
        tests/lib/sqlitejdbc-v056.jar \
        tests/lib/fakenetty.jar
    do
        if [[ -f "${jar_file}" ]]; then
            CASE_CLASSPATH="${CASE_CLASSPATH}:${jar_file}"
        fi
    done

    export LD_LIBRARY_PATH="/opt/python-2.7.18/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    export PYTHONPATH="${PWD}/build/lib.linux-x86_64-2.7:${PWD}:${PYTHONPATH:-}"

    local python_lib
    python_lib="$(find /opt/python-2.7.18/lib -maxdepth 1 -type f \
        -name 'libpython2.7.so*' | head -n 1)"

    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi
}

""",
}


JUNIXSOCKET_CASE_TESTS = r"""    python3 /benchmark/run_case_tests.py
}
"""


LWJGL_RUNNER_TESTS = r"""    python3 /benchmark/test_runner.py /testbed /results \
        > /results/runner.stdout.log 2> /results/runner.stderr.log
    local status=$?
    cat /results/runner.stdout.log
    return "$status"
}
"""


JEP_VERBOSE_TESTS = r"""    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /benchmark/run_tests_verbose.py
}
"""


# Commands executed inside run_project_tests for each instance.
TEST_COMMANDS = {
    "kohlschutter__junixsocket-clb-150": r"""    local status
    mvn -B -o -Puse-snapshots -pl junixsocket-common -am test \
        '-Dtest=AbstractNamespaceTest,AFUNIXSocketAddressTest#testAbstractNamespace' \
        -Dsurefire.failIfNoSpecifiedTests=false
    status=$?
    python3 /benchmark/report_surefire.py \
        /testbed/junixsocket-common/target/surefire-reports
    return "${status}"
}
""",
    "kohlschutter__junixsocket-clb-152": r"""    local common_jar native_common_jar native_custom_jar class_path
    common_jar="$(find junixsocket-common/target -maxdepth 1 -type f \
        -name 'junixsocket-common-*.jar' ! -name '*-sources.jar' \
        ! -name '*-javadoc.jar' ! -name '*-tests.jar' | head -n 1)"
    native_common_jar="$(find junixsocket-native-common/target -maxdepth 1 -type f \
        -name 'junixsocket-native-common-*.jar' ! -name '*-sources.jar' \
        ! -name '*-javadoc.jar' | head -n 1)"
    native_custom_jar="$(find junixsocket-native-custom/target -maxdepth 1 -type f \
        -name '*default.jar' | head -n 1)"
    class_path="${common_jar}:${native_common_jar}:${native_custom_jar}"

    test -n "${common_jar}" && test -n "${native_common_jar}" \
        && test -n "${native_custom_jar}" || return 2
    rm -rf benchmark-tests/target
    mkdir -p benchmark-tests/target/classes
    javac -cp "${class_path}" -d benchmark-tests/target/classes \
        $(find benchmark-tests/src/test/java -name '*.java') || return $?
    java -cp "${class_path}:benchmark-tests/target/classes" \
        org.newsclub.net.unix.FileDescriptorCastRegressionTest
}
""",
    "kohlschutter__junixsocket-clb-160": r"""    local control_status target_status
    local report_dir=/testbed/junixsocket-common/target/surefire-reports

    rm -rf "${report_dir}"
    mvn -B -o -f junixsocket-common/pom.xml test \
        '-Dtest=SoTimeoutTest#testSocketTimeoutExceptionRead'
    control_status=$?
    python3 /benchmark/report_surefire.py "${report_dir}"
    if [[ "${control_status}" -ne 0 ]]; then
        return "${control_status}"
    fi

    rm -rf "${report_dir}"
    timeout --signal=TERM --kill-after=5s 15s \
        mvn -B -o -f junixsocket-common/pom.xml test \
        '-Dtest=SoTimeoutTest#testSocketTimeoutExceptionWrite'
    target_status=$?
    if [[ "${target_status}" -eq 124 || "${target_status}" -eq 137 ]]; then
        printf '%s\n' \
            'testSocketTimeoutExceptionWrite (org.newsclub.net.unix.SoTimeoutTest) ... ERROR'
        return 1
    fi
    python3 /benchmark/report_surefire.py "${report_dir}"
    return "${target_status}"
}
""",
    "kohlschutter__junixsocket-clb-161": r"""    local control_status target_status
    local report_dir=/testbed/junixsocket-common/target/surefire-reports

    rm -rf "${report_dir}"
    mvn -B -o -f junixsocket-common/pom.xml test \
        '-Dtest=SoTimeoutTest#issue14Pass'
    control_status=$?
    python3 /benchmark/report_surefire.py "${report_dir}"
    if [[ "${control_status}" -ne 0 ]]; then
        return "${control_status}"
    fi

    rm -rf "${report_dir}"
    timeout --signal=TERM --kill-after=5s 30s \
        mvn -B -o -f junixsocket-common/pom.xml test \
        '-Dtest=SoTimeoutTest#testSocketTimeoutException'
    target_status=$?
    if [[ "${target_status}" -eq 124 || "${target_status}" -eq 137 ]]; then
        printf '%s\n' \
            'testSocketTimeoutException (org.newsclub.net.unix.SoTimeoutTest) ... ERROR'
        return 1
    fi
    python3 /benchmark/report_surefire.py "${report_dir}"
    return "${target_status}"
}
""",
    "kohlschutter__junixsocket-clb-163": JUNIXSOCKET_CASE_TESTS,
    "kohlschutter__junixsocket-clb-170": JUNIXSOCKET_CASE_TESTS,
    "kohlschutter__junixsocket-clb-175": r"""    local control_status target_status
    local report_dir=/testbed/junixsocket-jetty/target/surefire-reports

    rm -rf "${report_dir}"
    mvn -B -o -f junixsocket-jetty/pom.xml test \
        '-Dtest=UnixDomainTest#testHTTPOverUnixDomain'
    control_status=$?
    python3 /opt/clb-pilot/report_surefire.py "${report_dir}"
    if [[ "${control_status}" -ne 0 ]]; then
        return "${control_status}"
    fi

    rm -rf "${report_dir}"
    timeout --signal=TERM --kill-after=5s 30s \
        mvn -B -o -f junixsocket-jetty/pom.xml test \
        '-Dtest=UnixDomainTest#testLargeBody'
    target_status=$?
    if [[ "${target_status}" -eq 124 || "${target_status}" -eq 137 ]]; then
        printf '%s\n' \
            'testLargeBody (org.eclipse.jetty.unixdomain.server.UnixDomainTest) ... ERROR'
        return 1
    fi
    python3 /opt/clb-pilot/report_surefire.py "${report_dir}"
    return "${target_status}"
}
""",
    "lwjgl__lwjgl3-clb-056": r"""    python3 /benchmark/test_runner.py /testbed /results > /results/runner.stdout.log 2>/results/runner.stderr.log
    local status=$?
    python3 - "${status}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path('/results')
path = root / 'sanitized_results.json'
if path.is_file():
    report = json.loads(path.read_text(encoding='utf-8'))
    mapping = {'PASS': 'passed', 'FAIL': 'failed', 'SKIP': 'skipped'}
    tests = {name: {'status': mapping.get(item['status'], 'error')} for name, item in report['nodes'].items()}
    print(json.dumps({'oracle_type': 'runtime_behavior', 'phase': report['phase'], 'collected': report['collected'], 'infrastructure_error': report['infrastructure_error'], 'tests': tests}))
else:
    lines = (root / 'runner.stdout.log').read_text(encoding='utf-8', errors='replace').splitlines()
    report = {}
    for line in lines:
        try:
            report = json.loads(line)
        except ValueError:
            continue
    print(json.dumps({'oracle_type': 'runtime_behavior', 'tests': {}, 'diagnostic': report}))

code = int(sys.argv[1])
if code == 2:
    # Tools were checked before the current build. A candidate that breaks
    # compilation, library inputs, loading or test collection is unresolved.
    # Timeouts and failures outside the known execution phases remain infra.
    phase = report.get('phase')
    if phase in {'fixture_compilation', 'test_compilation', 'dynamic_loading', 'collection', 'call'} and report.get('category') != 'timeout':
        sys.exit(1)
    sys.exit(2)
sys.exit(code if code in (0, 1) else 2)
PY
}
""",
    "lwjgl__lwjgl3-clb-062": r"""    python3 /benchmark/test_runner.py /testbed /results > /results/runner.stdout.log 2>/results/runner.stderr.log
    local status=$?
    cat /results/runner.stdout.log
    return "$status"
}
""",
    "lwjgl__lwjgl3-clb-068": LWJGL_RUNNER_TESTS,
    "lwjgl__lwjgl3-clb-069": r"""    local cp="bin/classes/lwjgl/core:bin/classes/test:bin/libs/java/testng.jar:bin/libs/java/jcommander.jar"
    local native="bin/libs:bin/libs/linux/x64"
    local raw=/tmp/testng.raw.log

    java -ea -Dorg.lwjgl.util.Debug=true -Dorg.lwjgl.util.DebugAllocator=true \
        -Djava.library.path="${native}" -cp "${cp}" \
        org.testng.TestNG -verbose 2 -testclass org.lwjgl.system.MemoryUtilTest >"${raw}" 2>&1
    local status=$?
    cat "${raw}"

    # Keep the complete TestNG log while emitting stable unittest-shaped lines
    # consumed by the generic evaluator.
    if grep -q '^PASSED: testTextDecoding' "${raw}"; then
        echo 'testTextDecoding (org.lwjgl.system.MemoryUtilTest) ... ok'
    else
        echo 'testTextDecoding (org.lwjgl.system.MemoryUtilTest) ... FAIL'
    fi
    if grep -q '^PASSED: testUTF8' "${raw}"; then
        echo 'testUTF8 (org.lwjgl.system.MemoryUtilTest) ... ok'
    else
        echo 'testUTF8 (org.lwjgl.system.MemoryUtilTest) ... FAIL'
    fi
    return "${status}"
}
""",
    "lwjgl__lwjgl3-clb-074": LWJGL_RUNNER_TESTS,
    "lwjgl__lwjgl3-clb-075": LWJGL_RUNNER_TESTS,
    "mdsplus__mdsplus-clb-194": r"""    local control_status=0
    local target_status=0

    run_one_tdi_test test-tdishr || control_status=$?
    run_one_tdi_test test-treeshr || target_status=$?
    [[ "${control_status}" -eq 0 && "${target_status}" -eq 0 ]]
}
""",
    "mdsplus__mdsplus-clb-200": r"""    local control_status=0
    local target_status=0

    run_one_tdi_test test-tdishr test-tdishr || control_status=$?
    run_one_tdi_test test-treeshr test-treeshr-owner-id || target_status=$?
    [[ "${control_status}" -eq 0 && "${target_status}" -eq 0 ]]
}

""",
    "ninia__jep-clb-092": JEP_VERBOSE_TESTS,
    "ninia__jep-clb-093": r"""    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /opt/clb-pilot/run_tests_verbose.py
}
""",
    "ninia__jep-clb-094": r"""    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run runtests.py
}
""",
    "ninia__jep-clb-097": r"""    export BENCHMARK_CHILD_LOG_DIR=/results/children
    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /benchmark/run_tests_verbose.py
}
""",
    "ninia__jep-clb-099": JEP_VERBOSE_TESTS,
    "ninia__jep-clb-100": JEP_VERBOSE_TESTS,
    "uclouvain__openjpeg-clb-112": r"""    local encode_status=1
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
""",
}


# Files shared by every task of a project.
PROJECT_FIXTURES = {
    "mdsplus__mdsplus": ("common/kohlschutter__junixsocket-clb-150/format_test_log.py",),
    "uclouvain__openjpeg": ("common/kohlschutter__junixsocket-clb-150/format_test_log.py",),
}


# Additional files required by specific tasks.
INSTANCE_FIXTURES = {
    "kohlschutter__junixsocket-clb-150": (
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "kohlschutter__junixsocket/report_surefire.py",
    ),
    "kohlschutter__junixsocket-clb-152": ("common/kohlschutter__junixsocket-clb-150/format_test_log.py",),
    "kohlschutter__junixsocket-clb-160": (
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "kohlschutter__junixsocket/report_surefire.py",
    ),
    "kohlschutter__junixsocket-clb-161": (
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "kohlschutter__junixsocket/report_surefire.py",
    ),
    "kohlschutter__junixsocket-clb-163": (
        "kohlschutter__junixsocket/163/build_project.py",
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "kohlschutter__junixsocket/163/run_case_tests.py",
        "kohlschutter__junixsocket/163/upstream_tests.json",
    ),
    "kohlschutter__junixsocket-clb-170": (
        "kohlschutter__junixsocket/170/build_project.py",
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "kohlschutter__junixsocket/170/run_case_tests.py",
        "kohlschutter__junixsocket/170/upstream_tests.json",
    ),
    "kohlschutter__junixsocket-clb-175": (
        "common/normalize_results.py",
        "kohlschutter__junixsocket/report_surefire.py",
    ),
    "lwjgl__lwjgl3-clb-056": (
        "lwjgl__lwjgl3/056/build_project.py",
        "lwjgl__lwjgl3/format_test_log.py",
        "lwjgl__lwjgl3/056/test_runner.py",
    ),
    "lwjgl__lwjgl3-clb-062": (
        "lwjgl__lwjgl3/062/build_project.py",
        "lwjgl__lwjgl3/format_test_log.py",
        "lwjgl__lwjgl3/062/test_runner.py",
    ),
    "lwjgl__lwjgl3-clb-068": (
        "lwjgl__lwjgl3/068/build_project.py",
        "lwjgl__lwjgl3/format_test_log.py",
        "lwjgl__lwjgl3/068/test_runner.py",
    ),
    "lwjgl__lwjgl3-clb-069": ("common/kohlschutter__junixsocket-clb-150/format_test_log.py",),
    "lwjgl__lwjgl3-clb-074": (
        "lwjgl__lwjgl3/074/build_project.py",
        "lwjgl__lwjgl3/format_test_log.py",
        "lwjgl__lwjgl3/074/test_runner.py",
    ),
    "lwjgl__lwjgl3-clb-075": (
        "lwjgl__lwjgl3/075/build_project.py",
        "lwjgl__lwjgl3/format_test_log.py",
        "lwjgl__lwjgl3/075/test_runner.py",
        "lwjgl__lwjgl3/upstream_results.py",
        "lwjgl__lwjgl3/upstream_tests.json",
    ),
    "ninia__jep-clb-092": (
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "ninia__jep/092/run_tests_verbose.py",
    ),
    "ninia__jep-clb-093": (
        "common/normalize_results.py",
        "ninia__jep/092/run_tests_verbose.py",
    ),
    "ninia__jep-clb-094": ("ninia__jep/format_test_log.py",),
    "ninia__jep-clb-097": (
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "ninia__jep/092/run_tests_verbose.py",
    ),
    "ninia__jep-clb-099": (
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "ninia__jep/092/run_tests_verbose.py",
    ),
    "ninia__jep-clb-100": (
        "common/kohlschutter__junixsocket-clb-150/format_test_log.py",
        "ninia__jep/100/run_tests_verbose.py",
    ),
}
