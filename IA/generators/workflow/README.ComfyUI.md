# ComfyUI WAN 2.2 Workflow Setup

This document explains how to set up ComfyUI to use the WAN 2.2 text-to-video workflow.

## 1. Update ComfyUI

Before you begin, make sure you have the latest version of ComfyUI. You can update it by navigating to the ComfyUI directory in your terminal and running:

```bash
git pull
```

## 2. Download Model Files

You will need to download the following model files.

*   **Main Model (UNET):** This is the main text-to-video model. For a low VRAM setup, we use the 5B parameter model.
    *   **File:** `wan2.2_ti2v_5B_fp16.safetensors`
    *   **Download from:** [Hugging Face](https://huggingface.co/stabilityai/wan-2.2-ti2v/blob/main/wan2.2_ti2v_5B_fp16.safetensors)
    *   **Place in:** `ComfyUI/models/diffusers/`

*   **VAE (Variational Autoencoder):**
    *   **File:** `wan2.2_vae.safetensors`
    *   **Download from:** [Hugging Face](https://huggingface.co/stabilityai/wan-2.2-ti2v/blob/main/wan2.2_vae.safetensors)
    *   **Place in:** `ComfyUI/models/vae/`

*   **Text Encoder (CLIP):** This model is used to understand the text prompt.
    *   **File:** `umt5_xxl_fp8_e4m3fn_scaled.safetensors`
    *   **Download from:** [Hugging Face](https://huggingface.co/stabilityai/wan-2.2-ti2v/blob/main/text_encoder/umt5_xxl_fp8_e4m3fn_scaled.safetensors)
    *   **Place in:** `ComfyUI/models/clip/` (you might need to create a `wan` subfolder or adjust the workflow if you place it elsewhere). The provided `Text2VideoWan2.2.json` expects it in the `clip` folder with `type: wan` in the loader.

## 3. Load the Workflow

1.  Start ComfyUI.
2.  Click on "Load" and select the `Text2VideoWan2.2.json` file from this directory.
3.  The workflow should load with all the necessary nodes.

## 4. Run the Generation

1.  Locate the "CLIP Text Encode (Positive Prompt)" node.
2.  Enter your desired prompt in the `text` field, replacing `_PROMPT_`.
3.  Click "Queue Prompt" to start the video generation.

## Optional: Performance Enhancements (LoRA)

For better motion and realism, especially on the low VRAM model, you can use LoRAs.

*   **PUCA V1:** Helps with smoother motion and realism.
*   **LightX2V:** Can significantly speed up generation time.

To use a LoRA:
1.  Download the LoRA file (e.g., from Civitai or Hugging Face).
2.  Place it in `ComfyUI/models/loras/`.
3.  Add a `Load LoRA` node to your workflow after the model loader and connect it accordingly. 


## Source 

https://www.youtube.com/watch?v=lio_LBd-n9U 
https://aistudynow.com/wan-2-2-comfyui-workflow-low-vram-image-text-to-video/