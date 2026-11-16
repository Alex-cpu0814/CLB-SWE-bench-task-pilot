FROM yutu0814/clb.base.x86_64.spglib_1776_spglib-clb-174:latest@sha256:494bc87195b7935e77944f1fa9eef0bbbdfb144de503843d2c32129de6ce5b9f

COPY --chmod=0644 <<'EOF_895a7f4e0e5b' /benchmark/case_adapter.sh
#!/usr/bin/env bash

build_project() {
    cmake -S test -B build -DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=/opt/googletest && cmake --build build --target test_magnetic_symmetry --parallel 2
}

run_project_tests() {
    python /benchmark/native_gtest_runner.py --binary /testbed/build/test_magnetic_symmetry \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_symmetry_from_database' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_spacegroup_type' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_magnetic_dataset_type4' \
        'test/test_magnetic_symmetry.cpp::test_magnetic_symmetry.test_spg_get_symmetry_with_tensors_rough_mag_symprec'
}
EOF_895a7f4e0e5b

COPY --chmod=0644 <<'EOF_fb38b443dc0a' /benchmark/format_test_log.py
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

COPY --chmod=0644 <<'EOF_bd846add4648' /benchmark/native_gtest_runner.py
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

COPY --chmod=0644 <<'EOF_0b97b77abd96' /benchmark/native_no_core.c
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
