#!/usr/bin/env python3
################################################################################
# respawn_nostrcard_helper.py
#
# Compagnon Python de tools/respawn_NOSTRCARD.sh.
#
# Ce module est la SEULE source de vérité pour :
#   - la liste des artefacts "modernes" attendus dans un MULTIPASS/ZenCard
#     (checklist), afin que le bash et ce script ne divergent jamais
#   - l'audit d'un compte (quels fichiers manquent, legacy ou pas)
#   - le parsing du DISCO (/?salt=...&nostr=...) depuis .secret.disco ou
#     .multipass.json
#   - la vérification de sécurité : re-dériver NPUB/HEX depuis un SALT/PEPPER
#     recouvré et s'assurer qu'ils correspondent bien à l'identité déjà
#     enregistrée dans .secret.nostr AVANT toute réparation (empêche de
#     fabriquer une identité différente si le DISCO fourni est faux/corrompu)
#   - la récupération best-effort du "niveau économique" (UPLANETNAME_G1 /
#     libellé ORIGIN vs ẐEN) déjà associé au compte, pour ne jamais réécrire
#     un compte legacy avec la valeur COURANTE de la station si une trace
#     de la valeur d'origine existe encore quelque part
#
# Toutes les opérations cryptographiques réelles (dérivation de clés) sont
# déléguées à tools/keygen et tools/nostr2hex.py (subprocess), exactement
# comme le fait make_NOSTRCARD.sh — ce script ne réimplémente aucune crypto.
#
# Usage : voir `respawn_nostrcard_helper.py --help` et le --help de chaque
# sous-commande. Toujours appelé par respawn_NOSTRCARD.sh, mais utilisable
# seul pour du diagnostic (sortie JSON sur stdout).
################################################################################
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import parse_qs, urlparse

MY_PATH = Path(__file__).resolve().parent
HOME = Path(os.environ.get("HOME", os.path.expanduser("~")))
NOSTR_DIR = HOME / ".zen" / "game" / "nostr"
PLAYERS_DIR = HOME / ".zen" / "game" / "players"

################################################################################
# CHECKLIST — source unique de vérité (le bash lib la consomme via `checklist`)
################################################################################

# Fichiers dont l'ABSENCE signifie "ce n'est pas / plus un MULTIPASS" : on ne
# tente jamais de les fabriquer depuis rien (identité fondatrice).
MULTIPASS_MANDATORY = [".secret.nostr", "G1PUBNOSTR"]

# Tier 1 : réparables SANS le DISCO (SALT/PEPPER). Ne dépendent que de
# l'identité déjà connue (.secret.nostr, G1PUBNOSTR) + l'environnement
# courant de la station (my.sh).
MULTIPASS_TIER1 = [
    ".pass",
    "LANG",
    "HEX",
    "NPUB",
    "home.station",
    "TODATE",
    "ZUMAP",
    "GPS",
    "identity/.Core.md",
    "identity/.Style.md",
    "identity/.Rules.md",
    "identity/.Preferences.md",
    "identity/.Objectifs.md",
    "did.json.cache",
    "APP/uDRIVE/index.html",
]

# Tier 2 : nécessitent le DISCO (SALT+PEPPER) reconstitué, car ils encodent
# ou dérivent du secret original (SSSS split du DISCO, portefeuilles
# jumeaux Bitcoin/Monero, clé IPNS personnelle NOSTRNS).
MULTIPASS_TIER2 = [
    ".secret.disco",
    ".multipass.json",
    "BITCOIN",
    "MONERO",
    ".ssss.head.player.enc",
    ".ssss.mid.captain.enc",
    "ssss.tail.uplanet.enc",
    ".ssss.player.key",
    "NOSTRNS",
    "uSPOT.QR.png",
    "IPNS.QR.png",
    "._SSSSQR.png",
    "MULTIPASS.QR.png",
    "MULTIPASS.QR.png.cid",
    "PROFILE.QR.png",
    ".nostr.zine.html",
]

# Informationnel seulement : jamais auto-réparé par respawn (nécessite des
# données que le compte n'a jamais fournies : naissance/conception pour LOVE).
MULTIPASS_INFO_ONLY = [".secret.love", "HEX_LOVE"]

