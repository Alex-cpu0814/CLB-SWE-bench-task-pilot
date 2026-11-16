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
