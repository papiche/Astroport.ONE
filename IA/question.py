#!/usr/bin/env python3
"""
question.py — Orchestrateur IA Ollama avec mémoire multi-source

Sources de contexte (priorité décroissante, toutes cumulables) :
  1. Flashmem skill  --skill devops   → ~/.zen/flashmem/skills/devops.md
  2. Qdrant RAG      --skill devops   → collection wotx2_resources (sémantique)
  3. Slot user       --user-id email --slot N  → ~/.zen/flashmem/<email>/slotN.json
  4. UMAP memory     --lat --lon      → ~/.zen/flashmem/uplanet_memory/<coord>.json
  5. Pubkey memory   --pubkey <hex>   → ~/.zen/flashmem/uplanet_memory/pubkey/<hex>.json
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes — UNIQUEMENT
# en exécution directe (`__main__`), jamais au simple import : un appelant qui
# importerait ce module (ex. bro_watch_core.py pour appeler get_ollama_answer
# sans passer par un sous-processus) verrait sinon TOUT SON PROCESS remplacé
# par execv — catastrophique pour un serveur long-lived (ex. FastAPI) qui
# importerait ce module transitivement.
import sys as _sys
import os as _os
if __name__ == "__main__":
    _venv_python = _os.path.expanduser("~/.astro/bin/python3")
    if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
        _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os


import os
import sys
import re

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
sys.path.insert(0, MY_DIR)
from prompt_safety import wrap_untrusted


def load_skill_context(skill: str, question: str = "") -> str:
    """
    Charge le contexte skill depuis :
    1. Flashmem partagé (~/.zen/flashmem/skills/<skill>.md)
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


_HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)


def load_identity(user_id: str) -> str:
    """
    Charge la biographie narrative de l'utilisateur — fichiers Markdown sous
    ~/.zen/game/nostr/<user_id>/identity/ (.Core.md, .Style.md, .Rules.md,
    .Preferences.md, .Objectifs.md). Injectée en tête du prompt système pour
    que BRO reste le clone numérique du capitaine, pas un assistant générique.

    Fichiers préfixés par un point : ~/.zen/game/nostr/<email>/ est publié
    intégralement sur l'IPNS de l'essaim (NOSTRCARD.refresh.sh:
    `ipfs add -rwq`), qui exclut par défaut tout chemin caché — l'identité
    reste donc privée à la station du capitaine.

    Les commentaires HTML (<!-- ... -->) sont retirés avant injection : les
    templates par défaut ne contiennent que des instructions en commentaire,
    donc un fichier non renseigné par l'utilisateur n'ajoute rien au prompt.
    """
    identity_dir = os.path.expanduser(f"~/.zen/game/nostr/{user_id}/identity")
    if not os.path.isdir(identity_dir):
        return ""
    parts = []
    for filename in (".Core.md", ".Style.md", ".Rules.md", ".Preferences.md", ".Objectifs.md"):
        path = os.path.join(identity_dir, filename)
        if not os.path.isfile(path):
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = _HTML_COMMENT_RE.sub("", f.read()).strip()
        except Exception:
            continue
        if content:
            parts.append(content)
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
    if not text:
        return text
    # re.sub supprime déjà toutes les occurrences de <think>...</think>
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL)
    return text.strip()


def get_ollama_answer(prompt: str, model_name: str = "gemma3:12b",
                      system_prompt: str = None,
                      temperature: float = None,
                      num_ctx: int = None,
                      num_predict: int = None,
                      top_p: float = None,
                      repeat_penalty: float = None,
                      format_json: bool = False) -> str | None:
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
    options = {}
    if temperature is not None:
        options['temperature'] = temperature
    if num_ctx is not None:
        options['num_ctx'] = num_ctx
    if num_predict is not None:
        options['num_predict'] = num_predict
    if top_p is not None:
        options['top_p'] = top_p
    if repeat_penalty is not None:
        options['repeat_penalty'] = repeat_penalty
    kwargs = dict(
        model=model_name,
        messages=[
            {'role': 'system', 'content': _system},
            {'role': 'user',   'content': prompt},
        ]
    )
    if options:
        kwargs['options'] = options
    if format_json:
        # Contraint Ollama à générer un JSON syntaxiquement valide — rend
        # obsolète toute extraction/réparation regex côté appelant (voir
        # interpret_command_with_context dans bro_watch_core.py).
        kwargs['format'] = 'json'
    try:
        ai_response = ollama.chat(**kwargs)
        return filter_think_tags(ai_response['message']['content'])
    except Exception as e:
        print(f"[question.py] Erreur Ollama: {e}", file=sys.stderr)
        return None


