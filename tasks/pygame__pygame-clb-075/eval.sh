#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "0589ca062fa624f4bf2a9ebea7aedb2a08b37780" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/event_test.py b/test/event_test.py
index 399f0ee00..34fcd1df6 100644
--- a/test/event_test.py
+++ b/test/event_test.py
@@ -284,7 +284,7 @@ class EventModuleTest(unittest.TestCase):
         """Ensures NUMEVENTS does not exceed the maximum SDL number of events.
         """
         # Ref: https://www.libsdl.org/tmp/SDL/include/SDL_events.h
-        MAX_SDL_EVENTS = 0xFFFF + 1  # SDL_LASTEVENT = 0xFFFF
+        MAX_SDL_EVENTS = 0xFFFF  # SDL_LASTEVENT = 0xFFFF
 
         self.assertLessEqual(pygame.NUMEVENTS, MAX_SDL_EVENTS)
 
@@ -345,25 +345,21 @@ class EventModuleTest(unittest.TestCase):
 
     def test_post_and_get_keydown(self):
         """Ensure keydown events can be posted to the queue."""
-        surf = pygame.display.set_mode((10, 10))
-        pygame.event.get()
         activemodkeys = pygame.key.get_mods()
         
-        events = []
-        events.append(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_p))
-        events.append(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_y, mod=activemodkeys))
-        events.append(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_g, unicode="g"))
-        events.append(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_a, unicode=None))
-        events.append(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_m, mod=None, window=None))
-        events.append(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_e, mod=activemodkeys, unicode="e"))
+        events = [
+            pygame.event.Event(pygame.KEYDOWN, key=pygame.K_p),
+            pygame.event.Event(pygame.KEYDOWN, key=pygame.K_y, mod=activemodkeys),
+            pygame.event.Event(pygame.KEYDOWN, key=pygame.K_g, unicode="g"),
+            pygame.event.Event(pygame.KEYDOWN, key=pygame.K_a, unicode=None),
+            pygame.event.Event(pygame.KEYDOWN, key=pygame.K_m, mod=None, window=None),
+            pygame.event.Event(pygame.KEYDOWN, key=pygame.K_e, mod=activemodkeys, unicode="e")
+        ]
         
         for e in events:
-            pygame.event.clear()
             pygame.event.post(e)
             posted_event = pygame.event.poll()
-            self.assertEqual(e.type, posted_event.type, race_condition_notification)
-            self.assertEqual(e.type, pygame.KEYDOWN, race_condition_notification)
-            self.assertEqual(e.key, posted_event.key, race_condition_notification)
+            self.assertEqual(e, posted_event, race_condition_notification)
 
     def test_post_large_user_event(self):
         pygame.event.post(pygame.event.Event(pygame.USEREVENT, {"a": "a" * 1024}))
@@ -372,6 +368,18 @@ class EventModuleTest(unittest.TestCase):
         self.assertEqual(e.type, pygame.USEREVENT)
         self.assertEqual(e.a, "a" * 1024)
 
+    def test_post_blocked(self):
+        """
+        Test blocked events are not posted. Also test whether post()
+        returns a boolean correctly
+        """
+        pygame.event.set_blocked(pygame.USEREVENT)
+        self.assertFalse(pygame.event.post(pygame.event.Event(pygame.USEREVENT)))
+        self.assertFalse(pygame.event.poll())
+        pygame.event.set_allowed(pygame.USEREVENT)
+        self.assertTrue(pygame.event.post(pygame.event.Event(pygame.USEREVENT)))
+        self.assertEqual(pygame.event.poll(), pygame.event.Event(pygame.USEREVENT))
+
     def test_get(self):
         """Ensure get() retrieves all the events on the queue."""
         event_cnt = 10
@@ -390,6 +398,14 @@ class EventModuleTest(unittest.TestCase):
         self.assertEqual(len(queue), 1)
         self.assertEqual(queue[0].type, pygame.USEREVENT)
 
