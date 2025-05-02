#!/bin/bash
# cal_post_stats_thresh.sh: Splits ROIs and z-maps, performs transformations, and computes stats.
# Created for RECOVER project by A. Wu, Feb 2025
# Updated to include TFCE stats from randomise permutation test, Mar 2025
# Updated to save ROIs in subject-specific ROI folder, Mar 2025
# Updated to separate STG and Heschl ROIs for language task, Mar 2025
# Updated to include Dice and Coverage Percentage for TFCE vs. Z-stat comparison without re-thresholding TFCE, Mar 2025
# Updated to compute two coverage percentages (t-map and z-map denominators) for TFCE and Z-stat, Apr 2025

# Exit on any error
set -e

# Check if at least one subject ID was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <subject_id1> <subject_id2> ... <subject_idN>"
    exit 1
fi

# Check if TASKS is set
if [ -z "$TASKS" ]; then
    echo "Error: TASKS environment variable is not set."
    exit 1
fi

# Base directories (use exported ARCHIVEDIR and ROI from master_workflow.sh)
if [ -z "$ARCHIVEDIR" ] || [ -z "$ROI" ]; then
    echo "Error: ARCHIVEDIR and ROI environment variables must be set by the calling script."
    exit 1
fi
DATADIR=${ARCHIVEDIR}/derivatives

