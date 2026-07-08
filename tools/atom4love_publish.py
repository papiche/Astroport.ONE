#!/usr/bin/env python3
"""
atom4love_publish.py — Dérive la clé NOSTR dédiée ATOM4LOVE (.secret.love),
calcule la résonance Phi² et publie l'event kind 30078 (d=atom4love).

La clé LOVE est DÉTERMINISTE : dérivée par PBKDF2-HMAC-SHA256 (domaine
"uplanet-a4l-v1", 600k itérations) des données de naissance/conception —
formule IDENTIQUE à zelkova/lib/g1/atomic_keys.dart (buildSaltRaw/buildPepperRaw/
localSolarToUtcStr), pour garantir la conformité client/serveur : recevoir les
mêmes paramètres de naissance reproduit toujours exactement la même clé.

Cette clé est DISTINCTE de la clé NOSTR principale du MULTIPASS (.secret.nostr)
— elle sert uniquement à signer/chiffrer le canal DM "LOVE" avec BRO et à
publier le profil de résonance Phi² (kind 30078), jamais à des paiements ẐEN.

Réutilise phi2x.py (référence canonique partagée avec cabine-33/UPlanet-earth)
et nostr_send_note.py (signature + publication, même mécanisme que le kind 0
de nostr_setup_profile.py).

Usage:
    atom4love_publish.py EMAIL BIRTH_DATETIME BIRTH_LAT BIRTH_LON BIRTH_WEIGHT POLARITY [CONCEPTION_DATETIME]

Imprime en DERNIÈRE ligne de stdout un JSON — seule sortie parsée par les
appelants (atom4love_activate.sh, UPassport routers/identity.py).
"""
import sys
import os
import json
import math
import hashlib
import base64
import secrets
import subprocess
from datetime import datetime, timedelta, timezone

MY_PATH = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, MY_PATH)

import phi2x  # noqa: E402
from nostr_send_note import send_nostr_event  # noqa: E402

try:
    # nostr_sdk (rust-nostr officiel) — déjà dans UPassport/requirements.txt et
    # installé dans le venv ~/.astro/ (voir la ré-exécution ci-dessus, déclenchée
    # par l'import de nostr_send_note). Implémentation NIP-44 auditée — on évite
    # volontairement toute réimplémentation maison (HKDF/ChaCha20/HMAC à la main).
    from nostr_sdk import SecretKey, PublicKey, nip44_encrypt, Nip44Version
    _NIP44_AVAILABLE = True
except ImportError:
    _NIP44_AVAILABLE = False

DOMAIN_SALT = b"uplanet-a4l-v1"
PBKDF2_ITERATIONS = 600_000
BIRTH_HEIGHT_CM_DEFAULT = 50    # constante — non collectée, identique à atomic_keys.dart
CURRENT_HEIGHT_CM_DEFAULT = 170  # constante — non collectée, identique à atomic_keys.dart


# ── Port exact de zelkova/lib/g1/atomic_keys.dart ───────────────────────────

def _equation_of_time(year: int, month: int, day: int) -> float:
    """Correction saisonnière midi solaire vs midi civil (minutes)."""
    doy = (datetime(year, month, day) - datetime(year, 1, 1)).days + 1
    b = (2 * math.pi / 365) * (doy - 81)
    return 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b)


def local_solar_to_utc(year: int, month: int, day: int, hour: int, minute: int,
                        lon_deg: float) -> datetime:
    """Heure solaire locale + longitude → datetime UTC (aware). Précision minute."""
    offset_min = lon_deg * 4.0 + _equation_of_time(year, month, day)
    utc_min = round(hour * 60 + minute - offset_min)
    return datetime(year, month, day, tzinfo=timezone.utc) + timedelta(minutes=utc_min)


def _utc_str(dt: datetime) -> str:
    """Format 'YYYYMMDDHHMM' — identique à atomic_keys.dart::localSolarToUtcStr."""
    return dt.strftime("%Y%m%d%H%M")


def build_salt_raw(birth_dt_utc_str: str, birth_lat: float, birth_lon: float,
                    polarity: int, weight_kg: float) -> str:
    return (f"{birth_dt_utc_str}_{birth_lat:.2f}_{birth_lon:.2f}_{polarity}_"
            f"{weight_kg:.1f}_{BIRTH_HEIGHT_CM_DEFAULT}_{CURRENT_HEIGHT_CM_DEFAULT}")


