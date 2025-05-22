#!/usr/bin/env python3
import ollama
import argparse
import json
import os

def load_context(latitude=None, longitude=None, pubkey=None):
    """
    Loads memory context from UMAP (latitude/longitude) or from PUBKEY memory.

    Args:
        latitude (str, optional): Latitude coordinate.
        longitude (str, optional): Longitude coordinate.
        pubkey (str, optional): Public key.

    Returns:
        str: A formatted context string, or empty string if not found.
    """
    base_memory_dir = os.path.expanduser("~/.zen/strfry/uplanet_memory")

    if latitude and longitude:
        coord_key = f"{latitude}_{longitude}".replace(".", "_").replace("-", "m")
        memory_file = os.path.join(base_memory_dir, f"{coord_key}.json")
    elif pubkey:
        memory_file = os.path.join(base_memory_dir, "pubkey", f"{pubkey}.json")
    else:
        return ""

    if not os.path.isfile(memory_file):
        return ""

    try:
        with open(memory_file, 'r') as f:
            memory = json.load(f)
            messages = memory.get('messages', [])
            context = "\n".join(f"- {m.get('content', '')}" for m in messages)
            return context
    except Exception as e:
        print(f"Failed to load context from {memory_file}: {e}")
        return ""

def filter_think_tags(text):
    """
    Remove content between <think> and </think> tags (inclusive) from the text.
    """
    while "<think>" in text and "</think>" in text:
        start = text.find("<think>")
        end = text.find("</think>") + len("</think>")
        text = text[:start] + text[end:]
    return text.strip()

def get_ollama_answer(prompt, model_name="gemma3:latest"):
    """
    Generates an answer from Ollama based on the given prompt.
    """
    try:
        ai_response = ollama.chat(
            model=model_name,
            messages=[
                {
                    'role': 'user',
                    'content': prompt,
                },
            ]
        )
        answer = ai_response['message']['content']
        # Filter out <think> tags before returning
        return filter_think_tags(answer)
    except Exception as e:
        print(f"Error during Ollama processing: {e}")
        return None

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Answer a question using Ollama, with optional UMAP or PUBKEY context.")
    parser.add_argument("question", help="The question to ask Ollama.")
    parser.add_argument("-m", "--model", dest="ollama_model_name", default="gemma3:latest", help="The name of the Ollama model to use (default: gemma3:latest).")
    parser.add_argument("--lat", type=str, help="Latitude to load UMAP memory context.")
    parser.add_argument("--lon", type=str, help="Longitude to load UMAP memory context.")
    parser.add_argument("--pubkey", type=str, help="Pubkey to load PUBKEY memory context.")
    parser.add_argument("--json", action="store_true", help="Output answer in JSON format.")

    args = parser.parse_args()

    # Charger un éventuel contexte
    context_text = ""
    if args.lat and args.lon:
        context_text = load_context(latitude=args.lat, longitude=args.lon)
    elif args.pubkey:
        context_text = load_context(pubkey=args.pubkey)

    # Construire le prompt final
    final_prompt = ""
    if context_text:
        final_prompt += f"Contexte :\n{context_text}\n\n"
    final_prompt += f"Question: {args.question}"
    
    # Log the final prompt to IA.log
    with open(os.path.expanduser("~/.zen/tmp/IA.log"), "a") as log_file:
        log_file.write(f"{final_prompt}\n")

    # Get the answer from Ollama
    answer_output = get_ollama_answer(final_prompt, args.ollama_model_name)
    
    #Log the answer
    with open(os.path.expanduser("~/.zen/tmp/IA.log"), "a") as log_file:
        log_file.write(f"{answer_output}\n")

    if answer_output:
        if args.json:
            result = {"answer": answer_output}
            print(json.dumps(result))
        else:
            print(answer_output)
    else:
        if not args.json:
            print("Failed to get answer from Ollama.")
