#!/usr/bin/env python3
import requests
import ollama
import tempfile
import os
import sys
import argparse
import json

def describe_image_from_ipfs(ipfs_url, ollama_model="llava", output_json=False):
    """
    Downloads an image from an IPFS URL and uses Ollama to generate a description.

    Args:
        ipfs_url (str): The IPFS URL of the image.
        ollama_model (str, optional): The name of the Ollama model to use. Defaults to "llava".
        output_json (bool, optional): Whether to output the description in JSON format. Defaults to False.

    Returns:
        str or dict: The description of the image generated by Ollama.
                     If output_json is True, returns a JSON string.
                     Otherwise, returns a plain text string.
                     Returns None if an error occurs.
    """
    try:
        if not output_json:
            print(f"Downloading image from IPFS URL: {ipfs_url}")
        response = requests.get(ipfs_url, stream=True, timeout=10) # Added timeout
        response.raise_for_status()  # Raise HTTPError for bad responses (4xx or 5xx)

        with tempfile.NamedTemporaryFile(delete=False, suffix="") as tmp_file: # Suffix is important for Ollama to recognize as image
            for chunk in response.iter_content(chunk_size=8192):
                tmp_file.write(chunk)
            temp_image_path = tmp_file.name

        if not output_json:
            print(f"Image downloaded and saved to temporary file: {temp_image_path}")

        if not output_json:
            print(f"Sending image to Ollama model '{ollama_model}' for description...")
        ai_response = ollama.chat(
            model=ollama_model,
            messages=[
                {
                    'role': 'user',
                    'content': 'Describe this image.',
                    'images': [temp_image_path],
                },
            ]
        )

        description = ai_response['message']['content']
        if not output_json:
            print(f"Ollama description received.")

        if output_json:
            result = {"description": description}
            return json.dumps(result)
        else:
            return description

    except requests.exceptions.RequestException as e:
        if not output_json:
            print(f"Error downloading image from IPFS: {e}")
        return None
    except ollama.exceptions.OllamaError as e:
        if not output_json:
            print(f"Error during Ollama processing: {e}")
        return None
    except Exception as e:
        if not output_json:
            print(f"An unexpected error occurred: {e}")
        return None
    finally:
        if 'temp_image_path' in locals() and os.path.exists(temp_image_path):
            os.remove(temp_image_path)
            if not output_json:
                print(f"Temporary image file '{temp_image_path}' removed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Describe an image from an IPFS URL using Ollama.")
    parser.add_argument("ipfs_image_url", help="The IPFS URL of the image.")
    parser.add_argument("-m", "--model", dest="ollama_model_name", default="llava", help="The name of the Ollama model to use (default: llava).")
    parser.add_argument("--json", action="store_true", help="Output description in JSON format.")

    args = parser.parse_args()

    description_output = describe_image_from_ipfs(args.ipfs_image_url, args.ollama_model_name, args.json)

    if description_output:
        if args.json:
            print(description_output) # Already JSON string
        else:
            print("\nImage Description from Ollama:")
            print(description_output)
    else:
        if not args.json: # Only print error message if not in JSON mode (as JSON mode is for pure output)
            print("\nFailed to get image description.")
