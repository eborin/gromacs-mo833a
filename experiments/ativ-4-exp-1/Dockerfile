FROM mo833a/gromacs:runtime

WORKDIR /root/experiment

RUN apk add perf
COPY input .

ENTRYPOINT perf record -o output/perf.data gmx mdrun -v -deffnm em