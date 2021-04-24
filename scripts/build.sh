#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

GROMACS_VERSION="${2:-2020.1}"
TMP_DIR="${3:-/tmp/gromacs}"

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  fetch_gromacs
  build_gromacs
}


# Fetch GROMACS
# -------------------------------------------------------------------------------------------------

function fetch_gromacs {
  echo "Fetching GROMACS"

  mkdir -p $TMP_DIR
  cd $TMP_DIR
  wget ftp://ftp.gromacs.org/pub/gromacs/gromacs-${GROMACS_VERSION}.tar.gz 
  tar xfz "gromacs-${GROMACS_VERSION}.tar.gz"
}

# Build GROMACS
# -------------------------------------------------------------------------------------------------

function build_gromacs {
  echo "Building GROCAMS"

  cd "${TMP_DIR}/gromacs-${GROMACS_VERSION}"
  mkdir build && cd build
  cmake .. -DGMX_BUILD_OWN_FFTW=ON
  make -j6
  make install
}

# Execute
# -------------------------------------------------------------------------------------------------

main $@