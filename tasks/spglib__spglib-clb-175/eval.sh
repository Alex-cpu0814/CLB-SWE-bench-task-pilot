#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "4afa84322f83b368dada7e3c6f64c3a17114aaa0" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/test/test_magnetic_symmetry.cpp b/test/test_magnetic_symmetry.cpp
index 39a972f..6973a91 100644
--- a/test/test_magnetic_symmetry.cpp
+++ b/test/test_magnetic_symmetry.cpp
@@ -300,6 +300,68 @@ TEST(test_magnetic_symmetry, test_spg_get_magnetic_dataset_type4) {
     spg_free_magnetic_dataset(dataset);
 }
 
+TEST(
+    test_magnetic_symmetry,
+    test_spg_get_symmetry_with_tensors_rough_symprec) {
+
+    // https://github.com/spglib/spglib/issues/186
+    double lattice[][3] = {  // column-wise!
+        {3.36017962, 1.70747655, -0.0117898},
+        {0.        , 3.84457132, -0.29501452},
+        {0.95244787, 0.37960516,  6.4450749},
+    };
+    double positions[][3] = {
+        {0.0, 0.0, 0.0},
+        {0.26737473, 0.2232512, 0.24199933},
+        {0.73262527, 0.7767488, 0.75800067},
+    };
+    int types[] = {0, 1, 1};
+    double tensors[] = {0.005, 0.002, 0.002};
+    int num_atoms = 3;
+    int max_size = num_atoms * 96;
+
+    double symprec = 1e-2;  // with high symprec
+    double mag_symprec = symprec;  // with high mag_symprec
+
+    int i, size;
+    int equivalent_atoms[3];
+    double primitive_lattice[3][3];
+    int(*rotations)[3][3];
+    double(*translations)[3];
+    int *spin_flips;
+    int *time_reversals;
+
+    rotations = (int(*)[3][3])malloc(sizeof(int[3][3]) * max_size);
+    translations = (double(*)[3])malloc(sizeof(double[3]) * max_size);
+    spin_flips = (int *)malloc(sizeof(int *) * max_size);
+    time_reversals = (int *)malloc(sizeof(int *) * max_size);
+
+    size = spg_get_symmetry(rotations, translations, max_size, lattice, positions, types, num_atoms, symprec);
+    ASSERT_EQ(size, 4);
+    show_symmetry_operations(rotations, translations, size);
+
+    size = spgms_get_symmetry_with_site_tensors(
+        rotations, translations, equivalent_atoms, primitive_lattice, spin_flips,
+        max_size, lattice, positions, types, tensors,
+        0 /* tensor_rank */ , num_atoms,
+        1 /* with_time_reversal */,
+        0 /* is_axial */,
+        symprec, -1 /* angle_tolerance */, mag_symprec);
+    ASSERT_EQ(size, 4);
+
+    for (i = 0; i < size; i++) {
+        time_reversals[i] = (1 - spin_flips[i]) / 2;
+    }
+    show_magnetic_symmetry_operations(rotations, translations, time_reversals, size);
+
+    free(rotations);
+    free(translations);
+    free(spin_flips);
+    free(time_reversals);
+}
+
+// TODO: test get_magnetic_dataset with distorted positions
+
 // ****************************************************************************
 // Local functions
 // ****************************************************************************
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_3ccf383962a4' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    cmake -S test -B build -DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=/opt/googletest && cmake --build build --target test_magnetic_symmetry --parallel 2
}

run_project_tests() {
    python /benchmark/native_gtest_runner.py --binary /testbed/build/test_magnetic_symmetry \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_symmetry_from_database' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_spacegroup_type' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_dataset_type4' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_symmetry_with_tensors_rough_symprec'
}
EOF_3ccf383962a4
cat > /benchmark/format_test_log.py <<'EOF_fb38b443dc0a' || fail 'Cannot write /benchmark/format_test_log.py'
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

