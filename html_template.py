# html_template.py: Updated HTML template for output_generator.py

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>{subject} Task-Based fMRI Report</title>
    <style>
        .space-tab {{
            overflow: hidden;
            border: 1px solid #ccc;
            background-color: #f1f1f1;
        }}
        .space-tab button {{
            background-color: inherit;
            float: left;
            border: none;
            outline: none;
            cursor: pointer;
            padding: 14px 16px;
            transition: 0.3s;
        }}
        .space-tab button:hover {{
            background-color: #ddd;
        }}
        .space-tab button.active {{
            background-color: #ccc;
        }}
        .space-tabcontent {{
            display: none;
            padding: 6px 12px;
            border: 1px solid #ccc;
            border-top: none;
        }}
        .thresh-tab {{
            overflow: hidden;
            background-color: #e9ecef;
        }}
        .thresh-tab button {{
            background-color: inherit;
            float: left;
            border: none;
            outline: none;
            cursor: pointer;
            padding: 10px 12px;
            transition: 0.3s;
        }}
        .thresh-tab button:hover {{
            background-color: #ced4da;
        }}
        .thresh-tab button.active {{
            background-color: #adb5bd;
        }}
        .thresh-tabcontent {{
            display: none;
            padding: 6px 12px;
        }}
        img {{
            max-width: 90%;
            height: auto;
        }}
        .viewer {{
            width: 100%;
            height: 400px;
            border: none;
        }}
    </style>
