"""story_asset.py : portée coop/private, versions, historique, restauration, fork, personnages dans une scène.
IPFS et relais NOSTR sont simulés ; lancer avec : python -m pytest tests/test_story_asset.py"""
import importlib
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))


@pytest.fixture()
def sa(tmp_path, monkeypatch):
    monkeypatch.setenv("SCENES_DIR", str(tmp_path))
    import story_asset
    sa = importlib.reload(story_asset)
    blobs, events = {}, []

    monkeypatch.setattr(sa, "ipfs_add", lambda payload, name: blobs.setdefault("Qm%040d" % len(blobs), payload) and list(blobs)[-1])
    monkeypatch.setattr(sa, "ipfs_cat", lambda cid: blobs[cid])
    monkeypatch.setattr(sa, "ipfs_pin", lambda cid: None)

    def fake_publish(nsec, tags, content):
        ev = {"id": "ev%03d" % len(events), "kind": sa.KIND, "pubkey": sa.captain_hex(), "created_at": 1000 + len(events),
              "tags": tags, "content": json.dumps(content)}
        events.append(ev)
        return ev["id"]

    monkeypatch.setattr(sa, "publish_event", fake_publish)
    monkeypatch.setattr(sa, "relay_events", lambda **f: [e for e in events if not f.get("tag_t") or ["t", f["tag_t"]] in e["tags"]])
    monkeypatch.setattr(sa, "captain_secret", lambda: "nsec-test")
    monkeypatch.setattr(sa, "captain_hex", lambda: "a" * 64)
    monkeypatch.setattr(sa, "coop_key", lambda: "11" * 32)
    monkeypatch.setattr(sa, "send_key", lambda *a: True)
    sa.events = events
    return sa


def test_private_versions_and_restore(sa):
    e1 = sa.create("scene", "Demo", scope="private")
    assert e1["version"] == 1 and "key_hex" in e1
    sb = json.dumps({"shots": [{"prompt": "un plan"}, {"prompt": "deux"}]}).encode()
    e2 = sa.new_version(e1["cid"], {"storyboard.json": sb}, description="v2")
    assert e2["version"] == 2 and e2["cid"] != e1["cid"] and e2["key_hex"] != e1["key_hex"]
    ev = json.loads(sa.events[-1]["content"])
    assert [h["cid"] for h in ev["history"]] == [e1["cid"]]
    vs = sa.versions(e2["cid"])
    assert [v["version"] for v in vs] == [2, 1]
    # l'ancienne version reste lisible
    _e, _m, files = sa.open_bundle(e1["cid"])
    assert json.loads(files["storyboard.json"])["shots"][0]["prompt"].startswith("A calm")
    e3 = sa.restore(e1["cid"])
    assert e3["version"] == 3 and sa.versions(e3["cid"])[0]["cid"] == e3["cid"]
    _e, _m, f3 = sa.open_bundle(e3["cid"])
    assert f3["storyboard.json"] == files["storyboard.json"]
    assert len(sa.list_assets()) == 1  # une seule entrée par lignée


def test_coop_is_readable_by_another_station_and_forkable(sa, monkeypatch):
    e = sa.create("character", "lea", scope="coop")
    assert "key_hex" not in e  # clé coopérative recalculée, jamais stockée
    # autre station : pas de keyring, même UPLANETNAME, autre Capitaine
    other_events = [dict(ev, pubkey="b" * 64) for ev in sa.events]
    monkeypatch.setattr(sa, "relay_events", lambda **f: other_events)
    sa.KEYRING.unlink()
    assets = sa.list_assets()
    assert [(a["name"], a["scope"], a["mine"]) for a in assets] == [("lea", "coop", False)]
    _e, manifest, files = sa.open_bundle(assets[0]["cid"])
    assert manifest["name"] == "lea" and "cast/lea/character.json" in files
    with pytest.raises(sa.AssetError):
        sa.new_version(assets[0]["cid"], {"cast/lea/x.txt": b"x"})  # pas d'édition chez un autre
    mine = sa.fork(assets[0]["cid"], name="lea2", scope="private")
    assert mine["origin"]["d"] == "character-lea" and "cast/lea2/character.json" in sa.open_bundle(mine["cid"])[2]


def test_attach_character_to_scene(sa):
    ch = sa.create("character", "ana", scope="private")
    ch2 = sa.new_version(ch["cid"], {"cast/ana/portrait.png": b"PNG", "cast/ana/voice.wav": b"RIFF"})
    sc = sa.create("scene", "S", scope="private")
    sc2 = sa.new_version(sc["cid"], {}, attach=[{"cid": ch2["cid"]}])
    _e, _m, files = sa.open_bundle(sc2["cid"])
    cast = json.loads(files["storyboard.json"])["cast"]["ana"]
    assert cast == {"image": "$SCENES_DIR/cast/ana/portrait.png", "voice": "$SCENES_DIR/cast/ana/voice.wav"}
    assert files["cast/ana/portrait.png"] == b"PNG"


def test_coop_renders_announced(sa):
    e = sa.create("scene", "R", scope="coop")
    sa.add_render(e["cid"], {"id": "j1", "public": True, "mp4_cid": "QmVideo", "created": 5})
    sa.add_render(e["cid"], {"id": "j2", "public": False, "created": 6})
    sa.announce(e)
    ev = json.loads(sa.events[-1]["content"])
    assert [r["mp4_cid"] for r in ev["renders"]] == ["QmVideo"]  # le rendu non public ne sort pas de la station
