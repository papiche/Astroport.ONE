#!/usr/bin/env python3
import os
import json
import glob
import numpy as np
import umap
from sklearn.feature_extraction.text import TfidfVectorizer

MEMORY_DIR = os.path.expanduser("~/.zen/strfry/uplanet_memory")
EMBEDDING_DIR = os.path.join(MEMORY_DIR, "embedding")
os.makedirs(EMBEDDING_DIR, exist_ok=True)

def load_coordinate_memories(memory_dir):
    files = glob.glob(os.path.join(memory_dir, "*.json"))
    memories = {}
    for file in files:
        if os.path.basename(file) == "pubkey":  # Skip pubkey folder
            continue
        if os.path.isdir(file):
            continue
        with open(file, 'r') as f:
            data = json.load(f)
            key = os.path.splitext(os.path.basename(file))[0]
            memories[key] = [m['content'] for m in data.get('messages', [])]
    return memories

def compute_embedding(texts):
    if not texts:
        return None

    # TF-IDF vectorisation
    vectorizer = TfidfVectorizer(max_features=500)
    X = vectorizer.fit_transform(texts)

    # UMAP réduction
    reducer = umap.UMAP(n_components=10, random_state=42)
    embedding = reducer.fit_transform(X.toarray())

    # Moyenne des embeddings
    mean_vector = np.mean(embedding, axis=0)
    return mean_vector.tolist()

def main():
    memories = load_coordinate_memories(MEMORY_DIR)
    for coord_key, messages in memories.items():
        embedding = compute_embedding(messages)
        if embedding:
            out_file = os.path.join(EMBEDDING_DIR, f"{coord_key}.json")
            with open(out_file, 'w') as f:
                json.dump({
                    "coordinate": coord_key,
                    "embedding": embedding
                }, f, indent=2)
            print(f"Embedding saved for {coord_key}")
        else:
            print(f"No content for {coord_key}, skipping.")

if __name__ == "__main__":
    main()
