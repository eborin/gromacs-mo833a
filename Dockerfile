FROM alpine:3.13.5

WORKDIR /root

# Install dependencies
RUN apk add --no-cache g++

# Copy GROMACS library
COPY ./build/gromacs /lib/gromacs
ENV PATH "/lib/gromacs/bin:${PATH}"

CMD ["gmx", "--version"]