+        TESTEVENTS = 10
+        for _ in range(TESTEVENTS):
+            pygame.event.post(ev)
+        q = pygame.event.get([pygame.USEREVENT])
+        self.assertEqual(len(q), TESTEVENTS)
+        for event in q:
+            self.assertEqual(event, ev)
+
     def test_get__empty_queue(self):
         """Ensure get() works correctly on an empty queue."""
         expected_events = []
diff --git a/test/time_test.py b/test/time_test.py
index 8f99b1db6..da3c5c62e 100644
--- a/test/time_test.py
+++ b/test/time_test.py
@@ -247,7 +247,7 @@ class TimeModuleTest(unittest.TestCase):
         Also tests if setting milliseconds to 0 stops the timer and if
         the once argument and repeat arguments work.
         """
-        pygame.display.init()
+        pygame.init()
         TIMER_EVENT_TYPE = pygame.event.custom_type()
         timer_event = pygame.event.Event(TIMER_EVENT_TYPE)
         delta = 50
@@ -279,12 +279,12 @@ class TimeModuleTest(unittest.TestCase):
         pygame.time.delay(200)
         self.assertNotIn(timer_event, pygame.event.get())
 
-        # Test that the once argument works
+        # Test that the loops=True works
         pygame.time.set_timer(TIMER_EVENT_TYPE, 10, True)
         pygame.time.delay(40)
         self.assertEqual(pygame.event.get().count(timer_event), 1)
 
-        # Test a variety of event objects, test repeat argument
+        # Test a variety of event objects, test loops argument
         events_to_test = [
             pygame.event.Event(TIMER_EVENT_TYPE),
             pygame.event.Event(TIMER_EVENT_TYPE, foo="9gwz5", baz=12,
@@ -294,9 +294,10 @@ class TimeModuleTest(unittest.TestCase):
         repeat = 3
         millis = 50
         for e in events_to_test:
-            pygame.time.set_timer(e, millis, repeat=repeat)
+            pygame.time.set_timer(e, millis, loops=repeat)
             pygame.time.delay(2 * millis * repeat)
             self.assertEqual(pygame.event.get().count(e), repeat)
+        pygame.quit()
 
     def test_wait(self):
         """Tests time.wait() function."""
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_58a7f314bb3a' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    bash -c 'python setup.py build --build-lib /testbed/build/local --build-temp /testbed/build/temp --force > /tmp/pygame-build-buffer.raw.log 2>&1; rc=$?; cat /tmp/pygame-build-buffer.raw.log; exit "$rc"'
}

run_project_tests() {
    python /benchmark/pytest_no_dump.py -c /dev/null --rootdir=/testbed -p no:cacheprovider -vv --color=no \
        'test/event_test.py::EventModuleTest::test_post_large_user_event' \
        'test/event_test.py::EventModuleTest::test_get_type' \
        'test/event_test.py::EventModuleTest::test_post_blocked' \
        'test/time_test.py::TimeModuleTest::test_set_timer'
}
EOF_58a7f314bb3a
cat > /benchmark/format_test_log.py <<'EOF_c7734a8368ee' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)

TEST_START_LINE = re.compile(r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. .*")

PYTEST_LINE = re.compile(
    r"^(?P<test_id>test/\S+)\s+"
    r"(?P<status>PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[.*\])?$"
)

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
        pytest_match = PYTEST_LINE.match(line)
        if pytest_match:
            statuses[pytest_match.group("test_id")] = pytest_match.group("status")
            pending = None
            continue
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
EOF_c7734a8368ee
cat > /benchmark/pytest_no_dump.py <<'EOF_df4aa13b0e5b' || fail 'Cannot write /benchmark/pytest_no_dump.py'
"""Run official pytest nodes without producing host-side Linux/WSL core dumps."""
import ctypes
import resource
import sys

import pytest

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(4, 0, 0, 0, 0) != 0 or libc.prctl(3, 0, 0, 0, 0) != 0:
    raise RuntimeError("Could not disable process dumpability")
sys.exit(pytest.main(sys.argv[1:]))
EOF_df4aa13b0e5b
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
