#!/usr/bin/env python3
"""
skill_flashmem.py — Mémoire pré-prompt partagée par skill

Stockée dans ~/.zen/tmp/flashmem/skills/<skill>.md
Commune à tous les utilisateurs du node (base de connaissance collective).
Gérée (préservée) par 20h12.process.sh.

Format :
  [2026-05-17][npub:9da638...] Je maîtrise nginx et apache
  [2026-05-17][npub:2188e8...] Je bloque sur la conf TLS
  ...

Usage bash :
  python3 skill_flashmem.py read    --skill devops
  python3 skill_flashmem.py write   --skill devops --text "..." --npub <hex>
  python3 skill_flashmem.py list
  python3 skill_flashmem.py reset   --skill devops
  python3 skill_flashmem.py context --skill devops
"""

import os
import sys
from datetime import datetime
from pathlib import Path

FLASHMEM_BASE = Path.home() / ".zen" / "tmp" / "flashmem" / "skills"
MAX_LINES = 100  # Limite par skill


def _skill_path(skill: str) -> Path:
    skill_safe = skill.lower().strip().replace(" ", "_").replace("/", "_")[:40]
    FLASHMEM_BASE.mkdir(parents=True, exist_ok=True)
    return FLASHMEM_BASE / f"{skill_safe}.md"


def read_skill_memory(skill: str) -> str:
    """Retourne le contenu mémorisé pour ce skill (vide si rien)."""
    p = _skill_path(skill)
    if not p.exists():
        return ""
    try:
        return p.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def write_skill_memory(skill: str, entry: str, npub: str = "") -> bool:
    """Appende une entrée datée dans le fichier skill. Retourne True si OK."""
    p = _skill_path(skill)
    date_str = datetime.now().strftime("%Y-%m-%d")
    npub_tag  = f"[npub:{npub[:12]}]" if npub else ""
    line = f"[{date_str}]{npub_tag} {entry.strip()}"
    try:
        existing = p.read_text(encoding="utf-8").splitlines() if p.exists() else []
        existing.append(line)
        if len(existing) > MAX_LINES:
            existing = existing[-MAX_LINES:]
        p.write_text("\n".join(existing) + "\n", encoding="utf-8")
        return True
    except Exception as e:
        print(f"[skill_flashmem] Erreur écriture {p}: {e}", file=sys.stderr)
        return False


def list_skills() -> list:
    """Retourne la liste des skills mémorisés."""
    if not FLASHMEM_BASE.exists():
        return []
    return [f.stem for f in sorted(FLASHMEM_BASE.glob("*.md"))]


def reset_skill_memory(skill: str = None) -> bool:
    """Supprime la mémoire d'un skill (ou tous si skill=None)."""
    if skill:
        p = _skill_path(skill)
        if p.exists():
            p.unlink()
        return True
    if FLASHMEM_BASE.exists():
        for f in FLASHMEM_BASE.glob("*.md"):
            f.unlink()
    return True


def format_context(skill: str) -> str:
    """Retourne le contexte formaté pour injection dans le system prompt."""
    content = read_skill_memory(skill)
    if not content:
        return ""
    return (
        f"📝 Base de connaissance partagée pour '{skill}' (contributions des utilisateurs) :\n"
        f"{content}\n"
        f"--- fin notes ---"
    )


# ── CLI minimal pour usage bash ───────────────────────────────────────────────
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Gestion flashmem partagée par skill")
    parser.add_argument("cmd",     choices=["read", "write", "list", "reset", "context"])
    parser.add_argument("--skill", default="")
    parser.add_argument("--text",  default="")
    parser.add_argument("--npub",  default="")
    args = parser.parse_args()

    if args.cmd == "read":
        print(read_skill_memory(args.skill))
    elif args.cmd == "write":
        ok = write_skill_memory(args.skill, args.text, args.npub)
        sys.exit(0 if ok else 1)
    elif args.cmd == "list":
        skills = list_skills()
        print("\n".join(skills) if skills else "(aucun)")
    elif args.cmd == "reset":
        reset_skill_memory(args.skill or None)
        print("OK")
    elif args.cmd == "context":
        print(format_context(args.skill))