</head>
<body>
    <h1>{subject} Task-Based fMRI Report</h1>
    <div class="space-tab">
        <button class="space-tablinks" onclick="openSpaceTab(event, 'Native')" id="defaultSpaceOpen">Native Space</button>
        <button class="space-tablinks" onclick="openSpaceTab(event, 'MNI')">MNI Space</button>
    </div>

    <!-- Native Space Content -->
    <div id="Native" class="space-tabcontent">
        <div class="thresh-tab">
            <button class="thresh-tablinks" onclick="openThreshTab(event, 'Native_31', 'Native')" id="defaultThreshNative">Cluster-Threshold Z=3.1</button>
            <button class="thresh-tablinks" onclick="openThreshTab(event, 'Native_235', 'Native')">Cluster-Threshold Z=2.35</button>
        </div>
        <div id="Native_31" class="thresh-tabcontent">
            <h2>Z-Maps with ROI Outlines (Native Space, Z=3.1)</h2>
            <img src="data:image/png;base64,{native_roi_img_31}" alt="Native ROI Plot Z=3.1">
            <h2>ROI Statistics Table (Native Space, Z=3.1)</h2>
            <img src="data:image/png;base64,{native_table_img_31}" alt="Native Table Plot Z=3.1">
            <h2>Interactive Brain Viewer (Native Space, Z=3.1)</h2>
            <h3>Motor 1</h3>
            <iframe src="{native_viewer_31_motor1}" class="viewer"></iframe>
            <p><a href="{native_viewer_31_motor1}" target="_blank">Open Motor 1 Z=3.1 Viewer in New Tab</a></p>
            <h3>Motor 2</h3>
            <iframe src="{native_viewer_31_motor2}" class="viewer"></iframe>
            <p><a href="{native_viewer_31_motor2}" target="_blank">Open Motor 2 Z=3.1 Viewer in New Tab</a></p>
            <h3>Language</h3>
            <iframe src="{native_viewer_31_language}" class="viewer"></iframe>
            <p><a href="{native_viewer_31_language}" target="_blank">Open Language Z=3.1 Viewer in New Tab</a></p>
        </div>
        <div id="Native_235" class="thresh-tabcontent">
            <h2>Z-Maps with ROI Outlines (Native Space, Z=2.35)</h2>
            <img src="data:image/png;base64,{native_roi_img_235}" alt="Native ROI Plot Z=2.35">
            <h2>ROI Statistics Table (Native Space, Z=2.35)</h2>
            <img src="data:image/png;base64,{native_table_img_235}" alt="Native Table Plot Z=2.35">
            <h2>Interactive Brain Viewer (Native Space, Z=2.35)</h2>
            <h3>Motor 1</h3>
            <iframe src="{native_viewer_235_motor1}" class="viewer"></iframe>
            <p><a href="{native_viewer_235_motor1}" target="_blank">Open Motor 1 Z=2.35 Viewer in New Tab</a></p>
            <h3>Motor 2</h3>
            <iframe src="{native_viewer_235_motor2}" class="viewer"></iframe>
            <p><a href="{native_viewer_235_motor2}" target="_blank">Open Motor 2 Z=2.35 Viewer in New Tab</a></p>
            <h3>Language</h3>
            <iframe src="{native_viewer_235_language}" class="viewer"></iframe>
            <p><a href="{native_viewer_235_language}" target="_blank">Open Language Z=2.35 Viewer in New Tab</a></p>
        </div>
    </div>

    <!-- MNI Space Content -->
    <div id="MNI" class="space-tabcontent">
        <div class="thresh-tab">
            <button class="thresh-tablinks" onclick="openThreshTab(event, 'MNI_31', 'MNI')" id="defaultThreshMNI">Cluster-Threshold Z=3.1</button>
            <button class="thresh-tablinks" onclick="openThreshTab(event, 'MNI_235', 'MNI')">Cluster-Threshold Z=2.35</button>
        </div>
        <div id="MNI_31" class="thresh-tabcontent">
            <h2>Z-Maps with ROI Outlines (MNI Space, Z=3.1)</h2>
            <img src="data:image/png;base64,{mni_roi_img_31}" alt="MNI ROI Plot Z=3.1">
            <h2>ROI Statistics Table (MNI Space, Z=3.1)</h2>
            <img src="data:image/png;base64,{mni_table_img_31}" alt="MNI Table Plot Z=3.1">
        </div>
        <div id="MNI_235" class="thresh-tabcontent">
            <h2>Z-Maps with ROI Outlines (MNI Space, Z=2.35)</h2>
            <img src="data:image/png;base64,{mni_roi_img_235}" alt="MNI ROI Plot Z=2.35">
            <h2>ROI Statistics Table (MNI Space, Z=2.35)</h2>
            <img src="data:image/png;base64,{mni_table_img_235}" alt="MNI Table Plot Z=2.35">
        </div>
    </div>

    <script>
        function openSpaceTab(evt, spaceName) {{
            var i, spaceTabcontent, spaceTablinks;
            spaceTabcontent = document.getElementsByClassName("space-tabcontent");
            for (i = 0; i < spaceTabcontent.length; i++) {{
                spaceTabcontent[i].style.display = "none";
            }}
            spaceTablinks = document.getElementsByClassName("space-tablinks");
            for (i = 0; i < spaceTablinks.length; i++) {{
                spaceTablinks[i].className = spaceTablinks[i].className.replace(" active", "");
            }}
            document.getElementById(spaceName).style.display = "block";
            evt.currentTarget.className += " active";
            document.getElementById("defaultThresh" + spaceName).click();
        }}

        function openThreshTab(evt, threshName, spaceName) {{
            var i, threshTabcontent, threshTablinks;
            threshTabcontent = document.getElementsByClassName("thresh-tabcontent");
            for (i = 0; i < threshTabcontent.length; i++) {{
                if (threshTabcontent[i].parentElement.id === spaceName) {{
                    threshTabcontent[i].style.display = "none";
                }}
            }}
            threshTablinks = document.getElementsByClassName("thresh-tablinks");
            for (i = 0; i < threshTablinks.length; i++) {{
                if (threshTablinks[i].parentElement.parentElement.id === spaceName) {{
                    threshTablinks[i].className = threshTablinks[i].className.replace(" active", "");
                }}
            }}
            document.getElementById(threshName).style.display = "block";
            evt.currentTarget.className += " active";
        }}

        document.getElementById("defaultSpaceOpen").click();
    </script>
</body>
</html>
"""