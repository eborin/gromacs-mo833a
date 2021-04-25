#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

SCRIPTS_DIR_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
EXPERIMENTS_DIR_PATH=$(dirname ${SCRIPTS_DIR_PATH})
SOURCE_DIR_PATH=$(dirname ${EXPERIMENTS_DIR_PATH})

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  log_welcome

  refresh_compile_stage_image
  refresh_runtime_image
}

# Log welcome
# -------------------------------------------------------------------------------------------------

function log_welcome {
  echo "> Refreshing GROMACS containers..."
}

# Refresh compile stage image
# -------------------------------------------------------------------------------------------------

function refresh_compile_stage_image {
  echo ">    Refreshing compile stage image"

  pushd $SOURCE_DIR_PATH &> /dev/null
  docker build --target compile-stage \
    --cache-from=mo833a/gromacs:compile-stage \
    --tag mo833a/gromacs:compile-stage \
    -f $EXPERIMENTS_DIR_PATH/Dockerfile \
    .
  popd &> /dev/null
}

# Refresh runtime image
# -------------------------------------------------------------------------------------------------

function refresh_runtime_image {
  echo ">    Refreshing image"

  pushd $SOURCE_DIR_PATH &> /dev/null
  docker build --target runtime \
    --cache-from=mo833a/gromacs:compile-stage \
    --cache-from=mo833a/gromacs:runtime \
    --tag mo833a/gromacs:runtime \
    -f $EXPERIMENTS_DIR_PATH/Dockerfile \
    .
  popd &> /dev/null
}

# Execute
# -------------------------------------------------------------------------------------------------

main $@