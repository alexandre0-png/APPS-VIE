#!/usr/bin/env python3
"""Construit roblox/build/ChipeOeufs.rbxlx : un fichier de place Roblox (XML) contenant tous les scripts,
à ouvrir dans Roblox Studio (double-clic) puis File > Publish to Roblox. Aucun outil externe requis. Usage : python3 build_place.py"""
import itertools, os
from xml.etree import ElementTree as ET

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "src")
ids = itertools.count()

def read(rel):
    return open(os.path.join(SRC, rel), encoding="utf-8").read()

def cdata(s):
    return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def item(cls, name, source=None, children=()):
    props = f'<string name="Name">{name}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    kids = "".join(children)
    return f'<Item class="{cls}" referent="RBX{next(ids)}"><Properties>{props}</Properties>{kids}</Item>'

tree = [
    item("Workspace", "Workspace"),
    item("ReplicatedStorage", "ReplicatedStorage", children=[
        item("Folder", "Shared", children=[
            item("ModuleScript", "Config", read("ReplicatedStorage/Config.lua")),
            item("ModuleScript", "Easing", read("ReplicatedStorage/Easing.lua")),
            item("ModuleScript", "Cinema", read("ReplicatedStorage/Cinema.lua"))])]),
    item("ServerScriptService", "ServerScriptService", children=[
        item("Script", "Main", read("ServerScriptService/Main.server.lua")),
        item("ModuleScript", "Data", read("ServerScriptService/Data.lua")),
        item("ModuleScript", "Builder", read("ServerScriptService/Builder.lua")),
        item("ModuleScript", "Rules", read("ServerScriptService/Rules.lua"))]),
    item("StarterPlayer", "StarterPlayer", children=[
        item("StarterPlayerScripts", "StarterPlayerScripts", children=[
            item("LocalScript", "Client", read("StarterPlayerScripts/Client.client.lua")),
            item("LocalScript", "Animations", read("StarterPlayerScripts/Animations.client.lua")),
            item("LocalScript", "Cinematics", read("StarterPlayerScripts/Cinematics.client.lua"))])]),
]
xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
       '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
       '<Meta name="ExplicitAutoJoints">true</Meta>\n' + "\n".join(tree) + "\n</roblox>\n")
ET.fromstring(xml.encode("utf-8"))  # lève une erreur si le XML est invalide
out = os.path.join(ROOT, "build", "ChipeOeufs.rbxlx")
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, "w", encoding="utf-8", newline="\n").write(xml)
print("écrit", os.path.relpath(out, ROOT), f"({len(xml)//1024} Ko)")
