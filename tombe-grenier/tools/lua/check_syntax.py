#!/usr/bin/env python3
"""Vérifie la syntaxe de tout le Luau du projet avec un vrai analyseur Lua 5.4 (lupa).

Le Luau de Roblox est un sur-ensemble du Lua 5.1 : on convertit d'abord les extensions
(opérateurs composés +=, -=, *=, /=) pour que l'analyseur Lua 5.4 puisse les lire.
Les fichiers ne sont pas exécutés : seule la grammaire est contrôlée.

Lancer depuis tombe-grenier/ :  python3 tools/lua/check_syntax.py
"""
import glob
import os
import re
import sys

try:
    import lupa
except ImportError:  # pragma: no cover
    print("lupa manquant : pip install lupa", file=sys.stderr)
    sys.exit(2)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "src")

COMPOUND = re.compile(r"^(\s*)([\w.\[\]\"']+)\s*(\+|-|\*|/)=\s*(.+)$")


def to_lua54(text):
    out = []
    for line in text.split("\n"):
        m = COMPOUND.match(line)
        if m:
            indent, target, op, rhs = m.groups()
            line = f"{indent}{target} = {target} {op} ({rhs})"
        out.append(line)
    return "\n".join(out)


_compile_check = None


def compile_check(src, name):
    """Compile sans exécuter. Retourne (ok, message d'erreur)."""
    global _compile_check
    return _compile_check(src, name)


def check(path, lua):
    with open(path, encoding="utf-8") as f:
        src = to_lua54(f.read())
    try:
        ok, err = compile_check(src, "@" + os.path.basename(path))
    except Exception as e:  # erreur de l'interpréteur lui-même
        return f"erreur interne : {e}"
    return None if ok else str(err)


def main():
    global _compile_check
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    _compile_check = lua.eval(
        "function(src, name) local fn, err = load(src, name); return fn ~= nil, err or '' end"
    )
    failures = 0
    files = sorted(glob.glob(os.path.join(SRC, "**", "*.lua"), recursive=True))
    for path in files:
        err = check(path, lua)
        rel = os.path.relpath(path, ROOT)
        if err:
            failures += 1
            print(f"ERREUR  {rel}\n        {err}")
        else:
            print(f"ok      {rel}")
    print(f"\n{len(files)} fichiers, {failures} erreur(s) de syntaxe")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
