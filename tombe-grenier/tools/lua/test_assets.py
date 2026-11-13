#!/usr/bin/env python3
"""Tests du chargement de modèles (src/shared/AssetLoad.lua) avec un chargeur factice.

Cas couverts : modèle valide, conteneur nul, erreur de chargement, conteneur sans Model, modèle vide,
scripts et événements retirés, liste mixte. Seuls les modèles valides sont rangés : la carte reste jouable.
Chaque cas est un petit programme Lua exécuté avec lupa ; il lève une erreur si le comportement diffère.
"""
import os
import unittest

from lupa.lua54 import LuaRuntime

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ASSET = os.path.join(ROOT, "src", "shared", "AssetLoad.lua")

PRELUDE = r"""
A = dofile(ASSET_PATH)
function obj(class, name, kids)
  local o = { ClassName = class, Name = name, _kids = kids or {}, _destroyed = false }
  function o:GetDescendants()
    local out = {}
    local function walk(x)
      for _, k in ipairs(x._kids) do
        table.insert(out, k)
        walk(k)
      end
    end
    walk(self)
    return out
  end
  function o:FindFirstChildWhichIsA(cls)
    for _, d in ipairs(self:GetDescendants()) do
      if d.ClassName == cls then return d end
    end
    return nil
  end
  function o:Destroy() self._destroyed = true end
  return o
end
function check(cond, msg) if not cond then error(msg, 2) end end
"""


def run(case):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals()["ASSET_PATH"] = ASSET
    lua.execute(PRELUDE)
    lua.execute(case)


CASES = {
    "valid": r"""
        folder = obj("Folder", "Decor")
        local script = obj("Script", "s")
        local remote = obj("RemoteEvent", "r")
        local part = obj("Part", "p")
        model = obj("Model", "m", { part, script, remote })
        local container = obj("Folder", "c", { model })
        local report = A.install({ { name = "chaise", id = 1 } }, function() return container end, folder)
        check(report.ok[1] == "chaise", "modèle valide non installé")
        check(model.Parent == folder, "modèle non rangé")
        check(model.Name == "chaise", "nom non appliqué")
        check(script._destroyed, "script non retiré")
        check(remote._destroyed, "RemoteEvent non retiré")
        check(not part._destroyed, "pièce ordinaire retirée à tort")
    """,
    "nil": r"""
        local folder = obj("Folder", "Decor")
        local report = A.install({ { name = "lampe", id = 2 } }, function() return nil end, folder)
        check(#report.ok == 0, "rien ne doit être installé")
        check(report.failed[1] == "lampe", "échec non noté")
    """,
    "error": r"""
        local folder = obj("Folder", "Decor")
        local report = A.install({ { name = "table", id = 3 } }, function() error("réseau coupé") end, folder)
        check(#report.ok == 0, "rien ne doit être installé")
        check(report.failed[1] == "table", "erreur non notée")
    """,
    "corrupt": r"""
        local folder = obj("Folder", "Decor")
        local bad = obj("Folder", "corrompu", { obj("Part", "p") })
        local report = A.install({ { name = "plante", id = 4 } }, function() return bad end, folder)
        check(#report.ok == 0, "rien ne doit être installé")
        check(report.failed[1] == "plante", "corruption non notée")
    """,
    "empty": r"""
        local folder = obj("Folder", "Decor")
        local bad = obj("Folder", "vide", { obj("Model", "m") })
        local report = A.install({ { name = "fauteuil", id = 5 } }, function() return bad end, folder)
        check(#report.ok == 0, "rien ne doit être installé")
        check(report.failed[1] == "fauteuil", "modèle vide non noté")
    """,
    "mixed": r"""
        local folder = obj("Folder", "Decor")
        local good = obj("Folder", "ok", { obj("Model", "m", { obj("Part", "p") }) })
        local model_ok = good._kids[1]
        local bad = obj("Folder", "corrompu")
        local loaders = { [1] = good, [2] = bad, [3] = nil }
        -- Le modèle valide est dans good ; le conteneur corrompu n'a pas de Model
        local report = A.install(
          { { name = "a", id = 1 }, { name = "b", id = 2 }, { name = "c", id = 3 } },
          function(id) return loaders[id] end,
          folder)
        check(model_ok.Parent == folder, "le modèle valide doit être rangé")
        check(model_ok.Parent == folder and bad.Parent == nil, "le conteneur corrompu ne doit pas être rangé")
        check(report.ok[1] == "a" and #report.ok == 1, "mauvais modèle installé")
        check(#report.failed == 2, "deux échecs attendus")
    """,
}


CASES["candidates"] = r"""
        local folder = obj("Folder", "ServerStorage")
        local tried = {}
        local good = obj("Folder", "ok", { obj("Model", "m", { obj("Part", "p") }) })
        local loaders = { [10] = nil, [11] = obj("Folder", "corrompu"), [12] = good }
        local name = A.installFirst({ 10, 11, 12, 13 }, "Monster", function(id)
          tried[#tried + 1] = id
          return loaders[id]
        end, folder)
        check(name == "Monster", "le premier candidat valide doit être installé")
        check(good._kids[1].Parent == folder and good._kids[1].Name == "Monster", "modèle du monstre mal rangé")
        check(#tried == 3 and tried[3] == 12, "les candidats suivants ne doivent pas être essayés")
    """
CASES["candidates_none"] = r"""
        local folder = obj("Folder", "ServerStorage")
        local name = A.installFirst({ 20, 21 }, "Monster", function() return nil end, folder)
        check(name == nil, "aucun candidat valide : pas de modèle")
    """


class TestAssetLoad(unittest.TestCase):
    def test_first_valid_monster_candidate_is_used(self):
        run(CASES["candidates"])

    def test_no_valid_monster_candidate_gives_nothing(self):
        run(CASES["candidates_none"])

    def test_valid_model_installed_and_unsafe_objects_removed(self):
        run(CASES["valid"])

    def test_nil_container_refused(self):
        run(CASES["nil"])

    def test_load_error_does_not_crash(self):
        run(CASES["error"])

    def test_corrupt_container_refused(self):
        run(CASES["corrupt"])

    def test_empty_model_refused(self):
        run(CASES["empty"])

    def test_mixed_list_keeps_only_valid_models(self):
        run(CASES["mixed"])


if __name__ == "__main__":
    unittest.main()
