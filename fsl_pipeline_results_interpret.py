import pandas as pd
import numpy as np
import os
import logging
import plotly.express as px
from bokeh.plotting import figure, show
from bokeh.layouts import row
from bokeh.models import ColumnDataSource, FactorRange,HoverTool
from bokeh.transform import factor_cmap  # Correct Bokeh import for color mapping
from bokeh.io import output_file
import seaborn as sns
import matplotlib.pyplot as plt

# Define paths and groups
base_dir = "/Volumes/WILL_STUFF/RECOVER/fsl_pipeline/derivatives"
group_control = ["realUPN042", "UPN044", "UPN046correct", "UPN054"] 
group_patient = ["UPN037USB", "UPN038", "UPN039","UPN041", "UPN050", "UPN051", "UPN053", "UPN055"] 
tasks = ["motor_run-01", "motor_run-02", "lang"]
task_labels = ['Motor 1', 'Motor 2', 'Lang']  # Human-readable labels
thresholds = [2.35, 3.1]

# Load combined data
combined_data=pd.read_csv(os.path.join(base_dir, "combined_data.csv"))
data_native = combined_data[combined_data['Space']=='Native']

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Assign unique colors to each subject
subjects = group_control + group_patient
color_map = px.colors.qualitative.Plotly  # Use Plotly's qualitative color palette
subject_colors = {subject: color_map[i % len(color_map)] for i, subject in enumerate(subjects)}

# Calculate number of subjects and average
n_control = len(group_control)
n_patient = len(group_patient)
avg_subjects = (n_control + n_patient) / 2

# Define colors for metrics and groups
metric_colors = {
    'Activated Voxels within ROI (%)': '#ff7f0e',  # Orange
    'Activated ROI/Activated WB (%)': '#d62728'    # Red
}
group_colors = {
    'Control': {'light': '#aec7e8', 'dark': '#1f77b4'} ,  # Warm: Light red, dark blue
    'Patient': {'light': '#ff9896', 'dark': '#d62728'}   # Cold: Light blue, dark red
}

# Interactive Visualization 3: Bokeh Bar Plot with Scatter (Fixed)
plots = []
for task, task_label in zip(tasks, task_labels):
    task_data = data_native[data_native['Task'] == task]
    rois = task_data['ROI'].unique()
    groups = ['Control', 'Patient']
    metrics = ['Activated Voxels within ROI (%)', 'Activated ROI/Activated WB (%)']

    # Create factors for x-axis (ROI, Group, Metric)
    factors = [(roi, group, metric) for roi in rois for group in groups for metric in metrics]
    source = ColumnDataSource(data=dict(
        x=factors,
        y=[task_data[(task_data['ROI'] == roi) & (task_data['Group'] == group)][metric].mean() 
           for roi in rois for group in groups for metric in metrics],
        group=[group for roi in rois for group in groups for metric in metrics],
        metric=[metric for roi in rois for group in groups for metric in metrics]
    ))

    # Create a figure
    p = figure(x_range=FactorRange(*factors), height=500, width=600, title=task_label,
               toolbar_location=None, tools="")
    # Add hover tool for bars
    bar_hover = HoverTool(tooltips=[
        ("Group", "@group"),
        ("Metric", "@metric"),
        ("ROI", "@roi"),
        ("Value", "@y{0.2f}%")
    ])
    p.add_tools(bar_hover)

    # Plot bars with factor_cmap for coloring by group
    p.vbar(x='x', top='y', width=0.9, source=source,
           fill_color=factor_cmap('group', palette=['#aec7e8','#ff9896'], factors=groups),
           line_color='white')

    # Plot individual data points
    for subject in task_data['Subject'].unique():
        subject_data = task_data[task_data['Subject'] == subject]
        group = subject_data['Group'].iloc[0]
        color = subject_colors[subject]
        for idx, metric in enumerate(metrics):
            factors_subject = [(roi, group, metric) for roi in subject_data['ROI']]
            values = subject_data[metric].values
            rois_subject = subject_data['ROI'].values

            # Create a ColumnDataSource for the scatter points
            source_points = ColumnDataSource(data=dict(
                x=factors_subject,
                y=values,
                subject=[subject] * len(values),
                group=[group] * len(values),
                metric=[metric] * len(values),
                roi=rois_subject
            ))

            # Plot scatter points
            p.scatter(x='x', y='y', size=7, color=color, source=source_points)
            # Add hover tool for scatter points
            point_hover = HoverTool(tooltips=[
                ("Subject", "@subject"),
                ("Group", "@group"),
                ("Metric", "@metric"),
                ("ROI", "@roi"),
                ("Value", "@y{0.2f}%")
            ])
            p.add_tools(point_hover)

    # Customize plot
    p.xaxis.major_label_orientation = 45
    p.yaxis.axis_label = "Percentage (%)"
    # p.legend.location = "top_center"
    # p.legend.orientation = "horizontal"
    plots.append(p)

