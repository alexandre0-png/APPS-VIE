#!/usr/bin/env python3
"""Exécute les énigmes de Quests.lua dans un faux environnement Roblox (Lua 5.4 via lupa).

Ce n'est pas Roblox : les services, les invites et les événements sont simulés. Le test
attrape les erreurs d'exécution et vérifie que chaque énigme se résout bien.
Dépendance : pip install lupa.

Lancer depuis tombe-grenier/ :  python3 -m unittest discover -s tools/lua/sim -p "test_*.py" -v
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))  # tools/lua : check_syntax.py

try:
    from lupa import LuaRuntime
    from check_syntax import to_lua54
except ImportError:  # pragma: no cover
    LuaRuntime = None

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))


def run_scenario():
    lua = LuaRuntime(unpack_returned_tuples=True)

    def readsrc(p):
        with open(os.path.join(ROOT, p), encoding="utf-8") as f:
            return to_lua54(f.read())

    lua.globals()["__readsrc"] = readsrc
    harness = lua.execute(open(os.path.join(HERE, "harness.lua"), encoding="utf-8").read())
    lua.globals()["H"] = harness
    lua.execute(open(os.path.join(HERE, "scenario.lua"), encoding="utf-8").read())


@unittest.skipIf(LuaRuntime is None, "lupa non installé")
class TestPuzzlesRuntime(unittest.TestCase):
    def test_puzzles_resolve_without_runtime_error(self):
        run_scenario()


if __name__ == "__main__":
    unittest.main()
