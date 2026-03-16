#!/usr/bin/env python3
"""
Tests d'intégration SS58 pour natools.py et g1pub_to_ss58.py
Couvre :
  - normalize_pubkey() : v1 pass-through, SS58 → v1
  - encrypt/decrypt round-trip avec clé SS58
  - box_encrypt/box_decrypt avec clé SS58 (NaCl Box DH)
  - g1pub_to_ss58 round-trip v1 ↔ SS58
  - Simulation SSSS (cas make_NOSTRCARD.sh)

Usage : ~/.astro/bin/python tests/test_ss58_integration.py
"""

import sys, os, importlib.util, base64, tempfile

# ── Helpers de chargement ──────────────────────────────────────────────────────
def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

# Le script est dans tests/, les outils sont dans ../tools/
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS     = os.path.join(TESTS_DIR, '..', 'tools')
TOOLS     = os.path.normpath(TOOLS)

natools   = load_module("natools",        os.path.join(TOOLS, "natools.py"))
g1pub_mod = load_module("g1pub_to_ss58",  os.path.join(TOOLS, "g1pub_to_ss58.py"))

import duniterpy.key, libnacl, base58

# ── Jeu de clés de test ───────────────────────────────────────────────────────
# Clés déterministes générées à partir de salt/password connus
# Alice : destinataire habituel (MULTIPASS)
_ALICE_SK     = duniterpy.key.SigningKey.from_credentials("coucou", "coucou")
TEST_V1_PUB   = _ALICE_SK.pubkey                           # base58 v1
TEST_SS58     = g1pub_mod.v1_to_ss58(TEST_V1_PUB)          # SS58 g1...
TEST_PRIVKEY  = _ALICE_SK                                   # SigningKey pour natools

# Bob : expéditeur (CAPTAIN / UPlanet) — paire distincte pour NaCl Box (DH)
_BOB_SK       = duniterpy.key.SigningKey.from_credentials("bob", "bob")
BOB_V1_PUB    = _BOB_SK.pubkey
BOB_SS58      = g1pub_mod.v1_to_ss58(BOB_V1_PUB)
BOB_PRIVKEY   = _BOB_SK

PASS = 0
FAIL = 0

def ok(msg):
    global PASS
    PASS += 1
    print(f"  ✅ {msg}")

def ko(msg, exc=None):
    global FAIL
    FAIL += 1
    print(f"  ❌ {msg}", file=sys.stderr)
    if exc:
        print(f"     Exception : {exc}", file=sys.stderr)

def section(title):
    print(f"\n{'━'*60}")
    print(f"  {title}")
    print('━'*60)

# ─────────────────────────────────────────────────────────────────────────────
section("1. g1pub_to_ss58 — round-trip v1 ↔ SS58")

try:
    assert TEST_SS58.startswith('g1'), "SS58 doit commencer par g1"
    ok(f"v1 → SS58 : {TEST_V1_PUB[:12]}… → {TEST_SS58[:12]}…")
except Exception as e:
    ko("v1 → SS58 échoué", e)

try:
    recovered = g1pub_mod.ss58_to_v1(TEST_SS58)
    assert recovered == TEST_V1_PUB, f"Attendu {TEST_V1_PUB}, obtenu {recovered}"
    ok(f"SS58 → v1 round-trip : ✓")
except Exception as e:
    ko("SS58 → v1 round-trip échoué", e)

try:
    assert g1pub_mod.is_ss58(TEST_SS58), "is_ss58(SS58) doit être True"
    assert not g1pub_mod.is_ss58(TEST_V1_PUB), "is_ss58(v1) doit être False"
    ok("is_ss58() correctement différencie v1 et SS58")
except Exception as e:
    ko("is_ss58() échoué", e)

# ─────────────────────────────────────────────────────────────────────────────
section("2. natools.normalize_pubkey()")

try:
    result = natools.normalize_pubkey(TEST_V1_PUB)
    assert result == TEST_V1_PUB, f"v1 pass-through échoué : {result}"
    ok(f"normalize_pubkey(v1) → v1 inchangé")
except Exception as e:
    ko("normalize_pubkey(v1) échoué", e)

try:
    result = natools.normalize_pubkey(TEST_SS58)
    assert result == TEST_V1_PUB, f"SS58 → v1 échoué : {result}"
    ok(f"normalize_pubkey(SS58) → v1 correct")
except Exception as e:
    ko("normalize_pubkey(SS58) échoué", e)

try:
    result = natools.normalize_pubkey("")
    assert result == "", "Chaîne vide doit retourner chaîne vide"
    ok("normalize_pubkey('') → '' (guard clause OK)")
except Exception as e:
    ko("normalize_pubkey('') échoué", e)

try:
    garbage = "NotAValidKey123"
    result = natools.normalize_pubkey(garbage)
    assert result == garbage, "Clé invalide doit être retournée telle quelle"
    ok("normalize_pubkey(invalide) → pass-through (pas d'exception)")
except Exception as e:
    ko("normalize_pubkey(invalide) a levé une exception inattendue", e)

# ─────────────────────────────────────────────────────────────────────────────
section("3. natools.encrypt / decrypt avec clé SS58")

TEST_DATA = b"Message secret test UPlanet 2026"