# Show and save
output_file(os.path.join(base_dir, "group_comparison_MNI_Z31_bokeh_interactive.html"))
show(row(plots))
print(f"Interactive plot saved to {os.path.join(base_dir, 'group_comparison_MNI_Z31_bokeh_interactive.html')}")



## Non-Interactive Visualization 3: Matplotlib Box Plot with Strip Plot (Transparent Boxes)
# Create a 2x3 subplot grid (two rows for two variables, three columns for three tasks)
plt.figure(figsize=(18, 10))  # Wider and taller for better readability

# Plot for the first variable: Activated Voxels within ROI (%)
for i, (task, task_label) in enumerate(zip(tasks, task_labels)):
    ax = plt.subplot(2, 3, i + 1)  # Row 1: Columns 1, 2, 3
    task_data = data_native[data_native['Task'] == task]

    sns.boxplot(data=task_data, x='ROI', y='Activated Voxels within ROI (%)', hue='Group',
                palette={'Control': group_colors['Control']['light'], 'Patient': group_colors['Patient']['dark']}, 
                ax=ax, boxprops=dict(alpha=0.3))
    sns.stripplot(data=task_data, x='ROI', y='Activated Voxels within ROI (%)', hue='Group',
                  palette={'Control': group_colors['Control']['dark'], 'Patient': group_colors['Patient']['dark']}, 
                  ax=ax, dodge=True, size=5,legend=False)

    ax.set_title(task_label)
    ax.set_ylabel("Activated Voxels within ROI (%)")  # Added y-axis label
    ax.set_xlabel("ROI")
    ax.tick_params(axis='x', rotation=45)

# Plot for the second variable: Activated ROI/Activated WB (%)
for i, (task, task_label) in enumerate(zip(tasks, task_labels)):
    ax = plt.subplot(2, 3, i + 4)  # Row 2: Columns 1, 2, 3 (offset by 3)
    task_data = data_native[data_native['Task'] == task]

    sns.boxplot(data=task_data, x='ROI', y='Activated ROI/Activated WB (%)', hue='Group',
                palette={'Control': group_colors['Control']['light'], 'Patient': group_colors['Patient']['dark']}, 
                ax=ax, boxprops=dict(alpha=0.3))
    sns.stripplot(data=task_data, x='ROI', y='Activated ROI/Activated WB (%)', hue='Group',
                  palette={'Control': group_colors['Control']['dark'], 'Patient': group_colors['Patient']['dark']}, 
                  ax=ax, dodge=True, size=5,legend=False)

    ax.set_title(task_label)
    ax.set_ylabel("Activated ROI/Activated WB (%)")  # Added y-axis label
    ax.set_xlabel("ROI")
    ax.tick_params(axis='x', rotation=45)

# Add suptitle with subject information
plt.suptitle(f"Percentage of Supra-thresholded Voxels within ROI (first row)\nPercentage of Supra-thresholded Voxels in ROI out of Supra. in Whole Brain (second row) \nNumber of Subjects - Control: {n_control}, Patient: {n_patient}, Average: {avg_subjects:.1f}")
plt.tight_layout(rect=[0, 0, 1, 0.95])  # Adjust layout to accommodate suptitle
save_path = os.path.join(base_dir, "group_comparison_native_Z31_box_static.png")
plt.savefig(save_path, dpi=300, bbox_inches='tight')
plt.show()





# Function to load and aggregate data for a group
def load_group_data(subjects, space):
    all_data = []
    for subject in subjects:
        for task in tasks:
            print(f"Loading data for {subject} - {task} - {space}")
            csv_path = os.path.join(base_dir, f"sub-{subject}/ses-01/post_stats",
                                   f"sub-{subject}_task-{task}_roi_stats.csv")
            if os.path.exists(csv_path):
                df = pd.read_csv(csv_path)
                df = df[df['Threshold']=='Z=3.1']
                df = df[df['Space']==space]
                df['Group'] = "Control" if subject in group_control else "Patient"
                all_data.append(df)
    return pd.concat(all_data, ignore_index=True)

# Load data for both space
# data_MNI = load_group_data(group_control + group_patient, 'MNI')
# data_native = load_group_data(group_control + group_patient, 'Native')

# # # Combine data
# combined_data = pd.concat([data_MNI, data_native], ignore_index=True)
# save_path = os.path.join(base_dir, "combined_data.csv")
# combined_data.to_csv(save_path, index=False)
