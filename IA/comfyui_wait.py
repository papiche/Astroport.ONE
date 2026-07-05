#!/usr/bin/env python3
"""
comfyui_wait.py — Attend la fin d'un job ComfyUI via WebSocket.

Remplace le polling curl /history toutes les 2s dans generate_image.sh.
Reçoit les événements en push (execution_success / execution_error) et
sort dès que l'événement correspondant au prompt_id arrive.

Sorties stdout (une ligne) :
  done          — image générée avec succès
  no_websocket  — websocket-client absent, fallback nécessaire
  error:<msg>   — erreur ComfyUI ou connexion
  timeout       — délai maximal dépassé

Usage :
  comfyui_wait.py <client_id> <prompt_id> [--url ws://127.0.0.1:8188/ws] [--timeout 120]
Exit code : 0=done, 1=erreur/timeout, 2=pas de websocket-client
"""

import sys
import json
import argparse

try:
    import websocket
except ImportError:
    print("no_websocket")
    sys.exit(2)


def wait(client_id: str, prompt_id: str, ws_url: str, timeout: int) -> str:
    url = f"{ws_url}?clientId={client_id}"
    outcome = {"status": "timeout"}

    def on_message(ws, raw):
        try:
            msg = json.loads(raw)
        except Exception:
            return
        t = msg.get("type", "")
        data = msg.get("data", {})
        if data.get("prompt_id") != prompt_id:
            return
        if t == "executed":
            outcome["status"] = "done"
            ws.close()
        elif t == "execution_error":
            err = data.get("exception_message") or data.get("node_id") or "unknown"
            outcome["status"] = f"error:{err}"
            ws.close()

    def on_error(ws, err):
        outcome["status"] = f"error:{err}"

    ws = websocket.WebSocketApp(url, on_message=on_message, on_error=on_error)
    ws.run_forever(ping_interval=30, ping_timeout=10, sock_opt=None)
    return outcome["status"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Attend la fin d'un job ComfyUI via WebSocket.")
    parser.add_argument("client_id",  help="UUID envoyé à ComfyUI lors du submit")
    parser.add_argument("prompt_id",  help="prompt_id retourné par /prompt")
    parser.add_argument("--url",      default="ws://127.0.0.1:8188/ws",
                        help="URL WebSocket ComfyUI (défaut: ws://127.0.0.1:8188/ws)")
    parser.add_argument("--timeout",  type=int, default=120,
                        help="Timeout en secondes (défaut: 120)")
    args = parser.parse_args()

    status = wait(args.client_id, args.prompt_id, args.url, args.timeout)
    print(status)
    sys.exit(0 if status == "done" else 1)
