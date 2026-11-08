#!/usr/bin/env python3
"""Contrôles statiques du code Luau (pas d'exécution Roblox).

Vérifie :
  - que chaque require pointe sur un module existant ;
  - que chaque remote utilisé (Remotes.get / fire / fireAll) est déclaré dans Remotes.lua ;
  - que chaque clé audio (Audio.play) existe dans AudioManifest.lua ;
  - que chaque tag lu (CollectionService:GetTagged) est posé quelque part (code ou carte) ;
  - que chaque clé de Config utilisée existe dans Config.lua ;
  - que la structure des blocs (function/if/do/end) est équilibrée.

Lancer depuis tombe-grenier/ :
    python3 -m unittest discover -s tools/lua -p "test_*.py" -v
"""
import glob
import os
import re
import unittest

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "src")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def strip_comments_and_strings(src):
    t = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
    t = re.sub(r"--[^\n]*", "", t)
    t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
    t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
    return t


def lua_files():
    return sorted(glob.glob(os.path.join(SRC, "**", "*.lua"), recursive=True))


class TestRequires(unittest.TestCase):
    def test_every_require_resolves(self):
        missing = []
        for path in lua_files():
            folder = os.path.dirname(path)
            for m in re.finditer(r"require\((script(?:\.Parent)?\.(\w+)|Shared\.(\w+))\)", read(path)):
                if m.group(3):  # Shared.X -> src/shared/X.lua
                    target = os.path.join(SRC, "shared", m.group(3) + ".lua")
                elif m.group(1).startswith("script.Parent."):
                    target = os.path.join(os.path.dirname(folder), m.group(2) + ".lua")
                    if not os.path.exists(target):
                        target = os.path.join(folder, m.group(2) + ".lua")
                else:
                    target = os.path.join(folder, m.group(2) + ".lua")
                if not os.path.exists(target):
                    missing.append(f"{os.path.relpath(path, ROOT)} -> {m.group(1)}")
        self.assertEqual(missing, [], "modules introuvables")


class TestRemotes(unittest.TestCase):
    def test_every_remote_used_is_declared(self):
        declared = set(re.findall(r'"(\w+)",\s+--', read(os.path.join(SRC, "shared", "Remotes.lua"))))
        used = set()
        for path in lua_files():
            s = read(path)
            used |= set(re.findall(r'Remotes\.(?:get|fire|fireAll)\("(\w+)"', s))
        self.assertEqual(sorted(used - declared), [], "remotes non déclarés")

    def test_every_declared_remote_is_used(self):
        declared = set(re.findall(r'"(\w+)",\s+--', read(os.path.join(SRC, "shared", "Remotes.lua"))))
        used = set()
        for path in lua_files():
            used |= set(re.findall(r'Remotes\.(?:get|fire|fireAll)\("(\w+)"', read(path)))
        self.assertEqual(sorted(declared - used), [], "remotes déclarés mais inutilisés")


class TestAudio(unittest.TestCase):
    def test_every_audio_key_exists(self):
        manifest = set(re.findall(r"^\t(\w+)\s*=\s*\{", read(os.path.join(SRC, "shared", "AudioManifest.lua")), re.M))
        used = set()
        for path in lua_files():
            used |= set(re.findall(r'Audio\.play\("(\w+)"', read(path)))
        self.assertEqual(sorted(used - manifest), [], "clés audio inconnues")

    def test_every_audio_key_has_a_sound_id(self):
        text = read(os.path.join(SRC, "shared", "AudioManifest.lua"))
        for key, body in re.findall(r"^\t(\w+)\s*=\s*\{([^}]*)\}", text, re.M):
            self.assertIn("rbxassetid://", body, f"{key} : pas d'ID de son")


class TestTags(unittest.TestCase):
    def test_every_read_tag_is_produced(self):
        produced = set()
        for path in lua_files():
            produced |= set(re.findall(r'"([A-Za-z]\w+)"', read(path)))
        # Les tags posés par la carte générée
        mapdata = read(os.path.join(SRC, "shared", "MapData.lua"))
        produced |= set(re.findall(r'tag = "(\w+)"', mapdata))
        read_tags = set()
        for path in lua_files():
            read_tags |= set(re.findall(r'GetTagged\("(\w+)"\)', read(path)))
        # Tags lus qui ne sont jamais écrits nulle part
        self.assertEqual(sorted(t for t in read_tags if t not in produced), [], "tags lus jamais posés")

    def test_every_tag_written_by_code_is_read(self):
        written = set()
        for path in lua_files():
            written |= set(re.findall(r'AddTag\([^,]+,\s*"(\w+)"\)', read(path)))
        read_tags = set()
        for path in lua_files():
            read_tags |= set(re.findall(r'GetTagged\("(\w+)"\)', read(path)))
        self.assertEqual(sorted(t for t in written if t not in read_tags), [], "tags posés mais jamais lus")


