#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "8a63c06f2e082b8c7e3c0fce035a0a7e4ca55d85" ]] || fail 'Unexpected Base commit'
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/event_test.py b/test/event_test.py
index de9cb1a34..8db99a99c 100644
--- a/test/event_test.py
+++ b/test/event_test.py
@@ -147,6 +147,13 @@ class EventModuleTest(unittest.TestCase):
         self.assertEqual(len(queue), event_cnt)
         self.assertTrue(all(e.type == pygame.USEREVENT for e in queue))
 
+    def test_get_type(self):
+        ev = pygame.event.Event(pygame.USEREVENT)
+        pygame.event.post(ev)
+        queue = pygame.event.get(pygame.USEREVENT)
+        self.assertEqual(len(queue), 1)
+        self.assertEqual(queue[0].type, pygame.USEREVENT)
+
     def test_clear(self):
         """Ensure clear() removes all the events on the queue."""
         for e in events:
@@ -188,6 +195,10 @@ class EventModuleTest(unittest.TestCase):
 
         self.assertTrue(pygame.event.peek(event_types))
 
+    def test_peek_empty(self):
+        pygame.event.clear()
+        self.assertFalse(pygame.event.peek())
+
     def test_set_allowed(self):
         """Ensure a blocked event type can be unblocked/allowed."""
         event = events[0]
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
