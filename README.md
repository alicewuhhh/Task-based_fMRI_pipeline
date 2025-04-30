# Task-based_fMRI_pipeline created for RECOVER project by K. Nguyen and A. Wu, Mar 2025
Implemented two testing methods: 1) GLM testing adapted from MGH protocol. The goal is to explore new methods to improve exisiting methods in diagnosing/detecting consciousness of coma patients; <br> 
2) Permutation testing with threshold-free clustering enhancement method

# Inputs are selected from fmriprep output, including 
fMRIPrep version: 23.0.1 <br>
__fMRIPrep command__: /opt/conda/bin/fmriprep /flywheel/v0/work/bids /flywheel/v0/output/67b747ac81e8158d3b6ad2c6 participant --aroma-melodic-dimensionality=-200 --bold2t1w-dof=6 --bold2t1w-init=register --dvars-spike-threshold=1.5 --fd-spike-threshold=0.5 --n_cpus=2 --omp-nthreads=2 --output-spaces=MNI152NLin6Asym --skull-strip-t1w=force --skull-strip-template=OASIS30ANTs --use-aroma --mem=12203 <br>
__Inputs__:
1) Functional BOLD images (nifti) from tasks (two motor tasks and one language task), 
2) Structural T1w images in native and standard MNI space, brain masks of skull-stripped T1, and trasnformation matrix in h5 files, 
3) Design template for FSl FEAT analysis (design_test_script.fsf),
4) ROIs for Motor (SMA+PMC) and Language Tasks (STG, Heschl).

# Run master_workflow.sh calling all the steps of the pipeline 
master_workflow.sh: Orchestrates the RECOVER fMRI pipeline and accepts subject IDs as command-line arguments with options to run specific steps or all.
 Options: -f (FEAT stats), -p (randomise permutation testing), -c (calculate post-stats), -o (generate output pdf+html), -a (all steps)

1. feat_contrasts_recover_cluster.sh
- runs FSL FEAT analysis (GLM test) with specified designed matrix and configurations
2. run_permutation_test_cluster.sh
- runs randomise permutation testing with time series data
3. cal_post_stats_thresh.sh
- calculates quantitative measurements based on the output of previous step
4. output_generator.py
- calls __data_processor.py__ and uses __html_template.py__
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


