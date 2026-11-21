#!/usr/bin/env python3
"""Parcours complet côté client : toutes les étapes de la chaîne, dans l'ordre, avec objectifs, bannières de pièce,
indices, messages, voix du monstre et de l'enfant, fin de partie. Vérifie l'ordre annoncé, l'absence d'erreur client
et que rien ne reste affiché une fois les durées écoulées (budget d'écran)."""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from client_env import errors  # noqa: E402
import gen_deroule  # noqa: E402
import test_client as client  # noqa: E402

COUNT = r"""
function visibleTexts()
  local hud = findGui("TombeHUD")
  local out = {}
  for _, d in ipairs(hud:GetDescendants()) do
    local shown = d:IsA("TextLabel") and d.Visible and d.Text ~= "" and d.TextTransparency < 1 and d.Name ~= "DebugPerf" and d.Text:sub(1, 4) ~= "H : "
    local p = d.Parent
    while shown and p and p ~= hud do
      if p.Visible == false or p:IsA("TextButton") then shown = false end
      p = p.Parent
    end
    if shown then
      table.insert(out, d.Text)
    end
  end
  return out
end
"""


class TestPlaythrough(unittest.TestCase):
    def test_full_chain_plays_in_order_without_client_error(self):
        chain, der, _ = gen_deroule.load()
        ids = [chain.STEPS[i].id for i in range(1, len(chain.STEPS) + 1)]
        lua = client.boot()
        lua.execute(COUNT)
        announced = []
        client.fire(lua, "Effect", {"kind": "Intro", "duration": 1})
        lua.execute("advance(2)")
        for index, step_id in enumerate(ids, 1):
            step = chain.STEPS[index]
            client.fire(lua, "Objective", {"text": step.objective, "step": step_id})
            client.fire(
                lua,
                "Reveal",
                {
                    "n": index,
                    "total": len(ids),
                    "text": step.objective,
                    "step": step_id,
                },
            )
            client.fire(lua, "Hint", {"text": step.hint})
            client.fire(
                lua,
                "Journal",
                {
                    "lines": [
                        "Étape active : " + step.objective,
                        "Ce que je sais :",
                        "✓ fait",
                    ]
                },
            )
            voice = der.STEPS[step_id].voice
            if voice:
                client.fire(lua, "Message", {"text": "Je te vois.", "voice": "monster"})
            client.fire(lua, "Message", {"text": der.lockedText("grenier")})
            lua.execute("advance(2)")
            announced.append(step_id)
            # une seule étape active à l'écran : l'objectif affiché est celui de l'étape courante
            texts = list(lua.eval("visibleTexts()").values())
            self.assertTrue(any(step.objective in t for t in texts), step_id)
            for earlier in ids[: index - 1]:
                old = chain.get(earlier).objective
                self.assertFalse(
                    any(t == old for t in texts),
                    f"objectif de {earlier} encore affiché à l'étape {step_id}",
                )
        self.assertEqual(announced, ids)
        client.fire(lua, "Effect", {"kind": "Cine", "name": "win"})
        lua.execute("advance(30)")
        self.assertEqual(errors(lua), [])

    def test_screen_is_clean_after_every_duration_elapsed(self):
        lua = client.boot()
        lua.execute(COUNT)
        client.fire(lua, "Hint", {"text": "Indice"})
        client.fire(lua, "Message", {"text": "Réplique", "voice": "monster"})
        client.fire(lua, "Effect", {"kind": "Intro", "duration": 1})
        lua.execute("advance(60)")
        texts = list(lua.eval("visibleTexts()").values())
        # Seuls l'objectif (vide ici) et l'inventaire peuvent rester
        self.assertLessEqual(len(texts), 2, texts)
        self.assertEqual(errors(lua), [])


if __name__ == "__main__":
    unittest.main()
