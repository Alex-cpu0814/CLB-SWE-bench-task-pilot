FROM yutu0814/clb.base.x86_64.mdsplus_1776_mdsplus-clb-200:latest@sha256:540d1b56d89a81f690d9cafa09dc5f2310d58d20c3fd6d7d0b213e6cd8ba44b5
COPY runtime/ /benchmark/
USER root
RUN git config --system --add safe.directory /testbed
RUN git -C /testbed clean -fdx