# Function to calculate percentage
calculate_percentage() {
    local numerator=$1
    local denominator=$2
    if [ -z "$denominator" ] || ! [[ "$denominator" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Denominator is empty or not an integer: $denominator" >&2
        echo "0.0"
        return 1
    fi
    if [ "$denominator" -gt 0 ]; then
        local result=$(echo "scale=3; ($numerator / $denominator) * 100" | bc)
        printf "%.3f" "$result"
    else
        echo "0.0"
    fi
}

# Function to calculate Dice coefficient
calculate_dice() {
    local t_map=$1    # TFCE map (thresholded or unthresholded) or other map
    local z_map=$2    # Thresholded Z-map
    local overlap=$(fslstats "$t_map" -k "$z_map" -l 0 -V | awk '{print $1}')
    local total_t=$(fslstats "$t_map" -V | awk '{print $1}')
    local total_z=$(fslstats "$z_map" -V | awk '{print $1}')
    if [ "$total_t" -gt 0 ] && [ "$total_z" -gt 0 ]; then
        local dice=$(echo "scale=3; (2 * $overlap) / ($total_t + $total_z)" | bc)
        printf "%.3f" "$dice"
    else
        echo "0.0"
    fi
}

# Function to calculate coverage percentages (t-map and z-map denominators)
calculate_coverage() {
    local t_map=$1    # TFCE map (thresholded or unthresholded) or other map
    local z_map=$2    # Thresholded Z-map
    local overlap=$(fslstats "$t_map" -k "$z_map" -l 0 -V | awk '{print $1}')
    local total_t=$(fslstats "$t_map" -V | awk '{print $1}')
    local total_z=$(fslstats "$z_map" -V | awk '{print $1}')
    local coverage_t="0.0"
    local coverage_z="0.0"
    
    # Coverage with t-map (or input map) as denominator
    if [ "$total_t" -gt 0 ]; then
        coverage_t=$(echo "scale=3; ($overlap / $total_t) * 100" | bc)
        coverage_t=$(printf "%.3f" "$coverage_t")
    fi
    
    # Coverage with z-map as denominator
    if [ "$total_z" -gt 0 ]; then
        coverage_z=$(echo "scale=3; ($overlap / $total_z) * 100" | bc)
        coverage_z=$(printf "%.3f" "$coverage_z")
    fi
    
    # Return both coverage percentages as a comma-separated string
    echo "$coverage_t,$coverage_z"
}

# Function to preprocess subject (skull-strip T1w and inverse transform ROIs)
preprocess_subject() {
    local subject=$1
    SUBDIR=${DATADIR}/sub-${subject}/ses-01
    SUBJ_ROI_DIR=${SUBDIR}/ROI  # Subject-specific ROI directory

    # Create subject-specific ROI directory
    mkdir -p "$SUBJ_ROI_DIR"

    # Input and output files for T1w and ROIs
    T1W_PREPROC=${SUBDIR}/anat/sub-${subject}_ses-01_run-01_desc-preproc_T1w.nii.gz
    BRAIN_MASK=${SUBDIR}/anat/sub-${subject}_ses-01_run-01_desc-brain_mask.nii.gz
    T1W_SKULL_STRIPPED=${SUBDIR}/anat/sub-${subject}_ses-01_run-01_desc-brain_T1w.nii.gz
    TRANSFORM=${SUBDIR}/anat/sub-${subject}_ses-01_run-01_from-MNI152NLin6Asym_to-T1w_mode-image_xfm.h5
    SMA_PMC_NATIVE=${SUBJ_ROI_DIR}/SMA_PMC_sub_t1w_native.nii.gz
    SMA_PMC_NATIVE_LEFT=${SUBJ_ROI_DIR}/SMA_PMC_sub_t1w_native_left.nii.gz
    SMA_PMC_NATIVE_RIGHT=${SUBJ_ROI_DIR}/SMA_PMC_sub_t1w_native_right.nii.gz
    STG_NATIVE=${SUBJ_ROI_DIR}/STG_sub_t1w_native.nii.gz
    STG_NATIVE_LEFT=${SUBJ_ROI_DIR}/STG_sub_t1w_native_left.nii.gz
    STG_NATIVE_RIGHT=${SUBJ_ROI_DIR}/STG_sub_t1w_native_right.nii.gz
    HESCHL_NATIVE=${SUBJ_ROI_DIR}/Heschl_sub_t1w_native.nii.gz
    HESCHL_NATIVE_LEFT=${SUBJ_ROI_DIR}/Heschl_sub_t1w_native_left.nii.gz
    HESCHL_NATIVE_RIGHT=${SUBJ_ROI_DIR}/Heschl_sub_t1w_native_right.nii.gz

    # Skull-strip T1w
    echo "Skull-stripping T1w for sub-${subject}..."
    fslmaths "$T1W_PREPROC" -mas "$BRAIN_MASK" "$T1W_SKULL_STRIPPED"
    echo "Skull-stripped T1w saved as: $T1W_SKULL_STRIPPED"

    # Resample ROIs by the shape of Z-map into subject-specific ROI folder
    flirt -in ${ROI}/SMA_PMC.nii.gz -ref ${SUBDIR}/fsl_stats/sub-${subject}_task-motor_run-01_contrasts.feat/stats/zstat1.nii.gz -applyxfm -usesqform -out ${SUBJ_ROI_DIR}/SMA_PMC_sub.nii.gz
    flirt -in ${ROI}/STG.nii.gz -ref ${SUBDIR}/fsl_stats/sub-${subject}_task-motor_run-01_contrasts.feat/stats/zstat1.nii.gz -applyxfm -usesqform -out ${SUBJ_ROI_DIR}/STG_sub.nii.gz
    flirt -in ${ROI}/Heschl.nii.gz -ref ${SUBDIR}/fsl_stats/sub-${subject}_task-motor_run-01_contrasts.feat/stats/zstat1.nii.gz -applyxfm -usesqform -out ${SUBJ_ROI_DIR}/Heschl_sub.nii.gz
    
    # Split ROIs into left and right hemispheres in MNI space
    echo "Splitting ROIs in MNI space for sub-${subject}..."
    fslmaths "${SUBJ_ROI_DIR}/SMA_PMC_sub.nii.gz" -roi 1 45 -1 -1 -1 -1 0 1 "${SUBJ_ROI_DIR}/SMA_PMC_sub_left.nii.gz"
    fslmaths "${SUBJ_ROI_DIR}/SMA_PMC_sub.nii.gz" -roi 45 90 -1 -1 -1 -1 0 1 "${SUBJ_ROI_DIR}/SMA_PMC_sub_right.nii.gz"
    fslmaths "${SUBJ_ROI_DIR}/STG_sub.nii.gz" -roi 1 45 -1 -1 -1 -1 0 1 "${SUBJ_ROI_DIR}/STG_sub_left.nii.gz"
    fslmaths "${SUBJ_ROI_DIR}/STG_sub.nii.gz" -roi 45 90 -1 -1 -1 -1 0 1 "${SUBJ_ROI_DIR}/STG_sub_right.nii.gz"
    fslmaths "${SUBJ_ROI_DIR}/Heschl_sub.nii.gz" -roi 1 45 -1 -1 -1 -1 0 1 "${SUBJ_ROI_DIR}/Heschl_sub_left.nii.gz"
    fslmaths "${SUBJ_ROI_DIR}/Heschl_sub.nii.gz" -roi 45 90 -1 -1 -1 -1 0 1 "${SUBJ_ROI_DIR}/Heschl_sub_right.nii.gz"
    echo "MNI ROIs split: ${SUBJ_ROI_DIR}/SMA_PMC_sub_left.nii.gz, ${SUBJ_ROI_DIR}/SMA_PMC_sub_right.nii.gz, ${SUBJ_ROI_DIR}/STG_sub_left.nii.gz, ${SUBJ_ROI_DIR}/STG_sub_right.nii.gz, ${SUBJ_ROI_DIR}/Heschl_sub_left.nii.gz, ${SUBJ_ROI_DIR}/Heschl_sub_right.nii.gz"

    # Inverse transform ROIs (whole and split) to native T1w space
    echo "Inverse transforming ROIs for sub-${subject}..."
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/SMA_PMC_sub.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$SMA_PMC_NATIVE" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/SMA_PMC_sub_left.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$SMA_PMC_NATIVE_LEFT" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/SMA_PMC_sub_right.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$SMA_PMC_NATIVE_RIGHT" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/STG_sub.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$STG_NATIVE" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/STG_sub_left.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$STG_NATIVE_LEFT" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/STG_sub_right.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$STG_NATIVE_RIGHT" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/Heschl_sub.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$HESCHL_NATIVE" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/Heschl_sub_left.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$HESCHL_NATIVE_LEFT" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${SUBJ_ROI_DIR}/Heschl_sub_right.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$HESCHL_NATIVE_RIGHT" \
        -t "$TRANSFORM" -n NearestNeighbor
    echo "ROIs transformed to native space: $SMA_PMC_NATIVE, $SMA_PMC_NATIVE_LEFT, $SMA_PMC_NATIVE_RIGHT, $STG_NATIVE, $STG_NATIVE_LEFT, $STG_NATIVE_RIGHT, $HESCHL_NATIVE, $HESCHL_NATIVE_LEFT, $HESCHL_NATIVE_RIGHT"
}

# Function to process post-stats for a subject and task
process_post_stats() {
    local subject=$1
    local task=$2

    # Subject directory and FEAT output paths
    SUBDIR=${DATADIR}/sub-${subject}/ses-01
    SUBJ_ROI_DIR=${SUBDIR}/ROI  # Subject-specific ROI directory
    OUTPUT_DIR=${SUBDIR}/fsl_stats/sub-${subject}_task-${task}_contrasts.feat
    fslmaths ${OUTPUT_DIR}/stats/zstat1.nii.gz -mas ${SUBDIR}/func/sub-${subject}_ses-01_task-${task}_space-MNI152NLin6Asym_desc-brain_mask.nii.gz ${OUTPUT_DIR}/stats/remasked_zstat1.nii.gz
    ZSTAT=${OUTPUT_DIR}/stats/remasked_zstat1.nii.gz

    THRESH_ZSTAT=${OUTPUT_DIR}/thresh_zstat1.nii.gz
    THRESH_ZSTAT_235=${OUTPUT_DIR}/stats/thresh_zstat1_235.nii.gz
    ZSTAT_LEFT=${OUTPUT_DIR}/stats/zstat1_left.nii.gz
    ZSTAT_RIGHT=${OUTPUT_DIR}/stats/zstat1_right.nii.gz
    ZSTAT_NATIVE=${OUTPUT_DIR}/stats/zstat1_native.nii.gz
    THRESH_ZSTAT_NATIVE=${OUTPUT_DIR}/stats/thresh_zstat1_native.nii.gz
    THRESH_ZSTAT_235_NATIVE=${OUTPUT_DIR}/stats/thresh_zstat1_235_native.nii.gz
    ZSTAT_LEFT_NATIVE=${OUTPUT_DIR}/stats/zstat1_left_native.nii.gz
    ZSTAT_RIGHT_NATIVE=${OUTPUT_DIR}/stats/zstat1_right_native.nii.gz
    THRESH_ZSTAT_LEFT=${OUTPUT_DIR}/stats/thresh_zstat1_left.nii.gz
    THRESH_ZSTAT_RIGHT=${OUTPUT_DIR}/stats/thresh_zstat1_right.nii.gz
    THRESH_ZSTAT_LEFT_235=${OUTPUT_DIR}/stats/thresh_zstat1_left_235.nii.gz
    THRESH_ZSTAT_RIGHT_235=${OUTPUT_DIR}/stats/thresh_zstat1_right_235.nii.gz
    THRESH_ZSTAT_LEFT_NATIVE=${OUTPUT_DIR}/stats/thresh_zstat1_left_native.nii.gz
    THRESH_ZSTAT_RIGHT_NATIVE=${OUTPUT_DIR}/stats/thresh_zstat1_right_native.nii.gz
    THRESH_ZSTAT_LEFT_NATIVE_235=${OUTPUT_DIR}/stats/thresh_zstat1_left_235_native.nii.gz
    THRESH_ZSTAT_RIGHT_NATIVE_235=${OUTPUT_DIR}/stats/thresh_zstat1_right_235_native.nii.gz
    TRANSFORM=${SUBDIR}/anat/sub-${subject}_ses-01_run-01_from-MNI152NLin6Asym_to-T1w_mode-image_xfm.h5
    T1W_SKULL_STRIPPED=${SUBDIR}/anat/sub-${subject}_ses-01_run-01_desc-brain_T1w.nii.gz
    TFCE_CORRP=${OUTPUT_DIR}/randomise_time_series_tfce_corrp_tstat1.nii.gz
    THRESH_TFCE_CORRP=${OUTPUT_DIR}/stats/thresh_tfce_corrp_tstat1.nii.gz
    TFCE_CORRP_NATIVE=${OUTPUT_DIR}/stats/randomise_time_series_tfce_corrp_tstat1_native.nii.gz
    THRESH_TFCE_CORRP_NATIVE=${OUTPUT_DIR}/stats/thresh_tfce_corrp_tstat1_native.nii.gz
    TFCE_CORRP_LEFT=${OUTPUT_DIR}/stats/randomise_time_series_tfce_corrp_tstat1_left.nii.gz
    TFCE_CORRP_RIGHT=${OUTPUT_DIR}/stats/randomise_time_series_tfce_corrp_tstat1_right.nii.gz
    THRESH_TFCE_CORRP_LEFT=${OUTPUT_DIR}/stats/thresh_tfce_corrp_tstat1_left.nii.gz
    THRESH_TFCE_CORRP_RIGHT=${OUTPUT_DIR}/stats/thresh_tfce_corrp_tstat1_right.nii.gz
    TFCE_CORRP_LEFT_NATIVE=${OUTPUT_DIR}/stats/randomise_time_series_tfce_corrp_tstat1_left_native.nii.gz
    TFCE_CORRP_RIGHT_NATIVE=${OUTPUT_DIR}/stats/randomise_time_series_tfce_corrp_tstat1_right_native.nii.gz
    THRESH_TFCE_CORRP_LEFT_NATIVE=${OUTPUT_DIR}/stats/thresh_tfce_corrp_tstat1_left_native.nii.gz
    THRESH_TFCE_CORRP_RIGHT_NATIVE=${OUTPUT_DIR}/stats/thresh_tfce_corrp_tstat1_right_native.nii.gz

    # Cluster threshold at Z=2.35 for z-stats
    echo "Generating thresholded z-map at Z=2.35 for sub-${subject} task-${task}..."
    fslmaths "$ZSTAT" -thr 2.35 "$THRESH_ZSTAT_235"
    cluster -i "$THRESH_ZSTAT_235" -t 2.35 --mm --no_table

    # Threshold TFCE map at 1-p ≥ 0.95 (p ≤ 0.05)
    echo "Generating thresholded TFCE map at 1-p ≥ 0.95 for sub-${subject} task-${task}..."
    fslmaths "$TFCE_CORRP" -thr 0.95 "$THRESH_TFCE_CORRP"

    # Split z-maps, TFCE corrp, and thresholded TFCE corrp into left and right hemispheres in MNI space
    echo "Splitting z-maps, TFCE maps, and thresholded TFCE maps for sub-${subject} task-${task} in MNI space..."
    fslmaths "$ZSTAT" -roi 1 45 -1 -1 -1 -1 0 1 "$ZSTAT_LEFT"
    fslmaths "$ZSTAT" -roi 45 90 -1 -1 -1 -1 0 1 "$ZSTAT_RIGHT"
    fslmaths "$THRESH_ZSTAT" -roi 1 45 -1 -1 -1 -1 0 1 "$THRESH_ZSTAT_LEFT"
    fslmaths "$THRESH_ZSTAT" -roi 45 90 -1 -1 -1 -1 0 1 "$THRESH_ZSTAT_RIGHT"
    fslmaths "$THRESH_ZSTAT_235" -roi 1 45 -1 -1 -1 -1 0 1 "$THRESH_ZSTAT_LEFT_235"
    fslmaths "$THRESH_ZSTAT_235" -roi 45 90 -1 -1 -1 -1 0 1 "$THRESH_ZSTAT_RIGHT_235"
    fslmaths "$TFCE_CORRP" -roi 1 45 -1 -1 -1 -1 0 1 "$TFCE_CORRP_LEFT"
    fslmaths "$TFCE_CORRP" -roi 45 90 -1 -1 -1 -1 0 1 "$TFCE_CORRP_RIGHT"
    fslmaths "$THRESH_TFCE_CORRP" -roi 1 45 -1 -1 -1 -1 0 1 "$THRESH_TFCE_CORRP_LEFT"
    fslmaths "$THRESH_TFCE_CORRP" -roi 45 90 -1 -1 -1 -1 0 1 "$THRESH_TFCE_CORRP_RIGHT"

    # Inverse transform z-maps, TFCE corrp, and thresholded TFCE corrp to native T1w space
    echo "Inverse transforming z-maps, TFCE maps, and thresholded TFCE maps for sub-${subject} task-${task}..."
    antsApplyTransforms -d 3 -i "$ZSTAT" -r "$T1W_SKULL_STRIPPED" -o "$ZSTAT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_ZSTAT" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_ZSTAT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_ZSTAT_235" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_ZSTAT_235_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$ZSTAT_LEFT" -r "$T1W_SKULL_STRIPPED" -o "$ZSTAT_LEFT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$ZSTAT_RIGHT" -r "$T1W_SKULL_STRIPPED" -o "$ZSTAT_RIGHT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_ZSTAT_LEFT" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_ZSTAT_LEFT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_ZSTAT_RIGHT" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_ZSTAT_RIGHT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_ZSTAT_LEFT_235" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_ZSTAT_LEFT_NATIVE_235" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_ZSTAT_RIGHT_235" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_ZSTAT_RIGHT_NATIVE_235" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$TFCE_CORRP" -r "$T1W_SKULL_STRIPPED" -o "$TFCE_CORRP_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_TFCE_CORRP" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_TFCE_CORRP_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$TFCE_CORRP_LEFT" -r "$T1W_SKULL_STRIPPED" -o "$TFCE_CORRP_LEFT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$TFCE_CORRP_RIGHT" -r "$T1W_SKULL_STRIPPED" -o "$TFCE_CORRP_RIGHT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_TFCE_CORRP_LEFT" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_TFCE_CORRP_LEFT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    antsApplyTransforms -d 3 -i "$THRESH_TFCE_CORRP_RIGHT" -r "$T1W_SKULL_STRIPPED" -o "$THRESH_TFCE_CORRP_RIGHT_NATIVE" \
        -t "$TRANSFORM" -n Linear --float --default-value 0 -e 0
    echo "Inverse transform completed: z-maps, TFCE maps, and thresholded TFCE maps in native space: $ZSTAT_NATIVE, $THRESH_ZSTAT_NATIVE, $THRESH_ZSTAT_235_NATIVE, $ZSTAT_LEFT_NATIVE, $ZSTAT_RIGHT_NATIVE, $THRESH_ZSTAT_LEFT_235_NATIVE, $THRESH_ZSTAT_RIGHT_235_NATIVE, $TFCE_CORRP_NATIVE, $THRESH_TFCE_CORRP_NATIVE, $TFCE_CORRP_LEFT_NATIVE, $TFCE_CORRP_RIGHT_NATIVE, $THRESH_TFCE_CORRP_LEFT_NATIVE, $THRESH_TFCE_CORRP_RIGHT_NATIVE"

    # Task-specific ROI mappings for both spaces
    if [[ "$task" == "motor_run-01" || "$task" == "motor_run-02" ]]; then
        ROI_WB_MNI=${SUBJ_ROI_DIR}/SMA_PMC_sub.nii.gz
        ROI_LEFT_MNI=${SUBJ_ROI_DIR}/SMA_PMC_sub_left.nii.gz
        ROI_RIGHT_MNI=${SUBJ_ROI_DIR}/SMA_PMC_sub_right.nii.gz
        ROI_WB_NATIVE=${SUBJ_ROI_DIR}/SMA_PMC_sub_t1w_native.nii.gz
        ROI_LEFT_NATIVE=${SUBJ_ROI_DIR}/SMA_PMC_sub_t1w_native_left.nii.gz
        ROI_RIGHT_NATIVE=${SUBJ_ROI_DIR}/SMA_PMC_sub_t1w_native_right.nii.gz
    elif [[ "$task" == "lang" ]]; then
        ROI_WB_STG_MNI=${SUBJ_ROI_DIR}/STG_sub.nii.gz
        ROI_LEFT_STG_MNI=${SUBJ_ROI_DIR}/STG_sub_left.nii.gz
        ROI_RIGHT_STG_MNI=${SUBJ_ROI_DIR}/STG_sub_right.nii.gz
        ROI_WB_HESCHL_MNI=${SUBJ_ROI_DIR}/Heschl_sub.nii.gz
        ROI_LEFT_HESCHL_MNI=${SUBJ_ROI_DIR}/Heschl_sub_left.nii.gz
        ROI_RIGHT_HESCHL_MNI=${SUBJ_ROI_DIR}/Heschl_sub_right.nii.gz
        ROI_WB_STG_NATIVE=${SUBJ_ROI_DIR}/STG_sub_t1w_native.nii.gz
        ROI_LEFT_STG_NATIVE=${SUBJ_ROI_DIR}/STG_sub_t1w_native_left.nii.gz
        ROI_RIGHT_STG_NATIVE=${SUBJ_ROI_DIR}/STG_sub_t1w_native_right.nii.gz
        ROI_WB_HESCHL_NATIVE=${SUBJ_ROI_DIR}/Heschl_sub_t1w_native.nii.gz
        ROI_LEFT_HESCHL_NATIVE=${SUBJ_ROI_DIR}/Heschl_sub_t1w_native_left.nii.gz
        ROI_RIGHT_HESCHL_NATIVE=${SUBJ_ROI_DIR}/Heschl_sub_t1w_native_right.nii.gz
    else
        echo "Warning: No ROI defined for task $task"
        return 1
    fi

    # Output CSV file with added Dice and dual Coverage columns
    mkdir -p "${SUBDIR}/post_stats"
    CSV_FILE=${SUBDIR}/post_stats/sub-${subject}_task-${task}_roi_stats.csv
    echo "Subject,Task,Space,ROI,Threshold,Stat Type,Activated Voxels across Whole Brain (counts),Activated Voxels within ROI (counts),Activated Voxels across Whole Brain (%),Activated Voxels within ROI (%),Activated ROI/WB (%),%Activated ROI/%Activated WB (ratio),Voxels in ROI (counts),Voxels in Whole Brain (counts),Dice Coefficient,Coverage T-map (%),Coverage Z-map (%),Coverage T-map ROI (%),Coverage Z-map ROI (%)" > "$CSV_FILE"

    # Process each space (Native and MNI)
    for space in "Native" "MNI"; do
        # Set ROIs and maps based on space
        if [ "$space" == "Native" ]; then
            ZSTAT_USE="$ZSTAT_NATIVE"
            THRESH_ZSTAT_USE="$THRESH_ZSTAT_NATIVE"
            THRESH_ZSTAT_235_USE="$THRESH_ZSTAT_235_NATIVE"
            ZSTAT_LEFT_USE="$ZSTAT_LEFT_NATIVE"
            ZSTAT_RIGHT_USE="$ZSTAT_RIGHT_NATIVE"
            THRESH_ZSTAT_LEFT_USE="$THRESH_ZSTAT_LEFT_NATIVE"
            THRESH_ZSTAT_RIGHT_USE="$THRESH_ZSTAT_RIGHT_NATIVE"
            THRESH_ZSTAT_LEFT_235_USE="$THRESH_ZSTAT_LEFT_NATIVE_235"
            THRESH_ZSTAT_RIGHT_235_USE="$THRESH_ZSTAT_RIGHT_NATIVE_235"
            TFCE_CORRP_USE="$TFCE_CORRP_NATIVE"
            THRESH_TFCE_CORRP_USE="$THRESH_TFCE_CORRP_NATIVE"
            TFCE_CORRP_LEFT_USE="$TFCE_CORRP_LEFT_NATIVE"
            TFCE_CORRP_RIGHT_USE="$TFCE_CORRP_RIGHT_NATIVE"
            THRESH_TFCE_CORRP_LEFT_USE="$THRESH_TFCE_CORRP_LEFT_NATIVE"
            THRESH_TFCE_CORRP_RIGHT_USE="$THRESH_TFCE_CORRP_RIGHT_NATIVE"
            if [[ "$task" == "motor_run-01" || "$task" == "motor_run-02" ]]; then
                ROI_WB="$ROI_WB_NATIVE"
                ROI_LEFT="$ROI_LEFT_NATIVE"
                ROI_RIGHT="$ROI_RIGHT_NATIVE"
            elif [[ "$task" == "lang" ]]; then
                ROI_WB_STG="$ROI_WB_STG_NATIVE"
                ROI_LEFT_STG="$ROI_LEFT_STG_NATIVE"
                ROI_RIGHT_STG="$ROI_RIGHT_STG_NATIVE"
                ROI_WB_HESCHL="$ROI_WB_HESCHL_NATIVE"
                ROI_LEFT_HESCHL="$ROI_LEFT_HESCHL_NATIVE"
                ROI_RIGHT_HESCHL="$ROI_RIGHT_HESCHL_NATIVE"
            fi
        else  # MNI
            ZSTAT_USE="$ZSTAT"
            THRESH_ZSTAT_USE="$THRESH_ZSTAT"
            THRESH_ZSTAT_235_USE="$THRESH_ZSTAT_235"
            ZSTAT_LEFT_USE="$ZSTAT_LEFT"
            ZSTAT_RIGHT_USE="$ZSTAT_RIGHT"
            THRESH_ZSTAT_LEFT_USE="$THRESH_ZSTAT_LEFT"
            THRESH_ZSTAT_RIGHT_USE="$THRESH_ZSTAT_RIGHT"
            THRESH_ZSTAT_LEFT_235_USE="$THRESH_ZSTAT_LEFT_235"
            THRESH_ZSTAT_RIGHT_235_USE="$THRESH_ZSTAT_RIGHT_235"
            TFCE_CORRP_USE="$TFCE_CORRP"
            THRESH_TFCE_CORRP_USE="$THRESH_TFCE_CORRP"
            TFCE_CORRP_LEFT_USE="$TFCE_CORRP_LEFT"
            TFCE_CORRP_RIGHT_USE="$TFCE_CORRP_RIGHT"
            THRESH_TFCE_CORRP_LEFT_USE="$THRESH_TFCE_CORRP_LEFT"
            THRESH_TFCE_CORRP_RIGHT_USE="$THRESH_TFCE_CORRP_RIGHT"
            if [[ "$task" == "motor_run-01" || "$task" == "motor_run-02" ]]; then
                ROI_WB="$ROI_WB_MNI"
                ROI_LEFT="$ROI_LEFT_MNI"
                ROI_RIGHT="$ROI_RIGHT_MNI"
            elif [[ "$task" == "lang" ]]; then
                ROI_WB_STG="$ROI_WB_STG_MNI"
                ROI_LEFT_STG="$ROI_LEFT_STG_MNI"
                ROI_RIGHT_STG="$ROI_RIGHT_STG_MNI"
                ROI_WB_HESCHL="$ROI_WB_HESCHL_MNI"
                ROI_LEFT_HESCHL="$ROI_LEFT_HESCHL_MNI"
                ROI_RIGHT_HESCHL="$ROI_RIGHT_HESCHL_MNI"
            fi
        fi

        # Process Z-stats thresholds
        for thresh_label in "Z=3.1" "Z=2.35"; do
            if [[ "$task" == "motor_run-01" || "$task" == "motor_run-02" ]]; then
                roi_labels=("Whole-brain" "Left" "Right")
                roi_paths=("$ROI_WB" "$ROI_LEFT" "$ROI_RIGHT")
            elif [[ "$task" == "lang" ]]; then
                roi_labels=("Whole-brain STG" "Left STG" "Right STG" "Whole-brain Heschl" "Left Heschl" "Right Heschl")
                roi_paths=("$ROI_WB_STG" "$ROI_LEFT_STG" "$ROI_RIGHT_STG" "$ROI_WB_HESCHL" "$ROI_LEFT_HESCHL" "$ROI_RIGHT_HESCHL")
            fi

            for i in "${!roi_labels[@]}"; do
                roi_label="${roi_labels[$i]}"
                roi_path="${roi_paths[$i]}"
                if [ "$roi_label" == "Whole-brain" ] || [ "$roi_label" == "Whole-brain STG" ] || [ "$roi_label" == "Whole-brain Heschl" ]; then
                    z_map="$ZSTAT_USE"
                    if [ "$thresh_label" == "Z=3.1" ]; then
                        thresh_z_map="$THRESH_ZSTAT_USE"
                    else
                        thresh_z_map="$THRESH_ZSTAT_235_USE"
                    fi
                elif [ "$roi_label" == "Left" ] || [ "$roi_label" == "Left STG" ] || [ "$roi_label" == "Left Heschl" ]; then
                    z_map="$ZSTAT_LEFT_USE"
                    if [ "$thresh_label" == "Z=3.1" ]; then
                        thresh_z_map="$THRESH_ZSTAT_LEFT_USE"
                    else
                        thresh_z_map="$THRESH_ZSTAT_LEFT_235_USE"
                    fi
                elif [ "$roi_label" == "Right" ] || [ "$roi_label" == "Right STG" ] || [ "$roi_label" == "Right Heschl" ]; then
                    z_map="$ZSTAT_RIGHT_USE"
                    if [ "$thresh_label" == "Z=3.1" ]; then
                        thresh_z_map="$THRESH_ZSTAT_RIGHT_USE"
                    else
                        thresh_z_map="$THRESH_ZSTAT_RIGHT_235_USE"
                    fi
                fi

                # Total voxels in the z-map (whole brain or hemisphere)
                total_voxels=$(fslstats "$z_map" -V | awk '{print $1}')
                # Total voxels in the ROI mask
                roi_voxels=$(fslstats "$roi_path" -V | awk '{print $1}')

                # Activated voxels in thresh_z_map (whole brain or hemisphere)
                activated_voxels_wb=$(fslstats "$thresh_z_map" -k "$z_map" -l 0 -V | awk '{print $1}')
                # Activated voxels in thresh_z_map within ROI
                activated_voxels_roi=$(fslstats "$thresh_z_map" -k "$roi_path" -l 0 -V | awk '{print $1}')

                # Calculate percentages
                percentage_wb=$(calculate_percentage "$activated_voxels_wb" "$total_voxels")
                percentage_roi=$(calculate_percentage "$activated_voxels_roi" "$roi_voxels")
                percentage_roi_in_wb=$(calculate_percentage "$activated_voxels_roi" "$total_voxels")
                if [ "$(echo "$percentage_wb > 0" | bc)" -eq 1 ]; then
                    ratio_actv_roi_in_wb=$(printf "%.3f" $(bc -l <<< "scale=2; $percentage_roi / $percentage_wb"))
                else
                    ratio_actv_roi_in_wb="N/A"
                fi

                # Dice and coverage are N/A for Z-stat
                dice="N/A"
                coverage_t="N/A"
                coverage_z="N/A"
                coverage_t_roi="N/A"
                coverage_z_roi="N/A"

                # Append to CSV with "Z-stat" type
                echo "$subject,$task,$space,$roi_label,$thresh_label,Z-stat,$activated_voxels_wb,$activated_voxels_roi,$percentage_wb,$percentage_roi,$percentage_roi_in_wb,$ratio_actv_roi_in_wb,$roi_voxels,$total_voxels,$dice,$coverage_t,$coverage_z,$coverage_t_roi,$coverage_z_roi" >> "$CSV_FILE"
            done
        done

        # Process thresholded TFCE (1-p ≥ 0.95) and compare with Z=3.1
        thresh_label="p<0.05"
        if [[ "$task" == "motor_run-01" || "$task" == "motor_run-02" ]]; then
            roi_labels=("Whole-brain" "Left" "Right")
            roi_paths=("$ROI_WB" "$ROI_LEFT" "$ROI_RIGHT")
        elif [[ "$task" == "lang" ]]; then
            roi_labels=("Whole-brain STG" "Left STG" "Right STG" "Whole-brain Heschl" "Left Heschl" "Right Heschl")
            roi_paths=("$ROI_WB_STG" "$ROI_LEFT_STG" "$ROI_RIGHT_STG" "$ROI_WB_HESCHL" "$ROI_LEFT_HESCHL" "$ROI_RIGHT_HESCHL")
        fi

        for i in "${!roi_labels[@]}"; do
            roi_label="${roi_labels[$i]}"
            roi_path="${roi_paths[$i]}"
            if [ "$roi_label" == "Whole-brain" ] || [ "$roi_label" == "Whole-brain STG" ] || [ "$roi_label" == "Whole-brain Heschl" ]; then
                thresh_tfce_map="$THRESH_TFCE_CORRP_USE"  # Thresholded TFCE
                tfce_map="$TFCE_CORRP_USE"  # Unthresholded TFCE for total voxels
                thresh_z_map="$THRESH_ZSTAT_USE"  # Compare with Z=3.1
            elif [ "$roi_label" == "Left" ] || [ "$roi_label" == "Left STG" ] || [ "$roi_label" == "Left Heschl" ]; then
                thresh_tfce_map="$THRESH_TFCE_CORRP_LEFT_USE"  # Thresholded TFCE
                tfce_map="$TFCE_CORRP_LEFT_USE"  # Unthresholded TFCE for total voxels
                thresh_z_map="$THRESH_ZSTAT_LEFT_USE"  # Compare with Z=3.1
            elif [ "$roi_label" == "Right" ] || [ "$roi_label" == "Right STG" ] || [ "$roi_label" == "Right Heschl" ]; then
                thresh_tfce_map="$THRESH_TFCE_CORRP_RIGHT_USE"  # Thresholded TFCE
                tfce_map="$TFCE_CORRP_RIGHT_USE"  # Unthresholded TFCE for total voxels
                thresh_z_map="$THRESH_ZSTAT_RIGHT_USE"  # Compare with Z=3.1
            fi

            # Total voxels in the tfce_map (whole brain or hemisphere)
            total_voxels=$(fslstats "$tfce_map" -V | awk '{print $1}')
            # Total voxels in the ROI mask
            roi_voxels=$(fslstats "$roi_path" -V | awk '{print $1}')

            # Activated voxels in thresh_tfce_map (whole brain or hemisphere)
            activated_voxels_wb=$(fslstats "$thresh_tfce_map" -k "$tfce_map" -l 0 -V | awk '{print $1}')
            # Activated voxels in thresh_tfce_map within ROI
            activated_voxels_roi=$(fslstats "$thresh_tfce_map" -k "$roi_path" -l 0 -V | awk '{print $1}')

            # Calculate percentages
            percentage_wb=$(calculate_percentage "$activated_voxels_wb" "$total_voxels")
            percentage_roi=$(calculate_percentage "$activated_voxels_roi" "$roi_voxels")
            percentage_roi_in_wb=$(calculate_percentage "$activated_voxels_roi" "$total_voxels")
            if [ "$(echo "$percentage_wb > 0" | bc)" -eq 1 ]; then
                ratio_actv_roi_in_wb=$(printf "%.3f" $(bc -l <<< "scale=2; $percentage_roi / $percentage_wb"))
            else
                ratio_actv_roi_in_wb="N/A"
            fi

            # Calculate Dice and Coverage for thresholded TFCE vs. Z=3.1
            dice=$(calculate_dice "$thresh_tfce_map" "$thresh_z_map")
            coverage_values=$(calculate_coverage "$thresh_tfce_map" "$thresh_z_map")
            coverage_t=$(echo "$coverage_values" | cut -d',' -f1)
            coverage_z=$(echo "$coverage_values" | cut -d',' -f2)

            # Calculate ROI-specific coverage percentages
            activated_voxels_roi_z=$(fslstats "$thresh_z_map" -k "$roi_path" -l 0 -V | awk '{print $1}')
            overlap_roi=$(fslstats "$thresh_tfce_map" -k "$thresh_z_map" -k "$roi_path" -l 0 -V | awk '{print $1}')
            coverage_t_roi="0.0"
            coverage_z_roi="0.0"
            if [ "$activated_voxels_roi" -gt 0 ]; then
                coverage_t_roi=$(calculate_percentage "$overlap_roi" "$activated_voxels_roi")
            fi
            if [ "$activated_voxels_roi_z" -gt 0 ]; then
                coverage_z_roi=$(calculate_percentage "$overlap_roi" "$activated_voxels_roi_z")
            fi

            # Append to CSV with "TFCE" type
            echo "$subject,$task,$space,$roi_label,$thresh_label,TFCE,$activated_voxels_wb,$activated_voxels_roi,$percentage_wb,$percentage_roi,$percentage_roi_in_wb,$ratio_actv_roi_in_wb,$roi_voxels,$total_voxels,$dice,$coverage_t,$coverage_z,$coverage_t_roi,$coverage_z_roi" >> "$CSV_FILE"
        done
    done
    echo "Completed post-stats processing for sub-${subject} task-${task}"
    echo "Results saved to $CSV_FILE"
}

# Export functions for potential parallel use
export -f preprocess_subject
export -f process_post_stats
export -f calculate_percentage
export -f calculate_dice
export -f calculate_coverage

# Main processing loop using command-line arguments
for subject in "$@"; do
    echo "Preprocessing sub-${subject} (skull-stripping and ROI transformation)"
    preprocess_subject "$subject"
    for task in $TASKS; do
        echo "Processing post-stats for sub-${subject} task-${task}"
        mkdir -p "${DATADIR}/sub-${subject}/ses-01/post_stats"
        process_post_stats "$subject" "$task" > "${DATADIR}/sub-${subject}/ses-01/post_stats/log_${subject}_${task}.txt" 2>&1 &
    done
    wait
done

wait
echo "All processing completed for subjects: $@"