def parse_test_log(text):
    # Official wrapper owns terminal statuses after checking true child results.
    # Human-readable bundled-unittest output is retained but is not a second ID.
    statuses = {}
    for line in text.splitlines():
        match = PYTEST_LINE.match(line)
        if match and match.end() == len(line):
            statuses[match.group("test_id")] = match.group("status")
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_fb38b443dc0a
cat > /benchmark/native_gtest_runner.py <<'EOF_bd846add4648' || fail 'Cannot write /benchmark/native_gtest_runner.py'
"""Run complete upstream native GoogleTest cases; preserve real native exits/statuses."""
import argparse,hashlib,json,os,pathlib,re,signal,subprocess,sys
parser=argparse.ArgumentParser();parser.add_argument('--binary',required=True);parser.add_argument('--collect-only',action='store_true');parser.add_argument('nodes',nargs='+');args=parser.parse_args()
if len(args.nodes)!=len(set(args.nodes)):raise ValueError('Unique original nodes required')
mapping={}
for node in args.nodes:
 source,name=node.split('::',1)
 if not source.startswith('test/')or not source.endswith('.cpp')or not re.fullmatch(r'[A-Za-z0-9_]+\.[A-Za-z0-9_]+',name):raise ValueError('Original C++ GoogleTest node required')
 mapping[name]=node
binary=pathlib.Path(args.binary).resolve()
if not str(binary).startswith('/testbed/build/')or not binary.is_file():raise ValueError('Unexpected native test binary')
native_filter=':'.join(mapping)
if args.collect_only:
 command=[str(binary),'--gtest_color=no','--gtest_filter='+native_filter,'--gtest_list_tests'];r=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 print('__NATIVE_DISCOVERY__ '+json.dumps({'command':command,'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr}))
 if r.returncode:sys.exit(r.returncode if r.returncode>0 else 128-r.returncode)
 suite=None;found=[]
 for line in r.stdout.splitlines():
  if line and not line[0].isspace()and line.endswith('.'):suite=line.strip()
  elif suite and line.startswith('  '):
   name=suite+line.strip().split(' ',1)[0]
   if name in mapping:found.append(mapping[name])
 if set(found)!=set(args.nodes)or len(found)!=len(args.nodes):raise RuntimeError('Original binary discovery mismatch')
 for node in found:print(node)
 sys.exit(0)
guard=pathlib.Path('/benchmark/native_no_core.c');guard_library='/tmp/benchmark_no_core.so'
subprocess.check_call(['cc','-shared','-fPIC','-O2',str(guard),'-o',guard_library])
environment=os.environ.copy();environment['LD_PRELOAD']=guard_library
print('__NATIVE_GTEST_WRAPPER__ '+json.dumps({'guard_source_sha256':hashlib.sha256(guard.read_bytes()).hexdigest(),'guard_scope':'Process dumpability/resource metadata only; no interposed functions, allocator, signal handler or test modification','core_pattern':pathlib.Path('/proc/sys/kernel/core_pattern').read_text().strip()}),flush=True)
command=[str(binary),'--gtest_color=no','--gtest_filter='+native_filter];child=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1,env=environment)
active=set();starts=[];terminals={}
for line in child.stdout:
 sys.stdout.write(line)
 start=re.match(r'^\[\s*RUN\s*\]\s+(\S+)\s*$',line)
 if start and start.group(1)in mapping:
  name=start.group(1);active.add(name);starts.append(mapping[name]);print(mapping[name]+' STARTED',flush=True)
 terminal=re.match(r'^\[\s*(OK|FAILED|SKIPPED)\s*\]\s+(\S+)(?:\s+.*)?$',line)
 if terminal and terminal.group(2)in active:
  kind,name=terminal.groups();status={'OK':'PASSED','FAILED':'FAILED','SKIPPED':'SKIPPED'}[kind];active.remove(name);terminals[mapping[name]]=status;print(mapping[name]+' '+status,flush=True)
 sys.stdout.flush()
returncode=child.wait();shell_exit=returncode if returncode>=0 else 128-returncode
record={'command':command,'requested_nodes':args.nodes,'observed_starts':starts,'terminal_statuses':terminals,'returncode':returncode,'signal':signal.Signals(-returncode).name if returncode<0 else None,'shell_exit_code':shell_exit,'executed':True}
print('__NATIVE_PROCESS_RESULT__ '+json.dumps(record),flush=True)
sys.exit(shell_exit)
EOF_bd846add4648
cat > /benchmark/native_no_core.c <<'EOF_0b97b77abd96' || fail 'Cannot write /benchmark/native_no_core.c'
/* Runtime-only process resource guard for the WSL piped core handler.
 * No interposed functions, signal handlers, allocations or test operations. */
#include <sys/prctl.h>
#include <sys/resource.h>
#include <unistd.h>

__attribute__((constructor)) static void disable_core_dump(void) {
    struct rlimit limit = {0, 0};
    if (setrlimit(RLIMIT_CORE, &limit) != 0 ||
        prctl(PR_SET_DUMPABLE, 0UL, 0UL, 0UL, 0UL) != 0) {
        _exit(125);
    }
}
EOF_0b97b77abd96
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
