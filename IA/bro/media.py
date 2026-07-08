#!/usr/bin/env python3
"""
bro.media — Génération média (image/vidéo/musique/voix), reconnaissance (PlantNet/inventaire), pipeline scraper cookie et pipeline #craft.

Extrait de bro_watch_core.py (split du monolithe, aucune logique modifiée).
"""

import os
import re
import sys
import json
import time
import hashlib
import tempfile
import subprocess

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # IA/
from prompt_safety import wrap_untrusted
from bro._shared import BRO_IA_PATH, BRO_WATCH_CORE_PATH, PYTHON_BIN, _owner_dir
from bro.nostr import send_dm_to_owner
from bro.watch_store import _load_manifest, is_scraper_enabled, store_log

__all__ = ['_IA_IMG_URL_RE', '_extract_image_url', '_describe_image_url', '_call_generator', '_MEDIA_RUN_TIMEOUT_SEC', '_MEDIA_PROGRESS_MSG', '_dispatch_media_background', '_run_recognition_script', '_run_media_background', '_MEDIA_TAG_HANDLERS', 'SCRAPER_RUN_TIMEOUT_SEC', '_cookie_file_path', '_find_scraper_script', '_SCRAPER_ICONS', 'list_station_scrapers', '_available_scraper_domains', '_extract_scraper_domain', '_run_scraper_now', '_run_scraper_background', 'CRAFT_RUN_TIMEOUT_SEC', 'BADGE_RUN_TIMEOUT_SEC', '_run_craft_background', '_run_badge_background']



_IA_IMG_URL_RE = re.compile(
    r'https?://[^\s#"\'<>]+\.(?:jpg|jpeg|png|gif|webp)(?:[?][^\s#]*)?',
    re.IGNORECASE
)

def _extract_image_url(text):
    """Extrait la première URL d'image avec extension depuis un message BRO."""
    m = _IA_IMG_URL_RE.search(text)
    return m.group(0) if m else None

def _describe_image_url(image_url):
    """Appelle describe_image.py via le venv ~/.astro/.
    Retourne la description textuelle ou '' si Ollama indisponible."""
    script = os.path.join(BRO_IA_PATH, "describe_image.py")
    if not os.path.isfile(script):
        return ""
    venv_py = os.path.expanduser("~/.astro/bin/python3")
    py = venv_py if os.path.isfile(venv_py) else "python3"
    try:
        result = subprocess.run(
            [py, script, image_url, "--json"],
            capture_output=True, text=True, timeout=90,
        )
        data = json.loads(result.stdout.strip())
        return data.get("description", "")
    except Exception:
        return ""

def _call_generator(script_name, prompt):
    """Appelle generators/<script_name> avec le prompt.
    Retourne l'URL produite (stdout) ou None si ComfyUI indisponible."""
    script = os.path.join(BRO_IA_PATH, "generators", script_name)
    if not os.path.isfile(script):
        return None
    try:
        result = subprocess.run(
            ["bash", script, prompt],
            capture_output=True, text=True, timeout=300,
        )
        url = result.stdout.strip()
        return url if url.startswith("http") else None
    except Exception:
        return None

_MEDIA_RUN_TIMEOUT_SEC = {"image": 300, "video": 300, "music": 300, "plantnet": 60, "inventory": 60, "tts": 150}

_MEDIA_PROGRESS_MSG = {
    "image": "🖼️ Génération d'image en cours",
    "video": "🎬 Génération vidéo en cours",
    "music": "🎵 Génération musicale en cours",
    "plantnet": "🌿 Identification botanique en cours",
    "inventory": "📦 Inventaire en cours",
    "tts": "🔊 Préparation de la réponse vocale en cours",
}

