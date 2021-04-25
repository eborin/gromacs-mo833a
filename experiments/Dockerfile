# Compile Stage Image
# -------------------------------------------------------------------------------------------------
FROM alpine:3.13.5 AS compile-stage

WORKDIR /root

RUN apk update && \
  apk upgrade && \
  apk --update add \
    gcc \
    g++ \
    build-base \
    cmake \
    libstdc++

COPY . .
RUN /bin/sh scripts/compile.sh

# Runtime image
# -------------------------------------------------------------------------------------------------
FROM alpine:3.13.5 AS runtime

WORKDIR /root

RUN apk add --no-cache g++

COPY --from=compile-stage /usr/local/gromacs /usr/local/gromacs
ENV PATH "/usr/local/gromacs/bin:${PATH}"