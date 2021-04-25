#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

SCRIPTS_DIR_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
EXPERIMENTS_DIR_PATH=$(dirname ${SCRIPTS_DIR_PATH})
SOURCE_DIR_PATH=$(dirname ${EXPERIMENTS_DIR_PATH})
TEXT_BOLD=$(tput bold)
TEXT_CYAN=$(tput setaf 6)
TEXT_RESET=$(tput sgr0)

# Imports
# -------------------------------------------------------------------------------------------------

source <(curl -s "https://raw.githubusercontent.com/delucca/shell-functions/1.0.1/modules/feedback.sh")

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
  echo "${TEXT_BOLD}${TEXT_CYAN}Refreshing containers${TEXT_RESET}"
}

# Refresh compile stage image
# -------------------------------------------------------------------------------------------------

function refresh_compile_stage_image {
  log_title "COMPILE STAGE IMAGE"

  echo "Refreshing image"

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
  log_title "RUNTIME IMAGE"

  echo "Refreshing image"

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