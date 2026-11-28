#!/usr/bin/env python3
"""Contrôle automatique du projet Roblox (à lancer après CHAQUE modification) :
1. compile chaque script avec le compilateur Luau officiel (erreurs de syntaxe) ;
2. vérifie que chaque classe (Instance.new / GetService) et chaque Enum utilisés existent dans le dump officiel de l'API Roblox ;
3. vérifie la cohérence client/serveur des actions RemoteEvent ;
4. repère les variables locales jamais utilisées ;
5. vérifie que le fichier de place (.rbxlx) contient bien les sources à jour ;
6. exécute les tests de logique pure (tests/run.luau) avec Lua 5.x si `lupa` est installé.
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


# Propriétés / méthodes / événements utilisés par les scripts, à vérifier dans le dump officiel (classe -> membres).
# Ajoute ici tout nouveau membre Roblox utilisé dans le code.
MEMBER_CHECKS = {
    "TeleportOptions": ["ReservedServerAccessCode", "SetTeleportData"],
    "TeleportService": ["TeleportAsync", "ReserveServerAsync"],
    "MemoryStoreHashMap": ["GetAsync", "UpdateAsync", "RemoveAsync", "ListItemsAsync"],
    "MemoryStoreService": ["GetHashMap"],
    "ScreenGui": ["ScreenInsets"],
    "InsertService": ["LoadAsset"],
    "Lighting": ["ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness", "GlobalShadows"],
    "Atmosphere": ["Density", "Offset", "Color", "Decay", "Glare", "Haze"],
    "BloomEffect": ["Intensity", "Size", "Threshold"],
    "SunRaysEffect": ["Intensity", "Spread"],
    "ColorCorrectionEffect": ["Saturation", "Contrast", "Brightness", "TintColor"],
    "Fire": ["Size", "Heat", "Color", "SecondaryColor"],
    "SurfaceGui": ["Face", "CanvasSize", "LightInfluence", "Adornee"],
    "BillboardGui": ["Adornee", "Size", "StudsOffsetWorldSpace", "MaxDistance", "AlwaysOnTop", "Enabled"],
    "ProximityPrompt": ["ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance", "RequiresLineOfSight", "Enabled"],
    "ProximityPromptService": ["PromptTriggered", "PromptButtonHoldBegan"],
    "ClickDetector": ["MaxActivationDistance", "MouseClick"],
    "ParticleEmitter": ["Texture", "Rate", "Lifetime", "Speed", "SpreadAngle", "LightEmission", "Size", "Color", "Emit", "Acceleration"],
    "Workspace": ["GetServerTimeNow", "SetAttribute"],
    "Humanoid": ["PlatformStand", "WalkSpeed", "MoveDirection", "ChangeState", "Died", "Health", "CameraOffset"],
    "Part": ["AssemblyLinearVelocity", "Massless", "Shape", "CanCollide", "CanQuery", "Material", "Transparency"],
    "Player": ["RespawnLocation", "LoadCharacterAsync", "DisplayName", "Character", "CharacterAdded", "UserId", "Kick"],
    "Players": ["CharacterAutoLoads", "GetPlayerByUserId", "PlayerAdded", "PlayerRemoving", "GetPlayers", "GetNameFromUserIdAsync"],
    "MarketplaceService": ["PromptGamePassPurchaseFinished", "UserOwnsGamePassAsync", "PromptGamePassPurchase", "ProcessReceipt", "PromptProductPurchase"],
    "MessagingService": ["PublishAsync", "SubscribeAsync"],
    "OrderedDataStore": ["GetSortedAsync", "SetAsync"],
    "GlobalDataStore": ["UpdateAsync"],
    "DataStoreService": ["GetOrderedDataStore", "GetDataStore"],
    "HttpService": ["GenerateGUID"],
    "Beam": ["Attachment0", "Attachment1", "Width0", "Width1", "Color", "Transparency", "LightEmission", "FaceCamera", "Enabled"],
    "ScrollingFrame": ["ScrollBarThickness", "AutomaticCanvasSize", "CanvasPosition", "CanvasSize"],
    "TextLabel": ["MaxVisibleGraphemes", "TextTruncate", "TextWrapped", "AutomaticSize", "TextStrokeTransparency", "TextStrokeColor3", "TextYAlignment", "TextXAlignment", "TextScaled"],
    "TextButton": ["AutoButtonColor", "Activated"],
    "UIStroke": ["Color", "Thickness"],
    "UIScale": ["Scale"],
    "UIGradient": ["Color", "Rotation", "Transparency"],
    "RemoteEvent": ["FireClient", "FireAllClients", "OnServerEvent", "OnClientEvent", "FireServer"],
    "CollectionService": ["GetTagged", "AddTag", "GetInstanceAddedSignal"],
    "TweenService": ["Create"],
    "Sound": ["SoundId", "Volume", "PlaybackSpeed", "Play"],
    "UITextSizeConstraint": ["MaxTextSize", "MinTextSize"],
    "RunService": ["BindToRenderStep", "UnbindFromRenderStep", "IsStudio", "Heartbeat", "RenderStepped"],
    "UserInputService": ["InputBegan"],
    "BindableEvent": ["Fire", "Event"],
    "Instance": ["SetAttribute", "GetAttribute", "GetAttributeChangedSignal", "FindFirstChildOfClass", "FindFirstChild", "Destroy"],
    "Camera": ["FieldOfView", "CFrame", "ViewportSize"],
    "ScreenGui": ["DisplayOrder", "IgnoreGuiInset", "ResetOnSpawn", "ZIndexBehavior"],
    "SpecialMesh": ["Scale", "MeshType"],
    "Weld": ["Part0", "Part1", "C0"],
    "Frame": ["Rotation", "AnchorPoint", "BorderSizePixel", "BackgroundTransparency"],
    "Tween": ["Completed", "Play"],
    "Highlight": ["Adornee", "FillColor", "FillTransparency", "OutlineColor", "OutlineTransparency", "Enabled"],
    "BasePart": ["CFrame", "Size", "Transparency", "CanCollide", "Position"],
    "Model": ["ScaleTo", "PivotTo", "GetPivot", "PrimaryPart", "GetBoundingBox", "ModelStreamingMode", "GetScale", "GetExtentsSize"],
    "SurfaceGui": ["Face", "CanvasSize", "LightInfluence", "Adornee"],
}

def _members(cn, by_name):
    out = set()
    while cn and cn in by_name:
        out |= {m["Name"] for m in by_name[cn]["Members"]}
        cn = by_name[cn]["Superclass"]
    return out

by_name = {c["Name"]: c for c in api["Classes"]}
def _member_tags(cn, name):
    while cn and cn in by_name:
        for m in by_name[cn]["Members"]:
            if m["Name"] == name:
                return m.get("Tags", [])
        cn = by_name[cn]["Superclass"]
    return []

# Dépréciés dans le dump mais sans remplacement trouvé dans le même dump : exception documentée (VERIFICATION.md), repli prévu dans Party.launch.
DEPRECATED_BUT_ONLY_OPTION = {("TeleportOptions", "ReservedServerAccessCode"), ("TeleportService", "ReserveServerAsync")}

for cls, mems in MEMBER_CHECKS.items():
    if cls not in by_name:
        fail(f"MEMBER_CHECKS : classe inconnue {cls}")
        continue
    if "Deprecated" in by_name[cls].get("Tags", []):
        fail(f"classe dépréciée : {cls}")
    have = _members(cls, by_name)
    for m in mems:
        if m not in have:
            fail(f"{cls}.{m} n'existe pas dans l'API Roblox")
        elif "Deprecated" in _member_tags(cls, m):
            if (cls, m) in DEPRECATED_BUT_ONLY_OPTION:
                print(f"  ! {cls}.{m} déprécié mais seule voie de création d'un serveur réservé (repli public prévu s'il disparaît)")
            else:
                fail(f"{cls}.{m} est déprécié dans l'API Roblox")

# Classes réellement instanciées / services utilisés : aucune ne doit être dépréciée
for f in files:
    txt = open(f, encoding="utf-8").read()
    for c in set(re.findall(r'Instance\.new\("(\w+)"\)', txt)) | set(re.findall(r'GetService\("(\w+)"\)', txt)):
        if c in by_name and "Deprecated" in by_name[c].get("Tags", []):
            fail(f"{os.path.basename(f)} : classe dépréciée {c}")
# Appels de méthodes dépréciées connues (liste à compléter quand l'API évolue)
DEPRECATED_CALLS = [r":LoadCharacter\(", r"(?<![\w.:])wait\(", r"(?<![\w.:])spawn\(", r"(?<![\w.:])delay\("]
for f in files:
    txt = open(f, encoding="utf-8").read()
    for pat in DEPRECATED_CALLS:
        if re.search(pat, txt):
            fail(f"{os.path.basename(f)} : usage déprécié {pat}")

print("[3/5] Remotes client/serveur")
srv = open(os.path.join(SRC, "ServerScriptService", "Main.server.lua"), encoding="utf-8").read()
cli = "\n".join(open(f, encoding="utf-8").read() for f in sorted(glob.glob(os.path.join(SRC, "StarterPlayerScripts", "*.lua"))))  # tous les scripts client
handlers = set(re.findall(r"^\s*function actions\.(\w+)", srv, re.M))  # lot 15 : actions définies dans un bloc do (indentées)
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

print("[5/5] Fichiers de place à jour (jeu et hub)")
hub_files = [f for f in files if os.sep + "Hub" + os.sep in f]
game_files = [f for f in files if f not in hub_files]
for name, mine, other in (("ChipeOeufs.rbxlx", game_files, hub_files), ("Hub.rbxlx", [f for f in hub_files] + [f for f in game_files if os.sep + "ReplicatedStorage" + os.sep in f], [f for f in game_files if os.sep + "ReplicatedStorage" + os.sep not in f])):
    place = os.path.join(ROOT, "build", name)
    if not os.path.exists(place):
        fail(f"build/{name} absent : lance python3 roblox/tools/build_place.py")
        continue
    txt = open(place, encoding="utf-8").read()
    for f in mine:
        body = open(f, encoding="utf-8").read().replace("]]>", "]]]]><![CDATA[>")
        if body not in txt:
            fail(f"{os.path.relpath(f, ROOT)} absent ou périmé dans {name} : relance build_place.py")
    for f in other:
        body = open(f, encoding="utf-8").read().replace("]]>", "]]]]><![CDATA[>")
        if body in txt:
            fail(f"{os.path.relpath(f, ROOT)} ne doit PAS figurer dans {name}")

print("[4b] Boucles infinies : chaque « while true do » contient un task.wait")
for f in files:
    lines = open(f, encoding="utf-8").read().split("\n")
    for i, line in enumerate(lines):
        if re.match(r"\s*while true do\b", line):
            indent = re.match(r"\s*", line).group(0)
            body = []
            for l2 in lines[i + 1:]:
                if l2.startswith(indent + "end") and not l2.startswith(indent + "end)") or l2 == indent + "end":
                    break
                body.append(l2)
            if not any("task.wait" in l2 or ":Wait(" in l2 or "RenderStepped:Wait" in l2 for l2 in body):
                fail(f"{os.path.relpath(f, ROOT)}:{i + 1} : while true sans task.wait (boucle qui gèlerait le serveur)")

print("[4c] Tests sous Lune : aucun appel fs asynchrone dans une coroutine du runtime factice")
_fr = open(os.path.join(ROOT, "tests", "FakeRuntime.lua"), encoding="utf-8").read()
_run_script = _fr[_fr.index("function RT.runScript"):_fr.index("-- environnement des scripts")] if "function RT.runScript" in _fr else ""
if "fs." in _run_script or "readFile(src" in _fr:
    fail("tests/FakeRuntime.lua : fs.* appelé depuis runScript (coroutine) : sous Lune, fs est asynchrone et bloque le processus ; lire les fichiers dans buildTree")
if "task.delay(420" not in open(os.path.join(ROOT, "tests", "run.luau"), encoding="utf-8").read() or "process.exit(failed > 0 and 1 or 0)" not in open(os.path.join(ROOT, "tests", "run.luau"), encoding="utf-8").read():
    fail("tests/run.luau : watchdog global (task.delay 420 s) ou sortie explicite manquants")

print("[5b] Projets Rojo : JSON valide et chemins existants (substitut partiel de `rojo build`, non exécuté ici)")
def _paths(node, out):
    if isinstance(node, dict):
        if "$path" in node:
            out.append(node["$path"])
        for v in node.values():
            _paths(v, out)
for proj in ("default.project.json", "game.project.json", "hub.project.json"):
    try:
        data = json.load(open(os.path.join(ROOT, proj), encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        fail(f"{proj} : JSON invalide ({e})")
        continue
    paths = []
    _paths(data, paths)
    for rel in paths:
        if not os.path.isdir(os.path.join(ROOT, rel)):
            fail(f"{proj} : chemin « {rel} » introuvable")
    if data["tree"].get("Workspace", {}).get("$properties", {}).get("StreamingEnabled", None) is not False:
        fail(f"{proj} : Workspace.StreamingEnabled doit être explicitement false")
    print(f"  ✓ {proj} ({len(paths)} chemins)")

print("[5c] Chemins require / WaitForChild résolus dans l'arbre construit par chaque projet Rojo")

def _build_tree(node, base):
    """Simule Rojo : retourne un dict {nom: {"class": ..., "children": {...}}} pour un noeud du projet."""
    out = {}
    for key, val in node.items():
        if key.startswith("$"):
            continue
        out[key] = _make(val, base, key)
    return out

def _make(val, base, name):
    cls = val.get("$className", "Folder")
    kids = {}
    if "$path" in val:
        kids.update(_scan(os.path.join(base, val["$path"])))
    kids.update(_build_tree(val, base))
    return {"class": cls, "children": kids, "src": None}

def _scan(path):
    kids = {}
    if os.path.isdir(path):
        for entry in sorted(os.listdir(path)):
            full = os.path.join(path, entry)
            if os.path.isdir(full):
                kids[entry] = {"class": "Folder", "children": _scan(full), "src": None}
            elif entry.endswith(".server.lua"):
                kids[entry[:-11]] = {"class": "Script", "children": {}, "src": full}
            elif entry.endswith(".client.lua"):
                kids[entry[:-11]] = {"class": "LocalScript", "children": {}, "src": full}
            elif entry.endswith(".lua"):
                kids[entry[:-4]] = {"class": "ModuleScript", "children": {}, "src": full}
    return kids

def _index(tree, parent=None, out=None):
    out = {} if out is None else out
    for name, n in tree.items():
        n["parent"] = parent
        n["name"] = name
        if n["src"]:
            out[n["src"]] = n
        _index(n["children"], n, out)
    return out

TOKEN = re.compile(r'\s*(?:\.Parent\b|:WaitForChild\("([^"]+)"[^)]*\)|:FindFirstChild\("([^"]+)"[^)]*\)|:GetService\("([^"]+)"\))')

def _walk(node, expr, aliases, game_root):
    """Évalue une expression de chemin (script / game / alias puis .Parent, :WaitForChild, :FindFirstChild, :GetService). None si non statique."""
    m = re.match(r"\s*(script|game|[A-Za-z_]\w*)", expr)
    if not m:
        return None, expr
    head, pos = m.group(1), m.end()
    if head == "script":
        cur = node
    elif head == "game":
        cur = game_root
    elif head in aliases:
        cur = aliases[head]
    else:
        return None, expr
    path_ok = True
    while True:
        t = TOKEN.match(expr, pos)
        if not t:
            break
        pos = t.end()
        if t.group(0).strip().startswith(".Parent"):
            cur = cur["parent"] if cur and cur["parent"] else None
            if cur is None:
                return "MISSING:.Parent", expr
        elif t.group(3):
            nxt = game_root["children"].get(t.group(3)) if cur is game_root else None
            if nxt is None:
                return "MISSING:service " + t.group(3), expr
            cur = nxt
        else:
            name = t.group(1) or t.group(2)
            nxt = cur["children"].get(name)
            if nxt is None:
                return "MISSING:" + name, expr
            cur = nxt
    return cur, expr

RUNTIME_CREATED = {"Remotes", "State", "Notify", "Hatch", "Action", "Top", "HubRemote", "ReplayCinematic", "Kiosk"}
for proj in ("default.project.json", "game.project.json", "hub.project.json"):
    try:
        data = json.load(open(os.path.join(ROOT, proj), encoding="utf-8"))
    except Exception:  # noqa: BLE001
        continue
    game_root = {"class": "DataModel", "children": _build_tree(data["tree"], ROOT), "src": None, "parent": None, "name": "game"}
    scripts = _index(game_root["children"])
    checked = 0
    for src, node in scripts.items():
        text = open(src, encoding="utf-8").read()
        aliases = {}
        for am in re.finditer(r"^\s*local\s+(\w+)\s*=\s*(game:GetService\(\"\w+\"\)[^\n]*|script[^\n]*)$", text, re.M):
            val, _ = _walk(node, am.group(2).split("--")[0], aliases, game_root)
            if isinstance(val, dict):
                aliases[am.group(1)] = val
        for rm in re.finditer(r"require\(", text):
            depth, i = 1, rm.end()
            while i < len(text) and depth:
                depth += (text[i] == "(") - (text[i] == ")")
                i += 1
            expr = text[rm.end():i - 1]
            val, _ = _walk(node, expr, aliases, game_root)
            checked += 1
            if isinstance(val, str):
                fail(f"{proj} : {os.path.relpath(src, ROOT)} : require({expr.strip()}) -> {val} (absent de l'arbre Rojo)")
            elif isinstance(val, dict) and val["class"] != "ModuleScript":
                fail(f"{proj} : {os.path.relpath(src, ROOT)} : require({expr.strip()}) vise un objet de type {val['class']}, pas un ModuleScript")
        for wm in re.finditer(r"((?:script|game|[A-Za-z_]\w*)(?:\.Parent|:WaitForChild\(\"[^\"]+\"[^)]*\)|:GetService\(\"[^\"]+\"\))+)", text):
            chain = wm.group(1)
            names = re.findall(r':WaitForChild\("([^"]+)"', chain)
            if not names or names[-1] in RUNTIME_CREATED or any(n in RUNTIME_CREATED for n in names):
                continue
            if chain.startswith("script:") or chain.split(":")[0].split(".")[0] in ("PlayerGui", "player", "Players", "workspace", "char", "plot"):
                continue
            val, _ = _walk(node, chain, aliases, game_root)
            checked += 1
            if isinstance(val, str) and not (chain.split(".")[0].split(":")[0] in ("script",) and False):
                # seuls les chemins qui visent des modules statiques (Shared, frères de script) sont des erreurs
                static_targets = {"Shared", "Config", "Easing", "Cinema", "Layout", "Party", "Spawn", "SpawnGuard", "Data", "Builder", "Rules", "Assets", "Diag", "Scenery", "HubWorld", "MapGeo", "Placement"}
                if val.startswith("MISSING:") and val[8:] in static_targets:
                    fail(f"{proj} : {os.path.relpath(src, ROOT)} : {chain} -> {val}")
    print(f"  ✓ {proj} : {len(scripts)} scripts, {checked} chemins vérifiés")

print("[6/6] Tests de logique pure (Lua 5.x via lupa, à défaut de Lune)")
try:
    import lupa  # noqa: F401
    r = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "run_tests.py")], capture_output=True, text=True)
    print("  " + (r.stdout.strip().split("\n")[0] if r.stdout.strip() else "(aucune sortie)"))
    if r.returncode != 0:
        fail("des tests de logique échouent :\n" + r.stdout[-800:] + r.stderr[-400:])
except ImportError:
    print("  ! lupa absent : tests non exécutés (pip install --only-binary :all: lupa)")

print("\n" + ("✅ Aucun problème détecté" if errors == 0 else f"❌ {errors} problème(s)") + " (analyse statique uniquement : un playtest Studio reste nécessaire)")
sys.exit(1 if errors else 0)
