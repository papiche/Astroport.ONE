#!/usr/bin/env python3
"""
N2_Economics.py — Dividende Universel hyper-relativiste (TRM), Ğ1-Nostr (N²)

IMPORTANT — ce script opère ENTIÈREMENT sur les identités NOSTR LOVE
(.secret.love / HEX_LOVE, cf. atom4love_publish.py), JAMAIS sur le HEX
principal du MULTIPASS. Le MULTIPASS (G1PUBNOSTR + .secret.nostr) reste dédié
à l'économie réelle (Ğ1/Duniter, raccordement OpenCollective, comptage des €
versés au collectif) — le ledger Ğ1-N² (local, sans consensus) est
intentionnellement tenu à l'écart sur une identité distincte. Le graphe N1/N2
est donc le graphe de RÉCIPROCITÉ DES CLEFS LOVE (kind 3 publié par
.secret.love — une notion neuve, distincte du graphe social NOSTR classique
du MULTIPASS), pas celui du MULTIPASS.

Calcule et émet un incrément de DU quotidien pour CHAQUE identité LOVE locale,
selon la densité de son graphe de réciprocité (kind 3, follows LOVE↔LOVE) :

    DU_INCREMENT = c² * M_N1 / (|N1| + sqrt(|N2|))

    c²   ≈ 1% (paramètre --c2, cf. Astroport.ONE/docs/explanation/ZEN.ECONOMY.v3.md)
    M_N1 = masse monétaire Ğ1-N² (soldes HEX_LOVE) des contacts N1 (liens réciproques)
    N1   = contacts LOVE réciproques (A suit B ET B suit A)
    N2   = contacts LOVE de second degré (follows des N1, hors N1 et hors soi-même)

Émet le kind 30305, signé par la clef LOVE du membre (schéma JSON STRICTEMENT
INCHANGÉ — déjà consommé par le client TrocZen existant,
`nostr_service.dart#publishDuIncrement` ; ce script étend QUI peut en émettre
un chaque jour — jusqu'ici réservé au Capitaine via ZEN.ECONOMY.sh, une fois
par semaine, avec un montant = don volontaire — ici : chaque identité LOVE,
quotidiennement, calculé depuis son propre graphe de réciprocité LOVE).
ATTENTION compatibilité : TrocZen doit surveiller la clef LOVE de l'utilisateur
(pas son HEX MULTIPASS habituel) pour voir ces events — cf. suivi séparé côté
client.

Choix d'architecture : UN SEUL `strfry scan '{"kinds":[3]}'` pour la totalité
des follows de la station (kind 3 est *replaceable* : un seul event par
auteur en base), tout le calcul de réciprocité se fait ensuite en mémoire —
jamais un scan par membre (cf. /api/getN2 d'UPassport, O(N1) round-trips par
utilisateur, inadapté à un batch quotidien sur tous les MULTIPASS locaux).

Usage :
    N2_Economics.py [--dry-run] [--c2 0.01] [--min-n1 1]
"""
import argparse
import json
import math
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ZEN_HOME = Path(os.environ.get("HOME", "/home/fred")) / ".zen"
STRFRY_DIR = Path(os.environ.get("N2_STRFRY_DIR", str(ZEN_HOME / "strfry")))
NOSTR_DIR = ZEN_HOME / "game" / "nostr"
TOOLS_DIR = ZEN_HOME / "Astroport.ONE" / "tools"
TMP_DIR = ZEN_HOME / "tmp"

G1N2_CHECK = TOOLS_DIR / "g1n2_check.sh"
NOSTR_SEND = TOOLS_DIR / "nostr_send_note.py"


def log(msg):
    print(f"[N2_Economics] {msg}", file=sys.stderr)


def resolve_ipfsnodeid():
    """IPFSNODEID n'est JAMAIS exporté par my.sh (variable locale au shell qui
    la source) — un appelant comme 20h12.process.sh (qui invoque ce script en
    sous-processus après avoir sourcé my.sh) ne le transmettrait donc pas via
    l'environnement. Même stratégie que common.sh (NIP-101) : dérivé directement
    depuis ~/.ipfs/config plutôt que de dépendre d'un env var hérité."""
    env_val = os.environ.get("IPFSNODEID", "")
    if env_val:
        return env_val
    config_path = Path(os.environ.get("HOME", "/home/fred")) / ".ipfs" / "config"
    try:
        with open(config_path) as f:
            data = json.load(f)
        return data.get("Identity", {}).get("PeerID", "")
    except (OSError, json.JSONDecodeError):
        return ""


