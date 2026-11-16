FROM yutu0814/clb.base.x86_64.ninia_1776_jep-clb-093:latest@sha256:4ac5cee19d541869db19dc060db7ea23928c001afff67ef8655bca0ba7607015

COPY --chmod=0644 <<'EOF_8d58bd27b32d' /opt/clb-pilot/case_adapter.sh
#!/usr/bin/env bash

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

run_project_tests() {
    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /opt/clb-pilot/run_tests_verbose.py
}
EOF_8d58bd27b32d

COPY --chmod=0644 <<'EOF_c05e792222b6' /opt/clb-pilot/normalize_results.py
"""Translate CLB test result lines to the upstream status-first format."""

import io
import re
import sys


PYTEST = re.compile(
    r"^(scipy/\S.*?)\s+(PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[\s*\d+%\])?$"
)
UNITTEST = re.compile(r"^(\S+) \(([^)]+)\) \.\.\.(?: (.*))?$")


def statuses(lines, mode):
    pending = None
    mapping = {"ok": "PASSED", "FAIL": "FAILED", "ERROR": "ERROR", "skipped": "SKIPPED"}
    for raw in lines:
        line = raw.strip()
        if mode == "pytest":
            result = PYTEST.match(line)
            if result:
                yield result.group(2), result.group(1)
            continue
        result = UNITTEST.match(line)
        if result:
            method, test_class, line = result.groups()
            if mode == "jep" and test_class.startswith("tests."):
                test_class = test_class[len("tests."):]
            pending = test_class + "." + method
            line = line or ""
        if pending and line:
            status = mapping.get("skipped" if line.startswith("skipped") else line)
            if status:
                yield status, pending
                pending = None


if __name__ == "__main__":
    with io.open(sys.argv[2], encoding="utf-8", errors="replace") as stream:
        for status, test_id in statuses(stream, sys.argv[1]):
            print("{} {}".format(status, test_id))
EOF_c05e792222b6

COPY --chmod=0644 <<'EOF_45eb350b559a' /opt/clb-pilot/run_tests_verbose.py
from __future__ import print_function

import sys
import unittest


if __name__ == '__main__':
    suite = unittest.TestLoader().discover('tests')
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.stdout.flush()
    sys.stderr.flush()
    raise SystemExit(0 if result.wasSuccessful() else 1)
EOF_45eb350b559a
