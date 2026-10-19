#!/usr/bin/env python3
"""
code_chunker.py — découpe un fichier source en MORCEAUX sémantiques (une fonction, une classe, un bloc).

Pourquoi : l'index du code (collection Qdrant `codebase`) gardait UN vecteur par fichier, tronqué à ses 2 000
premiers caractères — pour un fichier de 1 800 lignes, seule l'en-tête était cherchable, et les gros fichiers
dépassaient le délai d'embedding. Avec un vecteur par fonction, « où est gérée la révocation d'un token ? »
retrouve la bonne fonction, avec son numéro de ligne.

chunk_file(texte, extension) → [{symbol, kind, start_line, end_line, text}], triés par ligne (1-indexées).
Stdlib seule (ast, re) : importable partout, testable sans réseau.
"""
import ast
import re

MAX_CHARS = 3500        # taille maximale d'un morceau (bge-m3 en lirait bien davantage ; au-delà la fonction est découpée)
WINDOW = 60             # lignes d'une fenêtre de repli
OVERLAP = 10
MIN_CHARS = 40          # en dessous : trivial, ignoré
MAX_CHUNKS_PER_FILE = 400

_SH_FUNC = re.compile(r"^(?:function\s+)?([A-Za-z_][\w:.\-]*)\s*\(\)\s*\{")
_JS_FUNC = re.compile(r"^(?:export\s+)?(?:async\s+)?function\s*\*?\s*([\w$]+)\s*\(")
_JS_ARROW = re.compile(r"^(?:export\s+)?(?:const|let|var)\s+([\w$]+)\s*=\s*(?:async\s*)?(?:function\b|\([^)]*\)\s*=>|[\w$]+\s*=>)")
_SCRIPT_BLOCK = re.compile(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", re.DOTALL | re.IGNORECASE)


def _mk(symbol, kind, lines, start, end):
    """Morceau [start, end] (1-indexés, inclusifs) ; None s'il est trivial."""
    text = "\n".join(lines[start - 1:end])
    if len(text.strip()) < MIN_CHARS:
        return None
    return {"symbol": symbol, "kind": kind, "start_line": start, "end_line": end, "text": text}


def _split_oversized(chunk, lines):
    """Un morceau de plus de MAX_CHARS est coupé en fenêtres de lignes (symbole#2, #3…)."""
    if len(chunk["text"]) <= MAX_CHARS:
        return [chunk]
    out, part, i = [], 1, chunk["start_line"]
    while i <= chunk["end_line"]:
        j, size = i, 0
        while j <= chunk["end_line"] and (size + len(lines[j - 1]) + 1 <= MAX_CHARS or j == i):
            size += len(lines[j - 1]) + 1
            j += 1
        c = _mk(chunk["symbol"] if part == 1 else f"{chunk['symbol']}#{part}", chunk["kind"], lines, i, j - 1)
        if c:
            out.append(c)
        i, part = j, part + 1
    return out


def windows(lines, offset=0, label="bloc"):
    """Repli : fenêtres de WINDOW lignes avec chevauchement."""
    out, i, n = [], 1, len(lines)
    while i <= n:
        j = min(n, i + WINDOW - 1)
        c = _mk(f"{label} L{offset + i}", "block", lines, i, j)
        if c:
            c["start_line"] += offset
            c["end_line"] += offset
            out.append(c)
        if j >= n:
            break
        i = j - OVERLAP + 1
    return out


def _shift(chunks, offset):
    for c in chunks:
        c["start_line"] += offset
        c["end_line"] += offset
    return chunks


# ── Python : AST ────────────────────────────────────────────────────────────
def _py_chunks(text, lines):
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return None
    chunks, first_def = [], None

    def start_of(node):
        decos = getattr(node, "decorator_list", None) or []
        return min([node.lineno] + [d.lineno for d in decos])

    for node in tree.body:
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            continue
        s, e = start_of(node), node.end_lineno
        first_def = s if first_def is None else first_def
        if isinstance(node, ast.ClassDef) and (e - s + 1) and len("\n".join(lines[s - 1:e])) > MAX_CHARS:
            methods = [m for m in node.body if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef))]
            head_end = (start_of(methods[0]) - 1) if methods else e
            c = _mk(node.name, "class", lines, s, max(s, head_end))
            if c:
                chunks.append(c)
            for m in methods:
                c = _mk(f"{node.name}.{m.name}", "function", lines, start_of(m), m.end_lineno)
                if c:
                    chunks.append(c)
        else:
            kind = "class" if isinstance(node, ast.ClassDef) else "function"
            c = _mk(node.name, kind, lines, s, e)
            if c:
                chunks.append(c)
    # En-tête : docstring du module, imports, constantes — avant la première définition
    head_end = (first_def - 1) if first_def else len(lines)
    head = _mk("en-tête", "header", lines, 1, head_end) if head_end >= 1 else None
    if head:
        chunks.insert(0, head)
    # Code de module hors définitions (point d'entrée `if __name__…`, constantes entre deux fonctions) :
    # UNIQUEMENT les séquences de lignes non couvertes, jamais un bloc qui recouvrirait des fonctions déjà découpées.
    covered = set()
    for c in chunks:
        covered.update(range(c["start_line"], c["end_line"] + 1))
    run = []
    for i in range(1, len(lines) + 2):
        if i <= len(lines) and i not in covered:
            run.append(i)
            continue
        body = [k for k in run if lines[k - 1].strip()]
        if len(body) >= 6:
            c = _mk("code du module", "block", lines, body[0], body[-1])
            if c:
                chunks.extend(_split_oversized(c, lines))
        run = []
    return chunks


