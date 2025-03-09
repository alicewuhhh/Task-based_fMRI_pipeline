#!/bin/bash
# This script splits ROIs and z-maps into left/right in MNI space, then performs skull-stripping,
# ROI/z-map inverse transformation once per subject, and processes zstat1 post-stats for each task.
# Computes results in both native and MNI spaces, combining them in a single table.
# Created for RECOVER project by A. Wu, Feb 2025
# Updated to include z-map thresholding at Z=2.35 and Z=3.1 and both spaces, Mar 2025
set -e

# Check if at least one subject ID was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <subject_id1> <subject_id2> ... <subject_idN>"
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
    if [ "$denominator" -gt 0 ]; then
        local result=$(echo "scale=3; ($numerator / $denominator) * 100" | bc)
        printf "%.3f" "$result"
    else
        echo "0.0"
    fi
}

# Function to preprocess subject (skull-strip T1w and inverse transform ROIs)
preprocess_subject() {
    local subject=$1
    SUBDIR=${DATADIR}/sub-${subject}/ses-01

    # Input and output files for T1w and ROIs
    T1W_PREPROC=${SUBDIR}/anat/sub-${subject}_ses-BRAINxRESEARCHxFISCHER_run-1_desc-preproc_T1w.nii.gz
    BRAIN_MASK=${SUBDIR}/anat/sub-${subject}_ses-BRAINxRESEARCHxFISCHER_run-1_desc-brain_mask.nii.gz
    T1W_SKULL_STRIPPED=${SUBDIR}/anat/sub-${subject}_ses-BRAINxRESEARCHxFISCHER_run-1_desc-brain_T1w.nii.gz
    TRANSFORM=${SUBDIR}/anat/sub-${subject}_ses-BRAINxRESEARCHxFISCHER_run-1_from-MNI152NLin2009cAsym_to-T1w_mode-image_xfm.h5
    SMA_PMC_NATIVE=${ROI}/SMA_PMC_sub_t1w_native.nii.gz
    STG_HESCHL_NATIVE=${ROI}/STG_Heschl_sub_t1w_native.nii.gz
    STG_HESCHL_NATIVE_LEFT=${ROI}/STG_Heschl_sub_t1w_native_left.nii.gz
    STG_HESCHL_NATIVE_RIGHT=${ROI}/STG_Heschl_sub_t1w_native_right.nii.gz
    SMA_PMC_NATIVE_LEFT=${ROI}/SMA_PMC_sub_t1w_native_left.nii.gz
    SMA_PMC_NATIVE_RIGHT=${ROI}/SMA_PMC_sub_t1w_native_right.nii.gz

    # Skull-strip T1w
    echo "Skull-stripping T1w for sub-${subject}..."
    fslmaths "$T1W_PREPROC" -mas "$BRAIN_MASK" "$T1W_SKULL_STRIPPED"
    echo "Skull-stripped T1w saved as: $T1W_SKULL_STRIPPED"

    # Resample ROIs by the shape of Z-map
    flirt -in ${ROI}/STG_Heschl.nii.gz -ref ${SUBDIR}/fsl_stats/sub-${subject}_task-motor_run-1_contrasts.feat/stats/zstat1.nii.gz -applyxfm -usesqform -out ${ROI}/STG_Heschl_sub.nii.gz
    flirt -in ${ROI}/SMA_PMC.nii.gz -ref ${SUBDIR}/fsl_stats/sub-${subject}_task-motor_run-1_contrasts.feat/stats/zstat1.nii.gz -applyxfm -usesqform -out ${ROI}/SMA_PMC_sub.nii.gz
    
    # Split ROIs into left and right hemispheres in MNI space 
    echo "Splitting ROIs in MNI space..."
    fslmaths "${ROI}/STG_Heschl_sub.nii.gz" -roi 1 45 -1 -1 -1 -1 0 1 "${ROI}/STG_Heschl_sub_left.nii.gz"
    fslmaths "${ROI}/STG_Heschl_sub.nii.gz" -roi 45 90 -1 -1 -1 -1 0 1 "${ROI}/STG_Heschl_sub_right.nii.gz"
    fslmaths "${ROI}/SMA_PMC_sub.nii.gz" -roi 1 45 -1 -1 -1 -1 0 1 "${ROI}/SMA_PMC_sub_left.nii.gz"
    fslmaths "${ROI}/SMA_PMC_sub.nii.gz" -roi 45 90 -1 -1 -1 -1 0 1 "${ROI}/SMA_PMC_sub_right.nii.gz"
    echo "MNI ROIs split: ${ROI}/STG_Heschl_sub_left.nii.gz, ${ROI}/STG_Heschl_sub_right.nii.gz, ${ROI}/SMA_PMC_sub_left.nii.gz, ${ROI}/SMA_PMC_sub_right.nii.gz}"

    # Inverse transform ROIs (whole and split) to native T1w space
    echo "Inverse transforming ROIs for sub-${subject}..."
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${ROI}/SMA_PMC_sub.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$SMA_PMC_NATIVE" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${ROI}/STG_Heschl_sub.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$STG_HESCHL_NATIVE" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${ROI}/STG_Heschl_sub_left.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$STG_HESCHL_NATIVE_LEFT" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${ROI}/STG_Heschl_sub_right.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$STG_HESCHL_NATIVE_RIGHT" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${ROI}/SMA_PMC_sub_left.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$SMA_PMC_NATIVE_LEFT" \
        -t "$TRANSFORM" -n NearestNeighbor
    antsApplyTransforms --default-value 0 -d 3 --float 0 \
        -i "${ROI}/SMA_PMC_sub_right.nii.gz" -r "$T1W_SKULL_STRIPPED" -o "$SMA_PMC_NATIVE_RIGHT" \
        -t "$TRANSFORM" -n NearestNeighbor
    echo "ROIs transformed to native space: $SMA_PMC_NATIVE, $STG_HESCHL_NATIVE, $SMA_PMC_NATIVE_LEFT, $SMA_PMC_NATIVE_RIGHT, $STG_HESCHL_NATIVE_LEFT, $STG_HESCHL_NATIVE_RIGHT"
}

