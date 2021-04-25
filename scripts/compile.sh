#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

COMPILE_FLAGS="${@:--DGMX_BUILD_OWN_FFTW=ON}"
SCRIPTS_DIR_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
SOURCE_DIR_PATH=$(dirname ${SCRIPTS_DIR_PATH})
BUILD_DIR_PATH="${SOURCE_DIR_PATH}/build"

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  echo "Compiling GROMACS"

  compile_gromacs

  exit 0
}

# Fetch GROMACS
# -------------------------------------------------------------------------------------------------

function compile_gromacs {
  echo "Compiling from: ${SOURCE_DIR}"

  ensure_required_dirs
  build_gromacs
}

function ensure_required_dirs {
  mkdir -p $BUILD_DIR_PATH
}

function build_gromacs {
  pushd $BUILD_DIR_PATH &> /dev/null

  cmake $SOURCE_DIR_PATH $COMPILE_FLAGS
  make -j6
  make install

  popd &> /dev/null
}

# Execute
# -------------------------------------------------------------------------------------------------

main $@