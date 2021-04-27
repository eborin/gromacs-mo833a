#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

EXPERIMENT_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
SOURCE_DIR=$(dirname $(dirname ${EXPERIMENT_PATH}))
COMPILE_FLAGS="${@:--DGMX_BUILD_OWN_FFTW=ON}"
TEXT_BOLD=$(tput bold)
TEXT_CYAN=$(tput setaf 6)
TEXT_RESET=$(tput sgr0)
TRIAL_NUMBER=1
TRIAL_PATH="${EXPERIMENT_PATH}/trials/trial-${TRIAL_NUMBER}"
TRIAL_SAMPLES_AMOUNT=10
SAMPLE_EXECUTION_TIMES=""

export GMX_BIN="${SOURCE_DIR}/build/bin/gmx"
export INPUT_DIR=$EXPERIMENT_PATH/input

# Imports
# -------------------------------------------------------------------------------------------------

source <(curl -s "https://raw.githubusercontent.com/delucca/shell-functions/1.0.1/modules/feedback.sh")

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  validate_requirements
  create_trial_dirs

  welcome
  log_experiment_settings
  compile
  run_trial
  summary
}

# Welcome
# -------------------------------------------------------------------------------------------------

function welcome {
  echo "${TEXT_BOLD}${TEXT_CYAN}Welcome${TEXT_RESET}"
  echo "You are running ${TEXT_BOLD}${TEXT_CYAN}GROMACS ativ-3-exp-1${TEXT_RESET} experiment"
  echo "This is the ${TEXT_BOLD}${TEXT_CYAN}trial number ${TRIAL_NUMBER}${TEXT_RESET}, which uses ${TRIAL_SAMPLES_AMOUNT} samples"
}

# Validate requirements
# -------------------------------------------------------------------------------------------------

function validate_requirements {
  validate_expect_dependency
}

function validate_expect_dependency {
  major_version="$(expect -v | head -1 | cut -d ' ' -f 3 | cut -d '.' -f 1)"
  min_major_version="5"

  if [ "${major_version}" -lt "${min_major_version}" ]; then
    throw_error "Your expect major version must be ${min_major_version} or greater"
  fi
}

# Create trial dirs
# -------------------------------------------------------------------------------------------------

function create_trial_dirs {
  mkdir -p $EXPERIMENT_PATH/trials

  update_trial_number
  update_trial_path

  create_trial_sample_dirs
}

function update_trial_number {
  while [[ -d "${EXPERIMENT_PATH}/trials/trial-${TRIAL_NUMBER}" ]] ; do
    TRIAL_NUMBER=$(($TRIAL_NUMBER+1))
  done
}

function update_trial_path {
  TRIAL_PATH="${EXPERIMENT_PATH}/trials/trial-${TRIAL_NUMBER}"
  mkdir $TRIAL_PATH
}

function create_trial_sample_dirs {
  for i in $(seq 1 $TRIAL_SAMPLES_AMOUNT); do
    mkdir "${TRIAL_PATH}/sample-${i}"
  done
}

# Log experiment settings
# -------------------------------------------------------------------------------------------------

function log_experiment_settings {
  log_title "EXPERIMENT SETTINGS"

  log_hardware_details
  log_env_variables
  log_compile_flags
  log_setting "Git HEAD revision" $(git rev-parse HEAD)
  log_setting "Trial number" $TRIAL_NUMBER
  log_setting "Amount of samples" $TRIAL_SAMPLES_AMOUNT
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

  $SOURCE_DIR/scripts/build.sh $COMPILE_FLAGS
}

# Run experiment
# -------------------------------------------------------------------------------------------------

function run_trial {
  log_title "TRIAL"

  for sample_number in $(seq 1 $TRIAL_SAMPLES_AMOUNT); do
    prepare_sample $sample_number
    setup_simulation $sample_number
    run_simulation $sample_number
    get_sample_result $sample_number
  done;
}

function prepare_sample {
  sample_number=$1
  sample_dir=$TRIAL_PATH/sample-${sample_number}
  data_dir=$sample_dir/data
  logs_dir=$sample_dir/logs

  log_sample_message $sample_number "Preparing"

  mkdir $data_dir
  mkdir $logs_dir
}

function setup_simulation {
  sample_number=$1
  sample_dir=$TRIAL_PATH/sample-${sample_number}
  data_dir=$sample_dir/data
  log_file=$sample_dir/logs/setup.log

  log_sample_message $sample_number "Creating simulation setup. The logs are being stored at ${log_file}"

  pushd $data_dir &> /dev/null

  touch $log_file

  run_gmx_interactive_command $EXPERIMENT_PATH/interactive-commands/pdb2gmx.expect &>> $log_file
  run_gmx_command editconf -f 6LVN_processed.gro -o 6LVN_newbox.gro -c -d 1.0 -bt cubic &>> $log_file
  run_gmx_command solvate -cp 6LVN_newbox.gro -cs spc216.gro -o 6LVN_solv.gro -p topol.top &>> $log_file
  run_gmx_command grompp -f $INPUT_DIR/ions.mdp -c 6LVN_solv.gro -p topol.top -o ions.tpr &>> $log_file
  run_gmx_interactive_command $EXPERIMENT_PATH/interactive-commands/genion.expect &>> $log_file
  run_gmx_command grompp -f $INPUT_DIR/ions.mdp -c 6LVN_solv_ions.gro -p topol.top -o em.tpr &>> $log_file

  popd &> /dev/null
}

function run_simulation {
  sample_number=$1
  sample_dir=$TRIAL_PATH/sample-${sample_number}
  data_dir=$sample_dir/data
  log_file=$sample_dir/logs/simulation.log

  pushd $data_dir &> /dev/null

  log_sample_message $sample_number "Running simulation. The logs are being stored at ${log_file}"

  run_gmx_command mdrun -v -deffnm em &>> $log_file

  popd &> /dev/null
}

function get_sample_result {
  sample_number=$1
  sample_dir=$TRIAL_PATH/sample-${sample_number}
  log_file=$sample_dir/logs/simulation.log

  result=$(cat $log_file | tail -n 1 | cut -d' ' -f 5)
  SAMPLE_EXECUTION_TIMES="${SAMPLE_EXECUTION_TIMES} ${sample_number}:${result}"

  log_sample_message $sample_number "Finished executing sample. The execution time result was ${result} seconds"
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

function log_sample_message {
  sample_number=$1
  message=$2

  echo "${TEXT_BOLD}${TEXT_CYAN}> Sample ${sample_number}:${TEXT_RESET} $message"
}

# Summary
# -------------------------------------------------------------------------------------------------

function summary {
  log_title "EXPERIMENT SUMMARY"

  echo "Execution time results:"

  for result in $SAMPLE_EXECUTION_TIMES; do
    sample_number=$(echo $result | cut -d':' -f 1)
    sample_result=$(echo $result | cut -d':' -f 2)

    log_sample_message $sample_number "${sample_result} seconds"
  done
}

# Execute
# -------------------------------------------------------------------------------------------------

main $@