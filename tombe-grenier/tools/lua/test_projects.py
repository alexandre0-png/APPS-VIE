#!/usr/bin/env python3
"""Deux projets Rojo distincts, un dossier commun : chaque lieu n'inclut que ce dont il a besoin.

- hub.project.json : Shared + Common + src/hub uniquement (ni maison, ni client, ni systèmes de partie).
- game.project.json : Shared + Common + src/server + src/client.
- Le code du hub ne requiert que Shared, Common et son propre dossier.
"""
import json
import os
import re
import unittest

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def load(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as f:
        return json.load(f)


def paths(node, prefix=""):
    """Chemins $path du projet, avec leur emplacement dans l'arbre (ex. ServerScriptService/Server)."""
    out = {}
    for key, value in node.items():
        if key.startswith("$"):
            continue
        if isinstance(value, dict):
            if "$path" in value:
                out[prefix + key] = value["$path"]
            else:
                out.update(paths(value, prefix + key + "/"))
    return out


class TestProjects(unittest.TestCase):
    def setUp(self):
        self.hub = paths(load("hub.project.json")["tree"])
        self.game = paths(load("game.project.json")["tree"])

    def test_projects_are_different(self):
        self.assertNotEqual(self.hub, self.game)

    def test_both_projects_share_the_common_folder(self):
        for tree in (self.hub, self.game):
            self.assertIn("ServerScriptService/Common", tree)
            self.assertEqual(tree["ServerScriptService/Common"], "src/common")
            self.assertEqual(tree["ReplicatedStorage/Shared"], "src/shared")

    def test_hub_has_no_game_systems(self):
        self.assertEqual(self.hub["ServerScriptService/Server"], "src/hub")
        self.assertNotIn("StarterPlayer/StarterPlayerScripts/Client", self.hub)
        for path in self.hub.values():
            self.assertNotEqual(path, "src/server")
            self.assertNotEqual(path, "src/client")

    def test_game_has_server_and_client(self):
        self.assertEqual(self.game["ServerScriptService/Server"], "src/server")
        self.assertEqual(self.game["StarterPlayer/StarterPlayerScripts/Client"], "src/client")

    def test_declared_folders_exist(self):
        for tree in (self.hub, self.game):
            for path in tree.values():
                self.assertTrue(os.path.isdir(os.path.join(ROOT, path)), f"dossier absent : {path}")

    def test_hub_code_requires_only_shared_common_and_hub(self):
        hub_dir = os.path.join(ROOT, "src", "hub")
        common_dir = os.path.join(ROOT, "src", "common")
        allowed = {"Shared", "Common", "Hub", "HubRules", "Config", "Remotes"}
        for dirpath in (hub_dir, common_dir):
            for name in os.listdir(dirpath):
                if not name.endswith(".lua"):
                    continue
                text = open(os.path.join(dirpath, name), encoding="utf-8").read()
                for m in re.finditer(r"require\(([^)]*)\)", text):
                    target = m.group(1)
                    self.assertTrue(
                        any(a in target for a in allowed) or "script.Parent.Common" in target,
                        f"{name} requiert une ressource hors hub : {target}",
                    )

    def test_hub_entry_exists(self):
        self.assertTrue(os.path.isfile(os.path.join(ROOT, "src", "hub", "init.server.lua")))


if __name__ == "__main__":
    unittest.main()
