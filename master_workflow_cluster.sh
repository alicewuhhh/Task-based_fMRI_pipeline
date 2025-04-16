#!/bin/bash
# master_workflow.sh: Orchestrates the RECOVER fMRI pipeline including FEAT stats,
# cal_post_stats_thresh.sh, output_generator.py, and randomise permutation testing.
# Accepts subject IDs as command-line arguments with options to run specific steps or all.
# Options: -f (FEAT stats), -p (randomise permutation testing), -c (calculate post-stats), 
#          -o (generate output pdf+html), -a (all steps), -t (specify tasks)
# Created for RECOVER project by K. Nguyen and A. Wu, Mar 2025

# Exit on any error
set -e

# Default flags
RUN_FEAT=0
RUN_RANDOMISE=0
RUN_CALC=0
RUN_OUTPUT=0
TASKS="motor_run-01 motor_run-02 lang"  # Default to all tasks

# Usage message
usage() {
    echo "Usage: $0 [-f] [-p] [-c] [-o] [-a] [-t task1,task2,...] <subject_id1> <subject_id2> ... <subject_idN>"
    echo "Options:"
    echo "  -f    Run only feat_contrasts_recover_cluster.sh (FEAT stats)"
    echo "  -p    Run only randomise permutation testing"
    echo "  -c    Run only calc_post_stats_thresh.sh (calculate post-stats)"
    echo "  -o    Run only output_generator.py (generate output pdf+html)"
    echo "  -a    Run all steps (default if no options specified)"
    echo "  -t    Specify tasks to process (comma-separated, e.g., motor_run-01,lang; default: all tasks)"
    exit 1
}

# Parse options
while getopts "fpcot:" opt; do
    case $opt in
        f) RUN_FEAT=1 ;;
        p) RUN_RANDOMISE=1 ;;
        c) RUN_CALC=1 ;;
        o) RUN_OUTPUT=1 ;;
        a) RUN_FEAT=1 RUN_RANDOMISE=1 RUN_CALC=1 RUN_OUTPUT=1 ;;
        t) TASKS=$(echo "$OPTARG" | tr ',' ' ') ;;  # Convert comma-separated tasks to space-separated
        ?) usage ;;
    esac
done

# Shift past the options to get subject IDs
shift $((OPTIND-1))

# Check if at least one subject ID was provided
if [ $# -eq 0 ]; then
    echo "Error: No subject IDs provided."
    usage
fi

# If no options specified, default to running all steps
if [ $RUN_FEAT -eq 0 ] && [ $RUN_CALC -eq 0 ] && [ $RUN_OUTPUT -eq 0 ] && [ $RUN_RANDOMISE -eq 0 ]; then
    RUN_FEAT=1
    RUN_RANDOMISE=1
    RUN_CALC=1
    RUN_OUTPUT=1
fi

# Base directories (aligned with cal_post_stats_thresh.sh and output_generator.py)
ARCHIVEDIR=/project/fischer/PREDICT/alicewu/fsl_pipeline
ROI=${ARCHIVEDIR}/ROI
export ARCHIVEDIR
export ROI
SCRIPTSDIR=${ARCHIVEDIR}/code/scripts/docker_cluster
FEAT_STATS=${SCRIPTSDIR}/feat_contrasts_recover_cluster.sh
RANDOMISE_STATS=${SCRIPTSDIR}/run_permutation_test_cluster.sh
CAL_POST_STATS=${SCRIPTSDIR}/calc_post_stats_thresh.sh
OUTPUT_GENERATOR=${SCRIPTSDIR}/output_generator.py
TEMPLATE=${ARCHIVEDIR}/code/templates/design_test_script.fsf

# Check if required tools are available
for cmd in feat fslmaths randomise antsApplyTransforms; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd not found. Please ensure FSL and ANTs are installed and sourced."
        exit 1
    fi
done
if [ ! -f "$TEMPLATE" ]; then
    echo "Error: FEAT template file not found at $TEMPLATE."
    exit 1
fi

# Function to run feat_contrasts_recover_cluster.sh
run_feat_stats() {
    echo "Running feat_contrasts_recover_cluster.sh to generate initial FEAT stats for subjects: $@ with tasks: $TASKS..."
    export TASKS  # Pass tasks to feat_contrasts_recover_cluster.sh
    bash "$FEAT_STATS" "$@"
    if [ $? -ne 0 ]; then
        echo "Error: feat_contrasts_recover_cluster.sh failed. Aborting workflow."
        exit 1
    fi
    echo "feat_contrasts_recover_cluster.sh completed successfully."
}

# Function to run run_permutation_test_cluster.sh
run_permutation_test_cluster() {
    echo "Running run_permutation_test_cluster.sh for subjects: $@ with tasks: $TASKS..."
    export TASKS
    bash "$RANDOMISE_STATS" "$@"
    if [ $? -ne 0 ]; then
        echo "Error: run_permutation_test_cluster.sh failed. Check logs for details."
        exit 1
    fi
    echo "run_permutation_test_cluster.sh jobs submitted successfully. Monitor with 'bjobs'."
}

# Function to run cal_post_stats_thresh.sh
run_cal_post_stats() {
    echo "Running cal_post_stats_thresh.sh to process z-maps and generate CSV files for subjects: $@ with tasks: $TASKS..."
    export TASKS
    bash "$CAL_POST_STATS" "$@"
    if [ $? -ne 0 ]; then
        echo "Error: cal_post_stats_thresh.sh failed. Aborting workflow."
        exit 1
    fi
    echo "cal_post_stats_thresh.sh completed successfully."
}

# Function to run output_generator.py
run_output_generator() {
    echo "Running output_generator.py to generate PDF and HTML reports for subjects: $@ with tasks: $TASKS..."
    export TASKS
    "$PYTHON" "$OUTPUT_GENERATOR" "$@"
    if [ $? -ne 0 ]; then
        echo "Error: output_generator.py failed. Check logs for details."
        exit 1
    fi
    echo "output_generator.py completed successfully. Reports generated."
}

# Main execution
echo "Starting RECOVER fMRI pipeline workflow on $(date) for subjects: $@ with tasks: $TASKS"

# Execute selected steps
if [ $RUN_FEAT -eq 1 ]; then
    run_feat_stats "$@"
fi

if [ $RUN_RANDOMISE -eq 1 ]; then
    run_permutation_test_cluster "$@"
fi

if [ $RUN_CALC -eq 1 ]; then
    run_cal_post_stats "$@"
fi

if [ $RUN_OUTPUT -eq 1 ]; then
    run_output_generator "$@"
fi

echo "RECOVER fMRI task-based pipeline workflow completed on $(date)"