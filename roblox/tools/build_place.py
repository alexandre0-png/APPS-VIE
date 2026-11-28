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

SHARED = [("Config", "Config.lua"), ("Easing", "Easing.lua"), ("Cinema", "Cinema.lua"), ("VfxKit", "VfxKit.lua"), ("CinematicKit", "CinematicKit.lua"), ("Placement", "Placement.lua"), ("MapGeo", "MapGeo.lua"), ("Culling", "Culling.lua"), ("AssetReportUi", "AssetReportUi.lua"), ("MiniMap", "MiniMap.lua"), ("Battle", "Battle.lua"), ("Layout", "Layout.lua"), ("Party", "Party.lua"),
          ("Spawn", "Spawn.lua"), ("SpawnGuard", "SpawnGuard.lua"), ("Belt", "Belt.lua"), ("Raven", "Raven.lua"), ("Assets", "Assets.lua"), ("Reveal", "Reveal.lua"), ("Guard", "Guard.lua"), ("Traps", "Traps.lua"), ("Riddle", "Riddle.lua"), ("Castle", "Castle.lua"), ("Upgrade", "Upgrade.lua"),
          ("Odds", "Odds.lua"), ("HatchPlan", "HatchPlan.lua"), ("IntroPlan", "IntroPlan.lua"), ("TypeFx", "TypeFx.lua"), ("Calendar", "Calendar.lua"), ("Npc", "Npc.lua"), ("Rewards", "Rewards.lua"),
          ("KioskData", "KioskData.lua"), ("DecorData", "DecorData.lua"), ("HouseDecorData", "HouseDecorData.lua"),  # lot 8B : kiosque, décor de carte, meubles
          ("ShopInfo", "ShopInfo.lua"), ("ShopData", "ShopData.lua"), ("Shop", "Shop.lua"), ("Season", "Season.lua"), ("SeasonData", "SeasonData.lua"),  # lot 16 : boutique, passe de combat
          ("Offers", "Offers.lua"), ("OffersData", "OffersData.lua"), ("SellersData", "SellersData.lua"),  # lot 16 : offres à l'écran, vendeurs PNJ
          ("Bestiary", "Bestiary.lua"), ("PetXp", "PetXp.lua"), ("BattleRewards", "BattleRewards.lua"),  # lots 11 et 12 : bestiaire, XP de pet, cartes de récompense
          ("Duel", "Duel.lua"), ("Ranked", "Ranked.lua"),
          ("BattleLayout", "BattleLayout.lua"),  # refonte du combat : disposition pure de la scène face à face
          ("Graphics", "Graphics.lua"),  # lot graphismes
          ("Onboarding", "Onboarding.lua"),  # lot 17 : onboarding
          ("Showcase", "Showcase.lua"),  # lot 17 (idée 3) : vitrine du pet du jour
          ("UiStyle", "UiStyle.lua"),  # graphismes 6 : style d'interface commun (pur)
          ("Music", "Music.lua"),  # graphismes 9 : musique par zone (pur)
          ("EggAura", "EggAura.lua"),  # lot graphismes 4 : halos d'œufs et bulles de protection (pur)
          ("EvolveLayout", "EvolveLayout.lua"),  # lot 17 (idée 2) : interface Évoluer, logique pure
          ("Evolution", "Evolution.lua")]  # lot 17 (idée 2) : évolution des pets (règles pures)  # lot 17 (idée 3) : vitrine du pet du jour (règles pures, DataStore injecté)  # lot 17 : onboarding des 5 premières minutes (règles pures)  # lot graphismes : lumière unifiée, styles d'arbres, sol, LOD (planificateur pur)  # lot 13 : duel local, ligues, remise de saison ; lot 14 : classé en direct (règles pures)

def shared():
    return item("ReplicatedStorage", "ReplicatedStorage", children=[
        item("Folder", "Shared", children=[item("ModuleScript", n, read("ReplicatedStorage/" + f)) for n, f in SHARED])])

def cfg_int(name):
    return int(re.search(name + r" = (\d+)", open(os.path.join(SRC, "ReplicatedStorage", "Config.lua"), encoding="utf-8").read()).group(1))

# StreamingEnabled : valeurs lues dans Config.Map.Streaming (source unique)
stream_on = re.search(r'Streaming = \{ Enabled = (true|false)', open(os.path.join(SRC, 'ReplicatedStorage', 'Config.lua'), encoding='utf-8').read()).group(1)
streaming = (f'<bool name="StreamingEnabled">{stream_on}</bool><int name="StreamingMinRadius">{cfg_int("MinRadius")}</int>'
             f'<int name="StreamingTargetRadius">{cfg_int("TargetRadius")}</int>')

