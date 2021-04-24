#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

EXPERIMENT_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
SOURCE_DIR=$(dirname $(dirname ${EXPERIMENT_PATH}))
COMPILE_FLAGS="${@:--DGMX_BUILD_OWN_FFTW=ON}"
TEXT_BOLD=$(tput bold)
TEXT_CYAN=$(tput setaf 6)
TEXT_RESET=$(tput sgr0)
export GMX_BIN="${SOURCE_DIR}/build/bin/gmx"
SAMPLE_NUMBER=1
SAMPLE_PATH="${EXPERIMENT_PATH}/samples/sample-${SAMPLE_NUMBER}"

# Imports
# -------------------------------------------------------------------------------------------------

source <(curl -s "https://raw.githubusercontent.com/delucca/shell-functions/1.0.1/modules/feedback.sh")

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  welcome
  validate_requirements
  create_sample_dirs

  # log_experiment_settings
  # compile
  run_experiment
}

# Validate requirements
# -------------------------------------------------------------------------------------------------

function validate_requirements {
  validate_expect_dependency
}

function validate_bash_dependency {
  major_version="$(expect -v | head -1 | cut -d ' ' -f 3 | cut -d '.' -f 1)"
  min_major_version="5"

  if [ "${major_version}" -lt "${min_major_version}" ]; then
    throw_error "Your expect major version must be ${min_major_version} or greater"
  fi
}

# Create sample dirs
# -------------------------------------------------------------------------------------------------

function create_sample_dirs {
  update_sample_number
  update_sample_path
}

function update_sample_number {
  while [[ -d "${EXPERIMENT_PATH}/samples/sample-${SAMPLE_NUMBER}" ]] ; do
    SAMPLE_NUMBER=$(($SAMPLE_NUMBER+1))
  done
}

function update_sample_path {
  SAMPLE_PATH="${EXPERIMENT_PATH}/samples/sample-${SAMPLE_NUMBER}"
  mkdir $SAMPLE_PATH
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

  log_hardware_details
  log_env_variables
  log_compile_flags
  log_setting "Git HEAD revision" $(git rev-parse HEAD)
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

# Compile
# -------------------------------------------------------------------------------------------------

function compile {
  log_title "COMPILATION"

  $SOURCE_DIR/scripts/build.sh
}

# Run experiment
# -------------------------------------------------------------------------------------------------

function run_experiment {
  log_title "RUN EXPERIMENT"

  parse_simulation_data
}

function parse_simulation_data {
  export INPUT_DIR=$EXPERIMENT_PATH/input
  data_dir=$SAMPLE_PATH/data
  mkdir $data_dir

  pushd $data_dir

  run_gmx_interactive_command $EXPERIMENT_PATH/interactive-commands/pdb2gmx.expect
  run_gmx_command editconf -f 6LVN_processed.gro -o 6LVN_newbox.gro -c -d 1.0 -bt cubic
  run_gmx_command solvate -cp 6LVN_newbox.gro -cs spc216.gro -o 6LVN_solv.gro -p topol.top
  run_gmx_command grompp -f $INPUT_DIR/ions.mdp -c 6LVN_solv.gro -p topol.top -o ions.tpr
  run_gmx_interactive_command $EXPERIMENT_PATH/interactive-commands/genion.expect
  run_gmx_command grompp -f $INPUT_DIR/ions.mdp -c 6LVN_solv_ions.gro -p topol.top -o em.tpr

  popd
}

function run_gmx_interactive_command {
  echo
  echo "Running interactive GMX command: ${TEXT_BOLD}${TEXT_CYAN}$@${TEXT_RESET}"
  expect $@
}

function run_gmx_command {
  echo
  echo "Running GMX command: ${TEXT_BOLD}${TEXT_CYAN}$@${TEXT_RESET}"
  $GMX_BIN $@
}

# Execute
# -------------------------------------------------------------------------------------------------

main $@