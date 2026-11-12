#!/usr/bin/env python3
"""Vérifie les noms d'API Roblox utilisés dans le code contre les définitions de types officielles
(globalTypes.d.luau de luau-lsp) : classes d'Instance.new, propriétés assignées, énumérations,
clés des tables de propriétés (UI.New / UI.Frame / mk ...).

Usage : tools/check_api.py chemin/vers/globalTypes.d.luau
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
defs_path = sys.argv[1]
defs = open(defs_path, encoding="utf-8").read()

# --- classes : nom -> (parent, {membres})
classes = {}
for m in re.finditer(r"^declare extern type (\w+)(?: extends (\w+))? with\n(.*?)^end", defs, re.M | re.S):
    name, parent, body = m.groups()
    members = set()
    for line in body.split("\n"):
        mm = re.match(r"\t(?:read |write )?([A-Za-z_]\w*)\s*:", line)
        if mm:
            members.add(mm.group(1))
    classes[name] = (parent, members)

def all_members(cls):
    out = set()
    while cls and cls in classes:
        parent, members = classes[cls]
        out |= members
        cls = parent
    return out

# --- enums : "Material" -> {Wood, Neon, ...}
enums = {}
for m in re.finditer(r"^declare extern type Enum(\w+)_INTERNAL extends Enum with\n(.*?)^end", defs, re.M | re.S):
    name, body = m.groups()
    enums[name] = set(re.findall(r"^\t(\w+): Enum\w+$", body, re.M))

creatable = set(re.findall(r'"(\w+)"', defs[: defs.index("}", defs.index("CREATABLE_INSTANCES"))])) if "CREATABLE_INSTANCES" in defs else set()

# Helpers UI du projet : (fonction -> classe par défaut, clés ignorées)
HELPERS = {
    "UI.Frame": ("Frame", {"Radius", "Stroke"}),
    "UI.Label": ("TextLabel", set()),
    "UI.Button": ("TextButton", {"Radius"}),
    "mk": ("Part", {"ClassName"}),
}

def top_level_keys(block):
    """Clés `Key =` au niveau 0 d'un littéral de table (sans les sous-tables)."""
    keys, depth, i = [], 0, 0
    s = block
    token = ""
    while i < len(s):
        c = s[i]
        if c in "{([":
            depth += 1
        elif c in "})]":
            depth -= 1
        elif c == '"':
            i += 1
            while i < len(s) and s[i] != '"':
                i += 1
        elif depth == 0:
            m = re.match(r"([A-Za-z_]\w*)\s*=(?!=)", s[i:])
            if m and (i == 0 or not (s[i - 1].isalnum() or s[i - 1] in "_.")):
                keys.append(m.group(1))
                i += len(m.group(0)) - 1
        i += 1
    return keys

def extract_braced(text, start):
    depth = 0
    for j in range(start, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1 : j], j
    return None, start

problems = 0
checked = 0
for dp, _, fns in os.walk(SRC):
    for fn in sorted(fns):
        if not fn.endswith(".luau"):
            continue
        path = os.path.join(dp, fn)
        rel = os.path.relpath(path, SRC)
        text = open(path, encoding="utf-8").read()
        nocomment = re.sub(r"--[^\n]*", "", text)
        lines = nocomment.split("\n")

        # 1) énumérations
        for enum, item in re.findall(r"\bEnum\.(\w+)\.(\w+)", nocomment):
            checked += 1
            if enum not in enums:
                print(f"[enum] {rel}: Enum.{enum} inconnu"); problems += 1
            elif item not in enums[enum]:
                print(f"[enum] {rel}: Enum.{enum}.{item} inconnu"); problems += 1

        # 2) classes créées
        for cls in re.findall(r'Instance\.new\("(\w+)"\)', nocomment):
            checked += 1
            if cls not in classes:
                print(f"[classe] {rel}: Instance.new(\"{cls}\") inconnu"); problems += 1

        # 3) propriétés assignées sur des variables issues d'Instance.new (suivi séquentiel)
        var_class = {}
        for ln, line in enumerate(lines, 1):
            m = re.match(r'\s*(?:local\s+)?(\w+)\s*=\s*Instance\.new\("(\w+)"\)', line)
            if m:
                var_class[m.group(1)] = m.group(2)
                continue
            m = re.match(r"\s*local\s+(\w+)\s*=\s*(?:\w+)", line)
            if m and m.group(1) in var_class and "Instance.new" not in line:
                var_class.pop(m.group(1), None)  # variable réutilisée pour autre chose
            for v, prop in re.findall(r"^\s*(\w+)\.(\w+)\s*=[^=]", line):
                cls = var_class.get(v)
                if cls and cls in classes:
                    checked += 1
                    if prop not in all_members(cls) and prop != "Parent":
                        print(f"[propriété] {rel}:{ln}: {cls}.{prop} inconnue"); problems += 1

        # 4) tables de propriétés : UI.New("Classe", {...}) et helpers
        for m in re.finditer(r'UI\.New\("(\w+)"\s*,\s*\{', nocomment):
            cls = m.group(1)
            block, _ = extract_braced(nocomment, m.end() - 1)
            if block is None:
                continue
            if cls not in classes:
                print(f"[classe] {rel}: UI.New(\"{cls}\") inconnu"); problems += 1
                continue
            for key in top_level_keys(block):
                checked += 1
                if key not in all_members(cls):
                    print(f"[propriété] {rel}: {cls}.{key} inconnue (UI.New)"); problems += 1
        for helper, (cls, ignore) in HELPERS.items():
            for m in re.finditer(rf"(?<![\w.]){re.escape(helper)}\(\s*[\w.]+\s*,\s*\{{", nocomment):
                block, _ = extract_braced(nocomment, m.end() - 1)
                if block is None:
                    continue
                for key in top_level_keys(block):
                    if key in ignore:
                        continue
                    checked += 1
                    if key not in all_members(cls):
                        print(f"[propriété] {rel}: {cls}.{key} inconnue ({helper})"); problems += 1

# 5) méthodes appelées (`obj:Methode(`) : doivent exister dans l'API Roblox ou être définies dans le projet
methods = set(re.findall(r"^\s+function (\w+)\(", defs, re.M)) | {"Connect", "Once", "Wait"}  # RBXScriptSignal
STRING_METHODS = {"format", "upper", "lower", "reverse", "gsub", "find", "sub", "match", "rep", "split", "byte", "char", "gmatch", "len"}
project_methods = set()
sources = {}
for dp, _, fns in os.walk(SRC):
    for fn in fns:
        if fn.endswith(".luau"):
            t = open(os.path.join(dp, fn), encoding="utf-8").read()
            sources[os.path.relpath(os.path.join(dp, fn), SRC)] = t
            project_methods |= set(re.findall(r"function \w+:(\w+)\(", t))
for rel, t in sources.items():
    t = re.sub(r"--[^\n]*", "", t)
    t = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', t)
    for name in sorted(set(re.findall(r":(\w+)\(", t))):
        checked += 1
        if name not in methods and name not in STRING_METHODS and name not in project_methods:
            print(f"[méthode] {rel}: :{name}() inconnue de l'API Roblox"); problems += 1

print(f"\nAPI Roblox : {checked} usages vérifiés, {problems} problème(s)")
sys.exit(1 if problems else 0)
