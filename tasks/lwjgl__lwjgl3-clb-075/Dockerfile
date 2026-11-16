FROM yutu0814/clb.base.x86_64.lwjgl_1776_lwjgl3-clb-075:latest@sha256:bab94a09875465ffbfb542746dfbc2c29205057939b1e1eb2a36fd0b86925984
COPY runtime/ /benchmark/
RUN ln -s /opt/clb-deps /benchmark/dependencies
RUN git -C /testbed clean -fdx -e bin