def _dispatch_media_background(media_type, owner_email, payload):
    """Valide (déjà fait par l'appelant) puis LANCE en tâche détachée le
    traitement média réel (_run_media_background) — jamais d'exécution
    synchrone ici. Même raison structurelle que le scraper et #craft/#badge :
    ces appels (ComfyUI jusqu'à 300s, reconnaissance jusqu'à 60s, TTS jusqu'à
    150s) bloquaient auparavant process_incoming_commands directement, avec
    le même risque de boucle de rejeu massive que l'incident du 2026-07-03."""
    try:
        subprocess.Popen(
            ["python3", BRO_WATCH_CORE_PATH, "run-media-background",
             media_type, owner_email, json.dumps(payload)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        return f"⚠️ Échec du lancement : {e}"
    timeout = _MEDIA_RUN_TIMEOUT_SEC.get(media_type, 120)
    progress = _MEDIA_PROGRESS_MSG.get(media_type, "⏳ Traitement en cours")
    return f"{progress}… (jusqu'à {timeout}s) — je vous enverrai le résultat par DM."

def _run_recognition_script(script_name, img_url, empty_msg, missing_msg, error_msg):
    """Factorise plantnet_recognition.py / inventory_recognition.py — même
    contrat (script img_url -> texte sur stdout), même venv, même timeout."""
    script = os.path.join(BRO_IA_PATH, script_name)
    if not os.path.isfile(script):
        return missing_msg
    venv_py = os.path.expanduser("~/.astro/bin/python3")
    py = venv_py if os.path.isfile(venv_py) else "python3"
    try:
        result = subprocess.run([py, script, img_url], capture_output=True, text=True, timeout=60)
        return result.stdout.strip() or empty_msg
    except Exception:
        return error_msg

def _run_media_background(media_type, owner_email, payload):
    """Exécute réellement le traitement média (appelé en sous-processus
    détaché par _dispatch_media_background) et notifie le résultat par DM.
    Logique identique à l'ancienne version synchrone de
    _handle_ia_responder_tags, seul le mode d'appel a changé."""
    if media_type == "image":
        url = _call_generator("generate_image.sh", payload["prompt"])
        reply = f"🖼️ Image générée :\n{url}" if url else \
            "⚠️ Génération d'image indisponible (ComfyUI non accessible — demandez à la constellation)."
    elif media_type == "video":
        url = _call_generator("generate_video.sh", payload["prompt"])
        reply = f"🎬 Vidéo générée :\n{url}" if url else "⚠️ Génération vidéo indisponible (ComfyUI non accessible)."
    elif media_type == "music":
        url = _call_generator("generate_music.sh", payload["prompt"])
        reply = f"🎵 Musique générée :\n{url}" if url else "⚠️ Génération musicale indisponible sur cette station."
    elif media_type == "plantnet":
        reply = _run_recognition_script(
            "plantnet_recognition.py", payload["img_url"],
            "⚠️ PlantNet n'a pas identifié de plante sur cette image.",
            "⚠️ PlantNet non installé sur cette station.", "⚠️ Service PlantNet indisponible.")
    elif media_type == "inventory":
        reply = _run_recognition_script(
            "inventory_recognition.py", payload["img_url"],
            "⚠️ Inventaire vide ou non reconnu.",
            "⚠️ Inventaire non disponible sur cette station.", "⚠️ Service inventaire indisponible.")
    elif media_type == "tts":
        voice = payload["voice"]
        clean_question = payload.get("clean_question", "")
        img_url = payload.get("img_url") or None
        if clean_question:
            # Import différé (même convention que skill_flashmem/bro_user_level
            # ailleurs dans ce codebase) : _conversational_reply reste dans
            # l'orchestrateur bro_watch_core.py, qui importe déjà bro.media —
            # un import en tête de module créerait un cycle au chargement.
            import bro_watch_core as _bwc
            text_reply = _bwc._conversational_reply(owner_email, clean_question, img_url)
            text_for_tts = re.sub(r'^[💬📋✅🤔🔔]\s*', '', text_reply).strip()
        else:
            text_for_tts = "BRO à votre service."
            text_reply = f"💬 {text_for_tts}"
        speech_script = os.path.join(BRO_IA_PATH, "generators", "generate_speech.sh")
        audio_url = ""
        if os.path.isfile(speech_script):
            try:
                result = subprocess.run(
                    ["bash", speech_script, text_for_tts, voice],
                    capture_output=True, text=True, timeout=120,
                )
                audio_url = result.stdout.strip()
            except Exception as exc:
                print(f"[BRO_WATCH] TTS échoué ({voice}) : {exc}")
        reply = f"{text_reply}\n\n🔊 Audio ({voice}) : {audio_url}" if audio_url else text_reply
    else:
        reply = "⚠️ Type de média inconnu."
    send_dm_to_owner(owner_email, reply, ttl_days=1)

_MEDIA_TAG_HANDLERS = (
    {
        "pattern": r'#image\b',
        "description": "#image PROMPT : génère une image (ComfyUI).",
        "build": lambda text, clean, img_url: ("image", {"prompt": clean or "abstract artwork"}),
    },
    {
        # DÉSACTIVÉ (2026-07-06, alerte capitaine) : generate_video.sh est un
        # GPU_HEAVY_GENERATORS (voir bro_node_reset.py) — jamais câblé sur un
        # déclenchement conversationnel automatique, charge GPU incontrôlable
        # depuis un simple message self-DM. Corrige une incohérence réelle :
        # le tag était dispatché automatiquement alors que la doctrine du
        # dépôt l'interdit explicitement pour ce générateur précis.
        "pattern": r'#vid[ée]o\b',
        "description": "#video : DÉSACTIVÉ (génération vidéo trop coûteuse en GPU pour un "
                        "déclenchement automatique — demande-le au capitaine directement).",
        "disabled_message": "⛔ La génération vidéo automatique est désactivée (trop coûteuse en GPU). "
                             "Demande directement au capitaine de la lancer manuellement si besoin.",
    },
    {
        "pattern": r'#music\b|#musique\b',
        "description": "#music PROMPT : génère de la musique (ComfyUI).",
        "build": lambda text, clean, img_url: ("music", {"prompt": clean or "ambient music"}),
    },
    {
        "pattern": r'#(?:plant(?:net|e)?|botanique|flora)\b',
        "description": "#plant + photo : identification botanique (PlantNet).",
        "requires_img": "🌿 Envoie une photo de plante avec #plant pour l'identification botanique.",
        "build": lambda text, clean, img_url: ("plantnet", {"img_url": img_url}),
    },
    {
        "pattern": r'#(?:inventory|inventaire)\b',
        "description": "#inventory + photo : inventaire automatique d'objets.",
        "requires_img": "📦 Envoie une photo avec #inventory pour l'inventaire automatique.",
        "build": lambda text, clean, img_url: ("inventory", {"img_url": img_url}),
    },
    {
        "pattern": r'#(?:pierre|am[ée]lie)\b',
        "description": "#pierre / #amelie TEXTE : synthèse vocale (voix Pierre ou Amélie).",
        "build": lambda text, clean, img_url: (
            "tts",
            {
                "voice": "amelie" if re.search(r'#am[ée]lie\b', text, re.IGNORECASE) else "pierre",
                "clean_question": re.sub(
                    r'#(?:bro|bot|pierre|am[ée]lie)\b', '', text, flags=re.IGNORECASE
                ).strip(),
                "img_url": img_url or "",
            },
        ),
    },
    {
        # advertise_only : pas de "pattern"/"build" — la reconnaissance
        # d'image SANS tag (img_url seul) est gérée ailleurs (repli
        # conversationnel avec image en contexte, voir _conversational_reply),
        # pas par cette boucle de dispatch. Entrée présente uniquement pour
        # que le texte d'aide la mentionne depuis cette même liste.
        "description": "Reconnaissance d'image : envoie une image (URL .jpg/.png/etc.) — "
                        "je la décris automatiquement, même sans tag.",
        "advertise_only": True,
    },
)

SCRAPER_RUN_TIMEOUT_SEC = 180

# ── Self-healing : suivi des échecs consécutifs ──────────────────────────
# Seuil : 3 cycles en erreur/0-item → déclenchement automatique d'arbor_scraper_forge --heal.
# Les codes de sortie distincts viennent de run_generated_scraper.py :
#   0 = succès avec items   → reset du compteur
#   1 = exception run()     → incrément "erreur"
#   2 = run() retourne []   → incrément "0 items" (scrapers générés uniquement)
#   3 = config manquante    → ignoré (pas une panne du scraper lui-même)
# Les scrapers existants (mastodon, discourse…) n'émettent que 0 ou !=0 ;
# le code 2 est réservé aux scrapers générés par arbor_scraper_forge.py.

HEAL_FAILURE_THRESHOLD = 3


def _scraper_failure_path(owner_email, domain):
    slug = re.sub(r"[^a-zA-Z0-9_-]", "_", domain)
    email_slug = re.sub(r"[^a-zA-Z0-9_-]", "_", owner_email)[:20]
    return os.path.expanduser(f"~/.zen/tmp/bro_scraper_health_{slug}_{email_slug}.json")


def _get_scraper_failure_state(owner_email, domain):
    """Retourne (count, last_error) — (0, '') si aucun échec enregistré."""
    try:
        with open(_scraper_failure_path(owner_email, domain)) as f:
            data = json.load(f)
        return data.get("count", 0), data.get("last_error", "")
    except Exception:
        return 0, ""


def _increment_scraper_failure(owner_email, domain, error_msg):
    """Incrémente le compteur d'échecs consécutifs. Retourne le nouveau count."""
    path = _scraper_failure_path(owner_email, domain)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception:
        data = {"count": 0}
    data["count"] = data.get("count", 0) + 1
    data["last_error"] = str(error_msg)[:500]
    try:
        with open(path, "w") as f:
            json.dump(data, f)
    except Exception:
        pass
    return data["count"]


def _reset_scraper_failure(owner_email, domain):
    """Remet le compteur à 0 après un cycle réussi avec items."""
    try:
        os.remove(_scraper_failure_path(owner_email, domain))
    except Exception:
        pass


def _trigger_scraper_heal(owner_email, domain, error_msg):
    """Lance arbor_scraper_forge.py --heal DOMAIN en tâche détachée.
    Appelé automatiquement après HEAL_FAILURE_THRESHOLD cycles en échec.
    Retourne True si le lancement a réussi."""
    forge_script = os.path.join(BRO_IA_PATH, "arbor_scraper_forge.py")
    if not os.path.isfile(forge_script):
        print(f"[BRO_WATCH] arbor_scraper_forge.py introuvable — self-healing désactivé pour {domain}")
        return False
    try:
        subprocess.Popen(
            [PYTHON_BIN, forge_script,
             "--heal", domain,
             "--owner-email", owner_email,
             "--error", error_msg[:500],
             "--notify-captain"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
        print(f"[BRO_WATCH] Self-healing lancé pour {domain} "
              f"(seuil {HEAL_FAILURE_THRESHOLD} atteint)")
        return True
    except Exception as e:
        print(f"[BRO_WATCH] Échec lancement self-healing pour {domain} : {e}")
        return False


def _cookie_file_path(owner_email, domain):
    return os.path.join(_owner_dir(owner_email), f".{domain}.cookie")

def _find_scraper_script(domain):
    """Même résolution que NOSTRCARD.refresh.sh : IA/scrapers/*/DOMAIN.sh en
    priorité, repli sur IA/DOMAIN.sh (legacy)."""
    scrapers_dir = os.path.join(BRO_IA_PATH, "scrapers")
    try:
        for sub in sorted(os.listdir(scrapers_dir)):
            candidate = os.path.join(scrapers_dir, sub, f"{domain}.sh")
            if os.path.isfile(candidate):
                return candidate
    except Exception:
        pass
    legacy = os.path.join(BRO_IA_PATH, f"{domain}.sh")
    return legacy if os.path.isfile(legacy) else None

_SCRAPER_ICONS = {
    "mastodon": "🦣", "youtube": "📺", "leboncoin": "🏷️",
    "duniter": "🔐", "monnaie-libre": "🌻", "google": "🔍",
}

def list_station_scrapers():
    """Retourne tous les scrapers disponibles sur cette station : domaine, catégorie, icône, description.
    Lecture des en-têtes de scripts (ligne «  — …» dans les 10 premières lignes)."""
    result = []
    seen = set()
    scrapers_dir = os.path.join(BRO_IA_PATH, "scrapers")
    try:
        for category in sorted(os.listdir(scrapers_dir)):
            cat_path = os.path.join(scrapers_dir, category)
            if not os.path.isdir(cat_path):
                continue
            for fname in sorted(os.listdir(cat_path)):
                if not fname.endswith(".sh") or fname.startswith("process_"):
                    continue
                domain = fname[:-3]
                if domain in seen:
                    continue
                seen.add(domain)
                desc = ""
                try:
                    with open(os.path.join(cat_path, fname)) as fh:
                        for _, line in zip(range(10), fh):
                            line = line.strip().lstrip("#").strip()
                            if "—" in line:
                                desc = line.split("—", 1)[1].strip()
                                break
                except Exception:
                    pass
                result.append({
                    "domain":      domain,
                    "category":    category,
                    "icon":        _SCRAPER_ICONS.get(category, "🍪"),
                    "description": desc or f"Surveillance {domain}",
                })
    except Exception:
        pass
    return result

def _available_scraper_domains(owner_email):
    """Domaines pour lesquels le propriétaire a déposé un cookie ET dont le
    fichier cookie en clair existe encore localement (condition réelle
    d'exécution, pas seulement la présence dans le manifest)."""
    manifest = _load_manifest(owner_email)
    return [d for d in manifest if os.path.isfile(_cookie_file_path(owner_email, d))]

def _extract_scraper_domain(owner_email, text):
    """Cherche lequel des domaines déjà déposés (cookie réel présent) est
    mentionné dans le texte — match sur le domaine complet ou son premier
    label (ex: 'mastodon' matche 'mastodon.social')."""
    lowered = text.lower()
    for domain in _available_scraper_domains(owner_email):
        if domain.lower() in lowered or domain.split(".")[0].lower() in lowered:
            return domain
    return None

def _run_scraper_now(owner_email, domain):
    """Lance un scraper à la demande du capitaine EN TÂCHE DÉTACHÉE (symétrique
    à _trigger_arbor_self_improve) et répond immédiatement — ne bloque JAMAIS
    process_incoming_commands. Incident réel (2026-07-03) : la version
    précédente exécutait le scraper de façon SYNCHRONE (jusqu'à
    SCRAPER_RUN_TIMEOUT_SEC=180s) directement dans _handle_command_text ;
    toute interférence externe pendant ce blocage prolongé (watchdog,
    kill, etc.) empêchait la persistance finale de last_check/dédup dans
    process_incoming_commands, et la commande — ainsi que TOUTES celles du
    même lot — étaient rejouées à l'infini (des centaines de "le scraper n'a
    pas terminé sous 180s" envoyés en boucle). Le résultat réel est envoyé
    par un second DM une fois le scraper terminé (_run_scraper_background)."""
    if not is_scraper_enabled(owner_email, domain):
        return f"🔒 Le scraper {domain} est désactivé (voir /mailjet pour le réactiver)."
    cookie_file = _cookie_file_path(owner_email, domain)
    if not os.path.isfile(cookie_file):
        return f"🍪 Aucun cookie déposé pour {domain} — déposez-en un sur /cookie."
    script = _find_scraper_script(domain)
    if not script:
        return f"⚠️ Aucun scraper disponible pour {domain} sur cette station."

    try:
        subprocess.Popen(
            ["python3", BRO_WATCH_CORE_PATH, "run-scraper-background",
             owner_email, domain, script, cookie_file],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        return f"⚠️ Échec du lancement du scraper {domain} : {e}"
    return (f"🚀 Scraper {domain} lancé en arrière-plan — je vous enverrai le résultat "
            f"dès qu'il aura terminé (jusqu'à {SCRAPER_RUN_TIMEOUT_SEC}s).")

def _run_scraper_background(owner_email, domain, script, cookie_file):
    """Exécute réellement le scraper (appelé en sous-processus détaché par
    _run_scraper_now — voir sa docstring) et notifie le résultat par DM.

    Intègre le suivi des échecs consécutifs pour le self-healing (Pilier 3
    d'arbor_scraper_forge.py) : 3 cycles en erreur ou sans item (exit 2 des
    scrapers générés) déclenchent automatiquement arbor_scraper_forge --heal."""
    log_path = os.path.expanduser(f"~/.zen/tmp/{domain}_sync_{owner_email}.log")
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    try:
        result = subprocess.run(
            ["bash", script, owner_email, cookie_file],
            capture_output=True, text=True, timeout=SCRAPER_RUN_TIMEOUT_SEC,
        )
        output = (result.stdout or "") + (result.stderr or "")
        returncode = result.returncode
    except subprocess.TimeoutExpired:
        send_dm_to_owner(owner_email,
                          f"⏱️ Le scraper {domain} n'a pas terminé sous {SCRAPER_RUN_TIMEOUT_SEC}s.",
                          ttl_days=1)
        error_msg = f"timeout après {SCRAPER_RUN_TIMEOUT_SEC}s"
        new_count = _increment_scraper_failure(owner_email, domain, error_msg)
        if new_count >= HEAL_FAILURE_THRESHOLD:
            _reset_scraper_failure(owner_email, domain)
            if _trigger_scraper_heal(owner_email, domain, error_msg):
                send_dm_to_owner(owner_email,
                    f"🔧 Le scraper {domain} est en timeout depuis {HEAL_FAILURE_THRESHOLD} jours. "
                    "Réparation automatique lancée.", ttl_days=1)
        return
    except Exception as e:
        send_dm_to_owner(owner_email, f"⚠️ Échec du scraper {domain} : {e}", ttl_days=1)
        return

    try:
        with open(log_path, "w", encoding="utf-8") as f:
            f.write(output)
        store_log(owner_email, domain, output)
    except Exception:
        pass

    # Dernière ligne informative du log (les scrapers impriment un résumé
    # type "Terminé — N nouvelle(s) mention(s)…") plutôt que tout le log brut.
    summary_lines = [l for l in output.strip().splitlines() if l.strip()]
    summary = summary_lines[-1] if summary_lines else "(aucune sortie)"

    # ── Suivi des échecs consécutifs pour le self-healing ─────────────────
    if returncode == 0:
        # Succès avec items → réinitialiser le compteur d'échecs
        _reset_scraper_failure(owner_email, domain)
        msg = f"✅ Scraper {domain} exécuté :\n{summary}"

    elif returncode == 2:
        # 0 items retournés (scrapers générés via run_generated_scraper.py) —
        # peut être légitime un jour calme, mais 3 fois consécutifs = suspect.
        new_count = _increment_scraper_failure(owner_email, domain, "0 items retournés")
        print(f"[BRO_WATCH] Scraper {domain} : 0 item "
              f"(cycle {new_count}/{HEAL_FAILURE_THRESHOLD})")
        if new_count >= HEAL_FAILURE_THRESHOLD:
            _reset_scraper_failure(owner_email, domain)
            heal_msg = "0 items retournés pendant 3 cycles consécutifs"
            if _trigger_scraper_heal(owner_email, domain, heal_msg):
                send_dm_to_owner(owner_email,
                    f"🔧 Le scraper {domain} retourne 0 item depuis "
                    f"{HEAL_FAILURE_THRESHOLD} jours. Réparation automatique lancée "
                    "(plusieurs minutes).", ttl_days=1)
        # Pas de DM séparé pour le résumé — le rapport quotidien de process_watch_digest
        # a déjà été envoyé (ou indique "rien de pertinent") depuis run_generated_scraper.py
        return

    elif returncode == 3:
        # Erreur de configuration (module manquant, cookie absent) — ne compte pas
        # comme panne du scraper lui-même, pas de déclenchement heal.
        msg = f"⚠️ Scraper {domain} : erreur de configuration (code 3) :\n{summary}"

    else:
        # returncode != 0, 2, 3 → exception réelle dans le scraper
        error_lines = [l for l in output.strip().splitlines()
                       if "ERROR:" in l or "Traceback" in l or l.strip()]
        error_msg = error_lines[-1][:300] if error_lines else f"code de sortie {returncode}"
        new_count = _increment_scraper_failure(owner_email, domain, error_msg)
        print(f"[BRO_WATCH] Scraper {domain} : erreur "
              f"(cycle {new_count}/{HEAL_FAILURE_THRESHOLD})")
        if new_count >= HEAL_FAILURE_THRESHOLD:
            _reset_scraper_failure(owner_email, domain)
            if _trigger_scraper_heal(owner_email, domain, error_msg):
                send_dm_to_owner(owner_email,
                    f"🔧 Le scraper {domain} est en erreur depuis "
                    f"{HEAL_FAILURE_THRESHOLD} jours. Réparation automatique lancée "
                    "(plusieurs minutes).", ttl_days=1)
        msg = f"⚠️ Scraper {domain} terminé avec une erreur (code {returncode}) :\n{summary}"

    send_dm_to_owner(owner_email, msg, ttl_days=1)

CRAFT_RUN_TIMEOUT_SEC = 90     # question.py, cf. _run_craft_background

BADGE_RUN_TIMEOUT_SEC = 300    # ComfyUI, cf. _run_badge_background (même durée que _call_generator)

def _run_craft_background(owner_email, url):
    """Exécute réellement le pipeline #craft (appelé en sous-processus détaché
    par _tool_craft — voir sa docstring) et notifie le résultat par DM. Même
    pipeline que bro_dm_daemon.sh::_handle_craft (bro_url_content.py ->
    describe_image.py en repli -> question.py pour extraire le JSON recette)."""
    content = ""
    try:
        result = subprocess.run(["python3", os.path.join(BRO_IA_PATH, "bro_url_content.py"), url],
                                 capture_output=True, text=True, timeout=30)
        content = result.stdout.strip()[:6000]
    except Exception:
        pass
    if len(content) < 80:
        content = _describe_image_url(url)[:4000]
    if len(content) < 40:
        send_dm_to_owner(owner_email, f"❌ Impossible de récupérer le contenu de : {url}", ttl_days=1)
        return

    prompt = (
        "Tu es un assistant pédagogique Crafting Mine Life sur UPlanet. Analyse ce tutoriel et "
        "identifie les compétences requises.\n"
        "Réponds UNIQUEMENT en JSON valide sur une seule ligne (aucun texte autour, aucun markdown) :\n"
        '{"name":"Nom en français","icon":"emoji","description":"1 phrase",'
        '"ingredients":[{"skill":"nom_skill","level":1}],"resource_type":"lien"}\n'
        "Règles strictes :\n"
        "- skills : minuscules, pas d'espaces (underscores), 1-3 mots (ex: arduino, soudure, electronique_base)\n"
        "- level : 1=débutant 2=intermédiaire 3=avancé\n"
        "- 2 à 6 ingrédients\n"
        f"- resource_type : \"document\", \"video\" ou \"lien\"\n\n"
        f"Tutoriel :\n{wrap_untrusted('scraped_content', content)}"
    )
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as f:
            f.write(prompt)
            tmp_path = f.name
        result = subprocess.run(
            [PYTHON_BIN, os.path.join(BRO_IA_PATH, "question.py"),
             "--prompt-file", tmp_path, "--model", "gemma3:latest",
             "--ctx", "8192", "--max-tokens", "256", "--temperature", "0.2"],
            capture_output=True, text=True, timeout=CRAFT_RUN_TIMEOUT_SEC,
        )
        answer = result.stdout.strip()
    except subprocess.TimeoutExpired:
        send_dm_to_owner(owner_email, f"⏱️ Analyse #craft de {url} non terminée sous {CRAFT_RUN_TIMEOUT_SEC}s.", ttl_days=1)
        return
    except Exception as e:
        send_dm_to_owner(owner_email, f"❌ Analyse IA indisponible : {e}", ttl_days=1)
        return
    finally:
        if tmp_path:
            try:
                os.remove(tmp_path)
            except Exception:
                pass

    json_match = re.search(r"\{.*\}", answer, re.DOTALL)
    reply = json_match.group(0) if json_match else (answer or '{"error":"IA indisponible — réessayez plus tard"}')
    send_dm_to_owner(owner_email, reply, ttl_days=1)

def _run_badge_background(owner_email, skill):
    """Exécute réellement la génération ComfyUI (appelé en sous-processus
    détaché par _tool_badge) et notifie le résultat par DM. Même prompt que
    bro_dm_daemon.sh::_handle_badge — réutilise _call_generator (même
    générateur que #image, donc même charge GPU qu'une génération d'image
    normale, jamais de vidéo)."""
    prompt = (f"A pixel art badge icon for the '{skill}' skill, hexagonal shape, vibrant colors, "
              "dark background, technology emblem, professional logo, 8-bit style, clean design, WoTx2 skill badge")
    url = _call_generator("generate_image.sh", prompt)
    if url:
        reply = (f"✅ Badge '{skill}' généré !\n🖼️ {url}\n\n"
                 "Copiez ce lien pour l'ajouter comme ressource dans l'onglet Formation de my_wotx2.html")
    else:
        reply = f"❌ Échec de la génération pour '{skill}'. Vérifiez que ComfyUI est démarré (port 8188)."
    send_dm_to_owner(owner_email, reply, ttl_days=1)