# Fichiers dont la présence NE DOIT JAMAIS être modifiée par ce script :
# ils encodent un état économique/coopératif vivant (abonnement, historique
# de capital, dernier paiement) et relèvent exclusivement du cycle de vie
# normal (RUNTIME/NOSTRCARD.refresh.sh). respawn ne les touche jamais, même
# en mode --force.
MULTIPASS_NEVER_TOUCH = [
    "U.SOCIETY",
    "U.SOCIETY.end",
    ".lastpayment",
    ".refresh_time",
    ".account_created",
    ".BIRTHDATE",
]

ZENCARD_MANDATORY = ["secret.june", ".g1pub", "secret.dunikey"]
ZENCARD_CHECK = [
    ".player",
    ".pseudo",
    ".playerns",
    ".pass",
    "ipfs/moa/index.html",
    "QR.png",
    "ZENG1avatar.png",
    "QRTWavatar.png",
    "ID.png",
    ".ZENCard.html",
]
ZENCARD_NEVER_TOUCH = ["U.SOCIETY", "U.SOCIETY.end", "G1PRIME"]


def _exists(base: Path, rel: str) -> bool:
    p = base / rel
    return p.is_file() and p.stat().st_size > 0


def checklist_cmd(_args):
    print(json.dumps({
        "multipass_mandatory": MULTIPASS_MANDATORY,
        "multipass_tier1": MULTIPASS_TIER1,
        "multipass_tier2": MULTIPASS_TIER2,
        "multipass_info_only": MULTIPASS_INFO_ONLY,
        "multipass_never_touch": MULTIPASS_NEVER_TOUCH,
        "zencard_mandatory": ZENCARD_MANDATORY,
        "zencard_check": ZENCARD_CHECK,
        "zencard_never_touch": ZENCARD_NEVER_TOUCH,
    }, indent=2))


################################################################################
# AUDIT
################################################################################

def audit_email(email: str) -> dict:
    nostr_dir = NOSTR_DIR / email
    players_dir = PLAYERS_DIR / email

    report = {
        "email": email,
        "multipass_dir": str(nostr_dir),
        "multipass_exists": nostr_dir.is_dir(),
        "is_multipass": False,
        "mandatory_missing": [],
        "tier1_missing": [],
        "tier2_missing": [],
        "info_only_missing": [],
        "zencard_dir": str(players_dir),
        "zencard_exists": players_dir.is_dir(),
        "zencard_mandatory_missing": [],
        "zencard_missing": [],
        "legacy": False,
        "repairable": False,
    }

    if not nostr_dir.is_dir():
        report["error"] = "NO_MULTIPASS_DIRECTORY"
        return report

    mandatory_missing = [f for f in MULTIPASS_MANDATORY if not _exists(nostr_dir, f)]
    report["mandatory_missing"] = mandatory_missing
    report["is_multipass"] = len(mandatory_missing) == 0

    if not report["is_multipass"]:
        # Sans .secret.nostr le compte n'est pas récupérable par ce script :
        # il n'y a aucune identité à partir de laquelle repartir.
        report["error"] = "MISSING_FOUNDATIONAL_IDENTITY"
        return report

    report["tier1_missing"] = [f for f in MULTIPASS_TIER1 if not _exists(nostr_dir, f)]
    report["tier2_missing"] = [f for f in MULTIPASS_TIER2 if not _exists(nostr_dir, f)]
    report["info_only_missing"] = [f for f in MULTIPASS_INFO_ONLY if not _exists(nostr_dir, f)]

    if players_dir.is_dir():
        zc_mandatory_missing = [f for f in ZENCARD_MANDATORY if not _exists(players_dir, f)]
        report["zencard_mandatory_missing"] = zc_mandatory_missing
        if not zc_mandatory_missing:
            report["zencard_missing"] = [f for f in ZENCARD_CHECK if not _exists(players_dir, f)]

    report["legacy"] = bool(report["tier1_missing"] or report["tier2_missing"] or report["zencard_missing"])
    # Tier2 gaps ne sont réparables que si le DISCO est recouvrable (vérifié
    # séparément par la commande recover-disco) — ce champ est affiné par le
    # script bash appelant après tentative de récupération.
    report["repairable"] = True
    return report


def audit_cmd(args):
    print(json.dumps(audit_email(args.email), indent=2, ensure_ascii=False))


def scan_all_cmd(_args):
    if not NOSTR_DIR.is_dir():
        print(json.dumps({"accounts": [], "legacy_count": 0}))
        return
    accounts = []
    for entry in sorted(NOSTR_DIR.iterdir()):
        if not entry.is_dir():
            continue
        email = entry.name
        if "@" not in email:
            continue
        accounts.append(audit_email(email))
    legacy = [a for a in accounts if a.get("legacy")]
    print(json.dumps({
        "accounts": accounts,
        "total": len(accounts),
        "legacy_count": len(legacy),
        "legacy_emails": [a["email"] for a in legacy],
    }, indent=2, ensure_ascii=False))


