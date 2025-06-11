# Task-based fMRI Pipeline (RECOVER Project)

Created by K. Nguyen and A. Wu, Mar 2025.

This pipeline implements three testing methods:
- **GLM Testing:** Adapted from the MGH protocol. Use GLM model to conduct the analysis. Cluster thresholding at Z=3.1
- **Permutation Testing:** Non-parametric method. Randomly shuffling or rearranging data to estimate the sampling distribution of a test statistic under the null hypothesis. Includes a threshold-free clustering enhancement (TFCE) method.
- **ICA** ICA Temporal correlation with task regressor and spatial correlation with GLM output Z-stat map

---

## Inputs

The pipeline uses outputs from fMRIPrep (version: 23.0.1).  
**fMRIPrep command used:**
`/opt/conda/bin/fmriprep /flywheel/v0/work/bids /flywheel/v0/output/67b747ac81e8158d3b6ad2c6 participant --aroma-melodic-dimensionality=-200 --bold2t1w-dof=6 --bold2t1w-init=register --dvars-spike-threshold=1.5 --fd-spike-threshold=0.5 --n_cpus=2 --omp-nthreads=2 --output-spaces=MNI152NLin6Asym --skull-strip-t1w=force --skull-strip-template=OASIS30ANTs --use-aroma --mem=12203`

**Required inputs:**
- **Functional BOLD images (NIfTI):** In the 'func' folder of fMRIPrep output. in standard MNI space.
  - From tasks (two motor tasks and one language task). e.g., `sub-xxx_ses-01_task-motor_run-01_space-MNI152NLin6Asym_desc-preproc_bold.nii.gz`
  - Brain masks for the functional bold images. `sub-xxx_ses-01_task-motor_run-01_space-MNI152NLin6Asym_desc-brain_mask.nii.gz`
- **Structural T1w images:** In the 'anat' folder of fMRIPrep output.
  - T1w image in native and MNI space. `sub-xxx_ses-01_run-01_desc-brain_T1w.nii.gz`, `sub-xxx_ses-01_run-01_space-MNI152NLin6Asym_desc-preproc_T1w.nii.gz`.
  - Brain masks of skull-stripped T1. `sub-xxx_ses-01_run-01_desc-brain_mask.nii.gz`
  - Transformation matrix file. `sub_xxx_ses-01_run-01_from-MNI152NLin6Asym_to-T1w_mode-image_xfm.h5`
- **Design template:** For FSL FEAT analysis (`design_test_script.fsf`).
- **ROIs:** Motor (`SMA_PMC.nii.gz`) and Language tasks (`STG.nii.gz`, `Heschl.nii.gz`).

---

## How to Run the Pipeline

Run the pipeline using `master_workflow.sh`.  
This script orchestrates the RECOVER fMRI pipeline and accepts subject IDs as command-line arguments. You can choose to run specific steps or the entire pipeline.

**Options:**
- `-f`: Run FEAT stats (`feat_contrasts_recover_cluster.sh`).
- `-p`: Run randomize permutation testing (`run_permutation_test_cluster.sh`).
- `-c`: Calculate post-stats (`cal_post_stats_thresh.sh`).
- `-i`: Run ICA analysis (`ica_corr.py`)
- `-o`: Generate output (PDF + HTML) (`output_generator.py`).
- `-a`: Run all steps (default if no specific option is specified).

**Usage example:**
./master_workflow.sh [-f] [-p] [-c] [-i] [-o] [-a] <subject_id1> <subject_id2> ... <subject_idN>

---

## Pipeline Steps

### 1. **`feat_contrasts_recover_cluster.sh`:**  
   - Runs FSL FEAT analysis (GLM test) with the specified design matrix and configurations.

### 2. **`run_permutation_test_cluster.sh`:**  
   - Runs randomize permutation testing with time series data.
     
### 3. **`ica_corr.py`:**
   - Runs ICA analysis on time-series data. Temporal correlation with task regressor and spatial orrelation with GLM zstat
  
### 4. **`cal_post_stats_thresh.sh`:**  
   - Calculates quantitative post-statistics and thresholding based on the outputs from previous steps. Generates a summary CSV file with quantitative results for each subject, task, ROI, and threshold.
4.1 **Thresholding statistical maps:**  
  - Applies cluster thresholding to Z-stat maps at Z=3.1 and Z=2.35.
  - Thresholds TFCE (Threshold-Free Cluster Enhancement) corrected p-value maps at 1-p ≥ 0.95 (p ≤ 0.05).<br>
 4.2 **Splitting and transforming results:**  
  - Splits statistical maps (Z-stats and TFCE) into left and right hemispheres in MNI space.
  - Applies inverse transforms to bring thresholded and unthresholded maps from standard (MNI) space back into each subject’s native T1w space using ANTs.<br>
 4.3 **Quantitative calculations**  
  - For each threshold and task seq, calculates:
    - The total number of voxels in the ROI and whole-brain.
    - The number and percentage of suprathreshold voxels in the ROI and whole-brain.
      percentage = (number of suprathreshold voxels in region) / (total number of voxels in region) * 100
      For example, to calculate the percentage of suprathreshold voxels in an ROI:
     - First, count the total number of voxels in the ROI mask.
     - Next, count the number of voxels in the thresholded map that also fall within the ROI.
     - Divide the suprathreshold voxel count by the total ROI voxel count, then multiply by 100.
    - Overlap between Z-stat and TFCE thresholded maps.
    - Dice coefficients and coverage metrics to quantify spatial overlap.<br>

5. **`output_generator.py`:**  
   - Calls `data_processor.py` and uses `html_template.py`.
   - Processes and combines results and plots.  
   - Generates an HTML report with visualizations for easier diagnosis and reporting.

---

## Outputs

For both FEAT GLM tests and Randomize Permutation tests:
- **Excel sheets** Save all the calculation results from cal_post_stats_thresh.sh
- **Tables:** Show the number and percentage of suprathresholded voxels in ROIs and the whole brain.
- **Thresholded Z-maps:** In native space, obtained from FSL FEAT analysis.
- **HTML Viewer (+ PDF):** Includes:
  - Tables and plots mentioned above.
  - Interactive brain viewer for physicians to diagnose and report results.
  - ICA results.
