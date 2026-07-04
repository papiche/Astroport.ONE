#!/usr/bin/env python3
"""
bro_node_reset.py — Remet à neuf les couches mémoire polluées par des tests
répétés, pour deux échelles distinctes :

  BRO  : le clone numérique d'UN propriétaire MULTIPASS (celui à qui on a
         confié des cookies de scraper). Mémoire personnelle, mots-clés
         appris, suggestions en attente, dédoublonnage de commandes.

  NODE : la station elle-même (celle qui héberge Arbor, l'auto-amélioration
         du code, l'administration). Corpus de routage sémantique (dérivé du
         code, donc reconstructible), registre d'outils actifs.

« À neuf » ne veut PAS dire vide : après un reset, BRO/NODE doivent rester
CONSCIENTS de qui ils sont et de ce qu'ils savent réellement faire — le
corpus de routage (bro_intent_routing) et le texte d'aide sont toujours
regénérés depuis bro_tools (le registre déclaratif, lui-même dérivé du code
actuel), jamais laissés vides après un reset.

Ne touche JAMAIS :
  - Les clés (secret.nostr, .secret.nostr, home.station) — identité, pas mémoire.
  - La configuration coopérative (Kind 30800 / cooperative_config.sh).
  - Les cookies déposés eux-mêmes (cid/uploaded_at/size/enabled) — coûteux à
    redéposer manuellement, jamais du "bruit de test".
  - Les mots-clés MANUELS (params.channels[].keywords, learn_from) — choix
    explicite de l'utilisateur, pas une donnée apprise/polluable.

Dry-run par défaut sur toute commande destructive : ajouter --apply pour
exécuter réellement.

Usage :
  python3 bro_node_reset.py list-accounts
  python3 bro_node_reset.py reset-bro EMAIL [--apply]
  python3 bro_node_reset.py reset-node [--apply]
  python3 bro_node_reset.py audit-tools
"""

import os
import re
import sys
import json
import glob
import hashlib
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bro_watch_core as bwc
import memory_manager as mm

NOSTR_DIR = os.path.expanduser("~/.zen/game/nostr")
FLASHMEM_DIR = os.path.expanduser("~/.zen/flashmem")
GENERATED_TOOLS_DIR = os.path.join(bwc.BRO_IA_PATH, "tools_generated")
GENERATORS_DIR = os.path.join(bwc.BRO_IA_PATH, "generators")

# Heuristique pure affichage (list-accounts) — jamais utilisée pour choisir
# une cible automatiquement : reset-bro exige toujours un EMAIL explicite.
_TEST_ACCOUNT_RE = re.compile(r"@astroport\.local$|^(e2e|eval|verify|test)[-_]", re.IGNORECASE)

# Générateurs volontairement exclus de tout branchement automatique vers l'IA
# conversationnelle : consomment le GPU, doivent rester déclenchés à la main.
GPU_HEAVY_GENERATORS = {"generate_video.sh", "image_to_video.sh", "generate_movie.sh", "apply_lipsync.sh"}


def _log(msg):
    print(msg)


# ── list-accounts ───────────────────────────────────────────────────────────

def cmd_list_accounts(args):
    _log("Comptes MULTIPASS avec manifest BRO (.cookie_manifest.json) :\n")
    for path in sorted(glob.glob(os.path.join(NOSTR_DIR, "*", bwc.MANIFEST_FILENAME))):
        email = os.path.basename(os.path.dirname(path))
        tag = " (⚠️  ressemble à un compte de test)" if _TEST_ACCOUNT_RE.search(email) else ""
        try:
            manifest = json.load(open(path, encoding="utf-8"))
        except Exception:
            manifest = {}
        domains = [k for k in manifest if not k.startswith("_")]
        _log(f"  - {email}{tag} — {len(domains)} domaine(s) : {', '.join(domains) or '(aucun)'}")


# ── reset-bro EMAIL ──────────────────────────────────────────────────────────

