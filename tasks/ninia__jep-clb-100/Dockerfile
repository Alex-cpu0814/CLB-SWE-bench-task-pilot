FROM yutu0814/clb.base.x86_64.ninia_1776_jep-clb-100:latest@sha256:4242937c5af25549c8e96b621a12ba12e7eeb418dbbd74ae32d774e7c3bead9d

COPY --chmod=0644 <<'EOF_8c196d945fd4' /benchmark/case_adapter.sh
#!/usr/bin/env bash

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

run_project_tests() {
    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /benchmark/run_tests_verbose.py
}
EOF_8c196d945fd4

COPY --chmod=0644 <<'EOF_8a58ff4098c6' /benchmark/format_test_log.py
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

COPY --chmod=0644 <<'EOF_2d28fb72eff7' /benchmark/run_tests_verbose.py
from __future__ import print_function

import sys
import unittest


if __name__ == '__main__':
    suite = unittest.TestLoader().discover('tests')
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.stdout.flush()
    sys.stderr.flush()
    # JEP 3.2 treats any Python SystemExit as an embedding exception,
    # including SystemExit(0). Return naturally on success instead.
    if not result.wasSuccessful():
        raise AssertionError("test suite failed")
EOF_2d28fb72eff7
RUN git -C /testbed clean -fdx
