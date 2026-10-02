#!/usr/bin/env python3
"""generate_voice.py : voix et narration avec Qwen3-TTS (venv ~/qwen3tts_env).

1) Une voix inventée d'après une description (modèle VoiceDesign) :
     generate_voice.py -o voix.wav [-l French] [-S seed] "description de la voix" "texte à dire"
   Deux descriptions différentes donnent deux voix différentes ; à description, texte et
   graine identiques la voix est reproductible. Sert de voix de référence <Audio k> à ref2va.

2) Narration (voix-off) à voix constante sur tous les plans :
     generate_voice.py --narrate lignes.json --ref narrateur.wav --design "description" [--ref-text "phrase"]
   lignes.json = [{"text": "...", "out": "vo_00.wav"}, ...]. La voix du narrateur est conçue une
   fois (VoiceDesign) et enregistrée dans --ref ; chaque ligne est ensuite synthétisée par
   clonage de cette référence (modèle Base) : une description seule donnerait une voix un peu
   différente à chaque appel. Les textes passent par lib/prononciation_fr.json (sigles).

Installation : install/install_qwen3_tts.sh (QWEN3TTS_PY est fixé par lib/env.sh).
"""
import argparse
import gc
import json
import pathlib
import sys

p = argparse.ArgumentParser()
p.add_argument("instruct", nargs="?", help="description de la voix, en anglais de préférence")
p.add_argument("text", nargs="?", help="phrase à prononcer")
p.add_argument("-o", "--output")
p.add_argument("-l", "--language", default="French")
p.add_argument("-S", "--seed", type=int, default=42)
p.add_argument("--narrate", help="JSON [{text, out}] : mode narration")
p.add_argument("--ref", help="narration : wav de référence du narrateur (créé s'il manque)")
p.add_argument("--design", help="narration : description de la voix du narrateur")
p.add_argument("--ref-text", default="Bonjour, je suis la voix de cette présentation. Je vais vous expliquer, pas à pas, comment fonctionne votre station.")
a = p.parse_args()

import soundfile as sf
import torch

sys.path.insert(0, str(pathlib.Path(__file__).parent / "lib"))
from pronounce import respell  # noqa: E402
from qwen_tts import Qwen3TTSModel  # noqa: E402

VOICE_DESIGN = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
BASE = "Qwen/Qwen3-TTS-12Hz-1.7B-Base"
dev = "cuda:0" if torch.cuda.is_available() else "cpu"
try:
    import flash_attn  # noqa: F401
    attn = "flash_attention_2"
except Exception:
    attn = "sdpa"


def load(repo):
    return Qwen3TTSModel.from_pretrained(
        repo, device_map=dev,
        dtype=torch.bfloat16 if dev != "cpu" else torch.float32,
        attn_implementation=attn)


def design(instruct, text, out):
    torch.manual_seed(a.seed)
    model = load(VOICE_DESIGN)
    wavs, sr = model.generate_voice_design(text=respell(text), language=a.language, instruct=instruct)
    sf.write(out, wavs[0], sr)
    del model
    gc.collect()
    torch.cuda.empty_cache()


if a.narrate:
    if not (a.ref and (a.design or pathlib.Path(a.ref).exists())):
        sys.exit("--narrate demande --ref (et --design si la référence n'existe pas encore)")
    if not pathlib.Path(a.ref).exists():
        design(a.design, a.ref_text, a.ref)
    model = load(BASE)
    # ref_text exact de la référence : il conditionne le clonage (ICL)
    prompt = model.create_voice_clone_prompt(ref_audio=a.ref, ref_text=a.ref_text)
    for line in json.loads(pathlib.Path(a.narrate).read_text()):
        torch.manual_seed(a.seed)
        text = respell(line["text"])
        # 12 tokens/s ; plafond proportionnel au texte (évite les boucles sans fin connues du modèle)
        cap = int(12 * (len(text.split()) / 1.5 + 4))
        wavs, sr = model.generate_voice_clone(text=text, language=a.language,
                                              voice_clone_prompt=prompt, max_new_tokens=cap)
        sf.write(line["out"], wavs[0], sr)
        print(line["out"])
else:
    if not (a.instruct and a.text and a.output):
        p.error("instruct, text et -o sont requis")
    design(a.instruct, a.text, a.output)
    print(a.output)
