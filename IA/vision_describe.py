#!/usr/bin/env python3
"""
vision_describe.py — Décrit UNE photo en français (modèle vision d'Ollama), sans rien publier.

Trois entrées, une seule sortie (une ligne JSON sur stdout) :
    {"description": "…", "model": "minicpm-v4.6:latest"}   ou   {"error": "…"}

    vision_describe.py --stdin                    image EN CLAIR sur stdin (accès DIRECT : UPassport
                                                  la déchiffre en mémoire et nous la passe, jamais de
                                                  clair sur disque côté appelant)
    vision_describe.py --cid <CID> --key <HEX64>  blob UENC chiffré sur IPFS + sa clé (mode RELAIS :
                                                  le Brain déchiffre en mémoire, le clair n'est écrit
                                                  que dans un dossier 0700 supprimé aussitôt)
    vision_describe.py --file <chemin>            fichier local (débogage)

La photo est réduite à 1280 px avant d'être envoyée au modèle (3 à 4× plus rapide, résultat identique
pour une description) et l'orientation EXIF appliquée. La description ne cite jamais de nom de
personne : elle décrit la scène, jamais l'identité — celle-ci reste l'affaire de l'utilisateur.

Le travail d'Ollama est celui de `describe_image.py` (tunnel `ollama.me.sh`, nouvel essai si le tunnel
tombe, dédoublonnage des phrases) : ce script n'ajoute que le prétraitement de l'image et le prompt.
"""
import sys as _sys
import os as _os

_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import argparse
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

VERBOSE = int(os.environ.get("FACECLOUD_VERBOSE", "0") or 0)


def vlog(msg: str, lvl: int = 1) -> None:
    """Suivi horodaté sur stderr (FACECLOUD_VERBOSE >= lvl), même format que UPassport/services/trace.py."""
    if VERBOSE >= lvl:
        import time as _t
        now = _t.time()
        print(f"[{_t.strftime('%H:%M:%S', _t.localtime(now))}.{int((now % 1) * 1000):03d}] vision_describe: {msg}", file=sys.stderr, flush=True)


HERE = Path(__file__).resolve().parent
DESCRIBE = HERE / "describe_image.py"
TOOLS = HERE.parent / "tools"
MAX_SIDE = 1280
# Modèle par défaut : qwen3-vl:4b-instruct. Comparés le 2026-10-16 sur 18 photos réelles variées (2 bancs) :
#   qwen3-vl:4b-instruct  ~1,7 s/photo, 3,3 Go : le plus juste sur la composition et le contexte (catamaran seul, immeuble vu depuis
#                         un pare-brise, « DECASPORT » sur un tapis) ; faiblit sur l'écriture manuscrite et invente parfois (« petit
#                         animal »), écrit « aucune personne n'est visible » malgré la consigne (filtré par _tidy).
#   qwen2.5vl:7b          ~5,7 s/photo, 6 Go : régulier, lit mieux le manuscrit (« Villa livrée neuve », « Clefs remises »), repli.
#   qwen3-vl:4b (défaut Ollama) : modèle À RÉFLEXION, réponse vide 5 fois sur 8 → à ne PAS utiliser ; gemma3:12b invente des détails ;
#   minicpm-v:latest boucle ; minicpm-v4.6 écrit un français mêlé d'anglais/italien.
# Même nom que services/analysis.py::DESCRIBE_MODEL.
DEFAULT_MODEL = os.environ.get("FACECLOUD_DESCRIBE_MODEL", "qwen3-vl:4b-instruct")
FALLBACK_MODELS = ["qwen2.5vl:7b", "gemma3:12b"]               # si le modèle n'est pas installé sur la machine d'IA
PROMPT = (
    "Décris cette photo en français pour qu'on puisse la retrouver plus tard avec une recherche. Réponds en deux parties. "
    "1) Deux ou trois phrases simples et factuelles sur ce qui est VISIBLE : le lieu ou le décor, la scène et l'activité, les objets, "
    "les animaux ou personnes présents (nombre approximatif ; dis « bébé », « enfant » ou « adulte » sans deviner le sexe ni l'identité, "
    "sans jamais citer de nom), la lumière ou le moment de la journée. "
    "Ne mentionne JAMAIS ce qui est absent (pas de « aucun animal », « pas de personne »). Si un détail est flou ou incertain, "
    "reste général plutôt que de deviner. Recopie les textes lisibles importants (panneaux, enseignes). "
    "2) Sur une dernière ligne qui commence par « Mots-clés : », 8 à 15 mots ou expressions courtes en français "
    "(objets, lieu, activité, saison, couleurs dominantes, texte lisible). Les mots-clés ne doivent contenir QUE ce que tu as vu et "
    "décrit dans la première partie : aucun lieu, activité ou saison simplement supposé (pas de « plage » s'il n'y a pas de plage). "
    "Pas d'introduction, pas de liste à puces, ne numérote pas."
)
GEN_OPTIONS = ["--repeat-penalty", "1.05", "--temperature", "0.2", "--num-predict", "320"]


