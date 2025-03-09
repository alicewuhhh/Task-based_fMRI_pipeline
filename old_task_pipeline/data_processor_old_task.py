#!/opt/anaconda3/bin/python
# Python 3.8.20
# data_processor.py: Functions to get values and save in plots and tables

import os
from nilearn import plotting
import logging
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class DataProcessor:
    def __init__(self, subject, path_img, roi_path):
        self.subject = subject
        self.path_img = path_img
        self.roi_path = roi_path
        self.subject_path = os.path.join(path_img, f"derivatives/sub-{subject}/ses-01")
        self.t1_native = os.path.join(self.subject_path, f"anat/sub-{subject}_ses-BRAINxRESEARCHxFISCHER_run-1_desc-brain_T1w.nii.gz")  # Native skull-stripped T1w
        self.t1_mni = os.path.join(self.subject_path, f"anat/sub-{subject}_ses-BRAINxRESEARCHxFISCHER_run-1_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii.gz")  # Standard MNI space
        
        # Define cut_coords for Native space
        self.native_motor_coords = np.linspace(15, 50, 10)
        self.native_stg_coords = np.linspace(-25, 15, 10)
        
        # Define cut_coords for MNI space
        self.mni_motor_coords = np.linspace(20, 75, 10)
        self.mni_stg_coords = np.linspace(-15, 40, 10)
        
        logging.info(f"Initializing DataProcessor for subject {subject}")
        self.task_roi_mapping = self._create_task_roi_mapping()

    def _create_task_roi_mapping(self):
        return {
            'Motor 1': {
                'Native': {
                    'z_map': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-1_contrasts.feat/stats/zstat1_native.nii.gz"),
                    'thresh_z_map_235': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-1_contrasts.feat/stats/thresh_zstat1_235_native.nii.gz"),
                    'thresh_z_map_31': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-1_contrasts.feat/thresh_zstat1_native.nii.gz"),
                    'roi_paths': {
                        'Whole-brain SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_t1w_native.nii.gz"),
                        'Left SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_t1w_native_left.nii.gz"),
                        'Right SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_t1w_native_right.nii.gz")
                    },
                    'csv_file': os.path.join(self.subject_path, f"post_stats/sub-{self.subject}_task-motor_run-1_roi_stats.csv"),
                    'cut_coords': self.native_motor_coords
                },
                'MNI': {
                    'z_map': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-1_contrasts.feat/stats/zstat1.nii.gz"),
                    'thresh_z_map_235': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-1_contrasts.feat/stats/thresh_zstat1_235.nii.gz"),
                    'thresh_z_map_31': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-1_contrasts.feat/thresh_zstat1.nii.gz"),
                    'roi_paths': {
                        'Whole-brain SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub.nii.gz"),
                        'Left SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_left.nii.gz"),
                        'Right SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_right.nii.gz")
                    },
                    'csv_file': os.path.join(self.subject_path, f"post_stats/sub-{self.subject}_task-motor_run-1_roi_stats.csv"),
                    'cut_coords': self.mni_motor_coords
                }
            },
            'Motor 2': {
                'Native': {
                    'z_map': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-2_contrasts.feat/stats/zstat1_native.nii.gz"),
                    'thresh_z_map_235': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-2_contrasts.feat/stats/thresh_zstat1_235_native.nii.gz"),
                    'thresh_z_map_31': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-2_contrasts.feat/thresh_zstat1_native.nii.gz"),
                    'roi_paths': {
                        'Whole-brain SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_t1w_native.nii.gz"),
                        'Left SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_t1w_native_left.nii.gz"),
                        'Right SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_t1w_native_right.nii.gz")
                    },
                    'csv_file': os.path.join(self.subject_path, f"post_stats/sub-{self.subject}_task-motor_run-2_roi_stats.csv"),
                    'cut_coords': self.native_motor_coords
                },
                'MNI': {
                    'z_map': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-2_contrasts.feat/stats/zstat1.nii.gz"),
                    'thresh_z_map_235': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-2_contrasts.feat/stats/thresh_zstat1_235.nii.gz"),
                    'thresh_z_map_31': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-motor_run-2_contrasts.feat/thresh_zstat1.nii.gz"),
                    'roi_paths': {
                        'Whole-brain SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub.nii.gz"),
                        'Left SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_left.nii.gz"),
                        'Right SMA + PMC': os.path.join(self.roi_path, "SMA_PMC_sub_right.nii.gz")
                    },
                    'csv_file': os.path.join(self.subject_path, f"post_stats/sub-{self.subject}_task-motor_run-2_roi_stats.csv"),
                    'cut_coords': self.mni_motor_coords
                }
            },
            'Language': {
                'Native': {
                    'z_map': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-lang_contrasts.feat/stats/zstat1_native.nii.gz"),
                    'thresh_z_map_235': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-lang_contrasts.feat/stats/thresh_zstat1_235_native.nii.gz"),
                    'thresh_z_map_31': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-lang_contrasts.feat/thresh_zstat1_native.nii.gz"),
                    'roi_paths': {
                        "Whole-brain STG + Heschl": os.path.join(self.roi_path, "STG_Heschl_sub_t1w_native.nii.gz"),
                        'Left STG + Heschl': os.path.join(self.roi_path, "STG_Heschl_sub_t1w_native_left.nii.gz"),
                        'Right STG + Heschl': os.path.join(self.roi_path, "STG_Heschl_sub_t1w_native_right.nii.gz")
                    },
                    'csv_file': os.path.join(self.subject_path, f"post_stats/sub-{self.subject}_task-lang_roi_stats.csv"),
                    'cut_coords': self.native_stg_coords
                },
                'MNI': {
                    'z_map': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-lang_contrasts.feat/stats/zstat1.nii.gz"),
                    'thresh_z_map_235': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-lang_contrasts.feat/stats/thresh_zstat1_235.nii.gz"),
                    'thresh_z_map_31': os.path.join(self.subject_path, f"fsl_stats/sub-{self.subject}_task-lang_contrasts.feat/thresh_zstat1.nii.gz"),
                    'roi_paths': {
                        "Whole-brain STG + Heschl": os.path.join(self.roi_path, "STG_Heschl_sub.nii.gz"),
                        'Left STG + Heschl': os.path.join(self.roi_path, "STG_Heschl_sub_left.nii.gz"),
                        'Right STG + Heschl': os.path.join(self.roi_path, "STG_Heschl_sub_right.nii.gz")
                    },
                    'csv_file': os.path.join(self.subject_path, f"post_stats/sub-{self.subject}_task-lang_roi_stats.csv"),
                    'cut_coords': self.mni_stg_coords
                }
            }
        }

    def plot_roi(self, space, threshold=None):
        logging.info(f"Plotting ROI for {space} space with threshold {threshold}")
        bg_img = self.t1_native if space == 'Native' else self.t1_mni 
        task_roi_mapping = self.task_roi_mapping

        fig, axes = plt.subplots(6,1 , figsize=(10, 16))
        for i, (task_name, task_info) in enumerate(task_roi_mapping.items()):
            thresh_235_path = task_info[space]['thresh_z_map_235']
            thresh_31_path = task_info[space]['thresh_z_map_31']
            roi_paths = task_info[space]['roi_paths']
            cut_coords = task_info[space]['cut_coords']
            z_map_path = task_info[space]['z_map'] 
            if threshold == 3.1:
                img_path = thresh_31_path
                thresh_value = 3.1
            elif threshold == 2.35:
                img_path = thresh_235_path
                thresh_value = 2.35
            else:
                raise ValueError("Threshold must be 3.1 or 2.35")

            display1 = plotting.plot_stat_map(
                z_map_path,
                cut_coords=cut_coords,
                display_mode='z',
                vmax=13,
                colorbar=True,
                bg_img=bg_img,
                draw_cross=False,
                axes=axes[2*i])
            
            display2 = plotting.plot_stat_map(
                img_path,
                cut_coords=cut_coords,
                display_mode='z',
                threshold=thresh_value,
                vmax=13,
                colorbar=True,
                bg_img=bg_img,
                draw_cross=False,
                axes=axes[2*i+1])

            for roi_label, roi_path in roi_paths.items():
                display1.add_contours(roi_path, colors='#38cb82', linewidths=0.25)
                display2.add_contours(roi_path, colors='#38cb82', linewidths=0.25)
            
            axes[2*i].set_title(f"{self.subject}: {task_name} (Unthresholded)", fontdict={'fontweight': 'bold', 'fontsize': 10})
            axes[2*i+1].set_title(f"{self.subject}: {task_name} (Thresholded)", fontdict={'fontweight': 'bold', 'fontsize': 10})
        
        png_path = os.path.join(self.subject_path, f"post_stats/sub-{self.subject}_roi_zmap_plot_{space}_{threshold}.png")
        plt.savefig(png_path, dpi=150, bbox_inches='tight')
        logging.info(f"Z-map plot saved as PNG: {png_path}")
        return fig

    def plot_table(self, space, threshold):
        logging.info(f"Generating table for {space} space with threshold {threshold}")
        df_all = pd.DataFrame()
        for task_name, task_info in self.task_roi_mapping.items():
            csv_file = task_info[space]['csv_file']
            if not os.path.exists(csv_file):
                logging.warning(f"CSV file missing: {csv_file}")
                continue
            try:
                df_task = pd.read_csv(csv_file)
                logging.info(f"Loaded {csv_file} with {len(df_task)} rows")
                df_all = pd.concat([df_all, df_task], ignore_index=True)
            except Exception as e:
                logging.error(f"Error reading {csv_file}: {str(e)}")
                continue

        df = df_all[(df_all['Space'] == space) & (df_all['Threshold'] == f"Z={threshold}")]
        logging.info(f"Filtered df has {len(df)} rows for {space} and threshold {threshold}")

        if df.empty:
            logging.warning(f"No data available for {space} space with threshold {threshold}; generating placeholder table")
            fig, ax = plt.subplots(figsize=(10, 5))  # Wider table to match plot width
            ax.text(0.5, 0.5, f"No data available for {space} space (Z={threshold})", 
                    ha='center', va='center', fontsize=10, color='red')
            ax.axis('off')
            png_path = os.path.join(self.subject_path, f"sub-{self.subject}_roi_stats_table_{space}_{threshold}.png")
            plt.annotate(f'Supra-thresholded Voxels in {space} Space (Z={threshold})', xy=(0.5, 0.6), xytext=(0, 5), xycoords='axes fraction', textcoords='offset points', fontsize=15,ha='center', va='bottom')
            plt.savefig(png_path, bbox_inches='tight', dpi=150)
            logging.info(f"Placeholder table saved as PNG: {png_path}")
            return fig, df

        table_df = df[['Task', 'ROI', 'Activated Voxels across Whole Brain (counts)', 
                       'Activated Voxels across Whole Brain (%)', 'Activated Voxels within ROI (counts)', 
                       'Activated Voxels within ROI (%)']]
        table_df['Task']=(['Motor 1', '','', 'Motor 2', '','','Language','',''])
        table_df['ROI']=( ['Whole-brain SMA + PMC', 'Left SMA + PMC', 'Right SMA + PMC',
                                  'Whole-brain SMA + PMC', 'Left SMA + PMC', 'Right SMA + PMC',
                                  'Whole-brain STG + Heschl', 'Left STG + Heschl', 'Right STG + Heschl'])
        
        table_data = table_df.values
        column_labels = [f"{' '.join(label.split(' ')[:2])}\n{' '.join(label.split(' ')[2:])}" if len(label.split(' ')) > 2 else label 
                         for label in table_df.columns]
        
        roi_voxel_counts = df['Voxels in ROI (counts)'].tolist()
        wb_voxel_counts = df['Voxels in Whole Brain (counts)'].unique()[0]  # Assuming consistent across tasks

        fig, ax = plt.subplots(figsize=(10, 5))  # Wider table to match plot width
        table = ax.table(cellText=table_data, colLabels=column_labels, loc='center', cellLoc='center', bbox=[0, 0, 1, 1])
        ax.axis('off')
        table.auto_set_font_size(False)
        table.set_fontsize(8)
        table.auto_set_column_width(col=list(range(len(column_labels))))

        for (row, col), cell in table.get_celld().items():
            if row == 0:
                cell.set_text_props(weight='bold', color='white')
                cell.set_facecolor('#4CAF50')
                cell.set_height(0.1)
            elif row % 3 == 1:
                cell.set_facecolor('#f2f2f2')
            cell.set_height(0.08)
        
        annotation_text = (
            f" Whole-brain voxel counts: {wb_voxel_counts}\n"
            f" ROI voxel counts (order follows table): {', '.join(map(str, roi_voxel_counts))}"
        )
        plt.annotate(annotation_text, xy=(0, 0), xytext=(0, -20), xycoords='axes fraction', textcoords='offset points', fontsize=8)
        plt.suptitle(f"Supra-thresholded Voxels in {space} Space (Z={threshold})", fontweight='bold', fontsize=12)
        png_path = os.path.join(self.subject_path, f"post_stats/sub-{self.subject}_roi_stats_table_{space}_{threshold}.png")
        plt.savefig(png_path, bbox_inches='tight', dpi=150)
        logging.info(f"Table saved as PNG: {png_path}")
        return fig, df

    def process_data(self):
        logging.info(f"Processing data for subject {self.subject}")
        native_roi_fig_31 = self.plot_roi('Native', threshold=3.1)
        native_roi_fig_235 = self.plot_roi('Native', threshold=2.35)
        native_table_fig_31, native_df_31 = self.plot_table('Native', threshold=3.1)
        native_table_fig_235, native_df_235 = self.plot_table('Native', threshold=2.35)
        mni_roi_fig_31 = self.plot_roi('MNI', threshold=3.1)
        mni_roi_fig_235 = self.plot_roi('MNI', threshold=2.35)
        mni_table_fig_31, mni_df_31 = self.plot_table('MNI', threshold=3.1)
        mni_table_fig_235, mni_df_235 = self.plot_table('MNI', threshold=2.35)

        native_viewers_31 = {task: plotting.view_img(task_info['Native']['thresh_z_map_31'], 
                                                     bg_img=self.t1_native, threshold=3.1, title=f"{task} Z=3.1")
                             for task, task_info in self.task_roi_mapping.items()}
        native_viewers_235 = {task: plotting.view_img(task_info['Native']['thresh_z_map_235'], 
                                                bg_img=self.t1_native, threshold=2.35, title=f"{task} Z=2.35")
                        for task, task_info in self.task_roi_mapping.items()}

        return {
            'native_roi_fig_31': native_roi_fig_31,
            'native_roi_fig_235': native_roi_fig_235,
            'native_table_fig_31': native_table_fig_31,
            'native_table_fig_235': native_table_fig_235,
            'mni_roi_fig_31': mni_roi_fig_31,
            'mni_roi_fig_235': mni_roi_fig_235,
            'mni_table_fig_31': mni_table_fig_31,
            'mni_table_fig_235': mni_table_fig_235,
            'native_viewers_31': native_viewers_31,
            'native_viewers_235': native_viewers_235
        }
