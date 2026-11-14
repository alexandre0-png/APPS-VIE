#!/usr/bin/env python3
"""Chaque `require(script....)` et chaque `Shared.X` se résout dans l'arbre RÉEL construit par Rojo, pour le lieu hub
et pour le lieu de partie. Un chemin faux (ex. script.Parent.Common depuis un module du dossier Server) tue le script
serveur à son démarrage : plus de Remotes, plus de carte, joueur seul dans le vide."""
import os
import re
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SCRIPT_CLASSES = ("Script", "LocalScript", "ModuleScript")


class Node:
    def __init__(self, name, cls, source, parent):
        self.name, self.cls, self.source, self.parent = name, cls, source, parent
        self.children = {}

    def path(self):
        return (self.parent.path() + "/" if self.parent and self.parent.parent else "") + self.name if self.parent else self.name


def load_tree(project):
    if shutil.which("rojo") is None:
        raise unittest.SkipTest("rojo absent")
    out = os.path.join(tempfile.mkdtemp(), "place.rbxlx")
    subprocess.run(["rojo", "build", "-o", out, project], cwd=ROOT, check=True, capture_output=True)
    root = ET.parse(out).getroot()

    def build(item, parent):
        name_node = item.find("Properties/string[@name='Name']")
        src_node = item.find("Properties/string[@name='Source']")
        node = Node(name_node.text if name_node is not None else item.get("class"), item.get("class"), src_node.text if src_node is not None else None, parent)
        if parent is not None:
            parent.children[node.name] = node
        for child in item.findall("Item"):
            build(child, node)
        return node

    top = Node("game", "DataModel", None, None)
    for item in root.findall("Item"):
        build(item, top)
    return top


def all_nodes(node):
    for child in node.children.values():
        yield child
        yield from all_nodes(child)


def resolve(script, chain):
    """chain = ['Parent', 'Parent', 'Common', 'Hub'] depuis `script` ; renvoie le nœud ou None."""
    cur = script
    for part in chain:
        if cur is None:
            return None
        cur = cur.parent if part == "Parent" else cur.children.get(part)
    return cur


class TestRequirePaths(unittest.TestCase):
    def check(self, project):
        tree = load_tree(project)
        shared = tree.children["ReplicatedStorage"].children["Shared"]
        problems = []
        checked = 0
        for node in all_nodes(tree):
            if node.cls not in SCRIPT_CLASSES or not node.source:
                continue
            for m in re.finditer(r"require\((script(?:\.\w+)+)\)", node.source):
                chain = m.group(1).split(".")[1:]
                checked += 1
                if resolve(node, chain) is None:
                    problems.append(f"{node.path()} : require(script.{'.'.join(chain)}) introuvable")
            if re.search(r'Shared\s*=\s*ReplicatedStorage:WaitForChild\("Shared"\)', node.source):
                for m in re.finditer(r"require\(Shared\.(\w+)\)", node.source):
                    checked += 1
                    if m.group(1) not in shared.children:
                        problems.append(f"{node.path()} : Shared.{m.group(1)} absent de ReplicatedStorage/Shared")
        self.assertGreater(checked, 5)
        self.assertEqual(problems, [], "\n".join(problems))

    def test_game_place_requires_all_resolve(self):
        self.check("game.project.json")

    def test_hub_place_requires_all_resolve(self):
        self.check("hub.project.json")

    def test_default_project_requires_all_resolve(self):
        self.check("default.project.json")

    def test_a_wrong_path_would_be_caught(self):
        tree = load_tree("game.project.json")
        shop = tree.children["ServerScriptService"].children["Server"].children["Shop"]
        self.assertIsNone(resolve(shop, ["Parent", "Common", "Hub"]), "le chemin fautif d'origine ne se résout pas")
        self.assertIsNotNone(resolve(shop, ["Parent", "Parent", "Common", "Hub"]))


class TestStartupOrder(unittest.TestCase):
    def test_remotes_created_first_in_both_scripts(self):
        for rel in ("src/server/init.server.lua", "src/hub/init.server.lua"):
            with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
                text = f.read()
            first = text.index("Remotes.init()")
            start = text.index("local Remotes")
            for later in ("require(script.", "require(Shared.HubRules)", "Hub.build", "MapBuilder", "task.wait", "WaitForChild("):
                idx = text.find(later, start)
                if idx != -1:
                    self.assertLess(first, idx, f"{rel} : Remotes.init() après {later}")

    def test_client_remote_wait_is_bounded(self):
        with open(os.path.join(ROOT, "src", "shared", "Remotes.lua"), encoding="utf-8") as f:
            text = f.read()
        self.assertIn('WaitForChild("Remotes", 10)', text)
        self.assertIn("warn(", text)


if __name__ == "__main__":
    unittest.main()
