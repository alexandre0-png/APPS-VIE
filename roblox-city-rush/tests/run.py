#!/usr/bin/env python3
"""Exécute les tests Lua (logique serveur) dans un faux environnement Roblox via lupa.
Usage : pip install lupa && python3 tests/run.py"""
import pathlib, sys
from lupa import LuaRuntime

root = pathlib.Path(__file__).resolve().parent.parent
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(f'ROOT_DIR = "{root}"')
g = lua.globals()
import os
if os.environ.get('ONLY'): g.ONLY = os.environ['ONLY']
g.PY_LIST = lambda path: lua.table_from(sorted(p.name for p in pathlib.Path(path).iterdir()))
g.PY_ISDIR = lambda path: pathlib.Path(path).is_dir()
failed = lua.execute((root / "tests" / "test_all.lua").read_text())
sys.exit(1 if failed else 0)
