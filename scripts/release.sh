#!/bin/bash

# REQUIRED DEPENDENCIES
# -------------------------------------------------------------------------------------------------
#
# To run this script, you must have the following tools installed:
# - bash 4

# Imports
# -------------------------------------------------------------------------------------------------

source <(curl -s "https://raw.githubusercontent.com/delucca/shell-functions/1.0.1/modules/feedback.sh")
source <(curl -s "https://raw.githubusercontent.com/delucca/shell-functions/1.0.1/modules/validation.sh")

# Global variables
# -------------------------------------------------------------------------------------------------

SCRIPTS_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
PARENT_PATH="$(dirname ${SCRIPTS_PATH})"
EXECUTION_TIMESTAMP="$(date +%s)"
LOG_FILE_PATH="${PARENT_PATH}/logs/release-${EXECUTION_TIMESTAMP}.log"

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  welcome
  validate_requirements

  build
  deploy
}

# Welcome
# -------------------------------------------------------------------------------------------------

function welcome {
  echo "Starting release script. The logs will be saved on:"
  echo $LOG_FILE_PATH

  rm -f ${LOG_FILE_PATH}
  mkdir -p "${PARENT_PATH}/logs"
  touch ${LOG_FILE_PATH}
  echo "Started at ${EXECUTION_TIMESTAMP}" > $LOG_FILE_PATH
}

# Validate
# -------------------------------------------------------------------------------------------------

function validate_requirements {
  validate_dependencies
}

function validate_dependencies {
  validate_bash_dependency
}

# Build
# -------------------------------------------------------------------------------------------------

function build {
  log_title "BUILD"

  update_build_container
  build_gromacs
}

function update_build_container {
  start_spinner_in_category 'Docker' 'Building delucca/mo833-gromacs:build container'

  docker build \
    -t delucca/mo833-gromacs:build \
    "${PARENT_PATH}" \
    -f "${PARENT_PATH}/Dockerfile.build" \
    &>> $LOG_FILE_PATH

  stop_spinner $?
}

function build_gromacs {
  start_spinner_in_category 'Docker' 'Building GROMACS'

  local gromacs_dist="${PARENT_PATH}/build/gromacs"

  mkdir -p dist
  mkdir -p $gromacs_dist
  docker run \
    --mount type=bind,source=$gromacs_dist,target=/usr/local/gromacs \
    delucca/mo833-gromacs:build \
    &>> $LOG_FILE_PATH

  stop_spinner $?
}

# Deploy
# -------------------------------------------------------------------------------------------------

function deploy {
  log_title "DEPLOY"

  update_runtime_container
}

function update_runtime_container {
  start_spinner_in_category 'Docker' 'Building delucca/mo833-gromacs:latest container'

  docker build \
    -t delucca/mo833-gromacs:latest \
    "${PARENT_PATH}" \
    -f "${PARENT_PATH}/Dockerfile" \
    &>> $LOG_FILE_PATH

  stop_spinner $?
}

# Execute
# -------------------------------------------------------------------------------------------------

main $@