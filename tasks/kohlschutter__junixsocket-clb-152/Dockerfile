FROM yutu0814/clb.base.x86_64.kohlschutter_1776_junixsocket-clb-152:latest@sha256:7c17382b5b88d9de614df35143fa0b97c0101611079574f0999b848d3ef1fda8

COPY --chmod=0644 <<'EOF_ac7b360ceedd' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    mvn -B -o -Prelease-native \
        -pl junixsocket-native-common,junixsocket-native-custom -am clean install \
        -Dmaven.test.skip=true \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default \
        && mvn -B -o -f junixsocket-common/pom.xml package -Dmaven.test.skip=true
}

run_project_tests() {
    local common_jar native_common_jar native_custom_jar class_path
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
EOF_ac7b360ceedd

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
RUN git -C /testbed clean -fdx
