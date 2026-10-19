#!/usr/bin/env python3
"""
eval_memory.py — mesure la QUALITÉ de la mémoire de BRO (pas seulement « ça tourne »).

À rejouer après chaque changement de modèle d'embedding, de seuil ou de consigne d'extraction :
  python3 eval_memory.py                # SANS LLM : rappel, obsolètes, oubli, protections, secrets (embeddings seuls, ~2 s)
  python3 eval_memory.py --llm          # + extraction et corrections par le LLM (≈ 10-15 appels, voir plus bas)
  python3 eval_memory.py --json         # sortie machine

Le GPU est PARTAGÉ (distant pour la plupart des stations) : les appels au LLM sont donc opt-in, ESPACÉS (--pace, 3 s par
défaut), un par un, et ne partent que lorsque ComfyUI est au repos (gpu_headroom.wait_idle) ; la VRAM est de toute façon
contrôlée avant chaque appel (gpu_headroom.ensure). Jamais en parallèle, jamais en boucle.
Code retour 1 si une métrique franchit son seuil (tests/eval_memory_cases.json → "thresholds").

Ce que l'on mesure :
  rappel          la bonne mémoire est dans les 3 premières (hit@3) ; un hors-sujet ne ramène RIEN (faux rappels)
  obsolètes       un souvenir remplacé ou supprimé n'est JAMAIS rendu
  oubli           la reformulation d'un sujet oublié est reconnue, un sujet voisin non
  protections     un souvenir oublié ne ressuscite pas par une source passive, un souvenir écrit par la personne
                  n'est pas écrasé, sa visibilité survit, le « chat » peut toujours se reprendre
  secrets         mots de passe, IBAN, cartes, clés : refusés ; phrases banales : acceptées
  extraction      (LLM) les faits attendus sont trouvés, AUCUN faux souvenir (question, tiers, secret, bavardage)
  corrections     « non, c'est X » remplace l'ancien fait ; « oublie… » efface

Tout se passe sur un compte jetable (eval-…@example.invalid) dont la collection est supprimée à la fin.
"""
import argparse   # AVANT memory_manager : le venv ~/.astro embarque un vieux argparse.py qui masque la stdlib
import json
import os
import sys
import time
from datetime import datetime, timedelta
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import memory_manager as mm

CASES = os.path.join(HERE, "tests", "eval_memory_cases.json")
R = {}          # métrique -> valeur
DETAIL = []     # lignes lisibles (échecs surtout)


def _fail(msg):
    DETAIL.append("  ✗ " + msg)


def _ts(days):
    return (datetime.utcnow() - timedelta(days=days)).isoformat() + "Z"


def _active_contents(user):
    return [p["payload"]["content"] for p in mm.list_memories(user, limit=500)]


def _find(user, needle):
    return [p for p in mm.list_memories(user, include_inactive=True, limit=500)
            if needle.lower() in (p["payload"].get("content") or "").lower()]


# ── rappel, obsolètes ───────────────────────────────────────────────────────
def eval_recall(user, c, ids):
    hits = 0
    for case in c["recall"]:
        found = [h["payload"].get("content", "") for h in mm.search_user_slot(user, case["q"], limit=3)]
        want = [next(s["text"] for s in c["seed"] if s["id"] == i) for i in case["expect"]]
        if any(w in found for w in want):
            hits += 1
        else:
            _fail(f"rappel manqué : « {case['q']} » → {[f[:40] for f in found] or 'rien'} (attendu {case['expect']})")
    R["recall_hit_at_3"] = round(hits / len(c["recall"]), 3)

    bad = 0
    for q in c["off_topic"]:
        got = mm.search_user_slot(user, q, limit=3)
        if got:
            bad += 1
            _fail(f"faux rappel hors-sujet : « {q} » → {got[0]['payload'].get('content', '')[:50]} ({got[0]['score']:.2f})")
    R["off_topic_false_recall"] = round(bad / len(c["off_topic"]), 3)

    leaks = 0
    probes = ["Où j'habite ?", "Quel est mon métier ?", "Est-ce que j'ai un animal ?", "Habite à Lyon", "Possède un chien nommé Rex",
              "Travaille chez un opérateur télécom"]
    for q in probes:
        for h in mm.search_user_slot(user, q, limit=10, score_threshold=0.0):
            t = h["payload"].get("content", "")
            if any(m.lower() in t.lower() for m in c["must_not_return"]):
                leaks += 1
                _fail(f"fuite d'un souvenir inactif : « {t[:60]} » pour « {q} »")
    R["obsolete_leaks"] = leaks


