#!/usr/bin/env python3
"""Construit build/CityRush.rbxlx à partir de src/ (équivalent minimal de `rojo build`).
Ouvrir le fichier dans Roblox Studio puis Play (F5). Aucune dépendance externe."""
import pathlib, itertools, sys
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "build" / "CityRush.rbxlx"
ref = itertools.count()

def cdata(s):
    return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def item(cls, name, props="", children=""):
    return (f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties>'
            f'<string name="Name">{escape(name)}</string>{props}</Properties>{children}</Item>')

def script_item(path):
    n = path.name
    if n.endswith(".server.lua"):
        cls, name = "Script", n[:-len(".server.lua")]
    elif n.endswith(".client.lua"):
        cls, name = "LocalScript", n[:-len(".client.lua")]
    else:
        cls, name = "ModuleScript", n[:-len(".lua")]
    src = f'<ProtectedString name="Source">{cdata(path.read_text())}</ProtectedString>'
    return item(cls, name, src)

def folder_children(d):
    out = []
    for p in sorted(d.iterdir()):
        if p.is_dir():
            out.append(item("Folder", p.name, "", folder_children(p)))
        elif p.suffix == ".lua":
            out.append(script_item(p))
    return "".join(out)

def build():
    ws = item("Workspace", "Workspace",
              '<bool name="StreamingEnabled">true</bool>'
              '<int name="StreamingMinRadius">128</int>'
              '<int name="StreamingTargetRadius">640</int>'
              '<float name="Gravity">196.2</float>')
    lighting = item("Lighting", "Lighting",
                    '<token name="Technology">3</token><float name="ClockTime">14</float>'
                    '<float name="Brightness">2.5</float><bool name="GlobalShadows">true</bool>')
    rs = item("ReplicatedStorage", "ReplicatedStorage", "",
              item("Folder", "Shared", "", folder_children(SRC / "ReplicatedStorage" / "Shared")))
    sss = item("ServerScriptService", "ServerScriptService", "", folder_children(SRC / "ServerScriptService"))
    sp = item("StarterPlayer", "StarterPlayer", "",
              item("StarterPlayerScripts", "StarterPlayerScripts", "",
                   folder_children(SRC / "StarterPlayer" / "StarterPlayerScripts")))
    body = ws + lighting + rs + sss + sp
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
            + body + '</roblox>')

if __name__ == "__main__":
    OUT.parent.mkdir(exist_ok=True)
    xml = build()
    OUT.write_text(xml, encoding="utf-8")
    # validation XML
    import xml.etree.ElementTree as ET
    ET.parse(OUT)
    print(f"OK : {OUT} ({len(xml)//1024} Ko, XML valide)")