def build_pepper_raw(con_dt_utc_str: str, birth_lat: float, birth_lon: float,
                      weight_kg: float) -> str:
    return f"{con_dt_utc_str}_{birth_lat:.2f}_{birth_lon:.2f}_{weight_kg:.1f}_{BIRTH_HEIGHT_CM_DEFAULT}"


def stretch_key(raw: str) -> str:
    """PBKDF2-HMAC-SHA256 → base64url sans padding. Identique à atomic_keys.dart::stretchKey."""
    derived = hashlib.pbkdf2_hmac("sha256", raw.encode(), DOMAIN_SALT, PBKDF2_ITERATIONS, dklen=32)
    return base64.urlsafe_b64encode(derived).rstrip(b"=").decode()


# ── Dérivation de la paire de clés NOSTR (.secret.love) ─────────────────────

def derive_love_keypair(stretched_salt: str, stretched_pepper: str) -> tuple[str, str, str]:
    """keygen -t nostr [-s] -i <credfile> → (nsec, npub, hex). Même mécanisme que make_NOSTRCARD.sh."""
    keygen = os.path.join(MY_PATH, "keygen")
    nostr2hex = os.path.join(MY_PATH, "nostr2hex.py")
    cred_path = f"/dev/shm/.a4l_{secrets.token_hex(8)}" if os.path.isdir("/dev/shm") \
        else f"/tmp/.a4l_{secrets.token_hex(8)}"
    try:
        with open(cred_path, "w") as f:
            f.write(f"{stretched_salt}\n{stretched_pepper}\n")
        os.chmod(cred_path, 0o600)
        nsec = subprocess.run([keygen, "-t", "nostr", "-s", "-i", cred_path],
                               capture_output=True, text=True, check=True).stdout.strip()
        npub = subprocess.run([keygen, "-t", "nostr", "-i", cred_path],
                               capture_output=True, text=True, check=True).stdout.strip()
        hex_pub = subprocess.run(["python3", nostr2hex, npub],
                                  capture_output=True, text=True, check=True).stdout.strip()
        return nsec, npub, hex_pub
    finally:
        try:
            os.remove(cred_path)
        except OSError:
            pass


def _nip44_encrypt_try(priv_bech32_or_hex: str, recipient_hex: str, plaintext: str):
    """Chiffre en NIP-44 v2, ou renvoie None en cas d'échec (jamais fatal)."""
    if not _NIP44_AVAILABLE:
        return None
    try:
        sk = SecretKey.parse(priv_bech32_or_hex)
        pk = PublicKey.parse(recipient_hex)
        return nip44_encrypt(sk, pk, plaintext, Nip44Version.V2)
    except Exception as e:
        print(f"⚠️ NIP-44 encrypt skipped ({recipient_hex[:8]}…): {e}", file=sys.stderr)
        return None


def _resolve_umap_hex(lat: float, lon: float):
    """Clé NOSTR déterministe de l'UMAP (grille 0.01°) — Umap2hex.sh, ou None."""
    umap2hex = os.path.join(MY_PATH, "Umap2hex.sh")
    if not os.path.exists(umap2hex):
        return None
    try:
        out = subprocess.run([umap2hex, str(lat), str(lon)],
                              capture_output=True, text=True, timeout=15, check=True)
        hex_key = out.stdout.strip()
        return hex_key if len(hex_key) == 64 else None
    except Exception as e:
        print(f"⚠️ UMAP hex resolution skipped: {e}", file=sys.stderr)
        return None


def write_secret_love(email: str, nsec: str, npub: str, hex_pub: str) -> str:
    nostr_dir = os.path.expanduser(f"~/.zen/game/nostr/{email}")
    os.makedirs(nostr_dir, exist_ok=True)
    path = os.path.join(nostr_dir, ".secret.love")
    with open(path, "w") as f:
        f.write(f"NSEC={nsec}; NPUB={npub}; HEX={hex_pub};\n")
    os.chmod(path, 0o600)
    # Copie en clair du hex (comme HEX pour .secret.nostr) — permet à
    # bro_resolve_email() (IA/bro/bro_common_lib.sh) de retrouver l'email
    # depuis le pubkey LOVE d'un message DM entrant.
    with open(os.path.join(nostr_dir, "HEX_LOVE"), "w") as f:
        f.write(hex_pub)
    return path