# ── oubli : pierres tombales ────────────────────────────────────────────────
def eval_tombstone(user, c):
    t = c["tombstone"]
    mm.upsert_memory(user, t["forgotten"], kind="person", source="chat")
    pid = mm._stable_id(user, mm._content_hash(t["forgotten"]))
    mm.delete_memory(user, [pid])
    sims = {}
    ok = 0
    for ph in t["paraphrases"]:
        m = mm.forgotten_match(user, ph, threshold=0.0)
        sims[ph] = round(m.get("score", 0), 3)
        if m and m["score"] >= mm.TOMBSTONE_MIN:
            ok += 1
        else:
            _fail(f"reformulation non reconnue ({sims[ph]} < {mm.TOMBSTONE_MIN}) : {ph}")
    R["tombstone_paraphrase_blocked"] = round(ok / len(t["paraphrases"]), 3)
    wrong = 0
    for u in t["unrelated_same_person"]:
        m = mm.forgotten_match(user, u, threshold=0.0)
        sims[u] = round(m.get("score", 0), 3)
        if m and m["score"] >= mm.TOMBSTONE_MIN:
            wrong += 1
            _fail(f"sujet voisin bloqué à tort ({sims[u]}) : {u}")
    R["tombstone_unrelated_blocked"] = round(wrong / len(t["unrelated_same_person"]), 3)
    R["_tombstone_similarities"] = sims
    return t


# ── protections (déterministes, sans LLM) ───────────────────────────────────
def eval_protections(user, c):
    import memory_writer as w
    checks = []

    def check(name, cond):
        checks.append(bool(cond))
        if not cond:
            _fail("protection : " + name)

    t = c["tombstone"]["forgotten"]
    refused = mm.upsert_memory(user, t, source="mastodon", auto=True) is False
    check("source passive ne ressuscite pas un oubli exact",
          refused and all(p["payload"].get("status") != "active" for p in _find(user, t)))
    check("le chat peut se reprendre", mm.upsert_memory(user, t, kind="person", source="chat", auto=True)
          and any(p["payload"].get("status") == "active" for p in _find(user, t)))

    pin = "Aime le thé vert sans sucre"
    mm.upsert_memory(user, pin, source="manual", visibility="love")
    mm.upsert_memory(user, pin, source="nostr_public", visibility="private", auto=True)
    got = _find(user, pin)[0]["payload"]
    check("souvenir écrit par la personne non écrasé (visibilité, origine)", got.get("visibility") == "love" and got.get("origin") == "user")

    auto = "Se rend au marché le dimanche matin"
    mm.upsert_memory(user, auto, source="chat", visibility="private", auto=True)
    pid = mm._stable_id(user, mm._content_hash(auto))
    mm.set_memory_fields(user, [pid], {"visibility": "love"})
    mm.upsert_memory(user, auto, source="chat", visibility="private", auto=True)
    check("la visibilité choisie survit à la relecture", _find(user, auto)[0]["payload"].get("visibility") == "love")

    # une source passive ne remplace ni ne supprime un souvenir écrit par la personne
    near = [{"id": mm._stable_id(user, mm._content_hash(pin)), "score": 0.8, "payload": _find(user, pin)[0]["payload"]}]
    with mock.patch.object(mm, "search_user_slot", return_value=near), \
         mock.patch.object(mm, "forgotten_match", return_value={}), \
         mock.patch.object(w, "_ask", return_value={"op": "UPDATE", "target": 0, "text": "Aime le café"}):
        d_passive = w.decide(user, {"text": "Aime le café", "kind": "trait", "confidence": 0.9}, source="nostr_public")
        d_chat = w.decide(user, {"text": "Aime le café", "kind": "trait", "confidence": 0.9}, source="chat")
    check("source passive : UPDATE d'un souvenir épinglé refusé", d_passive["op"] == "NOOP")
    check("chat : peut mettre à jour son propre souvenir", d_chat["op"] == "UPDATE")

    # décroissance : à pertinence égale, l'événement ancien passe après le fait ; une photo ne vieillit pas
    hits = [{"score": 0.70, "payload": {"kind": "episode", "source": "chat", "timestamp": _ts(700)}},
            {"score": 0.66, "payload": {"kind": "fact", "source": "chat", "timestamp": _ts(700)}},
            {"score": 0.70, "payload": {"kind": "episode", "source": "photo", "timestamp": _ts(700)}}]
    order = [h["payload"]["kind"] + ":" + h["payload"]["source"] for h in mm._age_rank(hits)]
    check("l'épisode ancien passe après un fait presque aussi pertinent, la photo non",
          order == ["episode:photo", "fact:chat", "episode:chat"])
    R["protection_checks"] = round(sum(checks) / len(checks), 3)


# ── secrets ─────────────────────────────────────────────────────────────────
def eval_secrets(c):
    s = c["secrets"]
    miss = [x for x in s["refuse"] if not mm.unstorable_reason(x)]
    fp = [x for x in s["accept"] if mm.unstorable_reason(x)]
    for x in miss:
        _fail(f"secret NON refusé : {x[:60]}")
    for x in fp:
        _fail(f"phrase banale refusée à tort ({mm.unstorable_reason(x)}) : {x[:60]}")
    R["secrets_refused"] = round(1 - len(miss) / len(s["refuse"]), 3)
    R["secrets_false_positive"] = round(len(fp) / len(s["accept"]), 3)


