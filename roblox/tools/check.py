#!/usr/bin/env python3
"""Contrôle automatique du projet Roblox (à lancer après CHAQUE modification) :
1. compile chaque script avec le compilateur Luau officiel (erreurs de syntaxe) ;
2. vérifie que chaque classe (Instance.new / GetService) et chaque Enum utilisés existent dans le dump officiel de l'API Roblox ;
3. vérifie la cohérence client/serveur des actions RemoteEvent ;
4. repère les variables locales jamais utilisées ;
5. vérifie que le fichier de place (.rbxlx) contient bien les sources à jour.
Ne remplace PAS un playtest dans Roblox Studio. Usage : python3 roblox/tools/check.py"""
import glob, json, os, re, subprocess, sys, urllib.request, zipfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "src")
CACHE = os.path.join(os.path.expanduser("~"), ".cache", "chipe-check")
os.makedirs(CACHE, exist_ok=True)
errors = 0

def fetch(url, dest):
    if not os.path.exists(dest):
        urllib.request.urlretrieve(url, dest)
    return dest

def fail(msg):
    global errors
    errors += 1
    print("  ✗", msg)

files = sorted(glob.glob(os.path.join(SRC, "**", "*.lua"), recursive=True))
print(f"[1/5] Syntaxe Luau ({len(files)} fichiers)")
zpath = fetch("https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip", os.path.join(CACHE, "luau.zip"))
binp = os.path.join(CACHE, "luau-compile")
if not os.path.exists(binp):
    with zipfile.ZipFile(zpath) as z:
        z.extract("luau-compile", CACHE)
    os.chmod(binp, 0o755)
for f in files:
    r = subprocess.run([binp, "--text", f], capture_output=True)
    print("  ✓" if r.returncode == 0 else "  ✗", os.path.relpath(f, ROOT))
    if r.returncode != 0:
        errors += 1
        print(r.stderr.decode("utf-8", "replace")[:400])

print("[2/5] API Roblox (dump officiel)")
api = json.load(open(fetch("https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json", os.path.join(CACHE, "api.json"))))
classes = {c["Name"] for c in api["Classes"]}
enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in api["Enums"]}
for f in files:
    s = open(f, encoding="utf-8").read()
    for c in set(re.findall(r'Instance\.new\("(\w+)"\)', s)) | set(re.findall(r'GetService\("(\w+)"\)', s)) | set(re.findall(r'\bmake\("(\w+)"', s)):
        if c not in classes:
            fail(f"{os.path.basename(f)} : classe inconnue {c}")
    for e, i in set(re.findall(r"\bEnum\.(\w+)\.(\w+)", s)):
        if e not in enums or i not in enums[e]:
            fail(f"{os.path.basename(f)} : enum inconnu Enum.{e}.{i}")

print("[3/5] Remotes client/serveur")
srv = open(os.path.join(SRC, "ServerScriptService", "Main.server.lua"), encoding="utf-8").read()
cli = open(os.path.join(SRC, "StarterPlayerScripts", "Client.client.lua"), encoding="utf-8").read()
handlers = set(re.findall(r"^function actions\.(\w+)", srv, re.M))
calls = set(re.findall(r'FireServer\("(\w+)"', cli))
for a in calls - handlers:
    fail(f"le client appelle l'action « {a} » sans gestionnaire serveur")
for a in handlers - calls:
    print(f"  ! action serveur « {a} » jamais appelée par le client")
for r in set(re.findall(r'newRemote\("(\w+)"\)', srv)):
    if f'WaitForChild("{r}")' not in cli:
        fail(f"RemoteEvent « {r} » créé côté serveur mais jamais attendu côté client")

print("[4/5] Variables locales inutilisées")
for f in files:
    s = open(f, encoding="utf-8").read()
    for n in sorted(set(re.findall(r"^\s*local function (\w+)", s, re.M)) | set(re.findall(r"^\s*local (\w+)\s*=", s, re.M))):
        if len(re.findall(r"\b" + n + r"\b", s)) <= 1:
            print(f"  ! {os.path.basename(f)} : « {n} » n'est jamais utilisé")

print("[5/5] Fichier de place à jour")
place = os.path.join(ROOT, "build", "ChipeOeufs.rbxlx")
if not os.path.exists(place):
    fail("build/ChipeOeufs.rbxlx absent : lance python3 roblox/tools/build_place.py")
else:
    txt = open(place, encoding="utf-8").read()
    for f in files:
        body = open(f, encoding="utf-8").read().replace("]]>", "]]]]><![CDATA[>")
        if body not in txt:
            fail(f"{os.path.relpath(f, ROOT)} a changé depuis le dernier build : relance build_place.py")

print("\n" + ("✅ Aucun problème détecté" if errors == 0 else f"❌ {errors} problème(s)") + " (analyse statique uniquement : un playtest Studio reste nécessaire)")
sys.exit(1 if errors else 0)