# ── Main ──────────────────────────────────────────────────────────────────────

def _fail(error: str, extra: dict | None = None) -> None:
    payload = {"activated": False, "error": error}
    if extra:
        payload.update(extra)
    print(json.dumps(payload))
    sys.exit(1)


def main() -> None:
    if len(sys.argv) < 7:
        print("Usage: atom4love_publish.py EMAIL BIRTH_DATETIME BIRTH_LAT BIRTH_LON "
              "BIRTH_WEIGHT POLARITY [CONCEPTION_DATETIME]", file=sys.stderr)
        sys.exit(1)

    email = sys.argv[1]
    birth_datetime = sys.argv[2]  # "YYYY-MM-DDTHH:MM" (heure locale de naissance)
    conception_datetime = sys.argv[7] if len(sys.argv) > 7 else ""

    try:
        birth_lat = float(sys.argv[3])
        birth_lon = float(sys.argv[4])
        birth_weight = float(sys.argv[5]) if sys.argv[5] else 3.5
        polarity = int(sys.argv[6]) if sys.argv[6] else 0
    except ValueError as e:
        _fail("INVALID_PARAMETERS", {"detail": str(e)})
        return

    primary_secret = os.path.expanduser(f"~/.zen/game/nostr/{email}/.secret.nostr")
    if not os.path.exists(primary_secret):
        _fail("PRIMARY_ACCOUNT_NOT_FOUND")
        return

    try:
        birth_local = datetime.strptime(birth_datetime, "%Y-%m-%dT%H:%M")
    except ValueError as e:
        _fail("INVALID_BIRTH_DATETIME", {"detail": str(e)})
        return

    birth_dt_utc = local_solar_to_utc(
        birth_local.year, birth_local.month, birth_local.day,
        birth_local.hour, birth_local.minute, birth_lon,
    )
    conception_local = birth_local - timedelta(days=280)
    con_dt_utc = local_solar_to_utc(
        conception_local.year, conception_local.month, conception_local.day,
        12, 0, birth_lon,
    )

    salt_raw = build_salt_raw(_utc_str(birth_dt_utc), birth_lat, birth_lon, polarity, birth_weight)
    pepper_raw = build_pepper_raw(_utc_str(con_dt_utc), birth_lat, birth_lon, birth_weight)
    stretched_salt = stretch_key(salt_raw)
    stretched_pepper = stretch_key(pepper_raw)

    try:
        love_nsec, love_npub, love_hex = derive_love_keypair(stretched_salt, stretched_pepper)
    except subprocess.CalledProcessError as e:
        _fail("KEYGEN_FAILED", {"detail": e.stderr.strip() if e.stderr else str(e)})
        return
    if not love_nsec or not love_npub or not love_hex:
        _fail("KEYGEN_FAILED")
        return

    love_keyfile = write_secret_love(email, love_nsec, love_npub, love_hex)

    # ── Résonance Phi² ─────────────────────────────────────────────────────
    birth_unix = int(birth_dt_utc.timestamp())
    personal_phase = phi2x.compute_personal_phase(birth_unix, birth_lat, birth_lon)
    water_ratio = 0.65 if polarity == 0 else 0.60  # même simplification que l'ex-client Dart
    omega_bio = phi2x.F_WATER * (birth_weight * water_ratio / 70.0)
    a4l_proof = phi2x.compute_a4l_proof(love_hex)
    kin = phi2x.calc_kin_unix(birth_unix) or {}

    # Tags géo/cymatiques — mêmes formules que atomic.html::publishIncarnationCert,
    # nécessaires à atomic_map.html pour localiser/afficher le profil.
    geo_tag = phi2x.geo_tag_a4l(birth_lat, birth_lon, birth_unix)
    a5l_amplitude = phi2x.compute_resonance_field(birth_lat, birth_lon, birth_unix)
    a5l_tag = phi2x.encode_a5l_tag(a5l_amplitude)

    content = {
        "personal_phase": round(personal_phase, 6),
        "omega_bio": round(omega_bio, 4),
        "a5l_amplitude": round(a5l_amplitude, 6),
        "biological_sex": polarity,
        "kin_num": kin.get("kin", 0),
        "version": 1,
        "email": email,
    }
    tags = [
        ["d", "atom4love"], ["a4l_proof", a4l_proof], ["email", email],
        ["g", geo_tag["penta"]], ["g", geo_tag["hex"]], ["a5l", a5l_tag],
    ]
    if kin:
        tags += [
            ["kin", str(kin["kin"])], ["glyph", kin["glyph_fr"]],
            ["tone", str(kin["tone_num"])], ["color", kin["color_fr"]],
        ]
    if conception_datetime:
        try:
            c_local = datetime.strptime(conception_datetime, "%Y-%m-%dT%H:%M")
            c_kin = phi2x.calc_kin(c_local.year, c_local.month, c_local.day)
            if c_kin:
                tags += [
                    ["kin_c", str(c_kin["kin"])], ["glyph_c", c_kin["glyph_fr"]],
                    ["tone_c", str(c_kin["tone_num"])],
                ]
        except ValueError:
            pass

    publish_result = send_nostr_event(love_keyfile, json.dumps(content), tags=tags,
                                       kind=30078, json_output=True)

    # ── Companion "atom4love-home" + "atom4love-priv" (résidence, si connue) ─
    gps_file = os.path.expanduser(f"~/.zen/game/nostr/{email}/GPS")
    if os.path.exists(gps_file):
        home_lat_s = home_lon_s = None
        try:
            gps_content = open(gps_file).read()
            home_lat_s = gps_content.split("LAT=")[1].split(";")[0].strip()
            home_lon_s = gps_content.split("LON=")[1].split(";")[0].strip()
            home_geo_tag = phi2x.geo_tag_a4l(float(home_lat_s), float(home_lon_s), birth_unix)
            home_tags = [["d", "atom4love-home"], ["app", "atom4love"],
                         ["a4l_proof", a4l_proof], ["g", home_geo_tag["penta"]],
                         ["lat", home_lat_s], ["lon", home_lon_s]]
            send_nostr_event(love_keyfile, "", tags=home_tags, kind=30078, json_output=True)
        except Exception as e:
            print(f"⚠️ atom4love-home publish skipped: {e}", file=sys.stderr)

        # d=atom4love-priv — préférences privées chiffrées NIP-44 (résidence +
        # heure de naissance), chiffrées vers soi-même et vers la clé UMAP de
        # résidence si résoluble. Silencieusement sauté si aucun chiffrement
        # n'aboutit (comme l'ancien client atomic.html::_publishA4lCompanion).
        if home_lat_s is not None and home_lon_s is not None:
            try:
                priv_data = json.dumps({
                    "home_lat": float(home_lat_s),
                    "home_lon": float(home_lon_s),
                    "birth_time_utc": birth_unix,
                    "privacy_prefs": {},
                })
                self_cipher = _nip44_encrypt_try(love_nsec, love_hex, priv_data)
                station_cipher = None
                umap_hex = _resolve_umap_hex(float(home_lat_s), float(home_lon_s))
                if umap_hex:
                    station_cipher = _nip44_encrypt_try(love_nsec, umap_hex, priv_data)

                if self_cipher or station_cipher:
                    priv_content = json.dumps({
                        **({"self": self_cipher} if self_cipher else {}),
                        **({"station": station_cipher} if station_cipher else {}),
                    })
                    priv_tags = [["d", "atom4love-priv"], ["app", "atom4love"],
                                 ["a4l_proof", a4l_proof]]
                    send_nostr_event(love_keyfile, priv_content, tags=priv_tags,
                                      kind=30078, json_output=True)
                else:
                    print("ℹ️ atom4love-priv ignoré — NIP-44 indisponible", file=sys.stderr)
            except Exception as e:
                print(f"⚠️ atom4love-priv publish skipped: {e}", file=sys.stderr)

    print(json.dumps({
        "activated": bool(publish_result.get("success")),
        "email": email,
        "love_nsec": love_nsec,
        "love_npub": love_npub,
        "love_hex": love_hex,
        "kin_num": kin.get("kin", 0),
        "personal_phase": round(personal_phase, 6),
    }))


if __name__ == "__main__":
    main()