class TestConfig(unittest.TestCase):
    def config_keys(self):
        keys = {}
        cur = None
        for line in read(os.path.join(SRC, "shared", "Config.lua")).splitlines():
            m = re.match(r"Config\.(\w+)\s*=\s*\{", line)
            if m:
                cur = m.group(1)
                keys[cur] = set()
                continue
            m = re.match(r"\s+(\w+)\s*=", line)
            if m and cur:
                keys[cur].add(m.group(1))
            if line.startswith("}"):
                cur = None
        return keys

    def test_direct_config_references_exist(self):
        keys = self.config_keys()
        missing = []
        for path in lua_files():
            for group, key in re.findall(r"Config\.(\w+)\.(\w+)", read(path)):
                if group not in keys or key not in keys[group]:
                    missing.append(f"{os.path.basename(path)}: Config.{group}.{key}")
        self.assertEqual(missing, [])

    def test_aliased_config_references_exist(self):
        # local CFG = Config.Monster ... CFG.X
        keys = self.config_keys()
        missing = []
        for path in lua_files():
            s = read(path)
            for alias, group in re.findall(r"local (\w+) = Config\.(\w+)", s):
                for key in re.findall(rf"\b{alias}\.(\w+)", s):
                    if group not in keys or key not in keys[group]:
                        missing.append(f"{os.path.basename(path)}: {alias}.{key} ({group})")
        self.assertEqual(missing, [])


class TestStructure(unittest.TestCase):
    def test_blocks_are_balanced(self):
        bad = []
        for path in lua_files():
            t = strip_comments_and_strings(read(path))
            opens = len(re.findall(r"\bfunction\b|\bif\b|\bdo\b", t))
            ends = len(re.findall(r"\bend\b", t))
            if opens != ends:
                bad.append(f"{os.path.basename(path)} ({opens} ouvertures, {ends} end)")
        self.assertEqual(bad, [])

    def test_brackets_are_balanced(self):
        bad = []
        for path in lua_files():
            s = read(path)
            if s.count("{") != s.count("}") or s.count("(") != s.count(")"):
                bad.append(os.path.basename(path))
        self.assertEqual(bad, [])


class TestMapDataFields(unittest.TestCase):
    def test_every_data_field_read_by_code_exists(self):
        mapdata = read(os.path.join(SRC, "shared", "MapData.lua"))
        missing = set()
        for path in lua_files():
            for field in re.findall(r"\bData\.(\w+)", read(path)):
                if not re.search(rf"\b{field} = ", mapdata):
                    missing.add(f"{os.path.basename(path)}: Data.{field}")
        self.assertEqual(sorted(missing), [], "champs de MapData lus mais absents")

    def test_every_slot_read_by_code_exists(self):
        mapdata = read(os.path.join(SRC, "shared", "MapData.lua"))
        missing = set()
        for path in lua_files():
            for field in re.findall(r"slots\.(\w+)", read(path)):
                if not re.search(rf"\b{field} = ", mapdata):
                    missing.add(f"{os.path.basename(path)}: slots.{field}")
        self.assertEqual(sorted(missing), [], "emplacements lus mais absents")


class TestSyntax(unittest.TestCase):
    """Analyseur Lua 5.4 réel (lupa) : nécessite pip install lupa."""

    def test_every_file_parses(self):
        try:
            import check_syntax
        except ImportError:
            self.skipTest("lupa non installé")
        import lupa
        rt = lupa.LuaRuntime(unpack_returned_tuples=True)
        check_syntax._compile_check = rt.eval(
            "function(src, name) local fn, err = load(src, name); return fn ~= nil, err or '' end")
        errors = []
        for path in lua_files():
            err = check_syntax.check(path, rt)
            if err:
                errors.append(f"{os.path.basename(path)}: {err}")
        self.assertEqual(errors, [], "erreurs de syntaxe")


if __name__ == "__main__":
    unittest.main()
