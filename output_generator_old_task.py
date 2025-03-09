#!/opt/anaconda3/bin/python
# Python 3.8.20
# output_generator.py: Simplified and optimized functions to generate PDF and HTML reports

import os
import sys
import logging
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import base64
from io import BytesIO
from html_template import HTML_TEMPLATE

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Paths

class OutputGenerator:
    def __init__(self, subject, path_img):
        self.subject = subject
        self.path_img = path_img
        self.subject_path = os.path.join(path_img, f"derivatives/sub-{subject}/ses-01")
        self.output_dir = os.path.join(self.subject_path, "post_stats")
        os.makedirs(self.output_dir, exist_ok=True)  # Ensure directory exists once here
        logging.info(f"Initializing OutputGenerator for subject {subject}")

    def _fig_to_base64(self, fig):
        """Convert a matplotlib figure to base64-encoded PNG string efficiently."""
        if not fig:
            return ""
        with BytesIO() as buf:
            fig.savefig(buf, format='png', dpi=150, bbox_inches='tight')
            buf.seek(0)
            img_str = base64.b64encode(buf.getvalue()).decode('utf-8')
        plt.close(fig)  # Close figure immediately after saving
        return img_str
    
    def _save_pdf(self, data):
        """Generate and save PDF report with all figures."""
        pdf_path = os.path.join(self.output_dir, f"sub-{self.subject}_task_pipeline_report.pdf")
        fig_keys = [
            'native_roi_fig_31', 'native_table_fig_31',
            'native_roi_fig_235', 'native_table_fig_235',
            'mni_roi_fig_31', 'mni_table_fig_31',
            'mni_roi_fig_235', 'mni_table_fig_235'
        ]

        fig_keys_pdf = [
            'native_table_fig_31','native_roi_fig_31',
            'native_table_fig_235','native_roi_fig_235', 
            'mni_table_fig_31','mni_roi_fig_31',
            'mni_table_fig_235','mni_roi_fig_235'
        ]

        with PdfPages(pdf_path) as pdf:
            # Cover page
            fig, ax = plt.subplots(figsize=(10, 2))
            ax.text(0.5, 0.5, f"Task-Based fMRI Report for {self.subject}", ha='center', va='center', fontsize=14)
            ax.axis('off')
            pdf.savefig(fig, dpi=300, bbox_inches='tight')
            plt.close(fig)

            # Save all figures
            for key in fig_keys_pdf:
                if key in data and data[key]:
                    pdf.savefig(data[key], dpi=300, bbox_inches='tight')
        logging.info(f"Combined PDF saved at: {pdf_path}")
        return pdf_path

    def _save_html(self, data):
        """Generate and save HTML report with embedded images and viewer links."""
        html_path = os.path.join(self.output_dir, f"sub-{self.subject}_task_pipeline_report.html")
        viewer_dir = os.path.join(self.output_dir, "viewers")
        os.makedirs(viewer_dir, exist_ok=True)

        # Convert figures to base64 efficiently
        img_data = {
            'native_roi_img_31': self._fig_to_base64(data.get('native_roi_fig_31')),
            'native_roi_img_235': self._fig_to_base64(data.get('native_roi_fig_235')),
            'native_table_img_31': self._fig_to_base64(data.get('native_table_fig_31')),
            'native_table_img_235': self._fig_to_base64(data.get('native_table_fig_235')),
            'mni_roi_img_31': self._fig_to_base64(data.get('mni_roi_fig_31')),
            'mni_roi_img_235': self._fig_to_base64(data.get('mni_roi_fig_235')),
            'mni_table_img_31': self._fig_to_base64(data.get('mni_table_fig_31')),
            'mni_table_img_235': self._fig_to_base64(data.get('mni_table_fig_235')),
        }

        # Save viewers and prepare relative paths
        viewer_paths = {}
        tasks = ['Motor 1', 'Motor 2', 'Language']
        
        # Save viewers for Z=3.1
        native_viewers_31 = data.get('native_viewers_31', {})
        for task in tasks:
            viewer_key = f"native_viewer_31_{task.lower().replace(' ', '_')}"
            viewer_file = f"native_{task.lower().replace(' ', '_')}_z31_viewer.html"
            viewer_paths[viewer_key] = os.path.join("viewers", viewer_file)
            if task in native_viewers_31:
                native_viewers_31[task].save_as_html(os.path.join(viewer_dir, viewer_file))

        # Save viewers for Z=2.35
        native_viewers_235 = data.get('native_viewers_235', {})
        for task in tasks:
            viewer_key = f"native_viewer_235_{task.lower().replace(' ', '_')}"
            viewer_file = f"native_{task.lower().replace(' ', '_')}_z235_viewer.html"
            viewer_paths[viewer_key] = os.path.join("viewers", viewer_file)
            if task in native_viewers_235:
                native_viewers_235[task].save_as_html(os.path.join(viewer_dir, viewer_file))

        # Generate HTML content
        html_content = HTML_TEMPLATE.format(
            subject=self.subject,
            **img_data,
            native_viewer_31_motor1=viewer_paths.get('native_viewer_31_motor_1', ''),
            native_viewer_31_motor2=viewer_paths.get('native_viewer_31_motor_2', ''),
            native_viewer_31_language=viewer_paths.get('native_viewer_31_language', ''),
            native_viewer_235_motor1=viewer_paths.get('native_viewer_235_motor_1', ''),
            native_viewer_235_motor2=viewer_paths.get('native_viewer_235_motor_2', ''),
            native_viewer_235_language=viewer_paths.get('native_viewer_235_language', ''),
        )

        with open(html_path, 'w') as f:
            f.write(html_content)
        logging.info(f"Combined HTML saved at: {html_path}")
        return html_path

    def generate_output(self, data):
        """Generate PDF and HTML outputs for the subject."""
        logging.info(f"Generating output for subject {self.subject}")
        try:
            self._save_pdf(data)
            self._save_html(data)
        except Exception as e:
            logging.error(f"Error generating output for subject {self.subject}: {str(e)}")
            raise

def main(subjects):
    logging.info("Starting main execution")
    path_img = os.environ.get('ARCHIVEDIR')
    roi_path = os.environ.get('ROI')
    from data_processor_old_task import DataProcessor

    for subject in subjects:
        logging.info(f"Processing subject: {subject}")
        data_processor = DataProcessor(subject, path_img, roi_path)
        data = data_processor.process_data()
        output_generator = OutputGenerator(subject, path_img)
        output_generator.generate_output(data)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        logging.error("No subject IDs provided. Usage: python output_generator.py <subject_id1> <subject_id2> ...")
        sys.exit(1)
    subjects = sys.argv[1:]
    main(subjects)