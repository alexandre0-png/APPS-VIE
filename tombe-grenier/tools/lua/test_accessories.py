#!/usr/bin/env python3
"""Accessoires Blender : chaque modèle est déclaré (Config, chargeur, plan d'échelle) et chaque emplacement est libre
(hors meubles, hors zones de portes), pour ne jamais gêner un passage ni une énigme."""
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "map"))
import generate_map as g  # noqa: E402


def read(*p):
    return open(os.path.join(ROOT, *p), encoding="utf-8").read()


def accessories():
    src = read("src", "server", "MapBuilder.lua")
    block = src[src.index("MapBuilder.ACCESSORIES = {") : src.index("local function placeAccessories")]
    rows = re.findall(r'\{ "([^"]+)", ([-\d.]+), ([-\d.]+), ([-\d.]+), \{ ([\d.]+), ([\d.]+), ([\d.]+) \} \}', block)
    return [(n, float(x), float(y), float(z), (float(a), float(b), float(c))) for n, x, y, z, a, b, c in rows]


class TestAccessories(unittest.TestCase):
    def test_list_is_parsed(self):
        self.assertGreaterEqual(len(accessories()), 15)

    def test_every_model_is_declared_loaded_and_fitted(self):
        loader = read("src", "server", "ModelLoader.lua")
        fit = read("src", "shared", "ModelFit.lua")
        cfg = read("src", "shared", "Config.lua")
        for name in {a[0] for a in accessories()} | {"cheminée gothique", "étagère livres", "gramophone ancien", "téléphone ancien"}:
            self.assertIn('"%s"' % name, loader, name)
            self.assertIn('["%s"]' % name, fit, name)
        for key in ("Cheminee", "Etagere", "Gramophone", "Lustre", "MachineCoudre", "PorteAncienne", "TapisRond", "Telephone", "ToileAraignee", "Valise", "Escalier"):
            self.assertRegex(cfg, rf"\b{key} = \d{{9,}}")

    def test_floor_accessories_are_clear_of_furniture_and_doors(self):
        boxes = g.furniture_boxes()
        for name, x, y, z, size in accessories():
            if name in ("lustre", "toile d'araignée"):
                continue  # suspendus : rien au sol
            wall = name == "porte ancienne"
            w, d = (size[0], 0.6) if wall else (size[0], size[2])
            if wall:
                # contre un mur ouest ou est : la largeur court le long de Z
                x0, x1, z0, z1 = x - 0.8, x + 0.8, z - size[0] / 2, z + size[0] / 2
            else:
                x0, x1, z0, z1 = x - w / 2, x + w / 2, z - d / 2, z + d / 2
            for f in boxes:
                if f["y1"] < y - 0.5 or f["y0"] > y + g.H:
                    continue
                overlap = x1 > f["x0"] and x0 < f["x1"] and z1 > f["z0"] and z0 < f["z1"]
                self.assertFalse(overlap, f"{name} ({x}, {z}) chevauche {f['name']}")
            lvl = next(k for k, b in g.BASE.items() if abs(b - round(y - 0.06)) < 1e-6 or b <= y < b + g.H)
            for door in g.DOORS:
                if door["level"] != lvl:
                    continue
                if door["orient"] == "v":
                    hit = x0 - 1 < door["line"] < x1 + 1 and z1 > door["c"] - door["w"] / 2 - 1 and z0 < door["c"] + door["w"] / 2 + 1
                else:
                    hit = z0 - 1 < door["line"] < z1 + 1 and x1 > door["c"] - door["w"] / 2 - 1 and x0 < door["c"] + door["w"] / 2 + 1
                self.assertFalse(hit, f"{name} ({x}, {z}) dans une zone de porte")


def wall_items():
    src = read("src", "server", "MapBuilder.lua")
    block = src[src.index("MapBuilder.WALL_ITEMS = {") : src.index("-- Ouvertures de porte")]
    rows = re.findall(r'\{ "([^"]+)", ([-\d.]+), ([-\d.]+), ([-\d.]+), \{ ([\d.]+), ([\d.]+), ([\d.]+) \}, ([-\d]+), ([-\d]+) \}', block)
    return [(n, float(x), float(y), float(z), (float(a), float(b), float(c))) for n, x, y, z, a, b, c, _, _ in rows]


class TestWallItems(unittest.TestCase):
    def test_parsed(self):
        self.assertGreaterEqual(len(wall_items()), 17)

    def test_clear_of_doors_and_furniture(self):
        boxes = g.furniture_boxes()
        for name, x, y, z, size in wall_items():
            if name == "soupirail":
                continue  # haut dans le mur du sous-sol
            x0, x1, z0, z1 = x - max(size[0], 0.8) / 2, x + max(size[0], 0.8) / 2, z - max(size[2], 1) / 2, z + max(size[2], 1) / 2
            lvl = next(k for k, b in g.BASE.items() if b <= y < b + g.H)
            for f in boxes:
                if f["y1"] < g.BASE[lvl] or f["y0"] > g.BASE[lvl] + g.H:
                    continue
                if name == "radiateur fonte":
                    continue  # posé contre le mur sous une fenêtre : le mobilier bas peut le masquer sans le gêner
                overlap = x1 > f["x0"] - 1 and x0 < f["x1"] + 1 and z1 > f["z0"] - 1 and z0 < f["z1"] + 1
                self.assertFalse(overlap, f"{name} ({x}, {z}) près de {f['name']}")
            for door in g.DOORS:
                if door["level"] != lvl:
                    continue
                if door["orient"] == "v":
                    hit = x0 - 1 < door["line"] < x1 + 1 and z1 > door["c"] - door["w"] / 2 - 1 and z0 < door["c"] + door["w"] / 2 + 1
                else:
                    hit = z0 - 1 < door["line"] < z1 + 1 and x1 > door["c"] - door["w"] / 2 - 1 and x0 < door["c"] + door["w"] / 2 + 1
                self.assertFalse(hit, f"{name} ({x}, {z}) dans une zone de porte")


if __name__ == "__main__":
    unittest.main()
