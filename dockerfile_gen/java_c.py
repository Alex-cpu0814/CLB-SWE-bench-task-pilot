"""Generation settings for the two Java–C cohorts."""

from .constants import CONTAINER_WORKDIR

COHORTS = {"java_author11", "java_upstream11"}
PILOT_NORMALIZERS = {
    "ninia__jep-clb-093": "python /opt/clb-pilot/normalize_results.py jep",
    "kohlschutter__junixsocket-clb-175": "python3 /opt/clb-pilot/normalize_results.py unittest",
}

PRESERVE_BIN = {
    "lwjgl__lwjgl3-clb-056",
    "lwjgl__lwjgl3-clb-062",
    "lwjgl__lwjgl3-clb-068",
    "lwjgl__lwjgl3-clb-069",
    "lwjgl__lwjgl3-clb-074",
    "lwjgl__lwjgl3-clb-075",
    "uclouvain__openjpeg-clb-112",
}

DOCKER_SETUP = {
    "lwjgl__lwjgl3-clb-075": "RUN ln -s /opt/clb-deps /benchmark/dependencies\n",
    # The checkout in this image belongs to the benchmark user.
    "mdsplus__mdsplus-clb-200": f"USER root\nRUN git config --system --add safe.directory {CONTAINER_WORKDIR}\n",
}

EVAL_SETUP = {
    "kohlschutter__junixsocket-clb-170": (
        "mkdir -p /case-noexec /case-exec || fail 'Cannot create test mountpoints'\n"
        "mount -t tmpfs -o rw,noexec,nosuid,size=64m tmpfs /case-noexec "
        "|| fail 'Cannot create noexec test mount'\n"
        "mount -t tmpfs -o rw,exec,nosuid,size=64m tmpfs /case-exec "
        "|| fail 'Cannot create executable test mount'\n"
    ),
}