def _reset_manifest(owner_email, apply_):
    """Nettoie SEULEMENT le bruit dérivé/appris du manifest : cache de
    commandes (_bro_commands), suggestions en attente, mots-clés appris.
    Laisse cid/uploaded_at/size/enabled/keywords/learn_from intacts."""
    manifest = bwc._load_manifest(owner_email)
    changed = []

    if bwc.COMMAND_LAST_CHECK_KEY in manifest:
        changed.append(f"manifest.{bwc.COMMAND_LAST_CHECK_KEY} (cache last_check + scrapers dispo)")
        if apply_:
            del manifest[bwc.COMMAND_LAST_CHECK_KEY]

    for domain, entry in manifest.items():
        if domain.startswith("_") or not isinstance(entry, dict):
            continue
        params = entry.get("params", {})
        if params.get("pending_feedback"):
            changed.append(f"manifest.{domain}.params.pending_feedback ({len(params['pending_feedback'])} en attente)")
            if apply_:
                params["pending_feedback"] = []
        for channel in params.get("channels", []):
            learned = channel.get("learned_keywords") or []
            learn_msgs = channel.get("learn_messages") or []
            if learned or learn_msgs:
                changed.append(f"manifest.{domain}.params.channels[{channel.get('channel', '?')}] "
                                f"({len(learned)} mot(s)-clé appris, {len(learn_msgs)} message(s) d'apprentissage)")
                if apply_:
                    channel["learned_keywords"] = []
                    channel["learn_messages"] = []

    if apply_ and changed:
        bwc._save_manifest(owner_email, manifest)
    return changed


def cmd_reset_bro(args):
    owner_email = args.email
    apply_ = args.apply
    mode = "APPLICATION RÉELLE" if apply_ else "SIMULATION (dry-run — ajouter --apply pour exécuter)"
    _log(f"── Reset BRO pour {owner_email} — {mode} ──\n")

    actions = []

    # 1. Manifest : cache de commandes, suggestions en attente, mots-clés appris.
    actions += _reset_manifest(owner_email, apply_)

    # 2. Mémoire locale (flashmem) : slots 0-13.
    owner_flashmem = os.path.join(FLASHMEM_DIR, owner_email)
    slot_files = sorted(glob.glob(os.path.join(owner_flashmem, "slot*.json")))
    for f in slot_files:
        actions.append(f"flashmem : {f}")
        if apply_:
            os.remove(f)

    # 3. Mémoire sémantique (Qdrant memory_{hex}) — collection dédiée à cet
    # utilisateur, couvre tous les slots (0-13) en une fois.
    cname = f"memory_{mm._user_hex(owner_email)}"
    if mm._curl("GET", f"{mm.QDRANT_URL}/collections/{cname}"):
        actions.append(f"qdrant : collection {cname} (mémoire sémantique, tous slots)")
        if apply_:
            mm._curl("DELETE", f"{mm.QDRANT_URL}/collections/{cname}")

    # 4. Alertes proactives (solde ẐEN bas, etc.) — état transitoire.
    alerts_path = os.path.join(bwc._owner_dir(owner_email), bwc.PROACTIVE_ALERTS_FILENAME)
    if os.path.isfile(alerts_path):
        actions.append(f"état : {alerts_path}")
        if apply_:
            os.remove(alerts_path)

    # 5. Marqueurs de dédoublonnage de commandes déjà traitées (propres à cet owner).
    owner_hash = hashlib.sha256(owner_email.encode()).hexdigest()[:16]
    markers = glob.glob(os.path.join(bwc.PROCESSED_COMMAND_IDS_DIR, f"{owner_hash}_*"))
    if markers:
        actions.append(f"dédoublonnage : {len(markers)} marqueur(s) sous {bwc.PROCESSED_COMMAND_IDS_DIR}")
        if apply_:
            for m in markers:
                os.remove(m)

    if not actions:
        _log("Rien à nettoyer — BRO est déjà « propre » pour ce compte.")
    else:
        for a in actions:
            _log(f"  {'✅' if apply_ else '·'} {a}")

    _log(f"\nConservé (jamais touché) : cid/uploaded_at/size/enabled des cookies, "
         f"keywords manuels, learn_from, identité NOSTR.")

    if apply_:
        _log("\n── Conscience de BRO après reset (généré depuis le code actuel) ──")
        _log(bwc._bro_capabilities_description(owner_email))


# ── reset-node ───────────────────────────────────────────────────────────────

