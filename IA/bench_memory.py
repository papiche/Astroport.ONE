#!/usr/bin/env python3
"""
bench_memory.py — CHRONOMÈTRE les opérations de la mémoire de BRO, de bout en bout, pour optimiser avec des chiffres.

  python3 bench_memory.py                  # sans LLM (quelques secondes ; embeddings et Qdrant seuls)
  python3 bench_memory.py --llm            # + extraction / décision / réponse de BRO (plusieurs minutes)

Le GPU est PARTAGÉ (distant pour la plupart des stations) : les appels au LLM sont opt-in, espacés (--pace, 3 s), un par un,
et n'ont lieu que lorsque ComfyUI est au repos (gpu_headroom.paced / wait_idle).
  python3 bench_memory.py -n 10 --json     # 10 répétitions, sortie machine

Chaque mesure : médiane et pire cas (p95) sur N répétitions, en millisecondes. Le résultat est AUSSI ajouté (une ligne
JSON) à ~/.zen/log/bench_memory.jsonl — dossier permanent, avec rotation — pour comparer avant/après chaque optimisation.

Ce qui est mesuré, avec la façon dont UPassport l'appelle aujourd'hui (sous-processus `ASTRO_PYTHON`) ET la même
opération EN PROCESSUS, pour savoir ce que coûte le démarrage de Python à lui seul :
  1 écran « Ce que BRO sait de moi » : liste des souvenirs, état des sources
  2 message à BRO : embedding, recherche Qdrant, contexte complet (+ réponse du LLM avec --llm)
  3 #rec : un souvenir écrit
  4 apprentissage : embeddings d'un lot de 8 textes un par un / en un seul appel ; extraction + décision (--llm)
  5 refresh 20h12 : lecture de la collection géo, scan strfry (à blanc)
  6 contacts (partie CPU seulement : l'écriture dans IPFS n'est pas mesurée)
Compte jetable bench-…@example.invalid, collection supprimée à la fin.
"""
import argparse   # AVANT memory_manager : le venv ~/.astro embarque un vieux argparse.py qui masque la stdlib
import json
import os
import statistics
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import memory_manager as mm

ASTRO_PY = os.path.expanduser("~/.astro/bin/python3")
if not os.path.exists(ASTRO_PY):
    ASTRO_PY = "python3"
RESULTS = {}        # nom -> {"median": ms, "p95": ms, "n": n}
NOTES = []

TEXTS = [
    "Est allergique aux noix", "Sa fille Camille a 8 ans et adore dessiner", "Son frère Antoine vit à Montréal",
    "Aime le jazz manouche et joue de la guitare", "Se déplace à vélo pour aller travailler",
    "Prépare une conférence sur les monnaies libres pour mars", "Cultive des tomates dans son potager",
    "Préfère être tutoyé et aime les réponses courtes",
]


def timeit(name, fn, n):
    """Chronomètre fn() n fois (la 1re mesure est écartée si n > 2 : caches, modèle à charger)."""
    ts = []
    for i in range(n + (1 if n > 2 else 0)):
        t0 = time.perf_counter()
        try:
            fn()
        except Exception as e:                      # une mesure qui échoue est dite, jamais ignorée
            RESULTS[name] = {"error": str(e)[:150]}
            print(f"  ✗ {name}: {e}", file=sys.stderr)
            return
        ts.append((time.perf_counter() - t0) * 1000)
    if n > 2:
        ts = ts[1:]
    ts.sort()
    RESULTS[name] = {"median": round(statistics.median(ts), 1),
                     "p95": round(ts[min(len(ts) - 1, int(len(ts) * 0.95))], 1), "n": len(ts)}


