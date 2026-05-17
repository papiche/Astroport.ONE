#!/usr/bin/env python3
"""
question.py — Orchestrateur IA Ollama avec mémoire multi-source

Sources de contexte (priorité décroissante, toutes cumulables) :
  1. Flashmem skill  --skill devops   → ~/.zen/tmp/flashmem/skills/devops.md
  2. Qdrant RAG      --skill devops   → collection wotx2_resources (sémantique)
  3. Slot user       --user-id email --slot N  → ~/.zen/flashmem/<email>/slotN.json
  4. UMAP memory     --lat --lon      → ~/.zen/flashmem/uplanet_memory/<coord>.json
  5. Pubkey memory   --pubkey <hex>   → ~/.zen/flashmem/uplanet_memory/pubkey/<hex>.json
"""

import os
import sys

# Activer l'environnement virtuel ~/.astro
venv_path = os.path.expanduser("~/.astro")
if os.path.exists(venv_path):
    python_version = f"python{sys.version_info.major}.{sys.version_info.minor}"
    site_packages = os.path.join(venv_path, "lib", python_version, "site-packages")
    if os.path.exists(site_packages):
        sys.path.insert(0, site_packages)

import ollama
import argparse
import json

MY_DIR = os.path.dirname(os.path.abspath(__file__))


def load_skill_context(skill: str, question: str = "") -> str:
    """
    Charge le contexte skill depuis :
    1. Flashmem partagé (~/.zen/tmp/flashmem/skills/<skill>.md)
    2. Qdrant RAG (collection wotx2_resources)
    """
    parts = []

    # 1. Flashmem skill (notes partagées)
    try:
        sys.path.insert(0, MY_DIR)
        from skill_flashmem import format_context as fm_context
        ctx = fm_context(skill)
        if ctx:
            parts.append(ctx)
    except Exception as e:
        pass

    # 2. Qdrant RAG
    try:
        from skill_qdrant import build_qdrant_context
        qdrant_ctx = build_qdrant_context(skill, question)
        if qdrant_ctx:
            parts.append(qdrant_ctx)
    except Exception:
        pass  # Qdrant optionnel

    return "\n\n".join(parts)


def load_context(latitude=None, longitude=None, pubkey=None, user_id=None, slot=0):
    """
    Charge la mémoire contextuelle depuis les slots utilisateur ou les mémoires UMAP/pubkey.
    """
    if user_id and slot is not None:
        slot_file = os.path.expanduser(f"~/.zen/flashmem/{user_id}/slot{slot}.json")
        if os.path.isfile(slot_file):
            try:
                with open(slot_file, 'r') as f:
                    memory = json.load(f)
                    messages = memory.get('messages', [])
                    return "\n".join(f"- {m.get('content', '')}" for m in messages[-20:])
            except Exception:
                pass

    base_memory_dir = os.path.expanduser("~/.zen/flashmem/uplanet_memory")
    os.makedirs(base_memory_dir, exist_ok=True)

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
            return "\n".join(f"- {m.get('content', '')}" for m in messages)
    except Exception:
        return ""


def filter_think_tags(text):
    """Supprime les balises <think>...</think> (modèles reasoning)."""
    while "<think>" in text and "</think>" in text:
        start = text.find("<think>")
        end = text.find("</think>") + len("</think>")
        text = text[:start] + text[end:]
    return text.strip()


