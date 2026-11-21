#!/usr/bin/env python3
"""Répliques et sous-titres : texte libre sans cadre, sans fond, sans contour de boîte, centré en bas, contour du texte,
fondu à l'apparition et à la disparition ; les répliques du monstre portent voice = "monster"."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from client_env import errors, make  # noqa: E402
import test_client as client  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

FIND = r"""
function findSubtitle()
  local hud = findGui("TombeHUD")
  for _, d in ipairs(hud:GetDescendants()) do if d.Name == "SousTitre" then return d end end
end
"""


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


class TestSpeech(unittest.TestCase):
    def boot(self):
        lua = client.boot()
        lua.execute(FIND)
        return lua

    def test_monster_line_is_free_text_without_box(self):
        lua = self.boot()
        client.fire(lua, "Message", {"text": "Je te vois.", "voice": "monster"})
        lua.execute("advance(1)")
        label = lua.eval("findSubtitle()")
        self.assertEqual(label.Text, "Je te vois.")
        self.assertEqual(label.BackgroundTransparency, 1, "aucun fond")
        self.assertEqual(label.BorderSizePixel, 0, "aucune bordure")
        self.assertLess(label.TextStrokeTransparency, 1, "contour du texte visible")
        self.assertEqual(label.TextTransparency, 0, "visible après le fondu d'entrée")
        for child in ("UICorner", "UIStroke", "UIGradient", "UIPadding"):
            self.assertIsNone(lua.eval('findSubtitle():FindFirstChildOfClass("%s")' % child), f"{child} fait un encadré")
        self.assertEqual(errors(lua), [])

    def test_every_kind_of_message_uses_the_same_free_text(self):
        lua = self.boot()
        for payload in ({"text": "Indice"}, {"text": "Chuchote", "voice": "whisper"}, {"text": "Alerte", "voice": "monster"}):
            client.fire(lua, "Message", payload)
            lua.execute("advance(0.6)")
            label = lua.eval("findSubtitle()")
            self.assertEqual(label.BackgroundTransparency, 1)
            self.assertEqual(label.Text, payload["text"])

    def test_fades_in_then_out_and_hides(self):
        lua = self.boot()
        client.fire(lua, "Message", {"text": "Une réplique assez courte."})
        label = lua.eval("findSubtitle()")
        lua.execute("advance(1)")
        self.assertEqual(label.TextTransparency, 0)
        lua.execute("advance(12)")
        self.assertEqual(label.TextTransparency, 1)
        self.assertFalse(label.Visible)

    def test_a_new_line_replaces_the_old_one_without_flicker(self):
        lua = self.boot()
        client.fire(lua, "Message", {"text": "Première"})
        lua.execute("advance(3.5)")
        client.fire(lua, "Message", {"text": "Seconde"})
        lua.execute("advance(2.5)")  # l'ancienne minuterie (4 s après la première) expire pendant ce temps
        label = lua.eval("findSubtitle()")
        self.assertEqual(label.Text, "Seconde")
        self.assertTrue(label.Visible, "l'ancienne minuterie n'efface pas la nouvelle réplique")

    def test_placed_bottom_center_and_readable(self):
        label_src = read("src", "client", "init.client.lua")
        self.assertIn("subtitleLabel = label({", label_src)
        self.assertIn("position = UDim2.new(0.5, 0, 1, -110)", label_src)
        self.assertIn("Enum.TextXAlignment.Center", label_src[label_src.index("local subtitleLabel") : label_src.index("local subtitleLabel") + 400])

    def test_malformed_messages_do_nothing(self):
        lua = self.boot()
        for bad in ("'x'", "12", "{}", "{ text = 5 }", "nil"):
            lua.execute('serverFire("Message", %s)' % bad)
        lua.execute("advance(2)")
        self.assertEqual(errors(lua), [])

    def test_server_marks_monster_voice(self):
        self.assertIn('voice = "monster"', read("src", "server", "MonsterAI.lua"))
        self.assertIn('voice = "monster"', read("src", "server", "Ambience.lua"))
        self.assertIn("clock() - lastLine < 25", read("src", "server", "MonsterAI.lua"))


if __name__ == "__main__":
    unittest.main()
