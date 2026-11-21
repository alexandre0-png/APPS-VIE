#!/usr/bin/env python3
"""Rien ne reste affiché sans raison : indice qui s'efface, panneaux fermés au début d'une manche, règles détruites."""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from client_env import errors  # noqa: E402
import test_client as client  # noqa: E402

COUNT = r"""
function visibleTexts()
  local hud = findGui("TombeHUD")
  local out = {}
  for _, d in ipairs(hud:GetDescendants()) do
    if d:IsA("TextLabel") and d.Visible and d.Text ~= "" and d.TextTransparency < 1 then
      table.insert(out, d.Text)
    end
  end
  return #out
end
function hintVisible()
  local hud = findGui("TombeHUD")
  for _, d in ipairs(hud:GetDescendants()) do
    if d:IsA("TextLabel") and d.Text:sub(1, 8) == "Indice :" then return d.Visible end
  end
  return false
end
"""


class TestLingering(unittest.TestCase):
    def boot(self):
        lua = client.boot()
        lua.execute(COUNT)
        return lua

    def test_hint_fades_by_itself(self):
        lua = self.boot()
        client.fire(lua, "Hint", {"text": "Cherche le miroir."})
        lua.execute("advance(1)")
        self.assertTrue(lua.eval("hintVisible()"))
        lua.execute("advance(16)")
        self.assertFalse(
            lua.eval("hintVisible()"), "l'indice reste affiché indéfiniment"
        )
        self.assertEqual(errors(lua), [])

    def test_new_step_clears_old_hint(self):
        lua = self.boot()
        client.fire(lua, "Hint", {"text": "Ancien indice."})
        lua.execute("advance(1)")
        client.fire(lua, "Objective", {"text": "Étape suivante"})
        lua.execute("advance(1)")
        self.assertFalse(
            lua.eval("hintVisible()"), "l'indice de l'étape précédente reste"
        )

    def test_new_round_resets_panels(self):
        lua = self.boot()
        client.fire(lua, "Hint", {"text": "Indice"})
        client.fire(lua, "Message", {"text": "Réplique"})
        client.fire(lua, "Keypad", {})
        lua.execute("advance(1)")
        client.fire(lua, "Effect", {"kind": "Intro", "duration": 1})
        lua.execute("advance(1)")
        self.assertFalse(lua.eval("hintVisible()"))
        self.assertIsNone(
            lua.eval(
                '(function() local h = findGui("TombeHUD") for _, d in ipairs(h:GetDescendants()) do if d.Name == "SousTitre" and d.Visible then return d end end end)()'
            )
        )
        self.assertEqual(errors(lua), [])

    def test_rules_label_is_destroyed(self):
        lua = self.boot()
        client.fire(lua, "Effect", {"kind": "Intro", "duration": 1})
        lua.execute("advance(15)")
        before = lua.eval("visibleTexts()")
        lua.execute("advance(20)")
        after = lua.eval("visibleTexts()")
        self.assertLessEqual(after, before)
        hud = lua.eval(
            '(function() local n = 0 for _, d in ipairs(findGui("TombeHUD"):GetDescendants()) do if d:IsA("TextLabel") and d.Text:find("trois vies") then n = n + 1 end end return n end)()'
        )
        self.assertEqual(hud, 0, "les règles restent dans l'interface")


if __name__ == "__main__":
    unittest.main()