################################################################################
# DISCO recovery : "/?salt=<SALT>&nostr=<PEPPER>"
################################################################################

DISCO_RE = re.compile(r"^/\?salt=([^&]+)&nostr=(.+)$")


def _parse_disco_string(disco: str):
    m = DISCO_RE.match(disco.strip())
    if not m:
        return None
    # Les valeurs SALT/PEPPER sont générées par make_NOSTRCARD.sh à partir de
    # [A-Za-z0-9] ou via diceware (mots séparés par des tirets) — jamais
    # url-encodées à la création (cf. make_NOSTRCARD.sh:229 `DISCO="/?salt=${SALT}&nostr=${PEPPER}"`,
    # à la différence de VISA.new.sh qui, lui, encode USALT/UPEPPER avec
    # jq -Rr @uri avant de les mettre dans son propre DISCO d'affichage GPG).
    # On tente néanmoins un unquote défensif si des caractères %XX sont présents.
    from urllib.parse import unquote
    salt, pepper = m.group(1), m.group(2)
    if "%" in salt:
        salt = unquote(salt)
    if "%" in pepper:
        pepper = unquote(pepper)
    return {"salt": salt, "pepper": pepper}


def recover_disco_cmd(args):
    nostr_dir = NOSTR_DIR / args.email
    result = {"email": args.email, "salt": None, "pepper": None, "source": None}

    disco_file = nostr_dir / ".secret.disco"
    if disco_file.is_file() and disco_file.stat().st_size > 0:
        parsed = _parse_disco_string(disco_file.read_text().strip())
        if parsed:
            result.update(parsed)
            result["source"] = ".secret.disco"
            print(json.dumps(result))
            return

    mp_json = nostr_dir / ".multipass.json"
    if mp_json.is_file() and mp_json.stat().st_size > 0:
        try:
            data = json.loads(mp_json.read_text())
            salt, pepper = data.get("salt"), data.get("pepper")
            if salt and pepper:
                result.update({"salt": salt, "pepper": pepper, "source": ".multipass.json"})
                print(json.dumps(result))
                return
        except (json.JSONDecodeError, OSError):
            pass

    if args.salt and args.pepper:
        result.update({"salt": args.salt, "pepper": args.pepper, "source": "cli-arguments"})
        print(json.dumps(result))
        return

    result["error"] = "DISCO_NOT_RECOVERABLE"
    print(json.dumps(result))
    sys.exit(1)


################################################################################
# Safety check : re-dériver NPUB/HEX depuis SALT/PEPPER et comparer à
# l'identité déjà enregistrée dans .secret.nostr, AVANT toute réparation.
################################################################################

def _run_keygen(keytype: str, cred_file: str, secret: bool = False) -> str:
    keygen = str(MY_PATH / "keygen")
    cmd = [keygen, "-t", keytype]
    if secret:
        cmd.append("-s")
    cmd += ["-i", cred_file]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if out.returncode != 0:
        raise RuntimeError(f"keygen -t {keytype} failed: {out.stderr.strip()}")
    return out.stdout.strip()


