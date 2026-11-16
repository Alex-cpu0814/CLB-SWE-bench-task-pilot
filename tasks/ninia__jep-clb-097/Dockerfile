FROM yutu0814/clb.base.x86_64.ninia_1776_jep-clb-097:latest@sha256:c7c49ac969885f0a4d0e198b07d853bb3cc6f6c370bbeebca3fdcee72e50ee77

COPY --chmod=0644 <<'EOF_dad71422d80f' /benchmark/case_adapter.sh
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

run_project_tests() {
    export BENCHMARK_CHILD_LOG_DIR=/results/children
    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run /benchmark/run_tests_verbose.py
}
EOF_dad71422d80f

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

COPY --chmod=0644 <<'EOF_45eb350b559a' /benchmark/run_tests_verbose.py
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
RUN git -C /testbed clean -fdx
