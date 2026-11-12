#!/usr/bin/env python3
"""Génère build/SauteTroupeau.rbxlx (place Roblox) à partir de src/, sans Rojo.

Ouvre ensuite le fichier dans Roblox Studio (Fichier > Ouvrir depuis le fichier) puis Play.
Usage : python3 tools/build_rbxlx.py
"""
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "build", "SauteTroupeau.rbxlx")

_counter = [0]


def ref():
    _counter[0] += 1
    return "RBX%d" % _counter[0]


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_item(class_name, name, source, children=""):
    return (
        '<Item class="%s" referent="%s"><Properties>'
        '<string name="Name">%s</string>'
        '<ProtectedString name="Source">%s</ProtectedString>'
        "</Properties>%s</Item>"
    ) % (class_name, ref(), escape(name), cdata(source), children)


def folder_item(name, children):
    return (
        '<Item class="Folder" referent="%s"><Properties><string name="Name">%s</string></Properties>%s</Item>'
        % (ref(), escape(name), children)
    )


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def modules_in(directory):
    """Tous les ModuleScripts (*.luau sauf init.*) d'un dossier."""
    items = []
    for filename in sorted(os.listdir(directory)):
        if filename.endswith(".luau") and not filename.startswith("init."):
            name = filename[: -len(".luau")]
            items.append(script_item("ModuleScript", name, read(os.path.join(directory, filename))))
    return "".join(items)


def build():
    # ReplicatedStorage/Shared
    shared = folder_item("Shared", modules_in(os.path.join(SRC, "shared")))
    replicated = (
        '<Item class="ReplicatedStorage" referent="%s"><Properties><string name="Name">ReplicatedStorage</string></Properties>%s</Item>'
        % (ref(), shared)
    )

    # ServerScriptService/Server (Script) + Modules
    server_dir = os.path.join(SRC, "server")
    server_modules = folder_item("Modules", modules_in(os.path.join(server_dir, "Modules")))
    server_script = script_item("Script", "Server", read(os.path.join(server_dir, "init.server.luau")), server_modules)
    sss = (
        '<Item class="ServerScriptService" referent="%s"><Properties><string name="Name">ServerScriptService</string></Properties>%s</Item>'
        % (ref(), server_script)
    )

    # StarterPlayer/StarterPlayerScripts/Client (LocalScript) + Modules
    client_dir = os.path.join(SRC, "client")
    client_modules = folder_item("Modules", modules_in(os.path.join(client_dir, "Modules")))
    client_script = script_item("LocalScript", "Client", read(os.path.join(client_dir, "init.client.luau")), client_modules)
    sps = (
        '<Item class="StarterPlayerScripts" referent="%s"><Properties><string name="Name">StarterPlayerScripts</string></Properties>%s</Item>'
        % (ref(), client_script)
    )
    starter_player = (
        '<Item class="StarterPlayer" referent="%s"><Properties><string name="Name">StarterPlayer</string></Properties>%s</Item>'
        % (ref(), sps)
    )

    workspace = '<Item class="Workspace" referent="%s"><Properties><string name="Name">Workspace</string></Properties></Item>' % ref()
    lighting = (
        '<Item class="Lighting" referent="%s"><Properties><string name="Name">Lighting</string>'
        '<token name="Technology">3</token></Properties></Item>' % ref()
    )

    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        '<Meta name="ExplicitAutoJoints">true</Meta>\n'
        + workspace + "\n" + lighting + "\n" + replicated + "\n" + sss + "\n" + starter_player + "\n</roblox>\n"
    )


if __name__ == "__main__":
    xml = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("OK -> %s (%d Ko)" % (os.path.relpath(OUT, ROOT), len(xml) // 1024))
    sys.exit(0)
