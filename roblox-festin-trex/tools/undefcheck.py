#!/usr/bin/env python3
"""Heuristique : repère les identifiants utilisés mais jamais déclarés dans le fichier (fautes de frappe).
Faux positifs possibles ; ne remplace pas luau-analyze."""
import re, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from blockcheck import strip  # noqa

KW = set('and break do else elseif end false for function if in local nil not or repeat return then true until while continue export type typeof'.split())
GLOBALS = set('''game workspace script Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum Ray RaycastParams TweenInfo NumberSequence NumberSequenceKeypoint
NumberRange ColorSequence ColorSequenceKeypoint math string table os task print warn pcall error tostring tonumber type ipairs pairs select next
require setmetatable getmetatable assert unpack tick time Random Players typeof Tween Part Model Folder BasePart Player ProximityPrompt TextLabel
Frame ScreenGui ScrollingFrame TextButton GuiObject Humanoid RBXScriptConnection Beam Attachment ColorCorrectionEffect InputObject Configuration
Instance Enum BillboardGui SpawnLocation Vector3 utf8 bit32 coroutine buffer rawget rawset rawequal any number boolean string Stats'''.split())

def check(path):
    src = strip(path.read_text(encoding='utf-8'))
    declared = set()
    for m in re.finditer(r'\blocal\s+function\s+([A-Za-z_]\w*)', src): declared.add(m.group(1))
    for m in re.finditer(r'\blocal\s+([A-Za-z_]\w*(?:\s*:\s*[^=,\n]+)?(?:\s*,\s*[A-Za-z_]\w*(?:\s*:\s*[^=,\n]+)?)*)', src):
        for n in re.findall(r'[A-Za-z_]\w*', re.sub(r':\s*[^,=\n]+', '', m.group(1))): declared.add(n)
    for m in re.finditer(r'\bfor\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s+(?:in|=)', src):
        declared.update(re.findall(r'[A-Za-z_]\w*', m.group(1)))
    for m in re.finditer(r'function\s*[\w.:]*\s*\(([^)]*)\)', src):
        for part in m.group(1).split(','):
            n = re.match(r'\s*([A-Za-z_]\w*)', part)
            if n: declared.add(n.group(1))
    for m in re.finditer(r'function\s+(?:[\w.]+[.:])?([A-Za-z_]\w*)\s*\(', src): declared.add(m.group(1))
    out = set()
    for m in re.finditer(r'(?<![\w.:"])([A-Za-z_]\w*)(?!\w)', src):
        n = m.group(1); end = m.end()
        nxt = src[end:end+3].lstrip()
        before = src[max(0, m.start()-2):m.start()].strip()
        if n in KW or n in GLOBALS or n in declared: continue
        if nxt.startswith('=') and not nxt.startswith('==') and before in ('{', ',', ''): continue  # clé de table
        if before.endswith(':') or before.endswith('::'): continue  # annotation de type
        out.add(n)
    return sorted(out)

bad = 0
for p in sorted(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'src').rglob('*.luau')):
    r = check(p)
    if r: print(p, r); bad += 1
print('fichiers avec candidats :', bad)
