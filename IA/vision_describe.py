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
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESCRIBE = HERE / "describe_image.py"
TOOLS = HERE.parent / "tools"
MAX_SIDE = 1280
DEFAULT_MODEL = os.environ.get("FACECLOUD_DESCRIBE_MODEL", "minicpm-v4.6:latest")
PROMPT = (
    "Décris cette photo en français, en une à trois phrases courtes et factuelles : le lieu ou le décor, "
    "l'activité ou la scène, les objets et l'ambiance (lumière, saison, moment de la journée si visibles). "
    "Indique le nombre de personnes visibles sans jamais citer de nom ni deviner qui elles sont. "
    "N'invente rien qui ne se voit pas. Pas d'introduction, pas de liste."
)


def _prepare(plain: bytes) -> bytes:
    """JPEG ≤ 1280 px, orientation EXIF appliquée (le modèle ne lit pas l'EXIF)."""
    try:
        from PIL import Image, ImageOps
        img = Image.open(io.BytesIO(plain))
        img.draft("RGB", (MAX_SIDE * 2, MAX_SIDE * 2))
        img = ImageOps.exif_transpose(img).convert("RGB")
        img.thumbnail((MAX_SIDE, MAX_SIDE))
        out = io.BytesIO()
        img.save(out, format="JPEG", quality=88)
        return out.getvalue()
    except Exception:
        return plain             # format que Pillow ne lit pas : on laisse le modèle essayer


def describe_bytes(plain: bytes, model: str = DEFAULT_MODEL, timeout: int = 300) -> dict:
    tmp = Path(tempfile.mkdtemp(prefix="vdesc-"))
    try:
        os.chmod(tmp, 0o700)
        f = tmp / "photo.jpg"
        fd = os.open(str(f), os.O_CREAT | os.O_WRONLY, 0o600)
        with os.fdopen(fd, "wb") as fh:
            fh.write(_prepare(plain))
        proc = subprocess.run([sys.executable, str(DESCRIBE), "--json", "-m", model, "-p", PROMPT, str(f)],
                              capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"error": f"délai dépassé ({timeout}s)"}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for line in reversed(proc.stdout.strip().splitlines()):
        try:
            data = json.loads(line)
        except ValueError:
            continue
        if isinstance(data, dict) and data.get("description"):
            return {"description": data["description"].strip(), "model": model}
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
