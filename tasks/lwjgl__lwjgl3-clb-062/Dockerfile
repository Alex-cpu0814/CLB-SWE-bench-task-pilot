FROM yutu0814/clb.base.x86_64.lwjgl_1776_lwjgl3-clb-062:latest@sha256:90695470bc689abb88d9d3d143bd855105f9daaa5abb0917c4289032cfcea0c6

COPY --chmod=0644 <<'EOF_5cdddc317386' /benchmark/case_adapter.sh
#!/usr/bin/env bash
build_project() {
    command -v python3 >/dev/null && command -v git >/dev/null && command -v ant >/dev/null && command -v gcc >/dev/null && command -v java >/dev/null && command -v javac >/dev/null || return 2
    python3 /benchmark/build_project.py /testbed
}
run_project_tests() {
    python3 /benchmark/test_runner.py /testbed /results > /results/runner.stdout.log 2>/results/runner.stderr.log
    local status=$?
    cat /results/runner.stdout.log
    return "$status"
}
EOF_5cdddc317386

COPY --chmod=0644 <<'EOF_3e8c5dbea025' /benchmark/build_project.py
"""Cold Ant build of current LWJGL Core/LLVM Java and JNI bindings."""
import json
import subprocess
import sys
from pathlib import Path

repo=Path(sys.argv[1] if len(sys.argv)>1 else '/testbed').resolve()
if repo != Path('/testbed') or not (repo/'build.xml').is_file():
    raise SystemExit('Expected isolated /testbed checkout')
flags=['-Dbuild.type=release/3.2.2','-Dbuild.offline=true','-Dbinding.llvm=true']
import xml.etree.ElementTree as ET
names={e.attrib.get('name',e.attrib.get('property','')) for e in ET.parse(repo/'config/build-bindings.xml').iter()}
flags.extend('-D'+name+'=false' for name in sorted(names) if name.startswith('binding.') and name not in ('binding.llvm','binding.DISABLE_CHECKS'))
cmd=['ant',*flags,'clean-kotlin','clean-java','clean-native','compile-templates','compile-native']
print(json.dumps({'phase':'source_build','command':cmd}),flush=True)
result=subprocess.run(cmd,cwd=repo)
if result.returncode:
    sys.exit(result.returncode)
for path in ('bin/libs/native/linux/x64/org/lwjgl/liblwjgl.so','bin/libs/native/linux/x64/org/lwjgl/llvm/liblwjgl_llvm.so'):
    if not (repo/path).is_file():
        raise SystemExit('Missing current native library: '+path)
EOF_3e8c5dbea025

COPY --chmod=0644 <<'EOF_284a4c0f196d' /benchmark/format_test_log.py
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

import json

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
        if line.startswith("{"):
            try:
                report = json.loads(line)
            except ValueError:
                continue
            if report.get("oracle_type") in ("runtime_behavior", "compilation") and isinstance(report.get("tests"), dict):
                mapping = {"passed": "PASSED", "failed": "FAILED", "error": "ERROR", "skipped": "SKIPPED"}
                for test_id, item in report["tests"].items():
                    if isinstance(item, dict):
                        statuses[test_id] = mapping.get(item.get("status"), "UNKNOWN")
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
EOF_284a4c0f196d

COPY --chmod=0644 <<'EOF_a6d3d966e8e7' /benchmark/test_runner.py
"""Run protected direct control and target binding in separate JVMs."""
import json
import subprocess
import sys
from pathlib import Path
repo,out=Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve()
out.mkdir(parents=True,exist_ok=True)
source=repo/'modules/lwjgl/llvm/src/test/java/org/lwjgl/llvm/ClangCStringRegressionTest.java'
cp=':'.join(str(repo/p) for p in ('bin/classes/lwjgl/core','bin/classes/lwjgl/llvm','bin/libs/java/*'))
classes=repo/'bin/classes/test'
classes.mkdir(parents=True,exist_ok=True)
with (out/'test-compilation.private.log').open('wb') as f:
    c=subprocess.run(['javac','--release','11','-cp',cp,'-d',str(classes),str(source)],cwd=repo,stdout=f,stderr=subprocess.STDOUT)
if c.returncode:
    print(json.dumps({'phase':'test_compilation','exit_code':c.returncode,'infrastructure_error':False,'tests':{}}))
    sys.exit(1)
native=repo/'bin/libs/native'
compiled=native/'linux/x64'
if not (compiled/'org/lwjgl/liblwjgl.so').is_file() or not (compiled/'org/lwjgl/llvm/liblwjgl_llvm.so').is_file():
    print(json.dumps({'phase':'native_preflight','infrastructure_error':True,'tests':{}}))
    sys.exit(2)
results={}
for mode in ('direct','binding'):
    cmd=['java','-XX:ErrorFile='+str(out/'hs_err-%p.log'),'-Dorg.lwjgl.librarypath='+str(native),'-Dorg.lwjgl.llvm.clang.libname=/usr/lib/llvm-14/lib/libclang.so','-cp',str(classes)+':'+cp,'org.lwjgl.llvm.ClangCStringRegressionTest',mode]
    with (out/(mode+'.private.log')).open('wb') as f:
        try: process=subprocess.run(cmd,cwd=repo,stdout=f,stderr=subprocess.STDOUT,timeout=120)
        except subprocess.TimeoutExpired:
            print(json.dumps({'phase':'call','category':'timeout','infrastructure_error':True,'tests':results}))
            sys.exit(2)
    status='passed' if process.returncode==0 else 'failed' if process.returncode==1 else 'error'
    results['org.lwjgl.llvm.ClangCStringRegressionTest::'+mode]={'status':status,'exit_code':process.returncode}
report={'oracle_type':'runtime_behavior','phase':'call','infrastructure_error':any(v['status']=='error' for v in results.values()),'tests':results}
(out/'sanitized_results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
sys.exit(2 if report['infrastructure_error'] else 0 if all(v['status']=='passed' for v in results.values()) else 1)
EOF_a6d3d966e8e7
RUN git -C /testbed clean -fdx -e bin
