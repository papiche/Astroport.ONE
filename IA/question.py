#!/usr/bin/env python3
"""
question.py — Orchestrateur IA Ollama avec mémoire multi-source

Sources de contexte (priorité décroissante, toutes cumulables) :
  1. Flashmem skill  --skill devops   → ~/.zen/flashmem/skills/devops.md
  2. Qdrant RAG      --skill devops   → collection wotx2_resources (sémantique)
  3. Mémoire perso   --user-id email  → collection Qdrant memory_<hex> (souvenirs actifs, sémantique)
  4. Mémoire du lieu --lat --lon      → collection Qdrant uplanet_geo : publications géolocalisées APPRÉCIÉES
                                        (1 like = UMAP, 3 = SECTOR, 12 = REGION), indexées depuis NOSTR par geo_memory.py
Plus aucun fichier local : tout vit dans NOSTR et Qdrant (stockage p2p).
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
import time
import subprocess

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


def load_context(latitude=None, longitude=None, pubkey=None, user_id=None, slot=0,
                 question_text=""):
    """
    Charge la mémoire contextuelle depuis la mémoire personnelle (utilisateur)
    ou les mémoires UMAP/pubkey (ambiantes, non personnelles).

    Simplification 2026-10 : la mémoire personnelle (user_id) n'est plus lue
    comme "les 20 derniers messages bruts d'un tiroir numéroté choisi par
    l'utilisateur" — elle est retrouvée par PERTINENCE SÉMANTIQUE à la question
    posée (memory_manager.search_user_slot, Qdrant), sur TOUS les souvenirs actifs
    du compte (faits, épisodes, proches, traits). Qdrant est la seule source de
    vérité : plus aucun fichier local."""
    if user_id:
        try:
            sys.path.insert(0, MY_DIR)
            import memory_manager
            # Toute la mémoire ACTIVE du compte (faits, épisodes, traits), pas seulement le
            # slot 0 (#rec, jamais pratiqué) : BRO retrouve seul ce qui compte. Seuil =
            # RECALL_THRESHOLD du modèle d'embedding. Sans question : les plus récents.
            if question_text:
                hits = memory_manager.search_user_slot(user_id, question_text, limit=6)
            else:
                hits = memory_manager.list_memories(user_id, limit=5)
            if hits:
                return "\n".join(
                    f"- {h.get('payload', {}).get('content', '')}" for h in hits
                )
        except Exception as e:
            print(f"[question.py] load_context: recherche Qdrant échouée ({e}) — contexte vide", file=sys.stderr)
        return ""

    if latitude and longitude:
        # Mémoire du LIEU : publications géolocalisées appréciées, pertinentes pour la question, au périmètre où elles
        # comptent (leur case UMAP ≥ 1 like, leur SECTOR ≥ 3, leur REGION ≥ 12). Avant : TOUS les messages d'un fichier JSON
        # local, sans tri, écrits par short_memory.py (supprimé : plus de disque local).
        try:
            sys.path.insert(0, MY_DIR)
            import memory_manager
            hits = memory_manager.search_geo(latitude, longitude, question_text or "ce qui se passe ici", limit=5)
        except Exception as e:
            print(f"[question.py] load_context: mémoire du lieu indisponible ({e}) — contexte vide", file=sys.stderr)
            return ""
        out = []
        for h in hits:
            pl = h.get("payload", {})
            out.append(f"- [{str(pl.get('timestamp', ''))[:10]} · {str(pl.get('level', '')).upper()} · "
                       f"{pl.get('likes', 0)} like(s)] {pl.get('content', '')[:400]}")
        return "\n".join(out)
    return ""


def filter_think_tags(text):
    """Supprime les balises <think>...</think> (modèles reasoning)."""
    if not text:
        return text
    # re.sub supprime déjà toutes les occurrences de <think>...</think>
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL)
    return text.strip()


## ── IA personnelle (Anthropic/Gemini) — « bring your own key » ─────────────
## Par défaut, BRO répond via Ollama fourni gratuitement par les stations
## DRAGON de la constellation (comportement INCHANGÉ pour tout appelant sans
## user_id, ou dont l'utilisateur n'a rien configuré — l'immense majorité).
## Un MULTIPASS peut configurer SA PROPRE clé Anthropic/Gemini via cookie.html
## (onglet "API officielle", vault chiffré UPassport/services/api_access_store.py,
## kind NOSTR 31904) pour que SES questions soient traitées par ce modèle précis.
_API_ACCESS_CLI = os.path.expanduser("~/.zen/UPassport/api_access_cli.py")
_LLM_OVERRIDE_CACHE_TTL = 300  # secondes — évite de re-sonder le vault à chaque question
_llm_override_cache: dict = {}  # user_id -> (timestamp, override_dict_or_None)


def _user_llm_override(user_id: str) -> dict | None:
    """Vérifie si cet utilisateur a configuré sa propre clé Anthropic/Gemini.
    Défensif par construction : toute erreur (CLI absent, timeout, JSON invalide)
    retombe silencieusement sur None → Ollama par défaut. Un « bring your own
    key » cassé ne doit JAMAIS empêcher BRO de répondre."""
    if not user_id:
        return None
    cached = _llm_override_cache.get(user_id)
    if cached and (time.time() - cached[0]) < _LLM_OVERRIDE_CACHE_TTL:
        return cached[1]

    override = None
    if os.path.isfile(_API_ACCESS_CLI):
        for provider in ("anthropic", "gemini"):
            try:
                r = subprocess.run(
                    [sys.executable, _API_ACCESS_CLI, "get", user_id, provider],
                    capture_output=True, text=True, timeout=10,
                )
                if r.returncode != 0:
                    continue
                values = json.loads(r.stdout.strip() or "{}")
                if values.get("api_key"):
                    override = {"provider": provider, **values}
                    break
            except Exception as e:
                print(f"[question.py] _user_llm_override({provider}): {e}", file=sys.stderr)
                continue

    _llm_override_cache[user_id] = (time.time(), override)
    return override


def get_anthropic_answer(prompt: str, system_prompt: str, api_key: str,
                         model: str = "claude-sonnet-5", max_tokens: int = None,
                         temperature: float = None) -> str | None:
    """Messages API Anthropic — REST simple, pas de SDK requis."""
    import requests
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }
    body = {
        "model": model,
        "max_tokens": max_tokens or 1024,
        "system": system_prompt,
        "messages": [{"role": "user", "content": prompt}],
    }
    if temperature is not None:
        body["temperature"] = temperature
    try:
        r = requests.post("https://api.anthropic.com/v1/messages",
                          headers=headers, json=body, timeout=60)
        if r.status_code == 200:
            parts = r.json().get("content", [])
            text = "".join(p.get("text", "") for p in parts if p.get("type") == "text").strip()
            return filter_think_tags(text) if text else None
        print(f"[question.py] Erreur Anthropic: http_{r.status_code}: {r.text[:200]}", file=sys.stderr)
    except Exception as e:
        print(f"[question.py] Erreur Anthropic: {e}", file=sys.stderr)
    return None


def get_gemini_answer(prompt: str, system_prompt: str, api_key: str,
                      model: str = "gemini-2.0-flash", max_tokens: int = None,
                      temperature: float = None) -> str | None:
    """generateContent REST Gemini — pas de SDK requis."""
    import requests
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    gen_config = {}
    if max_tokens:
        gen_config["maxOutputTokens"] = max_tokens
    if temperature is not None:
        gen_config["temperature"] = temperature
    body = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "systemInstruction": {"parts": [{"text": system_prompt}]},
    }
    if gen_config:
        body["generationConfig"] = gen_config
    try:
        r = requests.post(url, json=body, timeout=60)
        if r.status_code == 200:
            candidates = r.json().get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                text = "".join(p.get("text", "") for p in parts).strip()
                return filter_think_tags(text) if text else None
            return None
        print(f"[question.py] Erreur Gemini: http_{r.status_code}: {r.text[:200]}", file=sys.stderr)
    except Exception as e:
        print(f"[question.py] Erreur Gemini: {e}", file=sys.stderr)
    return None


def get_ollama_answer(prompt: str, model_name: str = "gemma3:12b",
                      system_prompt: str = None,
                      temperature: float = None,
                      num_ctx: int = None,
                      num_predict: int = None,
                      top_p: float = None,
                      repeat_penalty: float = None,
                      format_json: bool = False) -> str | None:
    """Génère une réponse Ollama avec le prompt final."""
    _system = system_prompt or (_JSON_RULES if format_json else
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
        # La 3090 est PARTAGÉE avec ComfyUI : ne pas demander un modèle à charger s'il n'y a pas la place (cf. gpu_headroom.py).
        sys.path.insert(0, MY_DIR)
        import gpu_headroom
        gpu_headroom.ensure(model_name, ctx=num_ctx)
    except Exception as e:                       # GpuBusy : dit pourquoi, la réponse est refusée plutôt que de risquer le GPU
        print(f"[question.py] GPU occupé : {e}", file=sys.stderr)
        return None
    import ollama_metrics                        # journal des appels au GPU partagé (~/.zen/log/ollama_calls_*.jsonl)
    _t0 = ollama_metrics.start()
    try:
        ai_response = ollama.chat(**kwargs)
        ollama_metrics.record("chat", model_name, _t0, resp=ai_response, ctx=num_ctx)
        return filter_think_tags(ai_response['message']['content'])
    except Exception as e:
        ollama_metrics.record("chat", model_name, _t0, ok=False, error=e, ctx=num_ctx)
        print(f"[question.py] Erreur Ollama: {e}", file=sys.stderr)
        return None


# Appels qui attendent une DONNÉE (classification, extraction, synthèse de profil) :
# aucune consigne de style conversationnel — « utilise des emojis » se retrouvait sinon
# dans les valeurs JSON recopiées telles quelles dans identity/.Preferences.md.
_JSON_RULES = (
    "Tu es un composant de traitement de données.\n"
    "RÈGLES:\n"
    "1. Réponds UNIQUEMENT par un objet JSON valide, conforme au format demandé\n"
    "2. Aucun texte autour, aucun markdown, AUCUN emoji\n"
    "3. Les valeurs textuelles sont écrites en français, sobres et factuelles"
)


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
        user_ctx = load_context(user_id=user_id, slot=slot, question_text=question_text)
        if user_ctx:
            context_parts.append(f"Historique personnel :\n{wrap_untrusted('personal_history', user_ctx)}")
            context_parts.append(
                "Règle de transparence : si ta réponse s'appuie sur un élément de l'historique personnel, dis-le en une "
                "courte incise (« je me souviens que… », « d'après ce que tu m'as dit… ») pour que la personne puisse te "
                "corriger. N'en cite aucun s'il n'aide pas à répondre, et n'invente jamais de souvenir.")
    elif lat and lon:
        geo_ctx = load_context(latitude=lat, longitude=lon, question_text=question_text)
        if geo_ctx:
            context_parts.append(f"Contexte géographique (publications appréciées du lieu) :\n{wrap_untrusted('geo_context', geo_ctx)}")
    # `pubkey` : n'ouvre plus de contexte (la mémoire par clé publique était un fichier local écrit par short_memory.py, supprimé)

    # ── Prompt final ──────────────────────────────────────────────────────────
    # Question seule dans le rôle "user" — contexte et règles dans "system"
    # (séparer les rôles réduit les hallucinations : le LLM ne confond plus
    #  le contexte RAG avec la demande utilisateur)
    final_prompt = question_text

    _base_rules = _JSON_RULES if format_json else (
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

    # ── Réponse : IA personnelle si configurée (Anthropic/Gemini), sinon
    # Ollama DRAGON par défaut — jamais de changement de comportement pour un
    # appelant sans user_id ou dont l'utilisateur n'a rien configuré. ────────
    answer = None
    override = _user_llm_override(user_id) if user_id else None
    if override:
        provider = override["provider"]
        if provider == "anthropic":
            answer = get_anthropic_answer(
                final_prompt, system_prompt, override["api_key"],
                model=override.get("model") or "claude-sonnet-5",
                max_tokens=max_tokens, temperature=temperature,
            )
        elif provider == "gemini":
            answer = get_gemini_answer(
                final_prompt, system_prompt, override["api_key"],
                model=override.get("model") or "gemini-2.0-flash",
                max_tokens=max_tokens, temperature=temperature,
            )
        if answer is None:
            print(f"[question.py] IA personnelle ({provider}) en échec pour {user_id} — repli Ollama", file=sys.stderr)

    if answer is None:
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
    parser.add_argument("--learn",           action="store_true",
                        help="Met la question en file d'apprentissage de la mémoire (source « chat », "
                             "memory_writer.py) — réservé aux canaux où l'auteur est AUTHENTIFIÉ comme "
                             "propriétaire de --user-id (DM déchiffré). Jamais Telegram/Mastodon/roaming : "
                             "n'importe qui peut y écrire.")
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

    if answer and args.learn and args.user_id:
        try:
            import memory_writer
            memory_writer.ingest(args.user_id, [question_text], source="chat")
        except Exception as e:
            print(f"[question.py] apprentissage mémoire indisponible : {e}", file=sys.stderr)

    if answer:
        if args.json:
            print(json.dumps({"answer": answer}))
        else:
            print(answer)
    else:
        if not args.json:
            print("Échec de la réponse Ollama.", file=sys.stderr)
        sys.exit(1)
