#!/usr/bin/env python3
"""Vérification statique du projet Luau (sans Roblox Studio).

1. Résout chaque `require(Alias.Module)` vers un fichier réel (sinon erreur).
2. Génère des copies d'analyse où les require deviennent des chemins relatifs
   (pour que luau-analyze type-check à travers les modules).
3. Injecte des stubs `any` pour les globaux Roblox (game, Instance, Vector3...).
4. Lance luau-analyze en mode strict et affiche les erreurs avec les lignes d'origine.
5. Vérifie que chaque Remote utilisé existe dans Shared/Remotes.luau.

Usage : tools/check.py [--analyze PATH_TO_luau-analyze] [--keep DIR]
"""
import argparse, os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

ALIASES = {
    "Shared": "ReplicatedStorage/Shared",
    "Server": "ServerScriptService/Server",
    "Client": "StarterPlayer/StarterPlayerScripts/Client",
}
GLOBALS = [
    "game", "workspace", "script", "Instance", "Vector3", "Vector2", "CFrame", "Color3", "Enum",
    "UDim2", "UDim", "TweenInfo", "Random", "RaycastParams", "NumberSequence", "NumberRange",
    "ColorSequence", "task", "warn", "tick", "wait", "shared", "Rect", "Font", "BrickColor",
    "DateTime", "OverlapParams", "PhysicalProperties",
]
PRELUDE = "local " + ", ".join(GLOBALS) + ": any" + ", any" * (len(GLOBALS) - 1) + " = " + ", ".join(["nil"] * len(GLOBALS))
# Chaque stub est typé `any` ; on évite `: any, any...` invalide : on déclare un par un.
TYPES = ["Player", "Vector3", "Model", "BasePart", "Tool", "Humanoid", "Instance", "CFrame", "Color3", "RBXScriptConnection", "Part"]
PRELUDE = "; ".join([f"type {t} = any" for t in TYPES] + [f"local {g}: any = nil" for g in GLOBALS])

REQ = re.compile(r"require\(\s*(\w+)\.(\w+)\s*\)")

def module_file(alias, name):
    base = os.path.join(SRC, ALIASES[alias], name)
    if os.path.isfile(base + ".luau"):
        return base + ".luau"
    if os.path.isfile(os.path.join(base, "init.luau")):
        return os.path.join(base, "init.luau")
    return None

def exported_names(path):
    """Noms exportés par un module : `function M.name`, `M.name =` et clés de table retournée."""
    text = open(path, encoding="utf-8").read()
    names = set(re.findall(r"^function\s+\w+[.:](\w+)", text, re.M))
    names |= set(re.findall(r"^(?:local\s+)?\w+\.(\w+)\s*=", text, re.M))
    return names

