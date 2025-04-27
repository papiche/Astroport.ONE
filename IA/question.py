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

def get_ollama_answer(prompt, model_name="qwen2.5"):
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
        return answer
    except ollama.exceptions.OllamaError as e:
        print(f"Error during Ollama processing in question.py: {e}")
        return None
    except Exception as e:
        print(f"An unexpected error occurred in question.py: {e}")
        return None

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Answer a question using Ollama, with optional UMAP or PUBKEY context.")
    parser.add_argument("question", help="The question to ask Ollama.")
    parser.add_argument("-m", "--model", dest="ollama_model_name", default="qwen2.5", help="The name of the Ollama model to use (default: qwen2.5).")
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
        final_prompt += f"Here is some previous context:\n{context_text}\n\n"
    final_prompt += f"Question: {args.question}"

    answer_output = get_ollama_answer(final_prompt, args.ollama_model_name)

    if answer_output:
        if args.json:
            result = {"answer": answer_output}
            print(json.dumps(result))
        else:
            print(answer_output)
    else:
        if not args.json:
            print("Failed to get answer from Ollama.")