game_tree = [
    item("Workspace", "Workspace", extra=streaming),
    shared(),
    item("ServerScriptService", "ServerScriptService", children=[
        item("Script", "Main", read("ServerScriptService/Main.server.lua")),
        item("ModuleScript", "Data", read("ServerScriptService/Data.lua")),
        item("ModuleScript", "Builder", read("ServerScriptService/Builder.lua")),
        item("ModuleScript", "Rules", read("ServerScriptService/Rules.lua")),
        item("ModuleScript", "Diag", read("ServerScriptService/Diag.lua")),
        item("ModuleScript", "HenQuest", read("ServerScriptService/HenQuest.lua")),
        item("ModuleScript", "Scenery", read("ServerScriptService/Scenery.lua")),
        item("ModuleScript", "Kiosk", read("ServerScriptService/Kiosk.lua")),  # lot 8B : kiosque central
        item("ModuleScript", "Sellers", read("ServerScriptService/Sellers.lua")),  # lot 16 : vendeurs PNJ
        item("ModuleScript", "PvpLive", read("ServerScriptService/PvpLive.lua")),  # lot 14 : transport du classé en direct (désactivé par défaut)
        item("ModuleScript", "Decor", read("ServerScriptService/Decor.lua")),  # lot 8B : décor de carte (lots 15 à 17)
        item("ModuleScript", "HouseDecor", read("ServerScriptService/HouseDecor.lua")),  # lot 8B : meubles des maisons (lots 18 et 19)
        item("ModuleScript", "Telemetry", read("ServerScriptService/Telemetry.lua"))]),  # lot 9 : mesures AnalyticsService
    item("StarterPlayer", "StarterPlayer", children=[
        item("StarterPlayerScripts", "StarterPlayerScripts", children=[
            item("LocalScript", "Client", read("StarterPlayerScripts/Client.client.lua")),
            item("LocalScript", "Animations", read("StarterPlayerScripts/Animations.client.lua")),
            item("LocalScript", "Cinematics", read("StarterPlayerScripts/Cinematics.client.lua")),
            item("LocalScript", "Ambience", read("StarterPlayerScripts/Ambience.client.lua")),
            item("LocalScript", "Culling", read("StarterPlayerScripts/Culling.client.lua")),
            item("LocalScript", "LightLod", read("StarterPlayerScripts/LightLod.client.lua")),  # lot graphismes : au plus 4 PointLight allumées, effets lointains coupés
            item("LocalScript", "EggAura", read("StarterPlayerScripts/EggAura.client.lua")),
            item("LocalScript", "Music", read("StarterPlayerScripts/Music.client.lua")),  # graphismes 9 : musique par zone (muette sans pistes)  # lot graphismes 4 : halos d'œufs, bulles de protection (aucune PointLight)
            item("ModuleScript", "RevealFx", read("StarterPlayerScripts/RevealFx.lua")),
            item("ModuleScript", "SlotFx", read("StarterPlayerScripts/SlotFx.lua")),
            item("ModuleScript", "MiniMapUi", read("StarterPlayerScripts/MiniMapUi.lua")),
            item("ModuleScript", "BattleUi", read("StarterPlayerScripts/BattleUi.lua")),
            item("ModuleScript", "BattleIntro", read("StarterPlayerScripts/BattleIntro.lua")),  # lot 10 (branché plus tard)
            item("ModuleScript", "BattleScene", read("StarterPlayerScripts/BattleScene.lua")),  # refonte du combat : scène face à face
            item("ModuleScript", "HatchFx", read("StarterPlayerScripts/HatchFx.lua")),
            item("ModuleScript", "TypeFx", read("StarterPlayerScripts/TypeFx.lua")),
            item("ModuleScript", "BaseUpgradeFx", read("StarterPlayerScripts/BaseUpgradeFx.lua")),
            item("ModuleScript", "HenUi", read("StarterPlayerScripts/HenUi.lua")),
            item("ModuleScript", "EvolveUi", read("StarterPlayerScripts/EvolveUi.lua")),  # lot 17 (idée 2) : écran Évoluer
            item("ModuleScript", "CoinIcon", read("StarterPlayerScripts/CoinIcon.lua"))])]),
]

hub_tree = [
    item("Workspace", "Workspace", extra='<bool name="StreamingEnabled">false</bool>'),
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