try:
    encrypted_v1  = natools.encrypt(TEST_DATA, TEST_V1_PUB)
    encrypted_ss58 = natools.encrypt(TEST_DATA, TEST_SS58)
    # Les deux doivent produire des chiffrés déchiffrables
    decrypted_v1   = natools.decrypt(encrypted_v1,   TEST_PRIVKEY)
    decrypted_ss58  = natools.decrypt(encrypted_ss58,  TEST_PRIVKEY)
    assert decrypted_v1  == TEST_DATA, f"Déchiffrement v1 échoué : {decrypted_v1}"
    assert decrypted_ss58 == TEST_DATA, f"Déchiffrement SS58 échoué : {decrypted_ss58}"
    ok("encrypt(v1)  + decrypt → message original ✓")
    ok("encrypt(SS58) + decrypt → message original ✓")
except Exception as e:
    ko("encrypt/decrypt avec SS58 échoué", e)

# ─────────────────────────────────────────────────────────────────────────────
section("4. natools.box_encrypt / box_decrypt avec clé SS58")
# NaCl Box (DH) : Bob chiffre POUR Alice, Alice déchiffre.
# box_encrypt(data, privkey_expéditeur, pubkey_destinataire, attach_nonce=True)
# box_decrypt(data, privkey_destinataire, pubkey_expéditeur)
# IMPORTANT : attach_nonce=True est obligatoire pour que box_decrypt puisse
# extraire le nonce (24 bytes) depuis la tête du message chiffré.

try:
    # Bob chiffre pour Alice avec la clé v1 d'Alice
    box_enc_v1 = natools.box_encrypt(TEST_DATA, BOB_PRIVKEY, TEST_V1_PUB, attach_nonce=True)
    box_dec_v1 = natools.box_decrypt(box_enc_v1, TEST_PRIVKEY, BOB_V1_PUB)
    assert box_dec_v1 == TEST_DATA
    ok("box_encrypt(Bob→Alice v1, attach_nonce) + box_decrypt(Alice, Bob v1) → ✓")
except Exception as e:
    ko("box_encrypt/box_decrypt (v1) échoué", e)

try:
    # Bob chiffre pour Alice avec la clé SS58 d'Alice (test du normalize_pubkey)
    box_enc_ss58 = natools.box_encrypt(TEST_DATA, BOB_PRIVKEY, TEST_SS58, attach_nonce=True)
    box_dec_ss58 = natools.box_decrypt(box_enc_ss58, TEST_PRIVKEY, BOB_V1_PUB)
    assert box_dec_ss58 == TEST_DATA
    ok("box_encrypt(Bob→Alice SS58, attach_nonce) + box_decrypt(Alice, Bob v1) → ✓")
except Exception as e:
    ko("box_encrypt/box_decrypt avec SS58 destinataire échoué", e)

try:
    # Cross-format : chiffré avec v1 Alice, déchiffré en passant SS58 de Bob
    box_enc_v1   = natools.box_encrypt(TEST_DATA, BOB_PRIVKEY, TEST_V1_PUB, attach_nonce=True)
    box_dec_cross = natools.box_decrypt(box_enc_v1, TEST_PRIVKEY, BOB_SS58)
    assert box_dec_cross == TEST_DATA
    ok("box_encrypt(v1, attach_nonce) + box_decrypt(SS58 expéditeur) → cross-format ✓")
except Exception as e:
    ko("Cross-format box_decrypt (SS58 expéditeur) échoué", e)

# ─────────────────────────────────────────────────────────────────────────────
section("5. Chiffrement SSSS simulé (cas make_NOSTRCARD.sh)")

try:
    ssss_secret = b"2-c3a7f1b2e4d5a6b8:some_nostr_vault_key"

    with tempfile.NamedTemporaryFile(delete=False, suffix=".ssss.head") as f:
        f.write(ssss_secret)
        ssss_path = f.name

    with tempfile.NamedTemporaryFile(delete=False, suffix=".enc") as f:
        enc_path = f.name

    # Chiffrement avec SS58 (comme dans make_NOSTRCARD.sh après fix)
    encrypted = natools.encrypt(ssss_secret, TEST_SS58)
    with open(enc_path, "wb") as f:
        f.write(encrypted)

    # Déchiffrement avec clé privée
    with open(enc_path, "rb") as f:
        decrypted = natools.decrypt(f.read(), TEST_PRIVKEY)

    assert decrypted == ssss_secret
    ok("Simulation SSSS encrypt(SS58) / decrypt(privkey) → ✓")

    os.unlink(ssss_path)
    os.unlink(enc_path)
except Exception as e:
    ko("Simulation SSSS échouée", e)

# ─────────────────────────────────────────────────────────────────────────────
section("6. Longueur et format des clés")

try:
    raw_v1 = base58.b58decode(TEST_V1_PUB)
    assert len(raw_v1) == 32, f"Clé v1 doit faire 32 bytes, obtenu {len(raw_v1)}"
    ok(f"Clé v1 = {len(raw_v1)} bytes ✓")

    raw_ss58 = base58.b58decode(TEST_SS58)
    assert len(raw_ss58) == 36, f"Clé SS58 doit faire 36 bytes (2+32+2), obtenu {len(raw_ss58)}"
    ok(f"Clé SS58 = {len(raw_ss58)} bytes (2 préfixe + 32 raw + 2 checksum) ✓")

    # normalize_pubkey extrait bien les 32 bytes centraux
    normalized = natools.normalize_pubkey(TEST_SS58)
    raw_norm = base58.b58decode(normalized)
    assert len(raw_norm) == 32
    assert raw_norm == raw_ss58[2:-2]
    ok("normalize_pubkey extrait les 32 bytes raw corrects ✓")
except Exception as e:
    ko("Test longueur clés échoué", e)

# ─────────────────────────────────────────────────────────────────────────────
print(f"\n{'═'*60}")
print(f"  Résultat : {PASS} test(s) réussi(s), {FAIL} échec(s)")
print('═'*60)
sys.exit(0 if FAIL == 0 else 1)
