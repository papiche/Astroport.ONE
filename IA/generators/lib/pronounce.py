#!/usr/bin/env python3
"""
pronounce.py — prépare un prompt MiniMax pour une meilleure diction française :
applique lib/prononciation_fr.json aux seules répliques entre guillemets, puis
ajoute une consigne de diction si le prompt contient une réplique.

Usage : pronounce.py "<prompt>"   (le prompt corrigé sort sur stdout)
        pronounce.py --lines "<prompt>"   (répliques d'origine, une par ligne)
"""

import json
import pathlib
import re
import sys

LEXICON = json.loads((pathlib.Path(__file__).parent / "prononciation_fr.json").read_text())
LEXICON.pop("_doc", None)
# Les entrées les plus longues d'abord (« ZEN Card » avant « zen »)
TERMS = sorted(LEXICON, key=len, reverse=True)
PATTERN = re.compile(r"(?<![\w-])(" + "|".join(re.escape(t) for t in TERMS) + r")(?![\w-])", re.IGNORECASE)
LOWER = {t.lower(): v for t, v in LEXICON.items()}
QUOTE = re.compile(r'"([^"]+)"')
DICTION = (" The dialogue is spoken slowly and clearly, in natural French with a native French accent,"
           " articulating every word, with short pauses between sentences.")


def respell(line):
    return PATTERN.sub(lambda m: LOWER[m.group(1).lower()], line)


def main():
    if sys.argv[1] == "--lines":
        print("\n".join(QUOTE.findall(sys.argv[2])))
        return
    prompt = sys.argv[1]
    if not QUOTE.search(prompt):
        print(prompt)
        return
    print(QUOTE.sub(lambda m: '"' + respell(m.group(1)) + '"', prompt) + DICTION)


if __name__ == "__main__":
    main()
