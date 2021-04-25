#!/bin/bash

apt-get update -y
apt-get install -y expect

# Install perf
pushd /tmp &> /dev/null && \
  wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.14.173.tar.xz && \
  tar -xf ./linux-4.14.173.tar.xz && \
  pushd linux-4.14.173/tools/perf/ &> /dev/null && \
  apt-get -y install flex bison && \
  make -C . && \
  make install && \
  cp ./perf /usr/bin/perf && \
  popd &> /dev/null && \
  popd &> /dev/null