def cli(script, *args):
    r = subprocess.run([ASTRO_PY, "-W", "ignore", os.path.join(HERE, script), *map(str, args)],
                       capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        raise RuntimeError(f"{script} {args[0]} → code {r.returncode}: {r.stderr.strip()[-120:]}")
    return r.stdout


def main():
    ap = argparse.ArgumentParser(description="Chronomètre la mémoire de BRO")
    ap.add_argument("-n", type=int, default=5, help="répétitions par mesure")
    ap.add_argument("--llm", action="store_true", help="inclut les appels au LLM (lent, GPU partagé : espacé)")
    ap.add_argument("--pace", type=float, default=3.0, help="secondes minimum entre deux appels au LLM (défaut 3)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    if not mm._qdrant_available():
        sys.exit("ERROR: Qdrant injoignable — mesure impossible")
    n = a.n
    os.environ["OLLAMA_SOURCE"] = "bench_memory"       # ces appels sont des mesures : à part dans ollama_calls_*.jsonl
    if a.llm:
        import gpu_headroom
        import question as _q
        # (w._ask passe par question.answer_question : une seule enveloppe, sinon l'espacement serait doublé)
        _q.answer_question = gpu_headroom.paced(_q.answer_question, gap=a.pace)
    user = f"bench-{int(time.time())}@example.invalid"
    cname = f"memory_{mm._user_hex(user)}"
    try:
        # jeu de départ : 40 souvenirs (taille réaliste d'un compte qui apprend depuis quelques semaines)
        for i in range(40):
            mm.upsert_memory(user, f"{TEXTS[i % len(TEXTS)]} (variante {i})", kind="fact", source="chat", auto=True)

        # ── 0. plancher : ce que coûtent Python et les services seuls ──
        timeit("0a python à froid (rien)", lambda: subprocess.run([ASTRO_PY, "-c", "pass"], check=True), n)
        timeit("0b python + import memory_manager",
               lambda: subprocess.run([ASTRO_PY, "-W", "ignore", "-c", f"import sys;sys.path.insert(0,{HERE!r});import memory_manager"],
                                      check=True, capture_output=True), n)
        timeit("0c Qdrant : GET /collections", lambda: mm._curl("GET", f"{mm.QDRANT_URL}/collections"), n)
        timeit("0d Ollama : 1 embedding", lambda: mm._embed("Est allergique aux noix"), n)

        # ── 1. écran « Ce que BRO sait de moi » ──
        timeit("1a liste des souvenirs — sous-processus (actuel)", lambda: cli("memory_manager.py", "list-memories", "--user-id", user), n)
        timeit("1b liste des souvenirs — en processus", lambda: mm.list_memories(user), n)
        timeit("1c état des sources — sous-processus (actuel)", lambda: cli("memory_writer.py", "sources", user), n)

        def sources_inproc():
            import memory_writer as w
            w.sources_status(user)
        timeit("1d état des sources — en processus", sources_inproc, n)
        timeit("1e compteurs (memory_overview) — en processus", lambda: mm.memory_overview(user), n)

        # ── 2. message à BRO ──
        timeit("2a recherche sémantique complète (embedding + Qdrant)",
               lambda: mm.search_user_slot(user, "Qu'est-ce que je ne dois pas manger ?", limit=6), n)
        vec = mm._embed("Qu'est-ce que je ne dois pas manger ?")
        timeit("2b … dont Qdrant seul (vecteur déjà calculé)", lambda: mm._curl(
            "POST", f"{mm.QDRANT_URL}/collections/{cname}/points/search",
            {"vector": vec, "limit": 6, "with_payload": True,
             "filter": {"must_not": mm._NOT_ACTIVE}}), n)
        timeit("2c ensure_collection (appelé avant CHAQUE recherche/écriture)", lambda: mm.ensure_collection(cname), n)
        if a.llm:
            import question
            timeit("2d réponse de BRO complète (LLM compris)", lambda: question.answer_question(
                "Qu'est-ce que je ne dois pas manger ?", user_id=user), max(1, n // 2))

        # ── 3. #rec ──
        k = [0]

        def rec_cli():
            k[0] += 1
            cli("memory_manager.py", "upsert-memory", "--user-id", user, "--content", f"Souvenir bench cli {k[0]}",
                "--kind", "fact", "--source", "rec")

        def rec_inproc():
            k[0] += 1
            mm.upsert_memory(user, f"Souvenir bench direct {k[0]}", source="rec")
        timeit("3a #rec — sous-processus (actuel)", rec_cli, n)
        timeit("3b #rec — en processus", rec_inproc, n)

        def auto_write():
            k[0] += 1
            mm.upsert_memory(user, f"Souvenir bench auto {k[0]}", source="chat", auto=True)
        timeit("3c écriture automatique (embedding + 3 appels Qdrant)", auto_write, n)

        # ── 4. apprentissage ──
        timeit("4a embeddings de 8 textes — un par un", lambda: [mm._embed(t) for t in TEXTS], n)
        timeit("4b embeddings de 8 textes — UN appel groupé",
               lambda: mm._curl("POST", f"{mm.OLLAMA_URL}/api/embed", {"model": mm.EMBED_MODEL, "input": TEXTS}), n)
        if a.llm:
            import memory_writer as w
            msgs = ["Je suis végétarien depuis 5 ans et ma sœur Léa vient dîner samedi", "Ma fille Inès est allergique aux arachides"]
            res = {}

            def extract():
                res["f"] = w.extract_facts(msgs, "chat")[0]
            timeit("4c extraction par le LLM (2 messages)", extract, max(1, n // 2))
            facts = res.get("f") or []

            def decide():
                for f in facts:
                    w.decide(user, f, "chat")
            if facts:
                timeit(f"4d décision pour {len(facts)} fait(s)", decide, max(1, n // 2))

        # ── 5. refresh 20h12 ──
        timeit("5a lecture de la collection géo (geo_indexed)", lambda: mm.geo_indexed(0), n)
        import geo_memory as gm
        timeit("5b strfry scan des réactions des 3 derniers jours", lambda: gm.scan({"kinds": [7], "since": int(time.time()) - 3 * 86400}), max(1, n // 2))
        timeit("5c geo_memory refresh à blanc (total)", lambda: gm.refresh(dry=True), max(1, n // 2))

        # ── 6. contacts : partie CPU ──
        sys.path.insert(0, os.path.expanduser("~/workspace/AAA/UPassport"))
        try:
            from services import contacts_store as cs
            vcf = "".join(f"BEGIN:VCARD\nVERSION:3.0\nUID:u{i}\nFN:Personne {i}\nN:{i};Personne;;;\nTEL:+3360000{i:04d}\nEMAIL:p{i}@example.invalid\nEND:VCARD\n"
                          for i in range(200))
            timeit("6a découpe d'un fichier de 200 vCards", lambda: cs.split_vcf(vcf), n)
            cards = cs.split_vcf(vcf)
            timeit("6b réécriture de 200 vCards (build)", lambda: [cs.build({"fn": "x"}, c) for c in cards], max(1, n // 2))
        except Exception as e:
            NOTES.append(f"contacts non mesurés ({e})")
    finally:
        mm._curl("DELETE", f"{mm.QDRANT_URL}/collections/{cname}")

    out = {"at": time.strftime("%Y-%m-%dT%H:%M:%S"), "embed_model": mm.EMBED_MODEL, "n": n, "llm": a.llm,
           "results": RESULTS, "notes": NOTES}
    logdir = os.path.expanduser("~/.zen/log")
    os.makedirs(logdir, exist_ok=True)
    with open(os.path.join(logdir, "bench_memory.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps(out, ensure_ascii=False) + "\n")
    if a.json:
        print(json.dumps(out, ensure_ascii=False, indent=1))
        return
    print(f"Chronométrage mémoire — {mm.EMBED_MODEL}, {n} répétitions (médiane · pire cas, en ms)\n")
    for k_, v in RESULTS.items():
        print(f"  {k_:62} " + (f"✗ {v['error']}" if "error" in v else f"{v['median']:>9.1f} · {v['p95']:>9.1f}"))
    for note in NOTES:
        print("  note :", note)
    print("\n→ historique : ~/.zen/log/bench_memory.jsonl")


if __name__ == "__main__":
    main()