def today_str():
    # Horodatage passé en argument par l'appelant (20h12.process.sh) de préférence ;
    # à défaut, date du jour — jamais Date.now()/random dans un contexte rejouable,
    # mais ce script tourne en one-shot quotidien, pas dans un moteur de workflow.
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def fetch_all_kind3_follows():
    """UN SEUL scan pour TOUTE la station — kind 3 replaceable, un event/auteur."""
    strfry_bin = STRFRY_DIR / "strfry"
    if not strfry_bin.exists():
        log(f"ERREUR: strfry introuvable ({strfry_bin})")
        return {}

    try:
        proc = subprocess.run(
            [str(strfry_bin), "scan", '{"kinds":[3]}'],
            cwd=str(STRFRY_DIR), capture_output=True, text=True, timeout=60,
        )
    except Exception as e:
        log(f"ERREUR scan kind 3: {e}")
        return {}

    follows = {}
    latest_created_at = {}
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        pubkey = ev.get("pubkey")
        if not _is_hex64(pubkey):
            continue
        p_tags = {t[1] for t in ev.get("tags", []) if len(t) >= 2 and t[0] == "p" and _is_hex64(t[1])}
        created_at = ev.get("created_at", 0)
        # kind 3 replaceable : si plusieurs lignes pour le même auteur apparaissent
        # (ne devrait pas arriver via strfry scan, mais défensif), garder la plus
        # récente — ev triés par created_at non garanti ici, donc merge par max
        # (suivi dans un dict séparé : p_tags est un set, pas un objet avec métadonnée).
        if pubkey not in latest_created_at or created_at >= latest_created_at[pubkey]:
            follows[pubkey] = p_tags
            latest_created_at[pubkey] = created_at
    return follows


def _is_hex64(s):
    """Valide qu'une chaîne est un pubkey hex NOSTR bien formé (64 hex chars).
    Défensif contre des fichiers HEX corrompus (ex. constaté en pratique :
    un dossier système avec un fichier HEX multi-lignes accumulé au lieu
    d'une seule valeur) — jamais accepté silencieusement comme pubkey valide."""
    return isinstance(s, str) and len(s) == 64 and all(c in "0123456789abcdef" for c in s)


def local_members():
    """Mapping HEX_LOVE -> EMAIL pour toutes les identités LOVE locales (PAS le
    HEX du MULTIPASS — cf. en-tête du module). Une identité LOVE n'existe que
    pour les membres ayant inscrit naissance/conception (atom4love_activate.sh),
    condition déjà nécessaire au genesis mint (N2_Genesis.sh)."""
    members = {}
    if not NOSTR_DIR.is_dir():
        return members
    for d in NOSTR_DIR.iterdir():
        hex_file = d / "HEX_LOVE"
        if hex_file.is_file():
            try:
                h = hex_file.read_text().strip()
            except OSError:
                continue
            if _is_hex64(h):
                members[h] = d.name
            elif h:
                log(f"  ⚠️  HEX_LOVE invalide ignoré pour {d.name} ({len(h)} chars, attendu 64)")
    return members


def batch_g1n2_balances(hex_list):
    """Solde Ğ1-N² pour une liste de HEX — un seul appel batch g1n2_check.sh
    (lecture cache locale, pas de round-trip réseau) plutôt qu'un par contact."""
    if not hex_list or not G1N2_CHECK.exists():
        return {h: 0.0 for h in hex_list}
    try:
        proc = subprocess.run(
            [str(G1N2_CHECK)] + list(hex_list),
            capture_output=True, text=True, timeout=30,
        )
    except Exception as e:
        log(f"ERREUR batch g1n2_check.sh: {e}")
        return {h: 0.0 for h in hex_list}

    lines = [l.strip() for l in proc.stdout.splitlines()]
    balances = {}
    for h, l in zip(hex_list, lines):
        try:
            balances[h] = float(l)
        except (ValueError, TypeError):
            balances[h] = 0.0
    # Complète les manquants (sortie plus courte que l'entrée en cas d'erreur partielle)
    for h in hex_list:
        balances.setdefault(h, 0.0)
    return balances