def cmd_reset_node(args):
    apply_ = args.apply
    mode = "APPLICATION RÉELLE" if apply_ else "SIMULATION (dry-run — ajouter --apply pour exécuter)"
    _log(f"── Reset NODE (station) — {mode} ──\n")

    # 1. Collections dérivées du CODE — sans risque à reconstruire : effacer
    # puis reseeder immédiatement depuis bro_tools (jamais laissé vide).
    for cname in (bwc.QDRANT_INTENT_COLLECTION, bwc.QDRANT_TOPICS_COLLECTION):
        exists = bool(mm._curl("GET", f"{mm.QDRANT_URL}/collections/{cname}"))
        if exists:
            _log(f"  {'✅' if apply_ else '·'} qdrant : purge + reconstruction de {cname} (dérivée du code)")
            if apply_:
                mm._curl("DELETE", f"{mm.QDRANT_URL}/collections/{cname}")
        else:
            _log(f"  · qdrant : {cname} n'existe pas encore (sera créée à la reconstruction)")

    if apply_:
        # Ne jamais laisser la collection supprimée sans tentative de
        # reconstruction : une exception ici (Qdrant/Ollama tombé pile après
        # le DELETE ci-dessus) laisserait NODE sans corpus de routage du
        # tout — pire état qu'avant le reset.
        try:
            bwc._seed_intent_corpus()
            _log(f"    → {bwc.QDRANT_INTENT_COLLECTION} reconstruite depuis bro_tools "
                 f"({sum(1 for _ in bwc.bro_tools.iter_examples())} exemples)")
        except Exception as e:
            _log(f"    ⚠️ Reconstruction du corpus échouée ({e}) — {bwc.QDRANT_INTENT_COLLECTION} "
                 f"peut être vide ou absente. Relancer 'reset-node --apply' une fois Qdrant/Ollama disponibles.")

    # 2. Registre d'outils actifs (bro_active_tools.json) : purge des entrées
    # orphelines (fichier supprimé depuis) — NODE ne doit pas prétendre à une
    # capacité qu'il ne peut plus exécuter.
    active = bwc.list_active_tools()
    orphans = [name for name in active if not os.path.isfile(os.path.join(GENERATED_TOOLS_DIR, f"{name}.py"))]
    for name in orphans:
        _log(f"  {'✅' if apply_ else '·'} outil orphelin dans bro_active_tools.json : '{name}' "
             f"(fichier {name}.py introuvable)")
        if apply_:
            bwc.deactivate_tool(name)

    if not orphans:
        _log("  · aucun outil orphelin dans le registre.")

    if apply_:
        _log("\n── Registre NODE après reset ──")
        for tool in bwc.bro_tools.all_tools():
            _log(f"  [{tool.source}] {tool.name} — {tool.description}")


# ── audit-tools ──────────────────────────────────────────────────────────────

def cmd_audit_tools(args):
    """Repère les 'perles oubliées' : scripts qui existent dans le code mais
    ne sont invocables par AUCUN chemin (ni bro_tools, ni _handle_ia_responder_tags,
    ni UPlanet_IA_Responder.sh). Exclut délibérément les générateurs vidéo/lipsync
    (GPU_HEAVY_GENERATORS) : ne JAMAIS proposer de les brancher sur un déclenchement
    IA automatique — charge GPU incontrôlable depuis une conversation."""
    _log("── Outils forgés (tools_generated/) non actifs ──")
    active = set(bwc.list_active_tools().keys())
    found_inactive = False
    for path in sorted(glob.glob(os.path.join(GENERATED_TOOLS_DIR, "*.py"))):
        module_name = os.path.splitext(os.path.basename(path))[0]
        if module_name not in active:
            found_inactive = True
            _log(f"  💎 {module_name}.py — présent mais jamais activé "
                 f"(python3 bro_watch_core.py activate-tool {module_name})")
    if not found_inactive:
        _log("  · aucun — tous les outils forgés présents sont actifs.")

    _log("\n── Générateurs (generators/) et leur branchement ──")
    wired_scripts = set()
    for root, _, files in os.walk(bwc.BRO_IA_PATH):
        if root == GENERATORS_DIR:
            continue
        for fname in files:
            if fname.endswith((".py", ".sh")):
                try:
                    content = open(os.path.join(root, fname), encoding="utf-8", errors="ignore").read()
                except Exception:
                    continue
                for gen in os.listdir(GENERATORS_DIR):
                    if gen in content:
                        wired_scripts.add(gen)

    for gen in sorted(os.listdir(GENERATORS_DIR)):
        if not gen.endswith(".sh"):
            continue
        if gen in GPU_HEAVY_GENERATORS:
            status = "⛔ exclu volontairement (charge GPU) — ne pas brancher sur l'IA conversationnelle"
        elif gen in wired_scripts:
            status = "✅ déjà appelé depuis au moins un dispatcher IA (IA/*.py, *.sh)"
        else:
            status = "💎 jamais appelé par aucun dispatcher IA repéré — perle potentielle à vérifier"
        _log(f"  {gen:<28} {status}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list-accounts")

    p_bro = sub.add_parser("reset-bro")
    p_bro.add_argument("email")
    p_bro.add_argument("--apply", action="store_true", help="Exécute réellement (sinon dry-run)")

    p_node = sub.add_parser("reset-node")
    p_node.add_argument("--apply", action="store_true", help="Exécute réellement (sinon dry-run)")

    sub.add_parser("audit-tools")

    args = parser.parse_args()
    {
        "list-accounts": cmd_list_accounts,
        "reset-bro": cmd_reset_bro,
        "reset-node": cmd_reset_node,
        "audit-tools": cmd_audit_tools,
    }[args.cmd](args)


if __name__ == "__main__":
    main()
