#!/usr/bin/env python3
"""Construit les deux fichiers de place Roblox (XML) : build/ChipeOeufs.rbxlx (le jeu complet) et build/Hub.rbxlx (le hub, petit lieu),
à ouvrir dans Roblox Studio puis File > Publish to Roblox. Aucun outil externe requis. Usage : python3 build_place.py"""
import itertools, os, re
from xml.etree import ElementTree as ET

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "src")
ids = itertools.count()

def read(rel):
    return open(os.path.join(SRC, rel), encoding="utf-8").read()

def cdata(s):
    return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def item(cls, name, source=None, children=(), extra=""):
    props = f'<string name="Name">{name}</string>' + extra
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    kids = "".join(children)
    return f'<Item class="{cls}" referent="RBX{next(ids)}"><Properties>{props}</Properties>{kids}</Item>'

SHARED = [("Config", "Config.lua"), ("Easing", "Easing.lua"), ("Cinema", "Cinema.lua"), ("Layout", "Layout.lua"), ("Party", "Party.lua")]

def shared():
    return item("ReplicatedStorage", "ReplicatedStorage", children=[
        item("Folder", "Shared", children=[item("ModuleScript", n, read("ReplicatedStorage/" + f)) for n, f in SHARED])])

def cfg_int(name):
    return int(re.search(name + r" = (\d+)", open(os.path.join(SRC, "ReplicatedStorage", "Config.lua"), encoding="utf-8").read()).group(1))

# StreamingEnabled : valeurs lues dans Config.Map.Streaming (source unique)
streaming = (f'<bool name="StreamingEnabled">true</bool><int name="StreamingMinRadius">{cfg_int("MinRadius")}</int>'
             f'<int name="StreamingTargetRadius">{cfg_int("TargetRadius")}</int>')

game_tree = [
    item("Workspace", "Workspace", extra=streaming),
    shared(),
    item("ServerScriptService", "ServerScriptService", children=[
        item("Script", "Main", read("ServerScriptService/Main.server.lua")),
        item("ModuleScript", "Data", read("ServerScriptService/Data.lua")),
        item("ModuleScript", "Builder", read("ServerScriptService/Builder.lua")),
        item("ModuleScript", "Rules", read("ServerScriptService/Rules.lua")),
        item("ModuleScript", "Assets", read("ServerScriptService/Assets.lua")),
        item("ModuleScript", "Diag", read("ServerScriptService/Diag.lua")),
        item("ModuleScript", "Scenery", read("ServerScriptService/Scenery.lua"))]),
    item("StarterPlayer", "StarterPlayer", children=[
        item("StarterPlayerScripts", "StarterPlayerScripts", children=[
            item("LocalScript", "Client", read("StarterPlayerScripts/Client.client.lua")),
            item("LocalScript", "Animations", read("StarterPlayerScripts/Animations.client.lua")),
            item("LocalScript", "Cinematics", read("StarterPlayerScripts/Cinematics.client.lua")),
            item("LocalScript", "Ambience", read("StarterPlayerScripts/Ambience.client.lua"))])]),
]

hub_tree = [
    item("Workspace", "Workspace"),
    shared(),
    item("ServerScriptService", "ServerScriptService", children=[
        item("Script", "Hub", read("Hub/ServerScriptService/Hub.server.lua")),
        item("ModuleScript", "HubWorld", read("Hub/ServerScriptService/HubWorld.lua"))]),
    item("StarterPlayer", "StarterPlayer", children=[
        item("StarterPlayerScripts", "StarterPlayerScripts", children=[
            item("LocalScript", "HubClient", read("Hub/StarterPlayerScripts/HubClient.client.lua"))])]),
]

def write(name, tree):
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
           '<Meta name="ExplicitAutoJoints">true</Meta>\n' + "\n".join(tree) + "\n</roblox>\n")
    ET.fromstring(xml.encode("utf-8"))  # lève une erreur si le XML est invalide
    out = os.path.join(ROOT, "build", name)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w", encoding="utf-8", newline="\n").write(xml)
    print("écrit", os.path.relpath(out, ROOT), f"({len(xml)//1024} Ko)")

write("ChipeOeufs.rbxlx", game_tree)
write("Hub.rbxlx", hub_tree)
