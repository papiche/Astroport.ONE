#!/usr/bin/env python3
"""
Démon BRO Omni-Channel
Écoute sur le port 4243 les webhooks provenant de Matterbridge.
Passe le message au "Cerveau" (question.py) et retourne la réponse à Matterbridge.
"""

import os
import subprocess
import requests
import uvicorn
from fastapi import FastAPI, Request
from pydantic import BaseModel

app = FastAPI()

BRO_TOOLS_PATH = os.path.expanduser("~/.zen/Astroport.ONE/tools")
MATTERBRIDGE_API_URL = "http://127.0.0.1:4242/api/message"

@app.post("/webhook")
async def receive_message(request: Request):
    data = await request.json()
    
    # Format reçu de Matterbridge :
    # {"text": "hello BRO", "username": "Alice", "userid": "123", "account": "telegram.mon_bot", "gateway": "inout"}
    text = data.get("text", "")
    username = data.get("username", "Inconnu")
    account = data.get("account", "Inconnu")
    gateway = data.get("gateway", "inout")
    
    # Sécurité : Éviter les boucles infinies (BRO ne se répond pas à lui-même)
    if username == "BRO" or data.get("event") == "api":
        return {"status": "ignored"}
    
    # Garder la logique de déclenchement (seulement si on appelle #BRO, #BOT, ou si c'est un DM direct)
    if "#BRO" not in text.upper() and "#BOT" not in text.upper():
        return {"status": "ignored"}
        
    print(f"[OMNI] Message reçu de {username} (via {account}) : {text}")

    # Identifiant unique pour la base de mémoire (ex: telegram.mon_bot_Alice)
    user_id = f"{account}_{username}".replace(".", "_").replace(" ", "_")
    
    # 1. Mémoriser la requête utilisateur
    import uuid
    msg_id = uuid.uuid4().hex[:8]
    event_json = f'{{"event":{{"id":"mb_{msg_id}","content":"{text}","pubkey":"{user_id}"}}}}'
    
    subprocess.run([
        "python3", f"{BRO_TOOLS_PATH}/short_memory.py",
        event_json, "0.00", "0.00", "0", user_id
    ])

    # 2. Invoquer l'IA (question.py)
    # Remarque : On utilise le paramètre --user-id pour cibler spécifiquement la mémoire de cet utilisateur
    cleaned_text = text.replace("#BRO", "").replace("#BOT", "").strip()
    
    result = subprocess.run([
        "python3", f"{BRO_TOOLS_PATH}/question.py",
        cleaned_text,
        "--user-id", user_id,
        "--slot", "0"
    ], capture_output=True, text=True)

    reponse = result.stdout.strip()
    if not reponse:
        reponse = "⚠️ Désolé, BRO (Ollama) est temporairement injoignable."

    # 3. Mémoriser la réponse de BRO
    bot_event_json = f'{{"event":{{"id":"bro_{msg_id}","content":"{reponse}","pubkey":"BRO"}}}}'
    subprocess.run([
        "python3", f"{BRO_TOOLS_PATH}/short_memory.py",
        bot_event_json, "0.00", "0.00", "0", user_id
    ])

    # 4. Retourner la réponse vers la plateforme d'origine via Matterbridge
    payload = {
        "text": reponse,
        "username": "BRO",
        "gateway": gateway
    }
    
    try:
        requests.post(MATTERBRIDGE_API_URL, json=payload, timeout=5)
        print(f"[OMNI] Réponse envoyée à {username} : {reponse[:50]}...")
    except Exception as e:
        print(f"[OMNI] Erreur de communication avec Matterbridge : {e}")

    return {"status": "ok"}

if __name__ == "__main__":
    print("🚀 Démarrage du démon BRO Omni-Channel sur le port 4243...")
    uvicorn.run(app, host="127.0.0.1", port=4243)