# ── extraction par le LLM ───────────────────────────────────────────────────
def eval_extraction(c):
    import memory_writer as w
    found = total = fakes = 0
    for case in c["extraction"]:
        facts, _ = w.extract_facts(case["messages"], case["source"], now=datetime.utcnow().strftime("%Y-%m-%d"))
        texts = [f["text"] for f in facts]
        for alts in case["expect_any"]:
            total += 1
            if any(a.lower() in t.lower() for t in texts for a in alts):
                found += 1
            else:
                _fail(f"extraction [{case['name']}] : fait attendu {alts} absent → {texts}")
        for bad in case["forbid"]:
            for t in texts:
                if bad.lower() in t.lower():
                    fakes += 1
                    _fail(f"FAUX SOUVENIR [{case['name']}] : « {t} » contient « {bad} »")
    R["extraction_expected_found"] = round(found / total, 3) if total else 1.0
    R["extraction_false_memories"] = fakes


def eval_corrections(user, c):
    import memory_writer as w
    ok = 0
    for case in c["corrections"]:
        if case["seed"]:
            mm.upsert_memory(user, case["seed"], source="chat", auto=True)
        w.process_batch(user, [{"t": datetime.utcnow().isoformat() + "Z", "source": "chat", "text": case["message"]}])
        act = [t.lower() for t in _active_contents(user)]
        good = (all(any(a.lower() in t for t in act) for a in case["expect_active"])
                and not any(i.lower() in t for t in act for i in case["expect_inactive"]))
        if good:
            ok += 1
        else:
            _fail(f"correction [{case['name']}] : actifs = {act}")
    R["corrections_ok"] = round(ok / len(c["corrections"]), 3)


def main():
    ap = argparse.ArgumentParser(description="Évaluation de la mémoire de BRO")
    ap.add_argument("--llm", action="store_true", help="inclut l'extraction et les corrections par le LLM (GPU partagé : espacé)")
    ap.add_argument("--pace", type=float, default=3.0, help="secondes minimum entre deux appels au LLM (défaut 3)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    os.environ["OLLAMA_SOURCE"] = "eval_memory"        # ces appels sont des tests : à part dans ollama_calls_*.jsonl
    c = json.load(open(CASES, encoding="utf-8"))
    if not mm._qdrant_available():
        sys.exit("ERROR: Qdrant injoignable — évaluation impossible")
    user = f"eval-{int(time.time())}@example.invalid"
    cname = f"memory_{mm._user_hex(user)}"
    t0 = time.time()
    if a.llm:
        import memory_writer as w
        import gpu_headroom
        w._ask = gpu_headroom.paced(w._ask, gap=a.pace)          # un appel à la fois, espacés, ComfyUI au repos
        print(f"ℹ️ LLM partagé : environ 10 à 15 appels, un toutes les {a.pace:.0f} s au moins — patience.", file=sys.stderr)
    try:
        for s in c["seed"]:
            if not mm.upsert_memory(user, s["text"], kind=s["kind"], source="chat",
                                    timestamp=_ts(s.get("age_days", 5)), auto=True):
                sys.exit(f"ERROR: écriture du jeu de test impossible ({s['id']}) — embedding ou Qdrant en panne")
        for o in c["obsolete"]:
            mm.upsert_memory(user, o["text"], source="chat", auto=True)
            mm.set_memory_fields(user, [mm._stable_id(user, mm._content_hash(o["text"]))], {"status": o["status"]})
        eval_recall(user, c, {})
        eval_tombstone(user, c)
        eval_protections(user, c)
        eval_secrets(c)
        if a.llm:
            eval_extraction(c)
            eval_corrections(user, c)
    finally:
        mm._curl("DELETE", f"{mm.QDRANT_URL}/collections/{cname}")

    th = c["thresholds"]
    status = {}
    for k, limit in th.items():
        if k not in R:
            continue
        higher_is_better = k in ("recall_hit_at_3", "tombstone_paraphrase_blocked", "secrets_refused", "protection_checks",
                                 "extraction_expected_found", "corrections_ok")
        status[k] = (R[k] >= limit) if higher_is_better else (R[k] <= limit)
    out = {"model": mm.EMBED_MODEL, "metrics": {k: v for k, v in R.items() if not k.startswith("_")},
           "thresholds": {k: th[k] for k in status}, "ok": all(status.values()), "seconds": round(time.time() - t0, 1),
           "tombstone_similarities": R.get("_tombstone_similarities")}
    if a.json:
        print(json.dumps(out, ensure_ascii=False, indent=1))
    else:
        print(f"Évaluation mémoire — embedding {mm.EMBED_MODEL}, {out['seconds']} s\n")
        for k, ok in status.items():
            print(f"  {'✅' if ok else '❌'} {k:32} {R[k]:<7}  (seuil {th[k]})")
        if DETAIL:
            print("\nÉchecs et écarts :")
            print("\n".join(DETAIL))
        if R.get("_tombstone_similarities"):
            print("\nSimilarités de la pierre tombale (seuil %.2f) : %s" % (mm.TOMBSTONE_MIN, R["_tombstone_similarities"]))
    sys.exit(0 if out["ok"] else 1)


if __name__ == "__main__":
    main()
