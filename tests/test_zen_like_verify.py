"""Tests de tools/zen_like_verify.py — contrôle d'un paiement ẐEN relayé en roaming (Kind 7).
Exécution : ~/.astro/bin/python3 -m pytest tests/test_zen_like_verify.py -q"""
import hashlib
import importlib.util
import json
import secrets
import time
from pathlib import Path

import pytest
from coincurve import PrivateKey

SPEC = importlib.util.spec_from_file_location("zlv", Path(__file__).resolve().parents[1] / "tools" / "zen_like_verify.py")
zlv = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(zlv)

DEST = "g1" + "A" * 40


def make_event(sk, content="+5", e="e" * 64, p="p" * 64, kind=7):
    pub = sk.public_key_xonly.format().hex()
    tags = [["e", e], ["p", p]]
    ts = int(time.time())
    ser = json.dumps([0, pub, ts, kind, tags, content], separators=(",", ":"), ensure_ascii=False)
    ev = {"pubkey": pub, "created_at": ts, "kind": kind, "tags": tags, "content": content, "id": hashlib.sha256(ser.encode()).hexdigest()}
    ev["sig"] = sk.sign_schnorr(bytes.fromhex(ev["id"])).hex()
    return ev


@pytest.fixture
def sk():
    return PrivateKey(secrets.token_bytes(32))


def payload(ev, **kw):
    base = {"email": "membre@example.org", "event": ev, "zen_amount": 5, "reacted_event_id": "e" * 64,
            "reacted_author_pubkey": "p" * 64, "g1pub_dest": DEST, "is_crowdfunding": False, "project_id": ""}
    base.update(kw)
    return base


def run(p, sk, tmp_path, **kw):
    return zlv.verify(p, local_hex=lambda email: sk.public_key_xonly.format().hex(), bien=kw.get("bien", lambda pid: ""),
                      resolve=kw.get("resolve", lambda h: DEST), ledger=tmp_path, reserve=kw.get("reserve", True))


def test_paiement_legitime(sk, tmp_path):
    r = run(payload(make_event(sk)), sk, tmp_path)
    assert r["ok"] and r["zen_amount"] == 5 and r["kind"] == "like"


def test_sans_evenement_signe(sk, tmp_path):
    p = payload(make_event(sk)); p.pop("event")
    assert not run(p, sk, tmp_path)["ok"]


def test_signature_falsifiee(sk, tmp_path):
    ev = make_event(sk); ev["content"] = "+500"          # contenu modifié après signature
    assert "INVALIDE" in run(payload(ev, zen_amount=500), sk, tmp_path)["reason"]


def test_signe_par_un_autre_compte(sk, tmp_path):
    other = PrivateKey(secrets.token_bytes(32))
    assert "pas signé par la clé de ce compte" in run(payload(make_event(other)), sk, tmp_path)["reason"]


def test_montant_gonfle_par_le_noeud_visiteur(sk, tmp_path):
    r = run(payload(make_event(sk, "+5"), zen_amount=1000), sk, tmp_path)
    assert not r["ok"] and "montant incohérent" in r["reason"]


def test_like_sans_montant_ne_paie_pas(sk, tmp_path):
    assert not run(payload(make_event(sk, "+"), zen_amount=1), sk, tmp_path)["ok"]


def test_destination_forgee(sk, tmp_path):
    r = run(payload(make_event(sk), g1pub_dest="g1" + "B" * 40), sk, tmp_path)
    assert not r["ok"] and "destination différente" in r["reason"]


def test_destination_inconnue_ici_refusee(sk, tmp_path):
    r = run(payload(make_event(sk)), sk, tmp_path, resolve=lambda h: "")
    assert not r["ok"] and "impossible à confirmer" in r["reason"]


def test_ids_reagis_differents(sk, tmp_path):
    assert not run(payload(make_event(sk), reacted_author_pubkey="x" * 64), sk, tmp_path)["ok"]


def test_crowdfunding_destination_du_projet(sk, tmp_path):
    p = payload(make_event(sk), is_crowdfunding=True, project_id="CF-1")
    assert run(p, sk, tmp_path, bien=lambda pid: DEST if pid == "CF-1" else "")["ok"]
    sk2 = PrivateKey(secrets.token_bytes(32))
    p2 = payload(make_event(sk2), is_crowdfunding=True, project_id="CF-1", g1pub_dest="g1" + "C" * 40)
    assert not run(p2, sk2, tmp_path / "b", bien=lambda pid: DEST)["ok"]


def test_rejeu_refuse(sk, tmp_path):
    p = payload(make_event(sk))
    assert run(p, sk, tmp_path)["ok"]
    r = run(p, sk, tmp_path)
    assert not r["ok"] and r.get("replay")


def test_verification_sans_reserver(sk, tmp_path):
    p = payload(make_event(sk))
    assert run(p, sk, tmp_path, reserve=False)["ok"] and run(p, sk, tmp_path, reserve=False)["ok"]
