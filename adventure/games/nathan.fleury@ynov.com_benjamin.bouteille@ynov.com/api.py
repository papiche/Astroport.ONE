#!/bin/python3
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import whisper

app = FastAPI()

whisper = whisper.load_model("medium.en")

@app.post("/speechToText")
async def speech_to_text(file: UploadFile = File(...)):
    try:
        # Save the uploaded audio file locally
        audio_path = "temp_audio.wav"
        with open(audio_path, "wb") as audio_file:
            audio_file.write(file.file.read())

        # Use whisper to convert speech to text
        text = whisper.transcribe(audio_path,language="en")['text']

        # Return the transcribed text
        return text

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=9000)
