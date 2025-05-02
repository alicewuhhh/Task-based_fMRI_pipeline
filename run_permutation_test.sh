#!/bin/bash
# run_permutation_test.sh: Runs randomise permutation testing for functional scans
# in the RECOVER fMRI pipeline, using FEAT outputs, executed locally.
# Accepts subject IDs as command-line arguments.
# Created for RECOVER project by K. Nguyen and A. Wu, Mar 2025

# Exit on any error
set -e

# Check if at least one subject ID was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <subject_id1> <subject_id2> ... <subject_idN>"
    exit 1
fi

# Number of permutations
NUM_PERM=1000

process_subject_task() {
    subject=$1
    task=$2
    # Define directories and files
    SUBDIR=${DATADIR}/sub-${subject}/ses-01
    FEAT_DIR=${SUBDIR}/fsl_stats/sub-${subject}_task-${task}_contrasts.feat
    MASK=${SUBDIR}/func/sub-${subject}_ses-01_task-${task}_space-MNI152NLin6Asym_desc-brain_mask.nii.gz
    INPUT=${FEAT_DIR}/filtered_func_data.nii.gz
    DESIGN=${FEAT_DIR}/design.mat
    CONTRAST=${FEAT_DIR}/design.con
    OUTPUT=${FEAT_DIR}/randomise_time_series

    # Check if required files exist
    if [ ! -d "$FEAT_DIR" ]; then
        echo "Error: FEAT directory $FEAT_DIR not found for $subject. Run FEAT stats first."
        return 1
    fi
    if [ ! -f "$INPUT" ] || [ ! -f "$DESIGN" ] || [ ! -f "$CONTRAST" ]; then
        echo "Error: Required FEAT files (filtered_func_data.nii.gz, design.mat, design.con) missing in $FEAT_DIR for $subject."
        return 1
    fi
    if [ ! -f "$MASK" ]; then
        echo "Error: Mask file $MASK not found for $subject."
        return 1
    fi

    # Run randomise locally
    echo "Running randomise for $subject, task ${task} with $NUM_PERM permutations locally..."
    randomise_parallel \
        -i "$INPUT" \
        -o "$OUTPUT" \
        -d "$DESIGN" \
        -t "$CONTRAST" \
        -m "$MASK" \
        -n $NUM_PERM \
        -T
    if [ $? -ne 0 ]; then
        echo "Error: randomise failed for $subject, task ${task}."
        return 1
    fi

    echo "randomise completed for $subject, task ${task}."
}

# Loop through all subjects and tasks sequentially
for subject in "$@"; do
    for task in $TASKS; do # Add more tasks if needed, e.g., lang
        echo "Processing ${task} for ${subject} with randomise..."
        process_subject_task "$subject" "$task"
    done
done

echo "All randomise tasks completed locally for subjects: $@"
