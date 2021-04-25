#!/bin/bash

# Global variables
# -------------------------------------------------------------------------------------------------

COMPILE_FLAGS="${@:--DGMX_BUILD_OWN_FFTW=ON}"
EXPERIMENT_DIR_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
EXPERIMENTS_DIR_PATH=$(dirname $EXPERIMENT_DIR_PATH)
SOURCE_DIR_PATH=$(dirname $EXPERIMENTS_DIR_PATH)
INPUT_DIR_PATH=$EXPERIMENT_PATH/input
TRIAL_NUMBER=1
TRIAL_PATH="${EXPERIMENT_PATH}/trials/trial-${TRIAL_NUMBER}"
TRIAL_SAMPLES_AMOUNT=1
TEXT_BOLD=$(tput bold)
TEXT_CYAN=$(tput setaf 6)
TEXT_RESET=$(tput sgr0)
GIT_HEAD_REVISION=$(git rev-parse HEAD)

# Imports
# -------------------------------------------------------------------------------------------------

source <(curl -s "https://raw.githubusercontent.com/delucca/shell-functions/1.0.1/modules/feedback.sh")

# Entrypoint
# -------------------------------------------------------------------------------------------------

function main {
  do_setup
  log_welcome
  log_experiment_settings
  run_trial
  log_summary
}

# Do setup
# -------------------------------------------------------------------------------------------------

function do_setup {
  mkdir -p $EXPERIMENT_PATH/trials

  update_trial_number
  update_trial_path
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

# Welcome
# -------------------------------------------------------------------------------------------------

function log_welcome {
  echo "${TEXT_BOLD}${TEXT_CYAN}Welcome${TEXT_RESET}"
  echo "You are running ${TEXT_BOLD}${TEXT_CYAN}GROMACS ativ-4-exp-1${TEXT_RESET} experiment"
  echo "This is the ${TEXT_BOLD}${TEXT_CYAN}trial number ${TRIAL_NUMBER}${TEXT_RESET}, which uses ${TRIAL_SAMPLES_AMOUNT} samples"
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

# Run experiment
# -------------------------------------------------------------------------------------------------

function run_trial {
  log_title "TRIAL"

  prepare_trial

  for sample_number in $(seq 1 $TRIAL_SAMPLES_AMOUNT); do
    run_sample $sample_number
  done;
}

function prepare_trial {
  echo "Preparing trial"

  $EXPERIMENTS_DIR_PATH/scripts/refresh-containers.sh
  docker build -t mo833a/gromacs:ativ-4-exp-1 -f $EXPERIMENT_DIR_PATH/Dockerfile $EXPERIMENT_DIR_PATH
}

function run_sample {
  sample_number=$1
  sample_log_file_path=$TRIAL_PATH/sample-${sample_number}.log
  sample_perf_file_path=$TRIAL_PATH/sample-${sample_number}.perf
  output_dir=$TRIAL_PATH/output

  mkdir -p $output_dir

  log_sample_message $sample_number "Running simulation profiling. Logs are being stored at ${sample_log_file_path}. Perf data is being stored at ${sample_perf_file_path}"
  docker run \
    --cap-add SYS_ADMIN \
    --mount type=bind,source=$output_dir,target=/root/experiment \
    mo833a/gromacs:ativ-4-exp-1 \
    &> $sample_log_file_path

  mv $output_dir/perf.data $sample_perf_file_path
  rm -rf $output_dir
}

function log_sample_message {
  sample_number=$1
  message=$2

  echo "${TEXT_BOLD}${TEXT_CYAN}> Sample ${sample_number}:${TEXT_RESET} $message"
}

# Log summary
# -------------------------------------------------------------------------------------------------

function log_summary {
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