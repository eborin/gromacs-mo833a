FROM mo833a/gromacs:runtime

WORKDIR /root/experiment

RUN apk add perf
COPY input .

ENTRYPOINT perf record gmx mdrun -v -deffnm em