def _write_cred_file(salt: str, pepper: str) -> str:
    # Même précaution que make_NOSTRCARD.sh : credentials en RAM (/dev/shm),
    # jamais sur disque persistant, jamais visibles dans `ps aux`.
    fd, path = tempfile.mkstemp(dir="/dev/shm" if os.path.isdir("/dev/shm") else None)
    os.chmod(path, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(f"{salt}\n{pepper}\n")
    return path


def verify_identity_cmd(args):
    nostr_dir = NOSTR_DIR / args.email
    secret_file = nostr_dir / ".secret.nostr"
    result = {"email": args.email, "match": False}

    if not secret_file.is_file():
        result["error"] = "MISSING_SECRET_NOSTR"
        print(json.dumps(result))
        sys.exit(1)

    existing = {}
    for line in secret_file.read_text().replace(";", "\n").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            existing[k.strip()] = v.strip()
    existing_hex = existing.get("HEX", "")
    existing_npub = existing.get("NPUB", "")
    result["existing_hex"] = existing_hex
    result["existing_npub"] = existing_npub

    cred_path = _write_cred_file(args.salt, args.pepper)
    try:
        derived_npub = _run_keygen("nostr", cred_path)
        nostr2hex = str(MY_PATH / "nostr2hex.py")
        out = subprocess.run([nostr2hex, derived_npub], capture_output=True, text=True, timeout=15)
        derived_hex = out.stdout.strip()
    finally:
        try:
            os.remove(cred_path)
        except OSError:
            pass

    result["derived_npub"] = derived_npub
    result["derived_hex"] = derived_hex
    result["match"] = bool(derived_hex) and derived_hex.lower() == existing_hex.lower() and derived_npub == existing_npub

    print(json.dumps(result))
    if not result["match"]:
        sys.exit(1)


################################################################################
# Récupération best-effort du "niveau économique" (UPLANETNAME_G1 / ORIGIN)
# déjà associé au compte, pour ne jamais l'écraser silencieusement par la
# valeur COURANTE de la station si une trace de la valeur d'origine subsiste.
################################################################################

UPLANET8_RE = re.compile(r"UPlanet:([A-Za-z0-9]{8})")
UPLANETNAME_G1_RE = re.compile(r'"uplanetname_g1"\s*:\s*"([^"]*)"')


def _grep_uplanet8(text: str):
    m = UPLANET8_RE.search(text)
    return m.group(1) if m else None


def recover_econ_level_cmd(args):
    nostr_dir = NOSTR_DIR / args.email
    players_dir = PLAYERS_DIR / args.email
    result = {"email": args.email, "uplanetname_g1": None, "uplanet8": None, "source": None}

    # 1. Une trace .multipass.json déjà présente (même partiel) fait foi.
    mp_json = nostr_dir / ".multipass.json"
    if mp_json.is_file() and mp_json.stat().st_size > 0:
        m = UPLANETNAME_G1_RE.search(mp_json.read_text())
        if m and m.group(1):
            result.update({"uplanetname_g1": m.group(1), "source": ".multipass.json"})
            print(json.dumps(result))
            return

    # 2. Le zine MULTIPASS déjà envoyé contient "UPlanet:<8 premiers hex>".
    zine = nostr_dir / ".nostr.zine.html"
    if zine.is_file() and zine.stat().st_size > 0:
        u8 = _grep_uplanet8(zine.read_text(errors="ignore"))
        if u8:
            result.update({"uplanet8": u8, "source": ".nostr.zine.html"})
            print(json.dumps(result))
            return

    # 3. La carte ZenCard day0 (.ZENCard.html) contient la même trace.
    zencard_html = players_dir / ".ZENCard.html"
    if zencard_html.is_file() and zencard_html.stat().st_size > 0:
        u8 = _grep_uplanet8(zencard_html.read_text(errors="ignore"))
        if u8:
            result.update({"uplanet8": u8, "source": ".ZENCard.html"})
            print(json.dumps(result))
            return

    result["source"] = "none"
    print(json.dumps(result))


################################################################################

def main():
    parser = argparse.ArgumentParser(
        description="Fonctions d'audit/réparation pour respawn_NOSTRCARD.sh (JSON sur stdout)."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("checklist", help="Affiche la checklist des artefacts modernes (JSON)").set_defaults(func=checklist_cmd)

    p_audit = sub.add_parser("audit", help="Audit d'un compte : fichiers présents/manquants")
    p_audit.add_argument("email")
    p_audit.set_defaults(func=audit_cmd)

    sub.add_parser("scan-all", help="Audit de tous les comptes MULTIPASS locaux").set_defaults(func=scan_all_cmd)

    p_disco = sub.add_parser("recover-disco", help="Récupère SALT/PEPPER (.secret.disco > .multipass.json > CLI)")
    p_disco.add_argument("email")
    p_disco.add_argument("--salt", default=None)
    p_disco.add_argument("--pepper", default=None)
    p_disco.set_defaults(func=recover_disco_cmd)

    p_verify = sub.add_parser("verify-identity", help="Vérifie que SALT/PEPPER reproduit bien le NPUB/HEX existant")
    p_verify.add_argument("email")
    p_verify.add_argument("--salt", required=True)
    p_verify.add_argument("--pepper", required=True)
    p_verify.set_defaults(func=verify_identity_cmd)

    p_econ = sub.add_parser("recover-econ-level", help="Recopie le niveau économique (UPLANETNAME_G1/ORIGIN) déjà connu du compte")
    p_econ.add_argument("email")
    p_econ.set_defaults(func=recover_econ_level_cmd)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