def _prepare(plain: bytes) -> bytes:
    """JPEG ≤ 1280 px, orientation EXIF appliquée (le modèle ne lit pas l'EXIF)."""
    try:
        from PIL import Image, ImageOps
        img = Image.open(io.BytesIO(plain))
        vlog(f"image source {img.format} {img.size[0]}×{img.size[1]}, {len(plain) // 1024} Ko", 2)
        img.draft("RGB", (MAX_SIDE * 2, MAX_SIDE * 2))
        img = ImageOps.exif_transpose(img).convert("RGB")
        img.thumbnail((MAX_SIDE, MAX_SIDE))
        out = io.BytesIO()
        img.save(out, format="JPEG", quality=88)
        vlog(f"préparée : {img.size[0]}×{img.size[1]} JPEG, {out.tell() // 1024} Ko (orientation EXIF appliquée)")
        return out.getvalue()
    except Exception as exc:
        vlog(f"préparation impossible ({type(exc).__name__}: {exc}) : image envoyée telle quelle")
        return plain             # format que Pillow ne lit pas : on laisse le modèle essayer


def describe_bytes(plain: bytes, model: str = DEFAULT_MODEL, timeout: int = 300) -> dict:
    tmp = Path(tempfile.mkdtemp(prefix="vdesc-"))
    try:
        os.chmod(tmp, 0o700)
        f = tmp / "photo.jpg"
        fd = os.open(str(f), os.O_CREAT | os.O_WRONLY, 0o600)
        with os.fdopen(fd, "wb") as fh:
            fh.write(_prepare(plain))
        last = {"error": "pas de réponse"}
        chain = [model] + [x for x in FALLBACK_MODELS if x != model]
        vlog(f"modèles à essayer, dans l'ordre : {', '.join(chain)}", 2)
        for m in chain:
            cmd = [sys.executable, str(DESCRIBE), "--json", "-m", m, "-p", PROMPT, *GEN_OPTIONS, str(f)]
            vlog(f"→ {m} : {os.path.basename(cmd[1])} {' '.join(GEN_OPTIONS)}", 2)
            t0 = time.time()
            try:
                proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            except subprocess.TimeoutExpired:
                vlog(f"{m} : délai dépassé ({timeout}s)")
                return {"error": f"délai dépassé ({timeout}s)"}
            if VERBOSE and proc.stderr:                  # le suivi de describe_image.py passe par ici, tel quel
                sys.stderr.write(proc.stderr if proc.stderr.endswith("\n") else proc.stderr + "\n")
            last = _parse(proc, m)
            vlog(f"{m} : code retour {proc.returncode} en {time.time() - t0:.1f}s — "
                 + ("description reçue" if "description" in last else f"erreur : {last.get('error', '?')[:160]}"))
            # Modèle absent de la machine d'IA : on essaie le suivant ; toute autre erreur est remontée telle quelle.
            if "description" in last or not _model_missing(last.get("error", "")):
                return last
        return last
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _model_missing(msg: str) -> bool:
    m = msg.lower()
    return "not found" in m or "pull" in m or "unknown model" in m or "unknown model architecture" in m


