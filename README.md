# Task-based_fMRI_pipeline created for RECOVER project by K. Nguyen and Q. Wu, Mar 2025
Adapted from MGH protocol and used for detecting consciousness of coma patients

# Input are selected from fmriprep output including 
1) Functional BOLD images (nifti) from tasks (two motor tasks and one language task), 
2) Structural T1w images in native and standard MNI space, brain masks of skull-stripped T1, and trasnformation matrix in h5 files, 
3) Design matrix setting up for FSl FEAT analysis,
4) ROIs for Motor and Language Tasks.

# Run master_workflow.sh calling all the steps of the pipeline \
master_workflow.sh: Orchestrates the RECOVER fMRI pipeline \
Accepts subject IDs as command-line arguments with options to run specific steps or all.
Options: -f (FEAT stats), -c (calculate post-stats), -o (generate output pdf+html), -a (all steps)
1. feat_contrasts_recover_cluster.sh
- run FSL FEAT analysis with specified designed matrix and configurations
3. cal_post_stats_thresh.sh
- Calculate quantitative measurements based on the output of previous step
2. output_generator.py
- calls data_processor.py and uses html_template.py
- process and combine results and plots. Generate html with visualization, easier for physicians to diagnose and report results

# Outputs include 
1) Table showing the number and percentage of suprathresholded voxels in ROIs and Whole Brain,
2) Thresholded Z-maps in native space obtained from FSL FEAT analysis, 
3) HTML viewer (+pdf) for physicians including table and plots obtained above and interactive brain viewer. 