# ── Shell et JS : repérage des fonctions de premier niveau ───────────────────
def _brace_chunks(lines, func_res, header_label="en-tête"):
    starts = []
    for i, ln in enumerate(lines, 1):
        if ln[:1] in (" ", "\t", ""):
            continue
        for rx in func_res:
            m = rx.match(ln)
            if m:
                starts.append((i, m.group(1)))
                break
    if not starts:
        return None
    chunks = []
    for idx, (s, name) in enumerate(starts):
        limit = (starts[idx + 1][0] - 1) if idx + 1 < len(starts) else len(lines)
        e = s
        for j in range(s + 1, limit + 1):
            if lines[j - 1].startswith("}"):
                e = j
                break
        else:
            e = limit
        # on remonte aux commentaires qui précèdent la fonction (ils DISENT à quoi elle sert)
        cs = s
        while cs > 1 and lines[cs - 2].lstrip().startswith(("#", "//", "/*", "*", "##")):
            cs -= 1
        c = _mk(name, "function", lines, cs, e)
        if c:
            chunks.append(c)
    head_end = starts[0][0] - 1
    head = _mk(header_label, "header", lines, 1, head_end) if head_end >= 1 else None
    if head:
        chunks.insert(0, head)
    return chunks


def _html_chunks(text, lines):
    chunks, script_ranges = [], []
    for m in _SCRIPT_BLOCK.finditer(text):
        body = m.group(1)
        if len(body.strip()) < MIN_CHARS:
            continue
        first = text.count("\n", 0, m.start(1)) + 1            # ligne (1-indexée) où commence le script
        inner = body.split("\n")
        sub = _brace_chunks(inner, [_JS_FUNC, _JS_ARROW], "script (en-tête)")
        if sub is None:
            sub = windows(inner, label="script")
        chunks.extend(_shift(sub, first - 1))
        script_ranges.append((first, first + len(inner) - 1))
    # Le balisage / CSS hors scripts : fenêtres sur les lignes restantes
    rest = [ln if not any(a <= i <= b for a, b in script_ranges) else "" for i, ln in enumerate(lines, 1)]
    markup = windows(rest, label="balisage")
    chunks.extend(c for c in markup if len(c["text"].strip()) >= 3 * MIN_CHARS)
    return chunks


def chunk_file(text, ext):
    """Morceaux d'un fichier source. `ext` sans le point (py, sh, js, html, css…)."""
    lines = text.split("\n")
    ext = ext.lower().lstrip(".")
    chunks = None
    if ext == "py":
        chunks = _py_chunks(text, lines)
    elif ext == "sh":
        chunks = _brace_chunks(lines, [_SH_FUNC])
    elif ext in ("js", "mjs"):
        chunks = _brace_chunks(lines, [_JS_FUNC, _JS_ARROW])
    elif ext in ("html", "htm"):
        chunks = _html_chunks(text, lines)
    if chunks is None or not chunks:
        chunks = windows(lines)
    out = []
    for c in chunks:
        out.extend(_split_oversized(c, lines))
    out.sort(key=lambda c: (c["start_line"], c["end_line"]))
    return out[:MAX_CHUNKS_PER_FILE]
