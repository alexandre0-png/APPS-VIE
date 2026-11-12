#!/usr/bin/env python3
"""Cherche les appels à une fonction locale avant sa déclaration (elle vaudrait alors nil).

En Lua, une fonction locale n'est visible qu'à partir de sa déclaration. Un appel écrit plus haut
dans le fichier désigne une variable globale du même nom, qui est nil : erreur silencieuse.
Heuristique textuelle, sans analyse complète : les cas signalés sont à vérifier à la main.
"""
import glob
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "src")

KEYWORDS = {"if", "elseif", "while", "for", "return", "function", "local", "and", "or", "not",
            "until", "repeat", "end", "then", "do", "in", "else", "break"}
GLOBALS = {"game", "workspace", "script", "task", "math", "table", "string", "os", "typeof", "warn",
           "print", "pairs", "ipairs", "tostring", "tonumber", "pcall", "error", "assert", "select",
           "next", "Instance", "Vector3", "CFrame", "Color3", "UDim2", "UDim", "Enum", "TweenInfo",
           "NumberSequence", "NumberSequenceKeypoint", "RaycastParams", "NumberRange", "Random",
           "require", "setmetatable", "getmetatable", "rawget", "unpack", "Vector2"}


def strip(src):
    t = re.sub(r"--\[\[.*?\]\]", lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
    t = re.sub(r"--[^\n]*", "", t)
    t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
    t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
    return t


def problems(path):
    text = strip(open(path, encoding="utf-8").read())
    lines = text.split("\n")
    declared_at = {}  # nom -> ligne de la première déclaration locale
    for i, line in enumerate(lines, 1):
        for name in re.findall(r"\blocal\s+function\s+(\w+)", line):
            declared_at.setdefault(name, i)
        for group in re.findall(r"\blocal\s+([\w\s,]+?)\s*=", line):
            for name in group.split(","):
                declared_at.setdefault(name.strip(), i)
        # Variables de boucle : « for a, b in ... » et « for i = ... »
        for group in re.findall(r"\bfor\s+([\w\s,]+?)\s+(?:in\b|=)", line):
            for name in group.split(","):
                name = name.strip()
                if name:
                    declared_at.setdefault(name, i)
        # Paramètres des fonctions : déclarés sur la ligne de la fonction
        for params in re.findall(r"\bfunction\s*[\w.:]*\s*\(([^)]*)\)", line):
            for name in params.split(","):
                name = name.strip()
                if name:
                    declared_at.setdefault(name, i)
        # Déclaration sans valeur (« local x ») : forward declaration
        for name in re.findall(r"\blocal\s+(\w+)\s*$", line):
            declared_at.setdefault(name, i)
    found = []
    for i, line in enumerate(lines, 1):
        # Appels de fonctions simples (pas de méthode, pas de champ)
        for m in re.finditer(r"(?<![\w.:])(\w+)\s*\(", line):
            name = m.group(1)
            if name in KEYWORDS or name in GLOBALS:
                continue
            if re.search(rf"\bfunction\s+{name}\b", line):
                continue
            decl = declared_at.get(name)
            if decl is None:
                # Déclaration globale (function NAME) ou nom inconnu : signalé pour revue
                if not re.search(rf"^\s*function\s+{name}\b", text, re.M):
                    found.append((i, name, "jamais déclaré"))
            elif decl > i:
                found.append((i, name, f"déclaré seulement ligne {decl}"))
    # Variables lues avant leur déclaration locale (ex. « extraCode » utilisée puis déclarée plus bas)
    for i, line in enumerate(lines, 1):
        for m in re.finditer(r"(?<![\w.:])([A-Za-z_]\w*)\b", line):
            name = m.group(1)
            if name in KEYWORDS or name in GLOBALS or name in ("nil", "true", "false", "self"):
                continue
            decl = declared_at.get(name)
            if decl is None or decl <= i:
                continue
            rest = line[m.end():]
            before = line[:m.start()]
            # Déclarations, paramètres, clés de table (« nom = ») et appels : traités ailleurs ou ignorés
            if re.match(r"\s*=(?!=)", rest) or re.search(r"\blocal\s+[\w\s,]*$", before):
                continue
            if re.match(r"\s*\(", rest):
                continue
            found.append((i, name, f"variable lue avant sa déclaration ligne {decl}"))
    return found


def main():
    total = 0
    for path in sorted(glob.glob(os.path.join(SRC, "**", "*.lua"), recursive=True)):
        for line, name, why in problems(path):
            total += 1
            print(f"{os.path.relpath(path, ROOT)}:{line}  {name}  ({why})")
    print(f"{total} point(s) à vérifier")
    return total


if __name__ == "__main__":
    main()
