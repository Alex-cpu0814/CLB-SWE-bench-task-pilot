# syntax=docker/dockerfile:1
FROM eclipse-temurin:8-jdk-jammy@sha256:d57e5d0e3e5dd4cabb74feccfdb36249a58c76a3354a33ee8737813df93b7e0d

RUN apt-get update \
    && apt-get install -y --no-install-recommends git python3 gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

ARG BASE_COMMIT=@BASE@
ARG INSTANCE_ID=@INSTANCE@
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
RUN git config core.bare false \
    && git config core.autocrlf false \
    && git checkout --detach "${BASE_COMMIT}" \
    && test -z "$(git status --porcelain)" \
    && mkdir -p /benchmark /inputs /results

CMD ["/bin/bash"]
