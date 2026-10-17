#!/usr/bin/env python3
"""
zen_like_verify.py — contrôle d'un paiement ẐEN « zen_like » relayé par une station VISITEUSE (roaming Kind 7).

La station d'origine (bro_dm_daemon.sh::_handle_zen_like) ne doit JAMAIS payer sur la seule foi du message d'un
autre nœud : ce message porte le montant et l'adresse de destination, et n'importe quel nœud de la constellation
peut l'émettre. Ce script revérifie TOUT à partir de l'événement Kind 7 SIGNÉ que la station visiteuse joint :

  1. l'événement est présent, de kind 7, avec un identifiant et une signature Schnorr valides ;
  2. il a été signé par la clé (HEX) du compte local `email` — pas par un autre ;
  3. le montant revient de SON contenu (« +N », borné à 1000, comme parse_zen_amount) et égale zen_amount ;
  4. les identifiants réagis (tags e / p) correspondent à ceux du message ;
  5. la destination est recalculée ICI : crowdfunding → Bien du projet (game/crowdfunding/<id>/bien.pubkeys),
     sinon G1PUBNOSTR de l'auteur réagi (search_for_this_hex_in_uplanet.sh). Introuvable ici = REFUS
     (jamais de paiement vers une adresse que cette station ne peut pas confirmer) ;
  6. anti-rejeu : un événement ne paie qu'UNE fois (registre game/zen_like_done/<event_id>, créé de façon atomique).

Entrée : JSON du message sur stdin.  Sortie : une ligne JSON {"ok":bool,"reason":str,...} ; code retour 0 si ok.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
LEDGER = HOME / ".zen" / "game" / "zen_like_done"
CROWD = HOME / ".zen" / "game" / "crowdfunding"
NOSTR = HOME / ".zen" / "game" / "nostr"
RESOLVE = HOME / ".zen" / "Astroport.ONE" / "tools" / "search_for_this_hex_in_uplanet.sh"
HEX_RE = re.compile(r"^[0-9a-f]{64}$")
EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")


def _crypto():
    sys.path.insert(0, str(HOME / ".zen" / "UPassport"))
    from utils.crypto import verify_nostr_event      # implémentation Python pure, déjà utilisée par UPassport
    return verify_nostr_event


def amount_from_content(content: str) -> int:
    """Même règle que NIP-101/filter/common.sh::parse_zen_amount : « +N » → N borné [1, 1000], le reste → 0."""
    m = re.match(r"^\+(\d+)", content or "")
    if not m:
        return 0
    return max(1, min(1000, int(m.group(1))))


def tag(ev: dict, name: str) -> str:
    for t in ev.get("tags", []):
        if isinstance(t, list) and len(t) > 1 and t[0] == name:
            return str(t[1])
    return ""


def _local_hex(email: str) -> str:
    try:
        return (NOSTR / email / "HEX").read_text().strip().lower()
    except Exception:
        return ""


def _bien_g1pub(project_id: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,80}", project_id or ""):
        return ""
    try:
        for line in (CROWD / project_id / "bien.pubkeys").read_text().splitlines():
            if line.startswith("BIEN_G1PUB="):
                return line.split("=", 1)[1].strip().strip('"\'')
    except Exception:
        pass
    return ""


def _resolve_author_g1pub(hex_pub: str) -> str:
    try:
        r = subprocess.run([str(RESOLVE), hex_pub], capture_output=True, text=True, timeout=30)
        lines = [l.strip() for l in r.stdout.splitlines() if l.strip()]
        return lines[-1] if r.returncode == 0 and lines else ""
    except Exception:
        return ""


def claim(event_id: str, ledger: Path = None) -> bool:
    """Réserve l'événement (création exclusive). False s'il a déjà été payé/réservé."""
    ledger = ledger or LEDGER
    ledger.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(str(ledger / event_id), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        return False
    os.write(fd, str(int(__import__("time").time())).encode())
    os.close(fd)
    return True


def verify(p: dict, *, verify_event=None, local_hex=_local_hex, bien=_bien_g1pub, resolve=_resolve_author_g1pub,
           ledger: Path = None, reserve: bool = True) -> dict:
    def no(reason, **kw):
        return dict({"ok": False, "reason": reason}, **kw)

    ev = p.get("event")
    if not isinstance(ev, dict):
        return no("événement signé absent (station visiteuse trop ancienne ?)")
    if ev.get("kind") != 7:
        return no("l'événement joint n'est pas un Kind 7")
    event_id = str(ev.get("id", ""))
    if not HEX_RE.match(event_id):
        return no("identifiant d'événement invalide")
    try:
        ok = (verify_event or _crypto())(ev)
    except Exception as e:
        return no(f"vérification de signature impossible : {e}")
    if not ok:
        return no("signature ou identifiant d'événement INVALIDE", event_id=event_id)
    email = str(p.get("email", ""))
    if not EMAIL_RE.match(email):
        return no("email invalide")
    mine = local_hex(email)
    if not HEX_RE.match(mine) or str(ev.get("pubkey", "")).lower() != mine:
        return no("l'événement n'est pas signé par la clé de ce compte", event_id=event_id)
    amount = amount_from_content(ev.get("content", ""))
    try:
        claimed = float(p.get("zen_amount"))
    except Exception:
        return no("montant du message illisible")
    if amount <= 0 or abs(amount - claimed) > 1e-9:
        return no(f"montant incohérent : l'événement signé dit {amount}, le message {claimed}", event_id=event_id)
    if str(p.get("reacted_event_id", "")) != tag(ev, "e") or str(p.get("reacted_author_pubkey", "")) != tag(ev, "p"):
        return no("événement/auteur réagis différents de l'événement signé", event_id=event_id)

    dest = str(p.get("g1pub_dest", ""))
    if p.get("is_crowdfunding") in (True, "true", "True"):
        expected = bien(str(p.get("project_id", "")))
        kind = "crowdfunding"
    else:
        expected = resolve(tag(ev, "p"))
        kind = "like"
    if not expected:
        return no(f"destination impossible à confirmer sur cette station ({kind}) — paiement refusé, à examiner", event_id=event_id)
    if expected != dest:
        return no(f"destination différente de celle calculée ici ({kind}) : message {dest[:10]}… ≠ attendu {expected[:10]}…", event_id=event_id)
    if reserve and not claim(event_id, ledger):
        return no("événement déjà traité (rejeu)", event_id=event_id, replay=True)
    return {"ok": True, "reason": "ok", "event_id": event_id, "zen_amount": amount, "dest": expected, "kind": kind}


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception as e:
        print(json.dumps({"ok": False, "reason": f"message illisible : {e}"}))
        return 1
    res = verify(payload)
    print(json.dumps(res, ensure_ascii=False))
    return 0 if res["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
