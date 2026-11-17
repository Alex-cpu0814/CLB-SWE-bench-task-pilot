# syntax=docker/dockerfile:1
FROM ubuntu:22.04@sha256:5ec03bb3441e8b0bf3b4f9cd4629a1ae763010dc3035bb8da3ae6cf026486401
ENV DEBIAN_FRONTEND=noninteractive JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 LANG=C.UTF-8 LC_ALL=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends curl ant ca-certificates git openjdk-17-jdk-headless gcc g++ libx11-dev make unzip python3 && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y --no-install-recommends libffi-dev=3.4.2-4 && apt-get clean && rm -rf /var/lib/apt/lists/* && ln -s /usr/bin/python3 /usr/local/bin/python

ARG BASE_COMMIT=@BASE@
ARG INSTANCE_ID=@INSTANCE@
LABEL benchmark.instance_id="${INSTANCE_ID}" benchmark.base_commit="${BASE_COMMIT}" org.opencontainers.image.source="https://github.com/LWJGL/lwjgl3"
WORKDIR /testbed
# Only a depth-one Base object store and Base-declared dependency cache enter the image.
ARG REPO_URL=https://github.com/LWJGL/lwjgl3.git
RUN git init /testbed \
    && cd /testbed \
    && git config core.autocrlf false \
    && git fetch --no-tags --depth=1 "${REPO_URL}" "${BASE_COMMIT}" \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "${BASE_COMMIT}" \
    && test -z "$(git status --porcelain)"
RUN git config core.bare false && git config core.autocrlf false && git checkout --detach "${BASE_COMMIT}" && test -z "$(git status --porcelain)"
RUN mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/jsr305.jar "https://repo.maven.apache.org/maven2/com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2.jar" \
    && echo "766ad2a0783f2687962c8ad74ceecc38a28b9f72a2d085ee438b7813e928d0c7  /testbed/bin/libs/java/jsr305.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/jsr305-sources.jar "https://repo.maven.apache.org/maven2/com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2-sources.jar" \
    && echo "1c9e85e272d0708c6a591dc74828c71603053b48cc75ae83cce56912a2aa063b  /testbed/bin/libs/java/jsr305-sources.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/testng.jar "https://repo.maven.apache.org/maven2/org/testng/testng/7.4.0/testng-7.4.0.jar" \
    && echo "f28e9e881f5dcf2d197c447778369e3b2dc1a09742402577e87da58df21b86c0  /testbed/bin/libs/java/testng.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/testng-sources.jar "https://repo.maven.apache.org/maven2/org/testng/testng/7.4.0/testng-7.4.0-sources.jar" \
    && echo "7cbff3a284c29a6d983aa4e4336d3a33e2e97f1aad2f78b0176c10d36ef220ec  /testbed/bin/libs/java/testng-sources.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/jcommander.jar "https://repo.maven.apache.org/maven2/com/beust/jcommander/1.78/jcommander-1.78.jar" \
    && echo "7891debb84b5f83e9bd57593ebece3399abbe0fd938cf306b3534c57913b9615  /testbed/bin/libs/java/jcommander.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/joml.jar "https://repo.maven.apache.org/maven2/org/joml/joml/1.10.1/joml-1.10.1.jar" \
    && echo "f7b444565912ed322072c87b1a81125d826f3e0b35a07160d6994955fe1d52b6  /testbed/bin/libs/java/joml.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/joml-sources.jar "https://repo.maven.apache.org/maven2/org/joml/joml/1.10.1/joml-1.10.1-sources.jar" \
    && echo "fb733853b36c90b52be2d06aa14899b16095bc5268a35a5c8948791baf742a96  /testbed/bin/libs/java/joml-sources.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/jmh-core.jar "https://repo.maven.apache.org/maven2/org/openjdk/jmh/jmh-core/1.33/jmh-core-1.33.jar" \
    && echo "b1944c6c9b476abdd5756e04cff8b576c6a11728133d2bc54738ba785d9c8743  /testbed/bin/libs/java/jmh-core.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/jmh-core-sources.jar "https://repo.maven.apache.org/maven2/org/openjdk/jmh/jmh-core/1.33/jmh-core-1.33-sources.jar" \
    && echo "fc73b0f371cf4896a0e21636a32cffeacd7e422d417e781a0c2d9f62a7275988  /testbed/bin/libs/java/jmh-core-sources.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/jmh-generator-annprocess.jar "https://repo.maven.apache.org/maven2/org/openjdk/jmh/jmh-generator-annprocess/1.33/jmh-generator-annprocess-1.33.jar" \
    && echo "19948b4b281c66d9f31217d347f1a7b77b471ebcb67d2c3fc49c914de5906c16  /testbed/bin/libs/java/jmh-generator-annprocess.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/jopt-simple.jar "https://repo.maven.apache.org/maven2/net/sf/jopt-simple/jopt-simple/5.0.4/jopt-simple-5.0.4.jar" \
    && echo "df26cc58f235f477db07f753ba5a3ab243ebe5789d9f89ecf68dd62ea9a66c28  /testbed/bin/libs/java/jopt-simple.jar" | sha256sum -c - \
    && mkdir -p /testbed/bin/libs/java \
    && curl -fL --retry 3 --connect-timeout 30 -o /testbed/bin/libs/java/commons-math3.jar "https://repo.maven.apache.org/maven2/org/apache/commons/commons-math3/3.6.1/commons-math3-3.6.1.jar" \
    && echo "1e56d7b058d28b65abd256b8458e3885b674c1d588fa43cd7d1cbb9c7ef2b308  /testbed/bin/libs/java/commons-math3.jar" | sha256sum -c - \
    && mkdir -p /tmp \
    && curl -fL --retry 3 --connect-timeout 30 -o /tmp/kotlin-compiler.zip "https://github.com/JetBrains/kotlin/releases/download/v1.5.21/kotlin-compiler-1.5.21.zip" \
    && echo "f3313afdd6abf1b8c75c6292f4e41f2dbafefc8f6c72762c7ba9b3daeef5da59  /tmp/kotlin-compiler.zip" | sha256sum -c -
RUN python3 -m zipfile -e /tmp/kotlin-compiler.zip /testbed/bin/libs \
    && find /testbed/bin/libs/kotlinc/bin -type f -exec chmod +x {} + \
    && rm /tmp/kotlin-compiler.zip
RUN test "$(cat /testbed/bin/libs/kotlinc/build.txt)" = "1.5.21-release-314"

RUN python3 - <<'PY'
import hashlib
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

names = sorted({e.attrib.get('name', e.attrib.get('property', '')) for e in ET.parse('config/build-bindings.xml').iter() if e.attrib.get('name', e.attrib.get('property', '')).startswith('binding.')} - {'binding.DISABLE_CHECKS'})
flags = ['-D' + name + '=' + ('true' if name == 'binding.vulkan' else 'false') for name in names]
archive = Path('/usr/lib/x86_64-linux-gnu/libffi_pic.a')
assert hashlib.sha256(archive.read_bytes()).hexdigest() == 'fe417849a4af3c711b6b94f45219fbeb788896aaab478dd1806ecc23a8cfb85e'
destination = Path('bin/libs/native/linux/x64/org/lwjgl/libffi.a')
destination.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(archive, destination)
subprocess.run(['ant', '-Dbuild.type=release/3.3.0', *flags, 'compile-templates'], check=True)
subprocess.run(['ant', '-Dbuild.type=release/3.3.0', '-Dbuild.offline=true', *flags, 'compile-native'], check=True)
PY

# Keep dependencies; evaluations must compile project classes and JNI from current sources.
RUN python3 - <<'PY'
import shutil
from pathlib import Path
root = Path('/testbed').resolve()
for relative in ('bin/classes', 'bin/linux'):
    target = (root / relative).resolve()
    assert target.is_relative_to(root / 'bin')
    if target.exists():
        shutil.rmtree(target)
for library in (root / 'bin/libs/native').rglob('*.so'):
    library.unlink()
PY
RUN git restore --source="${BASE_COMMIT}" --worktree -- . \
    && test "$(git rev-parse HEAD)" = "${BASE_COMMIT}" \
    && test -z "$(git status --porcelain)" \
    && mkdir -p /benchmark /inputs /results
CMD ["/bin/bash"]