def get_ollama_answer(prompt: str, model_name: str = "gemma3:latest",
                      system_prompt: str = None) -> str | None:
    """Génère une réponse Ollama avec le prompt final."""
    _system = system_prompt or (
        "RÉPONDS EN FRANÇAIS UNIQUEMENT.\n\n"
        "RÈGLES:\n"
        "1. Réponds en FRANÇAIS (ou dans la langue de la question)\n"
        "2. Commence DIRECTEMENT par le contenu (sans introduction)\n"
        "3. Pas de markdown\n"
        "4. Utilise des emojis\n"
        "5. Sois concis"
    )
    try:
        ai_response = ollama.chat(
            model=model_name,
            messages=[
                {'role': 'system', 'content': _system},
                {'role': 'user',   'content': prompt},
            ]
        )
        return filter_think_tags(ai_response['message']['content'])
    except Exception as e:
        print(f"[question.py] Erreur Ollama: {e}", file=sys.stderr)
        return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Répond à une question via Ollama, avec contexte multi-source."
    )
    parser.add_argument("question",      nargs="?", default=None)
    parser.add_argument("--prompt-file", type=str)
    parser.add_argument("-m", "--model", dest="ollama_model_name", default="gemma3:latest")
    parser.add_argument("--skill",       type=str, default="",
                        help="Skill actif — charge flashmem+Qdrant pour ce skill")
    parser.add_argument("--npub",        type=str, default="",
                        help="Hex pubkey de l'utilisateur (pour logging)")
    parser.add_argument("--lat",         type=str)
    parser.add_argument("--lon",         type=str)
    parser.add_argument("--pubkey",      type=str)
    parser.add_argument("--user-id",     type=str)
    parser.add_argument("--slot",        type=int, default=0)
    parser.add_argument("--json",        action="store_true")

    args = parser.parse_args()

    # ── Charger le texte de la question ──────────────────────────────────────
    question_text = ""
    if args.prompt_file and os.path.isfile(args.prompt_file):
        with open(args.prompt_file, "r", encoding="utf-8", errors="replace") as f:
            question_text = f.read().strip()
    if not question_text and args.question:
        question_text = args.question
    if not question_text:
        print("Erreur : fournir la question en argument ou via --prompt-file.")
        sys.exit(1)

    # ── Construire le contexte ────────────────────────────────────────────────
    context_parts = []
    system_extra  = ""

    # 1. Contexte skill (flashmem + Qdrant)
    if args.skill:
        skill_ctx = load_skill_context(args.skill, question_text)
        if skill_ctx:
            context_parts.append(skill_ctx)
        system_extra = (
            f"Tu es un formateur expert en '{args.skill}'. "
            f"Tu guides l'utilisateur dans son apprentissage de façon pédagogique et pratique. "
        )

    # 2. Contexte utilisateur (slot / UMAP / pubkey)
    if args.user_id is not None:
        user_ctx = load_context(user_id=args.user_id, slot=args.slot)
        if user_ctx:
            context_parts.append(f"Historique personnel :\n{user_ctx}")
    elif args.lat and args.lon:
        geo_ctx = load_context(latitude=args.lat, longitude=args.lon)
        if geo_ctx:
            context_parts.append(f"Contexte géographique :\n{geo_ctx}")
    elif args.pubkey:
        pub_ctx = load_context(pubkey=args.pubkey)
        if pub_ctx:
            context_parts.append(f"Contexte utilisateur :\n{pub_ctx}")

    # ── Prompt final ──────────────────────────────────────────────────────────
    final_prompt = ""
    if context_parts:
        final_prompt = "\n\n".join(context_parts) + "\n\n"
    final_prompt += f"Question: {question_text}"

    # System prompt enrichi si skill actif
    system_prompt = None
    if system_extra:
        system_prompt = (
            system_extra +
            "RÈGLES: réponds en FRANÇAIS, commence directement par le contenu, "
            "utilise des emojis, sois concis et pratique."
        )

    # ── Log ──────────────────────────────────────────────────────────────────
    log_file_path = os.path.expanduser("~/.zen/tmp/IA.log")
    os.makedirs(os.path.dirname(log_file_path), exist_ok=True)
    with open(log_file_path, "a") as lf:
        npub_tag = f"[{args.npub[:12]}] " if args.npub else ""
        skill_tag = f"[skill:{args.skill}] " if args.skill else ""
        lf.write(f"{npub_tag}{skill_tag}{final_prompt}\n")

    # ── Réponse Ollama ────────────────────────────────────────────────────────
    answer = get_ollama_answer(final_prompt, args.ollama_model_name, system_prompt)

    if answer:
        with open(log_file_path, "a") as lf:
            lf.write(f"{answer}\n")
        if args.json:
            print(json.dumps({"answer": answer}))
        else:
            print(answer)
    else:
        if not args.json:
            print("Échec de la réponse Ollama.")
        sys.exit(1)