def publish_du_increment(email, amount, date_str, dry_run=False):
    """Publie le kind 30305 — schéma FIGÉ, ne jamais modifier tags/content.
    Signé par la clef LOVE (.secret.love), PAS .secret.nostr du MULTIPASS —
    cf. en-tête du module : tout le Ğ1-N² (solde ET DU) vit sur l'identité LOVE."""
    keyfile = NOSTR_DIR / email / ".secret.love"
    if not keyfile.exists():
        log(f"  ⚠️  .secret.love absent pour {email} — DU non publié")
        return False

    tags = json.dumps([["d", f"du-{date_str}"], ["amount", f"{amount:.2f}"]])
    if dry_run:
        log(f"  [DRY-RUN] kind 30305 pour {email} : amount={amount:.2f}")
        return True

    try:
        proc = subprocess.run(
            ["python3", str(NOSTR_SEND), "--json",
             "--keyfile", str(keyfile), "--kind", "30305", "--content", "",
             "--tags", tags, "--relays", os.environ.get("myRELAY", "ws://127.0.0.1:7777")],
            capture_output=True, text=True, timeout=30,
        )
        result = json.loads(proc.stdout) if proc.stdout.strip() else {}
        if result.get("success"):
            return True
        log(f"  ⚠️  Échec publication kind 30305 pour {email} : {result.get('errors')}")
        return False
    except Exception as e:
        log(f"  ⚠️  Exception publication kind 30305 pour {email} : {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="DU hyper-relativiste quotidien (Ğ1-Nostr N²)")
    parser.add_argument("--dry-run", action="store_true", help="Calcule sans publier")
    parser.add_argument("--c2", type=float, default=0.01, help="Constante c² (défaut 0.01 ≈ 1%%)")
    parser.add_argument("--min-n1", type=int, default=1, help="N1 minimum pour recevoir un DU (défaut 1)")
    args = parser.parse_args()

    date_str = today_str()
    log(f"=== N2_Economics {date_str} (c²={args.c2}) ===")

    follows = fetch_all_kind3_follows()
    log(f"Kind 3 (follows) chargés : {len(follows)} auteur(s)")

    members = local_members()
    log(f"Identités LOVE locales : {len(members)}")
    if not members:
        log("Aucun membre local — rien à faire")
        return 0

    # Pré-calcul N1/N2 par membre (en mémoire, aucun I/O supplémentaire)
    per_member = {}
    all_n1_contacts = set()
    for me_hex in members:
        my_follows = follows.get(me_hex, set())
        n1 = {x for x in my_follows if me_hex in follows.get(x, set())}
        n2 = set()
        for x in n1:
            n2 |= follows.get(x, set())
        n2 -= n1
        n2.discard(me_hex)
        per_member[me_hex] = {"n1": n1, "n2": n2}
        all_n1_contacts |= n1

    # Un seul batch pour TOUS les contacts N1 de TOUS les membres (dédupliqué)
    balances = batch_g1n2_balances(sorted(all_n1_contacts)) if all_n1_contacts else {}

    published = 0
    skipped = 0
    total_du = 0.0
    marker_dir = TMP_DIR / "n2_economics_markers"
    marker_dir.mkdir(parents=True, exist_ok=True)

    for me_hex, email in members.items():
        n1 = per_member[me_hex]["n1"]
        n2 = per_member[me_hex]["n2"]

        if len(n1) < args.min_n1:
            skipped += 1
            continue

        marker = marker_dir / f"{email}_{date_str}.done"
        if marker.exists():
            log(f"  {email} : déjà publié aujourd'hui — skip")
            continue

        m_n1 = sum(balances.get(h, 0.0) for h in n1)
        du_increment = args.c2 * m_n1 / (len(n1) + math.sqrt(len(n2)))

        if du_increment <= 0:
            skipped += 1
            continue

        log(f"  {email} : N1={len(n1)} N2={len(n2)} M_N1={m_n1:.2f} → DU={du_increment:.2f}")
        if publish_du_increment(email, du_increment, date_str, dry_run=args.dry_run):
            if not args.dry_run:
                marker.write_text(datetime.now(timezone.utc).isoformat())
            published += 1
            total_du += du_increment
        else:
            skipped += 1

    summary = {
        "date": date_str,
        "members_total": len(members),
        "published": published,
        "skipped": skipped,
        "total_du": round(total_du, 2),
        "c2": args.c2,
        "dry_run": args.dry_run,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }

    ipfsnodeid = resolve_ipfsnodeid()
    if ipfsnodeid:
        out_dir = TMP_DIR / ipfsnodeid
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / f"n2_economics_{date_str}.json").write_text(json.dumps(summary, indent=2))

    log(f"=== Terminé : {published} publié(s), {skipped} ignoré(s), total DU={total_du:.2f} ===")
    print(json.dumps(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
