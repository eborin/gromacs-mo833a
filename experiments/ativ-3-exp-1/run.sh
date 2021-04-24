#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

EXPERIMENT_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
SOURCE_DIR=$(dirname $(dirname ${EXPERIMENT_PATH}))
COMPILE_FLAGS="${@:--DGMX_BUILD_OWN_FFTW=ON}"
TEXT_BOLD=$(tput bold)
TEXT_CYAN=$(tput setaf 6)
TEXT_RESET=$(tput sgr0)

# Imports
# -------------------------------------------------------------------------------------------------

source <(curl -s "https://raw.githubusercontent.com/delucca/shell-functions/1.0.1/modules/feedback.sh")

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  welcome
  log_experiment_settings
}

# Log experiment settings
# -------------------------------------------------------------------------------------------------

function welcome {
  echo "${TEXT_BOLD}${TEXT_CYAN}Welcome${TEXT_RESET}"
  echo "You are running ${TEXT_BOLD}${TEXT_CYAN}GROMACS ativ-3-exp-1${TEXT_RESET} experiment"
  echo
}

# Log experiment settings
# -------------------------------------------------------------------------------------------------

function log_experiment_settings {
  log_title "EXPERIMENT SETTINGS"

  log_env_variables
  log_compile_flags
  log_setting "Git HEAD revision" $(git rev-parse HEAD)
}

function log_setting {
  label=$1
  setting=$2

  echo "> ${TEXT_BOLD}${label}:${TEXT_RESET} ${setting}"
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

# Execute
# -------------------------------------------------------------------------------------------------

main $@