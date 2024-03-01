#!/usr/bin/python3
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
import subprocess
import os
import magic

app = FastAPI()

# HTML form for file upload
html_form = """
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>File Upload and Processing</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            background-color: #f5f5f5;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
        }

        #upload-container {
            background-color: #ffffff;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }

        h1 {
            color: #333333;
        }

        form {
            margin-top: 20px;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        input[type="file"] {
            margin-bottom: 10px;
        }

        input[type="button"] {
            background-color: #4caf50;
            color: white;
            border: none;
            padding: 10px 20px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            cursor: pointer;
            border-radius: 4px;
        }

        #result-container {
            margin-top: 20px;
        }

        #loading-indicator {
            display: none;
            margin-top: 20px;
        }
    </style>
</head>

<body>
    <div id="upload-container">
        <h1>File Upload and Processing</h1>
        <form id="upload-form" enctype="multipart/form-data" method="post">
            <input type="file" id="file" accept="video/*,audio/*,text/*" required>
            <br>
            <label for="convert_to">Choose file type:</label>
            <input type="radio" id="video" name="convert_to" value="video" checked>
            <label for="video">Video</label>
            <input type="radio" id="audio" name="convert_to" value="audio">
            <label for="audio">Audio</label>
            <input type="radio" id="text" name="convert_to" value="text">
            <label for="text">Text</label>
            <br>
            <input type="button" value="Upload" onclick="uploadFile()">
            <div id="loading-indicator">Loading...</div>
        </form>

        <div id="result-container"></div>
    </div>

    <script>
        async function uploadFile() {
            const fileInput = document.getElementById('file');
            const file = fileInput.files[0];
            const fileType = document.querySelector('input[name="convert_to"]:checked').value;

            const formData = new FormData();
            formData.append('file', file);
            formData.append('convert_to', fileType);

            // Show loading indicator
            const loadingIndicator = document.getElementById('loading-indicator');
            loadingIndicator.style.display = 'block';

            try {
                const response = await fetch('/upload', {
                    method: 'POST',
                    body: formData
                });

                const result = await response.json();
                document.getElementById('result-container').innerHTML = JSON.stringify(result, null, 2);
            } catch (error) {
                console.error('Error uploading file:', error);
            } finally {
                // Hide loading indicator after response or error
                loadingIndicator.style.display = 'none';
            }
        }
    </script>
</body>

</html>

"""

@app.get("/")
async def read_root():
    return HTMLResponse(content=html_form, status_code=200)

def get_mime_type(file: UploadFile):
    mime = magic.Magic()
    mime_type = mime.from_buffer(file.file.read(1024))
    return mime_type

@app.post("/upload")
async def create_upload_file(file: UploadFile = File(...), convert_to: str = Form(...)):
    # Validate file size
    max_file_size = 100 * 1024 * 1024  # 100MB
    if file.file.__sizeof__() > max_file_size:
        raise HTTPException(status_code=400, detail="File size exceeds the limit of 100MB")

    # Check the file type
    mime_type = get_mime_type(file)
    print(f"Detected MIME type: {mime_type}")

    # Save the uploaded file to a temporary location
    with open(file.filename, "wb") as f:
        f.write(file.file.read())

    # Continue with the processing logic
    # Run the post-treatment Bash script
    logs = subprocess.run(["bash", "addfile.sh", file.filename, mime_type, convert_to], capture_output=True, text=True).stdout

    # Optionally, you can remove the temporary file
    os.remove(file.filename)

    return JSONResponse(content={"filename": file.filename, "mime_type": mime_type, "convert_to": convert_to, "message": "File processed successfully.", "logs": logs})

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=10101)
