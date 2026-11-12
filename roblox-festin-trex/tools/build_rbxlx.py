#!/usr/bin/env python3
"""Génère dist/FestinDuTRex.rbxlx : un fichier de place Roblox complet (sans Rojo).

Ouvrir le .rbxlx dans Roblox Studio, puis Fichier > Publier sur Roblox.
La structure est identique à celle de default.project.json (Rojo).
"""
import os
import sys
import uuid
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")


def referent():
    return "RBX" + uuid.uuid4().hex.upper()


def esc_cdata(text):
    return text.replace("]]>", "]]]]><![CDATA[>")


def item(cls, name, source=None, children=""):
    props = f'<string name="Name">{name}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source"><![CDATA[{esc_cdata(source)}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="{referent()}"><Properties>{props}</Properties>{children}</Item>'


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def script_class(filename):
    if filename.endswith(".server.luau"):
        return "Script", filename[: -len(".server.luau")]
    if filename.endswith(".client.luau"):
        return "LocalScript", filename[: -len(".client.luau")]
    return "ModuleScript", filename[: -len(".luau")]


def folder_xml(path, name, is_folder=True):
    """Construit récursivement un dossier de scripts."""
    children = ""
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            children += folder_xml(full, entry)
        elif entry.endswith(".luau"):
            cls, nm = script_class(entry)
            children += item(cls, nm, read(full))
    return item("Folder", name, None, children)


def main():
    shared = folder_xml(os.path.join(SRC, "shared"), "Shared")
    server = folder_xml(os.path.join(SRC, "server"), "Server")
    client = folder_xml(os.path.join(SRC, "client"), "Client")

    body = ""
    body += item("Workspace", "Workspace")
    body += item("ReplicatedStorage", "ReplicatedStorage", None, shared)
    body += item("ServerScriptService", "ServerScriptService", None, server)
    body += item("StarterPlayer", "StarterPlayer", None, item("StarterPlayerScripts", "StarterPlayerScripts", None, client))

    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        '<Meta name="ExplicitAutoJoints">true</Meta>' + body + "</roblox>"
    )

    ET.fromstring(xml)  # vérifie que le XML est bien formé

    out_dir = os.path.join(ROOT, "dist")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "FestinDuTRex.rbxlx")
    with open(out, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"OK : {out} ({len(xml) // 1024} Ko)")


if __name__ == "__main__":
    sys.exit(main())