def semantic_checks(files_src):
    problems = 0
    # 1. chaque `X.member` d'un module requis existe dans ce module
    remote_names = set()
    rtext = open(os.path.join(SRC, "ReplicatedStorage/Shared/Remotes.luau"), encoding="utf-8").read()
    for grp in re.findall(r"local (?:EVENTS|FUNCTIONS) = \{([^}]*)\}", rtext):
        remote_names |= set(re.findall(r'"(\w+)"', grp))
    for path in files_src:
        text = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, SRC)
        stripped = re.sub(r"--[^\n]*", "", text)
        stripped = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', stripped)
        for var, alias, mod in re.findall(r"local (\w+) = require\((\w+)\.(\w+)\)", text):
            target = module_file(alias, mod)
            if not target:
                continue
            if mod == "Remotes":
                for name in set(re.findall(rf"\b{var}\.(\w+)", stripped)):
                    if name not in remote_names:
                        print(f"[remote] {rel}: Remotes.{name} n'existe pas"); problems += 1
                continue
            exported = exported_names(target)
            for name in sorted(set(re.findall(rf"(?<![\w.]){var}\.(\w+)", stripped))):
                if name not in exported:
                    print(f"[membre] {rel}: {var}.{name} absent de {mod}.luau"); problems += 1
            for name in sorted(set(re.findall(rf"(?<![\w.]){var}:(\w+)\(", stripped))):
                print(f"[membre] {rel}: appel de méthode {var}:{name}() sur un module"); problems += 1
    # 2. attributs lus mais jamais écrits
    setters, getters = {}, {}
    for path in files_src:
        text = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, SRC)
        for n in re.findall(r'SetAttribute\("(\w+)"', text):
            setters.setdefault(n, rel)
        for n in re.findall(r'(?:GetAttribute|GetAttributeChangedSignal)\("(\w+)"', text):
            getters.setdefault(n, rel)
    for n, rel in sorted(getters.items()):
        if n not in setters:
            print(f"[attribut] '{n}' lu dans {rel} mais jamais défini"); problems += 1
    return problems

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--analyze", default=os.environ.get("LUAU_ANALYZE", "luau-analyze"))
    ap.add_argument("--keep", default=None)
    ap.add_argument("--emit", default=None, help="écrit aussi des copies exécutables (require par chemin, sans stubs) dans ce dossier")
    ap.add_argument("--mode", default="own", help="own = directive de chaque fichier, strict = tout en strict")
    args = ap.parse_args()

    out = args.keep or tempfile.mkdtemp(prefix="luau-check-")
    if os.path.exists(out):
        shutil.rmtree(out)
    shutil.copytree(SRC, out)

    errors = 0
    files = []
    for dp, _, fns in os.walk(out):
        for fn in fns:
            if fn.endswith(".luau"):
                files.append(os.path.join(dp, fn))

    for path in files:
        rel = os.path.relpath(path, out)
        text = open(os.path.join(SRC, rel), encoding="utf-8").read()
        lines = text.split("\n")
        header = lines[0] if lines and lines[0].startswith("--!") else None
        body_lines = lines[1:] if header else lines

        def repl(m):
            global_err = 0
            alias, name = m.group(1), m.group(2)
            if alias not in ALIASES:
                print(f"[require] {rel}: alias inconnu '{alias}' dans {m.group(0)}")
                return m.group(0)
            target = module_file(alias, name)
            if not target:
                print(f"[require] {rel}: module introuvable : {alias}.{name}")
                return m.group(0)
            target_in_out = os.path.join(out, os.path.relpath(target, SRC))
            relpath = os.path.relpath(target_in_out, os.path.dirname(path))
            relpath = relpath[: -len(".luau")]
            if not relpath.startswith("."):
                relpath = "./" + relpath
            return f'require("{relpath}")'

        new_body = []
        for i, line in enumerate(body_lines):
            for m in REQ.finditer(line):
                alias, name = m.group(1), m.group(2)
                if alias not in ALIASES or not module_file(alias, name):
                    errors += 1
            new_body.append(REQ.sub(repl, line))
        if args.emit:
            dest = os.path.join(args.emit, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            inject = []
            if os.environ.get("INJECT_MOCK"):
                up = "/".join([".."] * (rel.count(os.sep) + 1))
                inject = [f'local __M = require("{up}/tests/mock"); local game, workspace, script, Instance, Vector3, Color3, task, warn, ColorSequence, NumberRange, NumberSequence, Vector2 = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, __M.Color3, __M.task, __M.warn, __M.ColorSequence, __M.NumberRange, __M.NumberSequence, __M.Vector2']
            open(dest, "w", encoding="utf-8").write("\n".join(([header] if header else []) + inject + new_body))
        mode = "--!strict" if args.mode == "strict" else (header or "--!nonstrict")
        # ligne 1 : directive, ligne 2 : stubs (les numéros d'origine = numéro analysé - 1)
        analysed = [mode, PRELUDE] + new_body
        open(path, "w", encoding="utf-8").write("\n".join(analysed))

    proc = subprocess.run([args.analyze] + [os.path.relpath(f, out) for f in sorted(files)], cwd=out, capture_output=True, text=True)
    pat = re.compile(r"^(.*?)\((\d+),(\d+)\): (\w+): (.*)$")
    shown = 0
    for line in (proc.stdout + proc.stderr).splitlines():
        m = pat.match(line)
        if not m:
            if line.strip():
                print(line)
            continue
        f, ln, col, kind, msg = m.groups()
        if f.startswith("/"):
            continue  # doublon : module déjà analysé comme fichier explicite
        if kind == "LocalUnused" and re.search(r"Variable '(Shared|Server|Client)'", msg):
            continue  # alias utilisés uniquement dans les require() réécrits
        if kind == "LocalUnused" and re.search(r"Variable '_", msg):
            continue
        if kind == "UnknownType":
            continue  # typeof(x) == "Vector3" : types Roblox inconnus du CLI
        orig_line = int(ln) - 1  # on a inséré 1 ligne de stubs
        if int(ln) == 2 and "LocalUnused" in kind:
            continue
        # le préambule (ligne 2) contient des stubs inutilisés : ignorés
        if int(ln) == 2:
            continue
        # globaux stubbés non utilisés dans le fichier -> bruit
        print(f"{f}:{orig_line}:{col}: {kind}: {msg}")
        shown += 1
    print(f"\nluau-analyze : {shown} message(s)")
    errors += semantic_checks(files_src=[os.path.join(SRC, os.path.relpath(f, out)) for f in files])
    print(f"Contrôles sémantiques : {'OK' if not errors else str(errors) + ' problème(s)'}")
    if not args.keep:
        shutil.rmtree(out, ignore_errors=True)
    return 1 if (shown or errors) else 0

if __name__ == "__main__":
    sys.exit(main())