def _tidy(text: str) -> str:
    """Retire les « 1) » / « 2) » que le modèle recopie parfois, et met les mots-clés sur leur propre ligne."""
    t = re.sub(r"\*\*", "", text.strip())                                   # markdown gras que certains modèles ajoutent
    t = re.sub(r"^\s*1\)\s*(Description[^\n:]*:)?\s*", "", t)
    t = re.sub(r"\s*2\)\s*(?=Mots?[- ]cl)", "\n", t, flags=re.I)
    t = re.sub(r"\s+(?=Mots?-cl[ée]s\s*:)", "\n", t, count=1)
    t = re.sub(r"(Mots?-cl[ée]s\s*:)\s*\n+\s*", r"\1 ", t)                # « Mots-clés :\n\nchat » → « Mots-clés : chat »
    return _drop_absences(t.strip())


_ABSENT = re.compile(r"\b(aucun[e]?|pas de|n[’']y a pas|sans)\b[^.]*\b(visible|visibles|présent|présente|présents|présentes|identifiable)\b"
                     r"|\bn[’']est (pas )?(visible|présent)|\bne sont pas (visibles|présents)", re.I)


def _drop_absences(t: str) -> str:
    """Retire les phrases qui décrivent ce qui est ABSENT (« Aucune personne n'est visible ») : elles polluent la recherche
    (« personne » trouverait des photos sans personne). Les mots-clés ne sont pas touchés."""
    head, sep, kw = t.partition("\nMots-clés")
    if sep:                                       # mots-clés en double (« adulte, adulte ») : un seul
        label, _, items = kw.partition(":")
        seen, uniq = set(), []
        for it in (x.strip() for x in items.split(",")):
            if it and it.lower() not in seen:
                seen.add(it.lower())
                uniq.append(it)
        kw = f"{label}: {', '.join(uniq)}"
    parts = re.split(r"(?<=[.!?])\s+", head)
    kept = [p for p in parts if not _ABSENT.search(p)]
    return (" ".join(kept) if kept else head) + sep + kw


def _parse(proc, model: str) -> dict:
    for line in reversed(proc.stdout.strip().splitlines()):
        try:
            data = json.loads(line)
        except ValueError:
            continue
        if isinstance(data, dict) and data.get("description"):
            raw, tidy = data["description"], _tidy(data["description"])
            if " ".join(tidy.split()) != " ".join(raw.split()):          # ignore les seuls changements de saut de ligne
                vlog(f"nettoyage (markdown, numérotation, phrases d'absence) : {len(raw)} → {len(tidy)} caractères", 2)
                vlog(f"avant : {raw!r}", 2)
            return {"description": tidy, "model": model}
        if isinstance(data, dict) and data.get("error"):
            return {"error": str(data["error"])[:300]}
    return {"error": (proc.stderr or proc.stdout or "pas de réponse")[-300:]}


def _from_ipfs(cid: str, key_hex: str) -> bytes:
    sys.path.insert(0, str(TOOLS))
    import uenc_codec
    cid = cid.rsplit("/", 1)[-1]
    blob = subprocess.run(["ipfs", "cat", cid], capture_output=True, timeout=180, check=True).stdout
    return uenc_codec.decrypt_aes256gcm(blob, key_hex)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--stdin", action="store_true")
    g.add_argument("--cid")
    g.add_argument("--file")
    ap.add_argument("--key", default="")
    ap.add_argument("-m", "--model", default=DEFAULT_MODEL)
    args = ap.parse_args()
    try:
        if args.stdin:
            plain = sys.stdin.buffer.read()
            vlog(f"image reçue sur stdin : {len(plain) // 1024} Ko, modèle demandé {args.model}")
        elif args.cid:
            if len(args.key) != 64:
                raise ValueError("--key (64 hex) requis avec --cid")
            plain = _from_ipfs(args.cid, args.key)
        else:
            plain = Path(args.file).read_bytes()
        out = describe_bytes(plain, args.model)
    except Exception as exc:
        out = {"error": f"{type(exc).__name__}: {exc}"[:300]}
    print(json.dumps(out, ensure_ascii=False))
    return 0 if "description" in out else 1


if __name__ == "__main__":
    sys.exit(main())
