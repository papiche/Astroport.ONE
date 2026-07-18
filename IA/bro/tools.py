#!/usr/bin/env python3
"""
bro.tools — Registre d'outils BRO : niveaux d'accès, gestionnaires #tag gated, outils Arbor actifs (tools_generated/), intégration algorithm_planner.

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
import bro_tools
import observability
try:
    import bro_user_level
except Exception:
    bro_user_level = None
from bro._shared import BRO_IA_PATH, BRO_WATCH_CORE_PATH, RELAYS, _now_iso, _owner_hex
from bro.media import BADGE_RUN_TIMEOUT_SEC, CRAFT_RUN_TIMEOUT_SEC, _available_scraper_domains, _extract_scraper_domain, _run_scraper_now
from bro.identity import _dispatch_identity_update_check, list_preferences_history, rollback_preferences
from bro.nostr import send_dm_to_owner

__all__ = ['ACTIVE_TOOLS_FILE', 'TOOLS_GENERATED_DIR', 'list_active_tools', '_extract_tool_docstring', '_call_tool', '_extract_manifest_routing_examples', '_register_arbor_tool', 'activate_tool', 'add_tool_examples', 'deactivate_tool', '_load_arbor_tools_into_registry', 'TOOL_ROUTING_MODEL', '_META_CAPABILITY_PHRASES', 'match_tool', '_try_registered_tools', '_slots_from_text', '_generic_slot_file', '_persist_slot_content', '_format_slot_summary', '_clear_slot', '_tool_help', '_tool_mem', '_tool_reset', '_tool_pref', '_tool_rec', '_tool_scraper', 'ACCESS_LEVEL_ATOME', 'ACCESS_LEVEL_SATELLITE', 'ACCESS_LEVEL_CAPITAINE', '_owner_access_level', '_ACCESS_LEVEL_LABEL', '_make_gated_handler', '_tool_craft', '_tool_badge', '_tool_rec_skill', '_tool_mem_skill', '_tool_mod_skill', '_tool_rm_skill', '_notify_captain_skill_contribution', '_run_skill_notify_background', '_register_system_tools']



ACTIVE_TOOLS_FILE = os.path.expanduser("~/.zen/flashmem/bro_active_tools.json")

TOOLS_GENERATED_DIR = os.path.join(BRO_IA_PATH, "tools_generated")

def list_active_tools():
    try:
        with open(ACTIVE_TOOLS_FILE, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def _extract_tool_docstring(module_name):
    """Repli d'auto-description : premier PARAGRAPHE du docstring du module
    (jusqu'à la première ligne vide), si le capitaine n'a pas fourni de
    description explicite à l'activation. Une seule ligne tronquerait des
    phrases écrites sur plusieurs lignes (cas courant du code généré)."""
    tool_path = os.path.join(TOOLS_GENERATED_DIR, f"{module_name}.py")
    try:
        with open(tool_path, encoding="utf-8") as f:
            content = f.read()
        match = re.match(r'^\s*"""(.*?)(?:\n\n|""")', content, re.DOTALL)
        if match:
            paragraph = " ".join(line.strip() for line in match.group(1).strip().splitlines())
            return re.sub(r"\s+", " ", paragraph).strip()
    except Exception:
        pass
    return module_name

def _call_tool(module_name, query, owner_email=None):
    """Charge et exécute un outil généré (contrat : def run(query: str) -> str).
    Échoue silencieusement (None) — l'appelant retombe alors sur la conversation
    normale plutôt que de planter le canal self-DM pour un outil défaillant."""
    tool_path = os.path.join(TOOLS_GENERATED_DIR, f"{module_name}.py")
    if not os.path.isfile(tool_path):
        return None
    _t0 = time.monotonic()
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location(module_name, tool_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        result = module.run(query)
        observability.log_event(owner_email, module_name, "arbor_tool",
                                 success=bool(result), latency_ms=(time.monotonic() - _t0) * 1000)
        return result
    except Exception as e:
        print(f"[BRO_WATCH] Appel outil '{module_name}' échoué : {e}")
        observability.log_event(owner_email, module_name, "arbor_tool",
                                 success=False, latency_ms=(time.monotonic() - _t0) * 1000)
        return None

def _extract_manifest_routing_examples(module_name):
    """Lit tools_generated/<module>.md (généré par arbor_tool_forge.py) pour
    en extraire les paraphrases de routage, si présentes. Repli silencieux
    ([]) pour les outils forgés avant l'introduction de ce champ (ex:
    tool_meteo, activé le 2026-07-03) — activate_tool()/add-tool-examples
    permettent de les fournir manuellement dans ce cas."""
    manifest_path = os.path.join(TOOLS_GENERATED_DIR, f"{module_name}.md")
    try:
        with open(manifest_path, encoding="utf-8") as f:
            content = f.read()
    except Exception:
        return []
    match = re.search(r"Exemples de routage[^:]*:\n((?:- .+\n?)+)", content)
    if not match:
        return []
    return [line[2:].strip() for line in match.group(1).splitlines() if line.startswith("- ")]

def _register_arbor_tool(module_name, info):
    """Reflète un outil forgé par Arbor (persisté dans ACTIVE_TOOLS_FILE) dans
    le registre bro_tools — même représentation que les tags système, pour que
    _bro_capabilities_description n'ait plus qu'UNE seule boucle à maintenir.
    `examples` (si présents) rendent l'outil visible à match_intent() — le
    routage à marge (positif/négatifs partagés), plus robuste que le seuil
    fixe de match_tool() (voir l'incident documenté sur cette fonction)."""
    bro_tools.register(bro_tools.Tool(
        name=module_name,
        description=info.get("description", module_name),
        handler=lambda owner_email, text, _m=module_name: _call_tool(_m, text, owner_email),
        source="arbor",
        examples=tuple(info.get("examples") or ()),
    ))

def activate_tool(module_name, description=None, examples=None):
    """`examples` : paraphrases de routage explicites (prioritaires) —
    sinon auto-extraites du manifeste .md s'il existe (outils forgés après
    l'introduction de ce champ), sinon liste vide (l'outil reste routable
    via match_tool(), moins robuste, jusqu'à ce que des exemples soient
    ajoutés via add-tool-examples)."""
    tool_path = os.path.join(TOOLS_GENERATED_DIR, f"{module_name}.py")
    if not os.path.isfile(tool_path):
        return False, f"Fichier introuvable : {tool_path} — la branche a-t-elle été mergée ?"
    tools = list_active_tools()
    if examples is None:
        examples = _extract_manifest_routing_examples(module_name)
    tools[module_name] = {
        "description": description or _extract_tool_docstring(module_name),
        "activated_at": _now_iso(),
        "examples": list(examples or []),
    }
    os.makedirs(os.path.dirname(ACTIVE_TOOLS_FILE), exist_ok=True)
    with open(ACTIVE_TOOLS_FILE, "w", encoding="utf-8") as f:
        json.dump(tools, f, ensure_ascii=False, indent=2)
    _register_arbor_tool(module_name, tools[module_name])
    n_ex = len(tools[module_name]["examples"])
    ex_note = (f", {n_ex} exemple(s) de routage (match_intent à marge)" if n_ex
               else " — AUCUN exemple de routage : repli sur le seuil fixe de match_tool "
                    "(moins robuste), utiliser add-tool-examples pour corriger")
    return True, f"Outil '{module_name}' activé : {tools[module_name]['description']}{ex_note}"

def add_tool_examples(module_name, examples):
    """Ajoute/remplace les paraphrases de routage d'un outil déjà actif —
    backfill pour les outils activés avant l'introduction de ce champ (ex:
    tool_meteo) sans repasser par tout le cycle activate_tool()."""
    tools = list_active_tools()
    if module_name not in tools:
        return False, f"'{module_name}' n'est pas actif — utiliser activate-tool d'abord."
    tools[module_name]["examples"] = list(examples)
    with open(ACTIVE_TOOLS_FILE, "w", encoding="utf-8") as f:
        json.dump(tools, f, ensure_ascii=False, indent=2)
    _register_arbor_tool(module_name, tools[module_name])
    return True, f"'{module_name}' : {len(examples)} exemple(s) de routage enregistré(s)."

def deactivate_tool(module_name):
    tools = list_active_tools()
    if module_name not in tools:
        return False, f"'{module_name}' n'est pas actif."
    del tools[module_name]
    with open(ACTIVE_TOOLS_FILE, "w", encoding="utf-8") as f:
        json.dump(tools, f, ensure_ascii=False, indent=2)
    bro_tools.unregister(module_name)
    return True, f"Outil '{module_name}' désactivé."

def _load_arbor_tools_into_registry():
    """Reflète l'état persisté (ACTIVE_TOOLS_FILE) dans le registre en mémoire —
    appelé au chargement du module, pour qu'un process qui redémarre retrouve
    les outils déjà activés par un précédent process."""
    for module_name, info in list_active_tools().items():
        _register_arbor_tool(module_name, info)

_META_CAPABILITY_PHRASES = (
    "que sais-tu faire", "qu'est-ce que tu sais faire", "à quels outils",
    "a quels outils", "quelles sont tes capacités", "que peux-tu faire",
    "tes fonctionnalités", "c'est quoi tes commandes", "quelles commandes",
    # Incident réel (2026-07-06) : "existe-t-il une série de commandes que tu
    # comprends" a matché tool_meteo à 0.67 — une marge sémantique contre les
    # négatifs partagés a été testée pour remplacer cette liste (voir le
    # commentaire dans match_tool()) mais cassait aussi une vraie requête
    # météo (nomic-embed-text ne sépare pas assez ces phrases courtes) ;
    # patch ciblé conservé, comme pour les entrées précédentes de cette liste.
    "série de commandes", "liste des commandes", "liste de commandes",
    # Questions temporelles — ne jamais router vers un outil (ex: tool_meteo)
    "quelle heure", "il est quelle heure", "quelle heure est-il",
    "quelle heure est il", "l'heure", "donne moi l'heure", "what time",
)

TOOL_ROUTING_MODEL = "hermes3:latest"

def match_tool(text):
    """Détermine quel outil actif correspond sémantiquement à la requête,
    SANS l'exécuter — séparé de _try_registered_tools pour permettre de
    tester le ROUTAGE seul. Retourne (module_name, score) ou None.

    Historique (jusqu'au 2026-07-06) : routage par similarité cosinus
    (nomic-embed-text) entre l'embedding du texte et celui de la description
    de chaque outil — remplacé ci-dessous par du function calling natif
    Ollama, pour la raison suivante, vérifiée empiriquement en conditions
    réelles : nomic-embed-text ne sépare pas assez les commandes courtes et
    impératives pour un seuil fixe fiable. Deux faux positifs réels ont dû
    être patchés au cas par cas (_META_CAPABILITY_PHRASES, exclusion des
    outils déjà couverts par match_intent) plutôt que résolus structurellement
    — "existe-t-il une série de commandes que tu comprends ?" scorait 0.67
    contre tool_meteo, "Je veux que tu améliore ton code..." scorait 0.69.

    Function calling natif : le modèle lit les VRAIES descriptions des outils
    (jamais un texte séparé qui pourrait diverger, même principe que le reste
    du registre bro_tools) et décide lui-même s'il y a lieu d'appeler l'un
    d'eux — plus de calcul de distance vectorielle. Testé sur les 6 cas
    documentés ci-dessus (0 faux positif) avec TOOL_ROUTING_MODEL.

    Note modèle (2026-07-06) : COMMAND_INTERPRETATION_MODEL (qwen2.5-coder:14b)
    déclare la capability "tools" côté Ollama mais ne renvoie JAMAIS de
    tool_calls structurés dans cet environnement — le JSON de l'appel reste
    piégé dans `message.content`, jamais extrait (vérifié directement contre
    l'API Ollama, reproductible). hermes3:latest et mistral-small3.1:latest
    fonctionnent correctement ; hermes3 retenu pour la latence (~2.5s contre
    ~11s à froid pour un modèle 24B) — ce chemin ne s'exécute de toute façon
    que pour des outils Arbor SANS examples encore (fenêtre transitoire avant
    add_tool_examples), pas sur le flux conversationnel général."""
    lowered = text.strip().lower()
    if any(phrase in lowered for phrase in _META_CAPABILITY_PHRASES):
        return None
    # Un outil déjà couvert par match_intent() (a des examples) ne doit pas
    # repasser par ce mécanisme de repli — voir historique ci-dessus.
    arbor_tools = [t for t in bro_tools.all_tools() if t.source == "arbor" and not t.examples]
    if not arbor_tools:
        return None
    tools_spec = [{
        "type": "function",
        "function": {
            "name": t.name,
            "description": t.description,
            "parameters": {
                "type": "object",
                "properties": {"query": {"type": "string",
                                          "description": "La requête de l'utilisateur"}},
                "required": ["query"],
            },
        },
    } for t in arbor_tools]
    valid_names = {t.name for t in arbor_tools}
    try:
        import ollama
        response = ollama.chat(
            model=TOOL_ROUTING_MODEL,
            messages=[{"role": "user", "content": text}],
            tools=tools_spec,
            options={"temperature": 0.0},
        )
        calls = response.get("message", {}).get("tool_calls") or []
        if not calls:
            return None
        name = calls[0].get("function", {}).get("name")
        if name in valid_names:
            return name, 1.0
        return None
    except Exception as e:
        print(f"[BRO_WATCH] match_tool (function calling) indisponible : {e}")
        return None

def _try_registered_tools(owner_email, text):
    """Route vers un outil activé si sa description matche sémantiquement la
    requête. Retourne None (repli conversation normale) si aucun outil ne
    matche, ou si l'outil matché échoue à répondre."""
    match = match_tool(text)
    if not match:
        return None
    best_module, best_score = match
    result = _call_tool(best_module, text, owner_email)
    if result:
        print(f"[BRO_WATCH] Requête routée vers l'outil '{best_module}' (score {best_score:.2f})")
        return result
    return None

def _slots_from_text(text):
    """Détecte les tags #1..#12 et #all dans le texte (cohérent avec
    bro_dm_daemon.sh et UPlanet_IA_Responder.sh) — retourne la liste des
    slots visés. #all → tous les slots (0-12), priorité sur les #N
    explicites. Sans #all ni #N, seul le slot 0 (personnel) est visé —
    jamais tous les slots par défaut."""
    if re.search(r"#all\b", text, re.IGNORECASE):
        return list(range(13))
    slots = [i for i in range(1, 13) if re.search(rf"#{i}\b", text)]
    return slots or [0]

def _generic_slot_file(owner_email, slot):
    return os.path.expanduser(f"~/.zen/flashmem/{owner_email}/slot{slot}.json")

def _persist_slot_content(owner_email, slot, content):
    """#rec — mémorise EXPLICITEMENT une note dans le slot demandé (0-12,
    système documenté dans BRO_HELP_COMMANDS.md), distinct du rappel
    automatique de conversation (BRO_MEMORY_SLOT). Même mécanique que
    _remember_exchange : fichier local (lu par question.py --slot) + Qdrant
    (memory_manager.py, pour la recherche sémantique)."""
    try:
        from datetime import datetime
        ts = datetime.utcnow().isoformat() + "Z"
        slot_file = _generic_slot_file(owner_email, slot)
        os.makedirs(os.path.dirname(slot_file), exist_ok=True)
        if os.path.isfile(slot_file):
            with open(slot_file, encoding="utf-8") as f:
                slot_mem = json.load(f)
        else:
            slot_mem = {"user_id": owner_email, "slot": slot, "messages": []}
        slot_mem["messages"].append({"timestamp": ts, "content": content})
        slot_mem["messages"] = slot_mem["messages"][-200:]
        with open(slot_file, "w", encoding="utf-8") as f:
            json.dump(slot_mem, f, indent=2, ensure_ascii=False)

        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        mm.upsert_user_slot(owner_email, slot, content, timestamp=ts)
        if len(slot_mem["messages"]) >= 170:
            mm.reve_compress_slot(owner_email, slot, slot_file=slot_file)
        return True
    except Exception as e:
        print(f"[BRO_WATCH] #rec indisponible pour {owner_email} slot {slot} : {e}")
        return False

def _format_slot_summary(owner_email, slot, limit=5):
    slot_file = _generic_slot_file(owner_email, slot)
    try:
        with open(slot_file, encoding="utf-8") as f:
            messages = json.load(f).get("messages", [])
    except Exception:
        return None
    if not messages:
        return None
    lines = [f"- {m.get('content', '')}" for m in messages[-limit:]]
    return "\n".join(lines)

def _clear_slot(owner_email, slot):
    slot_file = _generic_slot_file(owner_email, slot)
    try:
        if os.path.isfile(slot_file):
            os.remove(slot_file)
    except Exception:
        pass
    try:
        import sys
        sys.path.insert(0, BRO_IA_PATH)
        import memory_manager as mm
        mm.delete_user_slot(owner_email, slot)
    except Exception:
        pass

def _tool_help(owner_email, text):
    # Import différé : _bro_capabilities_description reste dans l'orchestrateur
    # bro_watch_core.py (glue multi-domaines), qui importe déjà bro.tools — un
    # import en tête de module créerait un cycle au chargement.
    import bro_watch_core as _bwc
    lines = _bwc._bro_capabilities_description(owner_email).split("\n")
    lines.append("")
    lines.append("Voir aussi : #mem (souvenirs), #reset (les effacer), #rec <texte> (en noter un).")
    return "\n".join(lines)

def _filter_accessible_slots(owner_email, slots):
    """Sépare les slots demandés en (accessibles, refusés). Slot 0 toujours
    accessible ; slots 1-12 réservés au niveau BRO réel ≥ ACCESS_LEVEL_SATELLITE
    (sociétaire), même seuil et même source de vérité (bro_user_level.py) que
    bro_dm_daemon.sh::_check_slot_access (canal NODE) et
    UPlanet_IA_Responder.sh::check_memory_slot_access (canal public,
    aujourd'hui désactivé). Avant ce fix, #mem/#reset n'avaient ICI absolument
    aucune vérification (contrairement à #craft/#badge/#rec:<skill>, déjà
    gated via _make_gated_handler) — n'importe quel niveau pouvait lire/effacer
    n'importe quel slot 1-12 par self-DM."""
    if not any(s > 0 for s in slots):
        return slots, []
    if _owner_access_level(owner_email) >= ACCESS_LEVEL_SATELLITE:
        return slots, []
    return [s for s in slots if s == 0], [s for s in slots if s != 0]

def _tool_mem(owner_email, text):
    slots = _slots_from_text(text)
    accessible, denied = _filter_accessible_slots(owner_email, slots)
    parts = []
    for slot in accessible:
        summary = _format_slot_summary(owner_email, slot)
        parts.append(f"Slot {slot} :\n{summary}" if summary else f"Slot {slot} : (vide)")
    if denied:
        denied_str = ", ".join(str(s) for s in denied)
        parts.append(f"🔒 Slot(s) {denied_str} réservé(s) aux sociétaires "
                      f"({_ACCESS_LEVEL_LABEL[ACCESS_LEVEL_SATELLITE]}).")
    if not parts:
        return "⚠️ Aucun slot accessible."
    return "🧠 " + "\n\n".join(parts)

def _tool_reset(owner_email, text):
    slots = _slots_from_text(text)
    accessible, denied = _filter_accessible_slots(owner_email, slots)
    for slot in accessible:
        _clear_slot(owner_email, slot)
    parts = []
    if accessible:
        slots_str = ", ".join(str(s) for s in accessible)
        parts.append(f"🗑️ Mémoire effacée (slot{'s' if len(accessible) > 1 else ''} {slots_str}).")
    if denied:
        denied_str = ", ".join(str(s) for s in denied)
        parts.append(f"🔒 Slot(s) {denied_str} réservé(s) aux sociétaires "
                      f"({_ACCESS_LEVEL_LABEL[ACCESS_LEVEL_SATELLITE]}).")
    return "\n".join(parts) if parts else "⚠️ Aucun slot accessible."

def _tool_pref(owner_email, text):
    """#pref history : liste les dernières mises à jour de .Preferences.md.
    #pref rollback <n> : annule les n dernières réécritures (défaut 1).
    Données personnelles de l'utilisateur — jamais gated, comme #rec/#reset."""
    m = re.search(r"#pref\s+rollback(?:\s+(\d+))?", text, re.IGNORECASE)
    if m:
        steps = int(m.group(1)) if m.group(1) else 1
        ok, msg = rollback_preferences(owner_email, steps)
        return f"✅ {msg}" if ok else f"❌ {msg}"
    if re.search(r"#pref\s+history", text, re.IGNORECASE):
        entries = list_preferences_history(owner_email, limit=10)
        if not entries:
            return "📚 Aucun historique de préférences pour l'instant."
        lines = [f"{i}. [{e.get('timestamp', '?')[:10]}] {e.get('trigger_line', '?')}"
                 for i, e in enumerate(reversed(entries), start=1)]
        return ("📚 Historique de vos préférences (1 = plus récente) :\n" + "\n".join(lines) +
                "\n\nRestaurer : #pref rollback <n>  (n = nombre de mises à jour à annuler)")
    return ("⚠️ Usage : #pref history (voir les mises à jour récentes) ou "
            "#pref rollback <n> (annuler les n dernières, défaut 1)")

def _tool_rec(owner_email, text):
    slots = _slots_from_text(text)
    # Texte à mémoriser : le message débarrassé des tags #rec/#N eux-mêmes.
    content = re.sub(r"#rec\b", "", text, flags=re.IGNORECASE)
    content = re.sub(r"#\d{1,2}\b", "", content).strip()
    if not content:
        return "🤔 Dites-moi quoi mémoriser, par exemple « #rec j'aime le jardinage »."
    ok = all(_persist_slot_content(owner_email, slot, content) for slot in slots)
    if ok:
        # Biographie auto-mutative : ce souvenir modifie-t-il potentiellement
        # l'identité durable de l'utilisateur ? Évalué en tâche détachée,
        # jamais synchrone avec cette réponse (voir _dispatch_identity_update_check).
        _dispatch_identity_update_check(owner_email, content)
    slots_str = ", ".join(str(s) for s in slots)
    return f"✅ Noté dans le slot{'s' if len(slots) > 1 else ''} {slots_str}." if ok else \
        "⚠️ Échec de la mémorisation (Qdrant indisponible ?)."

def _tool_scraper(owner_email, text):
    domain = _extract_scraper_domain(owner_email, text)
    if domain:
        return _run_scraper_now(owner_email, domain)
    available = _available_scraper_domains(owner_email)
    if not available:
        return "🍪 Aucun cookie déposé pour l'instant — déposez-en un sur /cookie pour activer un scraper."
    return "🤔 Quel domaine ? " + ", ".join(available)

ACCESS_LEVEL_ATOME = 2       # profil atom4love (craft, rec:<skill>, mem:<skill>)

ACCESS_LEVEL_SATELLITE = 3   # sociétaire satellite ou + (badge)

ACCESS_LEVEL_CAPITAINE = 5   # = bro_tools.ACCESS_CAPTAIN, cf. bro_user_level.py

def _owner_access_level(owner_email):
    """Niveau BRO réel du propriétaire (0-5), voir bro_user_level.py. 0 si
    indisponible (Qdrant/relay hors service, ou module absent) — dégradation
    silencieuse vers le palier le plus restrictif plutôt qu'un crash.
    Relay : RELAYS[-1] (relai LOCAL de la station si résolu par _load_relays,
    sinon DEFAULT_RELAY) — un profil atom4love (Kind 30078) est le plus
    souvent publié sur le relay de la station d'accueil, pas forcément sur le
    relay public par défaut ; même logique que _CONSTELLATION_RELAY côté
    bro_dm_daemon.sh."""
    if not bro_user_level:
        return 0
    hex_ = _owner_hex(owner_email)
    if not hex_:
        return 0
    try:
        return bro_user_level.get_user_level(hex_, RELAYS[-1]).get("level", 0)
    except Exception as e:
        print(f"[BRO_WATCH] _owner_access_level indisponible : {e}")
        return 0

_ACCESS_LEVEL_LABEL = {
    ACCESS_LEVEL_ATOME: "un profil atom4love (créez-le sur atomic.html)",
    ACCESS_LEVEL_SATELLITE: "une souscription ẐEN satellite ou constellation "
                             "(https://opencollective.com/monnaie-libre/contribute)",
}

def _make_gated_handler(tag_name, min_level, real_handler):
    """Vérifie le niveau réel avant d'exécuter real_handler — mêmes seuils et
    même esprit que bro_dm_daemon.sh (canal DM-to-NODE), pour que la réponse
    au propriétaire ne dépende pas du canal utilisé pour la poser."""
    def _handler(owner_email, text):
        if _owner_access_level(owner_email) < min_level:
            requirement = _ACCESS_LEVEL_LABEL.get(min_level, "un niveau d'accès supérieur")
            return f"🔒 #{tag_name} nécessite {requirement}."
        return real_handler(owner_email, text)
    return _handler

def _tool_craft(owner_email, text):
    """Valide et LANCE en tâche détachée l'analyse d'un tutoriel — jamais
    d'exécution synchrone ici (bro_url_content.py + question.py peuvent
    prendre jusqu'à CRAFT_RUN_TIMEOUT_SEC). Même raison structurelle que
    _run_scraper_now : un appel bloquant dans _handle_command_text a déjà
    causé une boucle de rejeu massive le 2026-07-03 (voir sa docstring)."""
    m = re.search(r"https?://\S+", text)
    url = m.group(0) if m else re.sub(r"#craft\b", "", text, flags=re.IGNORECASE).strip()
    if not url:
        return "⚠️ Usage : #craft <url>  ex: #craft https://instructables.com/Arduino-TV-B-Gone/"
    try:
        subprocess.Popen(
            ["python3", BRO_WATCH_CORE_PATH, "run-craft-background", owner_email, url],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        return f"⚠️ Échec du lancement de l'analyse : {e}"
    return f"⏳ Analyse IA en cours pour : {url} — je vous enverrai le résultat sous {CRAFT_RUN_TIMEOUT_SEC}s."

def _tool_badge(owner_email, text):
    """Valide et LANCE en tâche détachée la génération du badge — ComfyUI
    peut prendre jusqu'à BADGE_RUN_TIMEOUT_SEC, même raison que _tool_craft
    ci-dessus : jamais d'appel bloquant dans _handle_command_text."""
    skill = re.sub(r".*#badge\b", "", text, flags=re.IGNORECASE)
    skill = re.sub(r"[^a-z0-9_-]", "", skill.strip().lower())[:40]
    if not skill:
        return "⚠️ Usage : #badge <compétence>  ex: #badge docker"
    try:
        subprocess.Popen(
            ["python3", BRO_WATCH_CORE_PATH, "run-badge-background", owner_email, skill],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        return f"⚠️ Échec du lancement de la génération : {e}"
    return (f"🎨 Génération du badge '{skill}'… Cela peut prendre jusqu'à {BADGE_RUN_TIMEOUT_SEC}s (ComfyUI) — "
            "je vous enverrai le résultat par DM.")

def _tool_rec_skill(owner_email, text):
    """Contribue à la mémoire collective d'une compétence — même backend
    (skill_flashmem.py, fichier partagé ~/.zen/flashmem/skills/<skill>.md)
    que bro_dm_daemon.sh::_handle_rec_skill, pour que la contribution soit
    visible quel que soit le canal utilisé pour l'écrire."""
    import skill_flashmem
    m = re.search(r"#rec:([a-z0-9_-]+)\s+(.*)", text, re.IGNORECASE)
    if not m:
        return "⚠️ Usage : #rec:<skill> <votre note>  ex: #rec:devops Je maîtrise nginx"
    skill, content = m.group(1).lower(), m.group(2).strip()
    if not content:
        return "⚠️ Usage : #rec:<skill> <votre note>  ex: #rec:devops Je maîtrise nginx"
    npub = _owner_hex(owner_email)
    if skill_flashmem.write_skill_memory(skill, content, npub):
        _notify_captain_skill_contribution(owner_email, skill, content)
        return f"💾 Mémorisé dans la base partagée 'skills/{skill}'. Merci pour la contribution ! 🧠"
    return f"❌ Échec mémorisation skill {skill}."

def _notify_captain_skill_contribution(owner_email, skill, content):
    """Modération a posteriori : notifie le Capitaine de chaque nouvelle
    contribution à la mémoire collective #rec:<skill> (voir la revue
    sécurité du 2026-07-06 sur l'empoisonnement possible de cette base
    partagée). Lancé en tâche détachée — jamais bloquant pour la
    confirmation déjà renvoyée au contributeur, même raison structurelle
    que _dispatch_identity_update_check (self-DM peut prendre jusqu'à 20s)."""
    try:
        subprocess.Popen(
            ["python3", BRO_WATCH_CORE_PATH, "run-skill-notify-background", owner_email, skill, content],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        print(f"[BRO_WATCH] Échec notification capitaine (contribution skill) : {e}")

def _run_skill_notify_background(owner_email, skill, content):
    """Exécute réellement la notification (appelée en sous-processus détaché
    par _notify_captain_skill_contribution)."""
    captain_email = os.environ.get("CAPTAINEMAIL", "").strip()
    if not captain_email or captain_email.strip().lower() == owner_email.strip().lower():
        return  # pas de captain configuré, ou le contributeur EST le capitaine
    message = (
        f"🧠 Nouvelle contribution à la mémoire partagée '{skill}' par {owner_email} :\n"
        f"« {content[:200]} »\n\n"
        f"Modération : #mod:{skill} pour lister les entrées, #rm:{skill} <n> pour en retirer une."
    )
    send_dm_to_owner(captain_email, message, ttl_days=7)

def _tool_mod_skill(owner_email, text):
    """Liste les entrées d'un skill avec leur index — modération a
    posteriori, réservée au Capitaine (voir _tool_rm_skill pour le retrait)."""
    import bro_watch_core as _bwc
    if not _bwc._is_captain(owner_email):
        return "🔒 #mod:<skill> est réservé au capitaine de la station."
    import skill_flashmem
    m = re.search(r"#mod:([a-z0-9_-]+)", text, re.IGNORECASE)
    if not m:
        return "⚠️ Usage : #mod:<skill>  ex: #mod:devops"
    skill = m.group(1).lower()
    entries = skill_flashmem.list_skill_entries(skill)
    if not entries:
        return f"📚 Aucune entrée pour '{skill}'."
    lines = [f"{i}. {line}" for i, line in enumerate(entries)]
    return f"📚 Entrées de '{skill}' ({len(entries)}) :\n" + "\n".join(lines) + \
           f"\n\nSupprimer : #rm:{skill} <n>"

def _tool_rm_skill(owner_email, text):
    """Retire une entrée précise (index donné par #mod:<skill>) de la
    mémoire partagée d'un skill — réservé au Capitaine. Retrait ciblé,
    contrairement à skill_flashmem.reset_skill_memory qui efface tout."""
    import bro_watch_core as _bwc
    if not _bwc._is_captain(owner_email):
        return "🔒 #rm:<skill> est réservé au capitaine de la station."
    import skill_flashmem
    m = re.search(r"#rm:([a-z0-9_-]+)\s+(\d+)", text, re.IGNORECASE)
    if not m:
        return "⚠️ Usage : #rm:<skill> <n>  ex: #rm:devops 2 (voir #mod:<skill> pour les index)"
    skill, index = m.group(1).lower(), int(m.group(2))
    if skill_flashmem.remove_skill_entry(skill, index):
        return f"🗑️ Entrée {index} supprimée de '{skill}'."
    return f"❌ Index {index} invalide pour '{skill}' (voir #mod:{skill})."

def _tool_mem_skill(owner_email, text):
    """Lit la mémoire collective d'une compétence (ou liste tous les skills
    connus si aucun nom donné) — même backend que _tool_rec_skill."""
    import skill_flashmem
    m = re.search(r"#mem:([a-z0-9_-]*)", text, re.IGNORECASE)
    skill = m.group(1).lower() if m else ""
    if not skill:
        skills = skill_flashmem.list_skills()
        if not skills:
            return ("📚 Aucune mémoire skill enregistrée sur ce node.\n"
                     "Contribuez avec : #rec:<skill> <votre note>\nExemple : #rec:devops Je maîtrise nginx")
        return ("📚 Skills mémorisés sur ce node :\n" + "\n".join(skills) +
                "\n\nConsultez un skill : #mem:<skill>\nContribuez : #rec:<skill> <note>")
    content = skill_flashmem.read_skill_memory(skill)
    if not content:
        return f"📚 Aucune note pour '{skill}'. Contribuez avec :\n#rec:{skill} <votre expérience ou ressource>"
    lines = content.count("\n") + 1
    return f"📚 Mémoire partagée '{skill}' ({lines} entrées) :\n{content}"

def _register_system_tools():
    bro_tools.register(bro_tools.Tool(
        name="help", tags=("help",), handler=_tool_help,
        description="« #help » ou « aide » : affiche la liste des commandes réellement disponibles.",
        examples=("help", "aide", "commandes BRO", "quelles sont les commandes",
                   "que peux-tu faire ?", "liste tes commandes"),
    ))
    bro_tools.register(bro_tools.Tool(
        name="mem", tags=("mem",), handler=_tool_mem,
        description="« #mem » : affiche le slot 0 par défaut — « #mem #N » un slot précis (1-12, "
                     "sociétaires) — « #mem #all » un résumé de tous les slots.",
        examples=("montre-moi mes souvenirs", "qu'est-ce que tu as retenu de moi ?",
                   "rappelle-moi ce qu'on s'est dit", "voir toutes mes mémoires"),
    ))
    bro_tools.register(bro_tools.Tool(
        name="reset", tags=("reset",), handler=_tool_reset,
        description="« #reset » : efface le slot 0 par défaut — « #reset #N » un slot précis (1-12, "
                     "sociétaires) — « #reset #all » tous les slots.",
        examples=("oublie tout ce qu'on s'est dit", "efface toutes mes mémoires"),
    ))
    bro_tools.register(bro_tools.Tool(
        name="pref", tags=("pref",), handler=_tool_pref,
        description="« #pref history » : liste vos dernières mises à jour de préférences (#rec durable) — "
                     "« #pref rollback <n> » pour en annuler.",
        examples=("montre l'historique de mes préférences", "annule la dernière mise à jour de mon profil",
                   "reviens en arrière sur mes préférences"),
    ))
    bro_tools.register(bro_tools.Tool(
        name="rec", tags=("rec",), handler=_tool_rec,
        description="« #rec TEXTE » : mémorise un fait précis dans un slot personnel.",
        examples=("retiens que j'aime le jardinage", "mémorise ça pour plus tard", "note ça",
                   "#rec j'adore le compost et les légumes anciens"),
    ))
    bro_tools.register(bro_tools.Tool(
        name="scraper", tags=("scraper",), handler=_tool_scraper,
        description="« lance le scraper DOMAINE » (ou « #scraper DOMAINE ») : exécute immédiatement la "
                     "surveillance d'une source dont vous avez déjà déposé le cookie.",
        examples=("lance le scraper mastodon maintenant", "exécute la surveillance mastodon.social",
                   "relance la synchro de mon cookie", "vérifie mes mentions tout de suite"),
    ))
    bro_tools.register(bro_tools.Tool(
        name="craft", tags=("craft",), min_access=ACCESS_LEVEL_ATOME,
        handler=_make_gated_handler("craft", ACCESS_LEVEL_ATOME, _tool_craft),
        description="« #craft <url> » : décompose un tutoriel en recette WoTx² (niveau atom4love requis).",
        examples=("décompose ce tutoriel en recette", "transforme ce lien en étapes"),
    ))
    bro_tools.register(bro_tools.Tool(
        name="badge", tags=("badge",), min_access=ACCESS_LEVEL_SATELLITE,
        handler=_make_gated_handler("badge", ACCESS_LEVEL_SATELLITE, _tool_badge),
        description="« #badge <compétence> » : génère une image de badge de compétence via ComfyUI "
                     "(niveau satellite ẐEN requis).",
        examples=("génère un badge pour cette compétence", "crée mon badge de compétence"),
    ))
    # #rec:<skill> (écriture, niveau 3 — sociétaire satellite) / #mem:<skill>
    # (lecture, niveau 2 — profil atom4love). Écriture relevée à SATELLITE :
    # ATOME (profil atom4love) est trivialement obtenable, ce qui rendait
    # l'empoisonnement de la mémoire collective (#rec:<skill>) peu coûteux
    # pour un attaquant — SATELLITE introduit une friction économique réelle
    # (cotisation ẐEN) sans fermer la fonctionnalité collaborative. Voir aussi
    # skill_flashmem.format_context() pour l'isolation anti-injection du
    # contenu au moment de la lecture. Enregistrés avec tags=() : détectés via
    # _detect_skill_tag (syntaxe à deux-points), pas le matcher générique
    # #tag\b, pour ne pas collisionner avec #rec/#mem simples.
    bro_tools.register(bro_tools.Tool(
        name="rec_skill", tags=(), min_access=ACCESS_LEVEL_SATELLITE,
        handler=_make_gated_handler("rec:<skill>", ACCESS_LEVEL_SATELLITE, _tool_rec_skill),
        description="« #rec:<skill> NOTE » : contribue à la mémoire partagée d'une compétence "
                     "(niveau satellite ẐEN requis).",
        advertise=False,  # syntaxe #rec:<skill> non couverte par la description générique de #rec
    ))
    bro_tools.register(bro_tools.Tool(
        name="mem_skill", tags=(), min_access=ACCESS_LEVEL_ATOME,
        handler=_make_gated_handler("mem:<skill>", ACCESS_LEVEL_ATOME, _tool_mem_skill),
        description="« #mem:<skill> » : lit la mémoire partagée d'une compétence "
                     "(niveau atom4love requis).",
        advertise=False,
    ))
    # #mod:<skill>/#rm:<skill> <n> — modération a posteriori des contributions
    # #rec:<skill> (voir _notify_captain_skill_contribution). Gate RÉEL via
    # _is_captain() dans le handler lui-même (même robustesse que ARBOR_TRIGGERS,
    # cf. _bro_capabilities_description) — min_access=ACCESS_LEVEL_CAPITAINE ici
    # n'est qu'une défense en profondeur si advertise devenait True un jour.
    bro_tools.register(bro_tools.Tool(
        name="mod_skill", tags=(), min_access=ACCESS_LEVEL_CAPITAINE,
        handler=_tool_mod_skill,
        description="« #mod:<skill> » : liste les entrées d'un skill avec leur index (réservé capitaine).",
        advertise=False,
    ))
    bro_tools.register(bro_tools.Tool(
        name="rm_skill", tags=(), min_access=ACCESS_LEVEL_CAPITAINE,
        handler=_tool_rm_skill,
        description="« #rm:<skill> <n> » : retire une entrée précise d'un skill (réservé capitaine).",
        advertise=False,
    ))
