#!/bin/bash
# master_workflow.sh: Orchestrates the RECOVER fMRI pipeline including FEAT stats,
# cal_post_stats_thresh.sh, and output_generator.py (which calls data_processor.py and uses html_template.py).
# Accepts subject IDs as command-line arguments with options to run specific steps or all.
# Options: -f (FEAT stats), -c (calculate post-stats), -o (generate output pdf+html), -a (all steps)
# Created for RECOVER project by K. Nguyen and A. Wu, Mar 2025

# Exit on any error
set -e

# Default flags
RUN_FEAT=0
RUN_CALC=0
RUN_OUTPUT=0

# Usage message
usage() {
    echo "Usage: $0 [-f] [-c] [-o] [-a] <subject_id1> <subject_id2> ... <subject_idN>"
    echo "Options:"
    echo "  -f    Run only feat_contrasts_recover_cluster.sh (FEAT stats)"
    echo "  -c    Run only calc_post_stats_thresh.sh (calculate post-stats)"
    echo "  -o    Run only output_generator.py (generate output pdf+html)"
    echo "  -a    Run all steps (default if no options specified)"
    exit 1
}

# Parse options
while getopts "fcoa" opt; do
    case $opt in
        f) RUN_FEAT=1 ;;
        c) RUN_CALC=1 ;;
        o) RUN_OUTPUT=1 ;;
        a) RUN_FEAT=1 RUN_CALC=1 RUN_OUTPUT=1 ;;
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
if [ $RUN_FEAT -eq 0 ] && [ $RUN_CALC -eq 0 ] && [ $RUN_OUTPUT -eq 0 ]; then
    RUN_FEAT=1
    RUN_CALC=1
    RUN_OUTPUT=1
fi

# Set ANTs path
export PATH="/Users/aliceqichaowu/ANTs/bin:$PATH" # Change to ANTs directory
if ! command -v antsApplyTransforms &> /dev/null; then
    echo "Error: antsApplyTransforms not found. Please verify ANTs installation at /Users/aliceqichaowu/ANTs/bin or adjust PATH."
    exit 1
fi

# Base directories (aligned with cal_post_stats_thresh.sh and output_generator.py)
ARCHIVEDIR=/Volumes/WILL_STUFF/RECOVER/fsl_pipeline # Change to your project directory
ROI=${ARCHIVEDIR}/ROI
export ARCHIVEDIR
export ROI
SCRIPTSDIR=${ARCHIVEDIR}/code/scripts/docker_cluster
FEAT_STATS=${SCRIPTSDIR}/feat_contrasts_recover_cluster_old_task.sh
CAL_POST_STATS=${SCRIPTSDIR}/calc_post_stats_thresh_old_task.sh
PYTHON=/opt/anaconda3/bin/python3
OUTPUT_GENERATOR=${SCRIPTSDIR}/output_generator_old_task.py
TEMPLATE=${ARCHIVEDIR}/code/templates/design_test_script_old_task.fsf

# Check if required tools are available
if ! command -v feat &> /dev/null; then
    echo "Error: FSL FEAT not found. Please ensure FSL is installed and sourced."
    exit 1
fi
if ! command -v fslmaths &> /dev/null; then
    echo "Error: FSL not found. Please ensure FSL is installed and sourced."
    exit 1
fi
if ! command -v antsApplyTransforms &> /dev/null; then
    echo "Error: ANTs not found. Please ensure ANTs is installed at /Users/aliceqichaowu/ANTs/bin or adjust PATH."
    exit 1
fi
if [ ! -f "$PYTHON" ]; then
    echo "Error: Python3 not found at $PYTHON. Please ensure Python 3.8.20 is installed at /opt/anaconda3/bin."
    exit 1
fi
if [ ! -f "$TEMPLATE" ]; then
    echo "Error: FEAT template file not found at $TEMPLATE."
    exit 1
fi

# Function to run feat_contrasts_recover_cluster_old_task.sh
run_feat_stats() {
    echo "Running feat_contrasts_recover_cluster_old_task.sh to generate initial FEAT stats for subjects: $@..."
    bash "$FEAT_STATS" "$@"
    if [ $? -ne 0 ]; then
        echo "Error: feat_contrasts_recover_cluster_old_task.sh failed. Aborting workflow."
        exit 1
    fi
    echo "feat_contrasts_recover_cluster_old_task.sh completed successfully."
}

# Function to run cal_post_stats_thresh_old_task.sh
run_cal_post_stats() {
    echo "Running cal_post_stats_thresh_old_task.sh to process z-maps and generate CSV files for subjects: $@..."
    bash "$CAL_POST_STATS" "$@"
    if [ $? -ne 0 ]; then
        echo "Error: cal_post_stats_thresh_old_task.sh failed. Aborting workflow."
        exit 1
    fi
    echo "cal_post_stats_thresh_old_task.sh completed successfully."
}

# Function to run output_generator_old_task.py
run_output_generator() {
    echo "Running output_generator_old_task.py to generate PDF and HTML reports for subjects: $@..."
    "$PYTHON" "$OUTPUT_GENERATOR" "$@"
    if [ $? -ne 0 ]; then
        echo "Error: output_generator_old_task.py failed. Check logs for details."
        exit 1
    fi
    echo "output_generator_old_task.py completed successfully. Reports generated."
}

# Main execution
echo "Starting RECOVER fMRI pipeline workflow on $(date) for subjects: $@"

# Execute selected steps
if [ $RUN_FEAT -eq 1 ]; then
    run_feat_stats "$@"
fi

if [ $RUN_CALC -eq 1 ]; then
    run_cal_post_stats "$@"
fi

if [ $RUN_OUTPUT -eq 1 ]; then
    run_output_generator "$@"
fi

echo "RECOVER fMRI task-based pipeline workflow completed on $(date)"