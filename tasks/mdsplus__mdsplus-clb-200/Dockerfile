FROM yutu0814/javac-case-200-mdsplus@sha256:77c71ce09d01e830e0b98f3607636f0ffb03abc24ad51498190f6e7e0fb961dd
COPY runtime/ /benchmark/
USER root
RUN git config --system --add safe.directory /testbed
RUN git -C /testbed clean -fdx