def answer_question(question_text: str, model_name: str = "gemma3:12b",
                    skill: str = "", npub: str = "",
                    lat=None, lon=None, pubkey=None, user_id=None, slot: int = 0,
                    temperature: float = None, ctx: int = None, max_tokens: int = None,
                    top_p: float = None, repeat_penalty: float = None,
                    format_json: bool = False) -> str | None:
    """Assemble contexte (skill/slot/UMAP/pubkey) + identité LifeOS + règles de
    base, journalise dans IA.log, puis appelle Ollama — cœur partagé par le
    CLI (main()) et tout appelant Python qui importe ce module directement
    (ex. bro_watch_core.py, bro/identity.py : un import évite le coût d'un
    sous-processus Python complet — allocation mémoire, interpréteur, rechargement
    d'ollama/qdrant_client — à chaque appel, ~1-3s d'overhead selon la machine)."""
    context_parts = []
    system_extra  = ""

    # 1. Contexte skill (flashmem + Qdrant)
    if skill:
        skill_ctx = load_skill_context(skill, question_text)
        if skill_ctx:
            context_parts.append(skill_ctx)
        system_extra = (
            f"Tu es un formateur expert en '{skill}'. "
            f"Tu guides l'utilisateur dans son apprentissage de façon pédagogique et pratique. "
        )

    # 2. Contexte utilisateur (slot / UMAP / pubkey)
    if user_id is not None:
        user_ctx = load_context(user_id=user_id, slot=slot)
        if user_ctx:
            context_parts.append(f"Historique personnel :\n{wrap_untrusted('personal_history', user_ctx)}")
    elif lat and lon:
        geo_ctx = load_context(latitude=lat, longitude=lon)
        if geo_ctx:
            context_parts.append(f"Contexte géographique :\n{wrap_untrusted('geo_context', geo_ctx)}")
    elif pubkey:
        pub_ctx = load_context(pubkey=pubkey)
        if pub_ctx:
            context_parts.append(f"Contexte utilisateur :\n{wrap_untrusted('user_context', pub_ctx)}")

    # ── Prompt final ──────────────────────────────────────────────────────────
    # Question seule dans le rôle "user" — contexte et règles dans "system"
    # (séparer les rôles réduit les hallucinations : le LLM ne confond plus
    #  le contexte RAG avec la demande utilisateur)
    final_prompt = question_text

    _base_rules = (
        "RÉPONDS EN FRANÇAIS UNIQUEMENT.\n\n"
        "RÈGLES:\n"
        "1. Réponds en FRANÇAIS (ou dans la langue de la question)\n"
        "2. Commence DIRECTEMENT par le contenu (sans introduction)\n"
        "3. Pas de markdown\n"
        "4. Utilise des emojis\n"
        "5. Sois concis"
    )
    identity_block = load_identity(user_id) if user_id else ""

    system_parts = []
    if identity_block:
        system_parts.append(
            "Tu es le clone numérique de l'utilisateur. Voici ton ADN :\n"
            f"{wrap_untrusted('identity', identity_block)}"
        )
    if system_extra:
        system_parts.append(system_extra)
    system_parts.append(_base_rules)
    if context_parts:
        system_parts.append("CONTEXTE:\n" + "\n\n".join(context_parts))
    system_prompt = "\n\n".join(system_parts)

    # ── Log ──────────────────────────────────────────────────────────────────
    log_file_path = os.path.expanduser("~/.zen/tmp/IA.log")
    os.makedirs(os.path.dirname(log_file_path), exist_ok=True)
    with open(log_file_path, "a") as lf:
        npub_tag = f"[{npub[:12]}] " if npub else ""
        skill_tag = f"[skill:{skill}] " if skill else ""
        lf.write(f"{npub_tag}{skill_tag}{final_prompt}\n")

    # ── Réponse Ollama ────────────────────────────────────────────────────────
    answer = get_ollama_answer(final_prompt, model_name, system_prompt,
                               temperature=temperature,
                               num_ctx=ctx,
                               num_predict=max_tokens,
                               top_p=top_p,
                               repeat_penalty=repeat_penalty,
                               format_json=format_json)

    if answer:
        with open(log_file_path, "a") as lf:
            lf.write(f"{answer}\n")
    return answer


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Répond à une question via Ollama, avec contexte multi-source."
    )
    parser.add_argument("question",      nargs="?", default=None)
    parser.add_argument("--prompt-file", type=str)
    parser.add_argument("-m", "--model", dest="ollama_model_name", default="gemma3:12b")
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
    parser.add_argument("--temperature",     type=float, default=None,
                        help="Température Ollama (0.0=factuel, 1.0=créatif). Défaut: modèle Ollama.")
    parser.add_argument("--ctx",             type=int,   default=None,
                        help="Fenêtre de contexte num_ctx (ex: 32768). Défaut: Ollama interne (~2048).")
    parser.add_argument("--max-tokens",      type=int,   default=None, dest="max_tokens",
                        help="Tokens max à générer num_predict (ex: 1024). Défaut: illimité.")
    parser.add_argument("--top-p",           type=float, default=None, dest="top_p",
                        help="Nucleus sampling top_p (ex: 0.9). Défaut: modèle Ollama.")
    parser.add_argument("--repeat-penalty",  type=float, default=None, dest="repeat_penalty",
                        help="Pénalité répétition repeat_penalty (ex: 1.1). Défaut: modèle Ollama.")
    parser.add_argument("--format-json",     action="store_true", dest="format_json",
                        help="Force Ollama à générer un JSON syntaxiquement valide "
                             "(paramètre API format=json) — pour les prompts qui exigent "
                             "une sortie structurée (PlantNet, Craft, Inventory, interprétation "
                             "de commandes). Sans effet sur les réponses en texte libre.")

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

    # ── Contexte + appel Ollama (logique partagée, voir answer_question) ──────
    answer = answer_question(
        question_text, model_name=args.ollama_model_name,
        skill=args.skill, npub=args.npub,
        lat=args.lat, lon=args.lon, pubkey=args.pubkey,
        user_id=args.user_id, slot=args.slot,
        temperature=args.temperature, ctx=args.ctx, max_tokens=args.max_tokens,
        top_p=args.top_p, repeat_penalty=args.repeat_penalty,
        format_json=args.format_json,
    )

    if answer:
        if args.json:
            print(json.dumps({"answer": answer}))
        else:
            print(answer)
    else:
        if not args.json:
            print("Échec de la réponse Ollama.", file=sys.stderr)
        sys.exit(1)
