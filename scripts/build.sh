#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

SCRIPTS_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
SOURCE_DIR=$(dirname ${SCRIPTS_PATH})
COMPILE_FLAGS="${@:--DGMX_BUILD_OWN_FFTW=ON}"
BUILD_DIR="${SOURCE_DIR}/build"

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  echo "Building GROMACS"

  compile_gromacs
}


# Fetch GROMACS
# -------------------------------------------------------------------------------------------------

function compile_gromacs {
  echo "Compiling from: ${SOURCE_DIR}"

  ensure_required_dirs
  build_gromacs
}

function ensure_required_dirs {
  mkdir -p $BUILD_DIR
}

function build_gromacs {
  cd $BUILD_DIR
  cmake .. $COMPILE_FLAGS
  make -j6
  make install
}

# Execute
# -------------------------------------------------------------------------------------------------

main $@