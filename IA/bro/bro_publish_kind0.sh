#!/bin/bash
########################################################################
# bro_publish_kind0.sh — Publie le profil NOSTR (kind 0) du bot BRO
#
# La clé NODE_NSEC (bot BRO) est distincte des clés MULTIPASS utilisateurs.
# Ce script publie son kind 0 avec bot=true pour que les clients NOSTR
# l'identifient correctement comme un bot automatisé de la station.
#
# Usage : ./bro_publish_kind0.sh [relay_url]
#   relay_url : optionnel, défaut = myRELAY ou wss://relay.copylaradio.com
#
# Idempotent : peut être relancé sans effet de bord (kind 0 replaceable).
########################################################################
set -euo pipefail

MY_PATH="$(dirname "$(realpath "$0")")"

# Charger l'environnement station (myDOMAIN, myRELAY, myIPFS, CAPTAINEMAIL…)
# shellcheck source=/dev/null
. "${HOME}/.zen/Astroport.ONE/tools/my.sh" 2>/dev/null || true

# Charger NODE_NSEC depuis le fichier de secrets du bot
if [[ ! -s "$HOME/.zen/game/secret.nostr" ]]; then
    echo "ERROR: ~/.zen/game/secret.nostr absent" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$HOME/.zen/game/secret.nostr"
NODE_NSEC="${NSEC:-}"
unset NSEC NPUB HEX

if [[ -z "$NODE_NSEC" ]]; then
    echo "ERROR: NSEC absent dans secret.nostr" >&2
    exit 1
fi

# Relay cible : argument CLI > myRELAY > défaut public
_relay="${1:-}"
if [[ -z "$_relay" ]]; then
    if [[ -n "${myRELAY:-}" && ! "${myRELAY}" =~ ^ws://127\. ]]; then
        _relay="${myRELAY}"
    else
        _relay="wss://relay.copylaradio.com"
    fi
fi

_domain="${myDOMAIN:-$(hostname)}"
_ipfs_gw="${myIPFS:-https://ipfs.${_domain}}"

echo "📡 Publication kind 0 BRO sur ${_relay}"
echo "   Station : ${_domain}"

# Lancer le venv ~/.astro/ si disponible
_venv_python="${HOME}/.astro/bin/python3"
_python="python3"
[[ -x "$_venv_python" ]] && _python="$_venv_python"

"$_python" - "$NODE_NSEC" "$_relay" "$_domain" "$_ipfs_gw" <<'PYEOF'
import sys
import json
import hashlib
import time
import base64
import websocket

def nsec_to_hex(nsec):
    try:
        import bech32 as b32m
        hrp, data = b32m.bech32_decode(nsec)
        if hrp != "nsec" or data is None:
            raise ValueError("nsec invalide")
        return bytes(b32m.convertbits(data, 5, 8, False)).hex()
    except ImportError:
        # Fallback: bech32 manuel minimal
        CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
        _, data_part = nsec.lower().split("1", 1)
        decoded = [CHARSET.index(c) for c in data_part[:-6]]
        acc = 0; bits = 0; result = []
        for val in decoded:
            acc = ((acc << 5) | val)
            bits += 5
            while bits >= 8:
                bits -= 8
                result.append((acc >> bits) & 0xFF)
        return bytes(result).hex()

def priv_to_pub_hex(priv_hex):
    try:
        import coincurve
        priv = coincurve.PrivateKey(bytes.fromhex(priv_hex))
        return priv.public_key.format(compressed=True)[1:].hex()
    except ImportError:
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.hazmat.backends import default_backend
        priv_obj = ec.derive_private_key(int(priv_hex, 16), ec.SECP256K1(), default_backend())
        pub_obj = priv_obj.public_key()
        pub_nums = pub_obj.public_numbers()
        return pub_nums.x.to_bytes(32, 'big').hex()

def sign_event(event, priv_hex):
    """Signe un event NOSTR (Schnorr secp256k1 via coincurve ou pynostr)."""
    try:
        from pynostr.event import Event as PyEvent
        from pynostr.key import PrivateKey
        ev = PyEvent(
            kind=event['kind'],
            content=event['content'],
            tags=event['tags'],
            pubkey=event['pubkey'],
            created_at=event['created_at'],
        )
        ev.sign(priv_hex)
        return ev.to_dict()
    except ImportError:
        pass
    # Fallback manuel avec coincurve (Schnorr BIP-340)
    import coincurve
    serialized = json.dumps(
        [0, event['pubkey'], event['created_at'], event['kind'], event['tags'], event['content']],
        separators=(',', ':'), ensure_ascii=False
    ).encode('utf-8')
    event_id = hashlib.sha256(serialized).hexdigest()
    event['id'] = event_id
    priv = coincurve.PrivateKey(bytes.fromhex(priv_hex))
    import os
    aux = os.urandom(32)
    sig = priv.sign_schnorr(bytes.fromhex(event_id), aux)
    event['sig'] = sig.hex()
    return event

def publish_event(relay_url, event_dict, timeout=15):
    """Publie un event sur un relay NOSTR et attend l'OK."""
    msg = json.dumps(["EVENT", event_dict])
    ws = None
    try:
        ws = websocket.create_connection(relay_url, timeout=timeout)
        ws.send(msg)
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                ws.settimeout(2.0)
                resp = ws.recv()
                if resp:
                    data = json.loads(resp)
                    if isinstance(data, list) and data[0] == "OK":
                        accepted = data[2] if len(data) > 2 else True
                        return bool(accepted), data[3] if len(data) > 3 else ""
            except websocket.WebSocketTimeoutException:
                continue
            except Exception:
                break
        return False, "timeout"
    finally:
        if ws:
            try:
                ws.close()
            except Exception:
                pass

# ── Main ────────────────────────────────────────────────────────────
node_nsec  = sys.argv[1]
relay_url  = sys.argv[2]
domain     = sys.argv[3]
ipfs_gw    = sys.argv[4]

priv_hex = nsec_to_hex(node_nsec)
pub_hex  = priv_to_pub_hex(priv_hex)

name    = f"BRO@{domain}"
about   = (
    f"🤖 BRO — IA coopérative de la station {domain}. "
    "Répond aux DMs chiffrés (NIP-44). "
    "Commandes : #mem #rec #reset #skills. "
    "Station UPlanet · https://qo-op.com"
)
picture = f"{ipfs_gw}/ipns/copylaradio.com/img/BRO.png"
website = f"https://{domain}"
nip05   = f"bro@{domain}"

metadata = {
    "name": name,
    "display_name": "BRO",
    "about": about,
    "picture": picture,
    "website": website,
    "nip05": nip05,
    "bot": True,
}

tags = [
    ["i", f"home_station:{domain}", ""],
]

event = {
    "kind": 0,
    "pubkey": pub_hex,
    "created_at": int(time.time()),
    "tags": tags,
    "content": json.dumps(metadata, ensure_ascii=False),
}

signed = sign_event(event, priv_hex)

print(f"🔑 BRO pubkey : {pub_hex}")
print(f"📝 Event ID   : {signed['id']}")
print(f"📡 Relay      : {relay_url}")

ok, reason = publish_event(relay_url, signed)
if ok:
    print("✅ Kind 0 BRO publié avec succès")
    sys.exit(0)
else:
    print(f"❌ Échec publication : {reason}", file=sys.stderr)
    sys.exit(1)
PYEOF