# Function to process post-stats for a subject and task
process_post_stats() {
    local subject=$1
    local task=$2

    # Subject directory and FEAT output paths
    SUBDIR=${DATADIR}/sub-${subject}/ses-01
    OUTPUT_DIR=${SUBDIR}/fsl_stats/sub-${subject}_task-${task}_contrasts.feat
    ZSTAT=${OUTPUT_DIR}/stats/zstat1.nii.gz
    THRESH_ZSTAT=${OUTPUT_DIR}/thresh_zstat1.nii.gz
    THRESH_ZSTAT_235=${OUTPUT_DIR}/stats/thresh_zstat1_235.nii.gz
    ZSTAT_LEFT=${OUTPUT_DIR}/stats/zstat1_left.nii.gz
    ZSTAT_RIGHT=${OUTPUT_DIR}/stats/zstat1_right.nii.gz
    ZSTAT_NATIVE=${OUTPUT_DIR}/stats/zstat1_native.nii.gz
    THRESH_ZSTAT_NATIVE=${OUTPUT_DIR}/thresh_zstat1_native.nii.gz
    THRESH_ZSTAT_235_NATIVE=${OUTPUT_DIR}/stats/thresh_zstat1_235_native.nii.gz
    ZSTAT_LEFT_NATIVE=${OUTPUT_DIR}/stats/zstat1_left_native.nii.gz
    ZSTAT_RIGHT_NATIVE=${OUTPUT_DIR}/stats/zstat1_right_native.nii.gz
    THRESH_ZSTAT_LEFT=${OUTPUT_DIR}/thresh_zstat1_left.nii.gz
    THRESH_ZSTAT_RIGHT=${OUTPUT_DIR}/thresh_zstat1_right.nii.gz
    THRESH_ZSTAT_LEFT_235=${OUTPUT_DIR}/stats/thresh_zstat1_left_235.nii.gz
    THRESH_ZSTAT_RIGHT_235=${OUTPUT_DIR}/stats/thresh_zstat1_right_235.nii.gz
    THRESH_ZSTAT_LEFT_NATIVE=${OUTPUT_DIR}/thresh_zstat1_left_native.nii.gz
    THRESH_ZSTAT_RIGHT_NATIVE=${OUTPUT_DIR}/thresh_zstat1_right_native.nii.gz
    THRESH_ZSTAT_LEFT_NATIVE_235=${OUTPUT_DIR}/stats/thresh_zstat1_left_235_native.nii.gz
    THRESH_ZSTAT_RIGHT_NATIVE_235=${OUTPUT_DIR}/stats/thresh_zstat1_right_235_native.nii.gz
    TRANSFORM=${SUBDIR}/anat/sub-${subject}_ses-BRAINxRESEARCHxFISCHER_run-1_from-MNI152NLin2009cAsym_to-T1w_mode-image_xfm.h5
    T1W_SKULL_STRIPPED=${SUBDIR}/anat/sub-${subject}_ses-BRAINxRESEARCHxFISCHER_run-1_desc-brain_T1w.nii.gz

    # Cluster threshold at Z=2.35 (assuming default thresh_zstat1 (Z=3.1) is from FEAT or earlier cluster command)
    echo "Generating thresholded z-map at Z=2.35 for sub-${subject} task-${tassk}..."
    fslmaths "$ZSTAT" -thr 2.35 "$THRESH_ZSTAT_235"
    cluster -i "$THRESH_ZSTAT_235" -t 2.35 --mm

    # Split z-maps into left and right hemispheres in MNI space
    echo "Splitting z-maps for sub-${subject} task-${task} in MNI space..."
    fslmaths "$ZSTAT" -roi 1 45 -1 -1 -1 -1 0 1 "$ZSTAT_LEFT"
    fslmaths "$ZSTAT" -roi 45 90 -1 -1 -1 -1 0 1 "$ZSTAT_RIGHT"
    fslmaths "$THRESH_ZSTAT" -roi 1 45 -1 -1 -1 -1 0 1 "$THRESH_ZSTAT_LEFT"
    fslmaths "$THRESH_ZSTAT" -roi 45 90 -1 -1 -1 -1 0 1 "$THRESH_ZSTAT_RIGHT"
    fslmaths "$THRESH_ZSTAT_235" -roi 1 45 -1 -1 -1 -1 0 1 "$THRESH_ZSTAT_LEFT_235"
    fslmaths "$THRESH_ZSTAT_235" -roi 45 90 -1 -1 -1 -1 0 1 "$THRESH_ZSTAT_RIGHT_235"

    # Inverse transform z-maps (whole and split) to native T1w space
    echo "Inverse transforming z-maps for sub-${subject} task-${task}..."
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
    echo "Inverse transform of z-maps completed: $ZSTAT_NATIVE, $THRESH_ZSTAT_NATIVE, $THRESH_ZSTAT_235_NATIVE, $ZSTAT_LEFT_NATIVE, $ZSTAT_RIGHT_NATIVE, $THRESH_ZSTAT_LEFT_NATIVE, $THRESH_ZSTAT_RIGHT_NATIVE, $THRESH_ZSTAT_LEFT_NATIVE_235, $THRESH_ZSTAT_RIGHT_NATIVE_235"

    # Task-specific ROI mappings for both spaces
    if [[ "$task" == "motor_run-1" || "$task" == "motor_run-2" ]]; then
        ROI_WB_MNI=${ROI}/SMA_PMC_sub.nii.gz
        ROI_LEFT_MNI=${ROI}/SMA_PMC_sub_left.nii.gz
        ROI_RIGHT_MNI=${ROI}/SMA_PMC_sub_right.nii.gz
        ROI_WB_NATIVE=${ROI}/SMA_PMC_sub_t1w_native.nii.gz
        ROI_LEFT_NATIVE=${ROI}/SMA_PMC_sub_t1w_native_left.nii.gz
        ROI_RIGHT_NATIVE=${ROI}/SMA_PMC_sub_t1w_native_right.nii.gz
    elif [[ "$task" == "lang" ]]; then
        ROI_WB_MNI=${ROI}/STG_Heschl_sub.nii.gz
        ROI_LEFT_MNI=${ROI}/STG_Heschl_sub_left.nii.gz
        ROI_RIGHT_MNI=${ROI}/STG_Heschl_sub_right.nii.gz
        ROI_WB_NATIVE=${ROI}/STG_Heschl_sub_t1w_native.nii.gz
        ROI_LEFT_NATIVE=${ROI}/STG_Heschl_sub_t1w_native_left.nii.gz
        ROI_RIGHT_NATIVE=${ROI}/STG_Heschl_sub_t1w_native_right.nii.gz
    else
        echo "Warning: No ROI defined for task $task"
        return 1
    fi

    # Output CSV file
    mkdir -p "${SUBDIR}/post_stats"
    CSV_FILE=${SUBDIR}/post_stats/sub-${subject}_task-${task}_roi_stats.csv
    echo "Subject,Task,Space,ROI,Threshold,Activated Voxels across Whole Brain (counts),Activated Voxels across Whole Brain (%),Activated Voxels within ROI (counts),Activated Voxels within ROI (%),Activated ROI/Activated WB (%), Voxels in ROI (counts),Voxels in Whole Brain (counts)" > "$CSV_FILE"

    # Process each space (Native and MNI)
    for space in "Native" "MNI"; do
        # Set z-maps and ROIs based on space
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
            ROI_WB="$ROI_WB_NATIVE"
            ROI_LEFT="$ROI_LEFT_NATIVE"
            ROI_RIGHT="$ROI_RIGHT_NATIVE"
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
            ROI_WB="$ROI_WB_MNI"
            ROI_LEFT="$ROI_LEFT_MNI"
            ROI_RIGHT="$ROI_RIGHT_MNI"
        fi

        # Process each threshold and ROI
        for thresh_label in "Z=3.1" "Z=2.35"; do
            for roi_label in "Whole-brain" "Left" "Right"; do
                if [ "$roi_label" == "Whole-brain" ]; then
                    roi_path="$ROI_WB"
                    z_map="$ZSTAT_USE"
                    if [ "$thresh_label" == "Z=3.1" ]; then
                        thresh_z_map="$THRESH_ZSTAT_USE"
                    else
                        thresh_z_map="$THRESH_ZSTAT_235_USE"
                    fi
                elif [ "$roi_label" == "Left" ]; then
                    roi_path="$ROI_LEFT"
                    z_map="$ZSTAT_LEFT_USE"
                    if [ "$thresh_label" == "Z=3.1" ]; then
                        thresh_z_map="$THRESH_ZSTAT_LEFT_USE"
                    else
                        thresh_z_map="$THRESH_ZSTAT_LEFT_235_USE"
                    fi
                elif [ "$roi_label" == "Right" ]; then
                    roi_path="$ROI_RIGHT"
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
                percentage_roi_in_wb=$(calculate_percentage "$activated_voxels_roi" "$activated_voxels_wb")

                # Append to CSV
                echo "$subject,$task,$space,$roi_label,$thresh_label,$activated_voxels_wb,$percentage_wb,$activated_voxels_roi,$percentage_roi,$percentage_roi_in_wb,$roi_voxels,$total_voxels" >> "$CSV_FILE"
            done
        done
    done

    echo "Completed post-stats processing for sub-${subject} task-${task}"
    echo "Results saved to $CSV_FILE"
}

# Export functions for potential parallel use
export -f preprocess_subject
export -f process_post_stats
export -f calculate_percentage

# Main processing loop using command-line arguments
for subject in "$@"; do
    echo "Preprocessing sub-${subject} (skull-stripping and ROI transformation)"
    preprocess_subject "$subject"

    for task in motor_run-1 motor_run-2 lang; do
        echo "Processing post-stats for sub-${subject} task-${task}"
        process_post_stats "$subject" "$task"
    done
done

echo "All processing completed for subjects: $@"
