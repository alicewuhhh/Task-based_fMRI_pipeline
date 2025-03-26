# Task-based_fMRI_pipeline created for RECOVER project by K. Nguyen and A. Wu, Mar 2025
Introduced two testing methods: 1) permutation testing with threshold-free clustering enhancement method; 2) GLM testing adapted from MGH protocol. The goal is to explore new methods to improve exisiting methods in diagnosing/detecting consciousness of coma patients

# Inputs are selected from fmriprep output, including 
1) Functional BOLD images (nifti) from tasks (two motor tasks and one language task), 
2) Structural T1w images in native and standard MNI space, brain masks of skull-stripped T1, and trasnformation matrix in h5 files, 
3) Design matrix setting up for FSl FEAT analysis,
4) ROIs for Motor and Language Tasks.

# Run master_workflow.sh calling all the steps of the pipeline 
master_workflow.sh: Orchestrates the RECOVER fMRI pipeline and accepts subject IDs as command-line arguments with options to run specific steps or all.
 Options: -f (FEAT stats), -p (randomise permutation testing), -c (calculate post-stats),  -o (generate output pdf+html), -a (all steps)

1. feat_contrasts_recover_cluster.sh
- runs FSL FEAT analysis (GLM test) with specified designed matrix and configurations
2. run_permutation_test_cluster.sh
- runs randomise permutation testing with time series data
3. cal_post_stats_thresh.sh
- calculates quantitative measurements based on the output of previous step
4. output_generator.py
- calls data_processor.py and uses html_template.py
- process and combine results and plots. Generate html with visualization, easier for physicians to diagnose and report results

usage() {
    echo "Usage: $0 [-f] [-p] [-c] [-o] [-a] <subject_id1> <subject_id2> ... <subject_idN>"
    echo "Options:"
    echo "  -f    Run only feat_contrasts_recover_cluster.sh (FEAT stats)"
    echo "  -p    Run only randomise permutation testing"
    echo "  -c    Run only calc_post_stats_thresh.sh (calculate post-stats)"
    echo "  -o    Run only output_generator.py (generate output pdf+html)"
    echo "  -a    Run all steps (default if no options specified)"
    exit 1
}
# Outputs include 
For FEAT GLM test and Randomise Permutation test:
1) Table showing the number and percentage of suprathresholded voxels in ROIs and Whole Brain,
2) Thresholded Z-maps in native space obtained from FSL FEAT analysis, 
3) HTML viewer (+pdf) for physicians including table and plots obtained above and interactive brain viewer. 


