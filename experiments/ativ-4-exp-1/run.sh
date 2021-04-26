#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

COMPILE_FLAGS="${@:--DGMX_BUILD_OWN_FFTW=ON}"
EXPERIMENT_DIR_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
EXPERIMENTS_DIR_PATH=$(dirname $EXPERIMENT_DIR_PATH)
SOURCE_DIR_PATH=$(dirname $EXPERIMENTS_DIR_PATH)
INPUT_DIR_PATH=$EXPERIMENT_DIR_PATH/input
GIT_HEAD_REVISION=$(git rev-parse HEAD)
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
  log_experiment_settings
  setup_trial
  log_next_steps
}

# Welcome
# -------------------------------------------------------------------------------------------------

function log_welcome {
  echo "${TEXT_BOLD}${TEXT_CYAN}Welcome${TEXT_RESET}"
  echo "You are running ${TEXT_BOLD}${TEXT_CYAN}GROMACS ativ-4-exp-1${TEXT_RESET} experiment"
}

# Log experiment settings
# -------------------------------------------------------------------------------------------------

function log_experiment_settings {
  log_title "EXPERIMENT SETTINGS"

  log_hardware_details
  log_env_variables
  log_compile_flags
  log_setting "Git HEAD revision" $GIT_HEAD_REVISION
  log_setting "Trial number" $TRIAL_NUMBER
}

function log_hardware_details {
  log_setting "Hardware details"

  inxi -Fxz 2> /dev/null
}

function log_env_variables {
  log_setting "Environment variables"

  env_variable_keys=$(env -v0 | cut -z -f1 -d= | tr '\0' '\n' | sort)
  variables_to_hide="_ GITHUB_CODESPACE_TOKEN GITHUB_TOKEN GIT_COMMITTER_EMAIL GIT_COMMITTER_NAME"

  for env_var in $env_variable_keys; do
    [[ ${variables_to_hide} != *"${env_var}"* ]] && eval "echo \">    ${env_var}=\$${env_var}\""
  done
}

function log_compile_flags {
  log_setting "Compile flags"
  for flag in $COMPILE_FLAGS; do
    echo ">    ${flag}"
  done
}

function log_setting {
  label=$1
  setting=$2

  echo "> ${TEXT_BOLD}${label}:${TEXT_RESET} ${setting}"
}

# Setup trial
# -------------------------------------------------------------------------------------------------

function setup_trial {
  log_title "SETUP TRIAL"

  echo "${TEXT_BOLD}${TEXT_CYAN}Building GROMACS containers${TEXT_RESET}"
  $EXPERIMENTS_DIR_PATH/scripts/refresh-containers.sh

  echo "${TEXT_BOLD}${TEXT_CYAN}Building trial container${TEXT_RESET}"
  docker build -t mo833a/gromacs:ativ-4-exp-1 -f $EXPERIMENT_DIR_PATH/Dockerfile $EXPERIMENT_DIR_PATH
}

# Log summary
# -------------------------------------------------------------------------------------------------

function log_next_steps {
  log_title "NEXT STEPS"

  echo "${TEXT_BOLD}Finished experiment setup${TEXT_RESET}"
  echo "To execute the Code Profiling, you can follow these steps:"

  echo
  echo "${TEXT_BOLD}Step 1:${TEXT_RESET} Open the container with the following command:"
  cat <<EOF
  ${TEXT_BOLD}${TEXT_CYAN}docker run \\
    --privileged \\
    -v /:/host \\
    -it \\
    mo833a/gromacs:ativ-4-exp-1 \\
    /bin/sh${TEXT_RESET}
EOF

  echo
  echo "${TEXT_BOLD}Step 2:${TEXT_RESET} Run the perf command:"
  cat <<EOF
  ${TEXT_BOLD}${TEXT_CYAN}perf record gmx mdrun -v -deffnm em${TEXT_RESET}
EOF

  echo
  echo "${TEXT_BOLD}Step 3:${TEXT_RESET} Evaluate the perf result:"
  cat <<EOF
  ${TEXT_BOLD}${TEXT_CYAN}perf report${TEXT_RESET}
EOF
}

# Execute
# -------------------------------------------------------------------------------------------------

main $@