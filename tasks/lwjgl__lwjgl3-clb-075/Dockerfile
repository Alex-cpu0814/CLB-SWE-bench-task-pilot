# syntax=docker/dockerfile:1
ARG TOOLCHAIN_IMAGE=eclipse-temurin:8-jdk-jammy@sha256:d57e5d0e3e5dd4cabb74feccfdb36249a58c76a3354a33ee8737813df93b7e0d
FROM ${TOOLCHAIN_IMAGE}

RUN if ! command -v ant >/dev/null || ! dpkg-query -W pocl-opencl-icd >/dev/null 2>&1; then \
      apt-get update \
      && apt-get install -y --no-install-recommends curl git python3 gcc libc6-dev ant \
        libffi-dev libx11-dev libxrandr-dev libxxf86vm-dev libxcursor-dev libxinerama-dev \
        libgl-dev libegl-dev pocl-opencl-icd ocl-icd-opencl-dev \
      && rm -rf /var/lib/apt/lists/*; \
    fi
ARG BASE_COMMIT=f40cd981a1ff81e3da603059a062728ee33ddf02
ARG INSTANCE_ID=lwjgl__lwjgl3-clb-075
LABEL benchmark.instance_id="${INSTANCE_ID}" benchmark.base_commit="${BASE_COMMIT}" \
      org.opencontainers.image.source="https://github.com/LWJGL/lwjgl3"
WORKDIR /testbed
ARG REPO_URL=https://github.com/LWJGL/lwjgl3.git
RUN git init /testbed \
    && cd /testbed \
    && git config core.autocrlf false \
    && git fetch --no-tags --depth=1 "${REPO_URL}" "${BASE_COMMIT}" \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "${BASE_COMMIT}" \
    && test -z "$(git status --porcelain)"
RUN mkdir -p /opt/clb-deps \
    && curl -fL --retry 3 --connect-timeout 30 -o /opt/clb-deps/jcommander.jar "https://repo.maven.apache.org/maven2/com/beust/jcommander/1.48/jcommander-1.48.jar" \
    && echo "a7313fcfde070930e40ec79edf3c5948cf34e4f0d25cb3a09f9963d8bdd84113  /opt/clb-deps/jcommander.jar" | sha256sum -c - \
    && mkdir -p /opt/clb-deps \
    && curl -fL --retry 3 --connect-timeout 30 -o /opt/clb-deps/testng.jar "https://repo.maven.apache.org/maven2/org/testng/testng/6.8.21/testng-6.8.21.jar" \
    && echo "0811dcf08fe329ef5d4d37d51a6a00032697e7f54ba84c6687bbf7cd39d29fec  /opt/clb-deps/testng.jar" | sha256sum -c - \
    && mkdir -p /tmp \
    && curl -fL --retry 3 --connect-timeout 30 -o /tmp/kotlin-compiler.zip "https://github.com/JetBrains/kotlin/releases/download/build-0.13.1513/kotlin-compiler-0.13.1513.zip" \
    && echo "ac93ad3360f38ba2692a7f8bc7b7c74e8ca4cdb03e6e71377c51cd44bf842698  /tmp/kotlin-compiler.zip" | sha256sum -c -
RUN python3 -m zipfile -e /tmp/kotlin-compiler.zip /opt/clb-deps \
    && find /opt/clb-deps/kotlinc/bin -type f -exec chmod +x {} + \
    && rm /tmp/kotlin-compiler.zip
RUN git config core.bare false \
    && git config core.autocrlf false \
    && git checkout --detach "${BASE_COMMIT}" \
    && test -z "$(git status --porcelain)" \
    && mkdir -p /inputs /results
CMD ["/bin/bash"]
