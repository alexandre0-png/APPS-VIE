#!/usr/bin/env python3
"""Invites d'interaction : aucune invite active hors de la partie (hub, attente, fin), portée de 8 studs au plus, vue
directe exigée, invites des étapes pas encore accessibles masquées ; le client les masque pendant les cinématiques."""
import os
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_robust as robust  # noqa: E402
import test_scenarios as sc  # noqa: E402
import test_spawn_roles as roles  # noqa: E402
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

SCAN = r"""
function scanPrompts()
  local out = { enabled = {}, all = {}, far = {}, noLos = {} }
  for _, d in ipairs(workspace:GetDescendants()) do
    if d.ClassName == "ProximityPrompt" and d.Name ~= "HubPrompt" and not (d.Parent and d.Parent.Parent and d.Parent.Parent.Name == "Hub") then
      table.insert(out.all, d.Name .. "@" .. tostring(d.Parent and d.Parent.Name))
      if d.Enabled ~= false then table.insert(out.enabled, d.Name .. "@" .. tostring(d.Parent and d.Parent.Name)) end
      if (d.MaxActivationDistance or 99) > 8 then table.insert(out.far, d.Name) end
      if d.RequiresLineOfSight ~= true then table.insert(out.noLos, d.Name) end
    end
  end
  return out
end
"""


def listing(t):
    return [str(t[i]) for i in range(1, len(t) + 1)]


class TestPromptRules(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.R = self.lua.execute(to_lua54(open(os.path.join(ROOT, "src", "shared", "PromptRules.lua"), encoding="utf-8").read()))

    def test_distance_is_capped_at_eight(self):
        d = self.R.distance
        self.assertEqual(d(6, 8), 6)
        self.assertEqual(d(14, 8), 8)
        self.assertEqual(d(None, 8), 8)
        self.assertEqual(d(0, 8), 8)
        self.assertEqual(d(-3, 8), 8)
        self.assertEqual(d(float("nan"), 8), 8)

    def test_enabled_only_in_round_and_for_reachable_steps(self):
        e = self.R.shouldBeEnabled
        reach = self.lua.eval("function(step) return step == 'note' end")
        self.assertFalse(e(False, True, "note", reach))
        self.assertFalse(e(True, False, "note", reach))
        self.assertTrue(e(True, True, "note", reach))
        self.assertFalse(e(True, True, "coffret", reach))
        self.assertTrue(e(True, True, None, reach), "objet libre")


class TestPromptsInTheRealGame(unittest.TestCase):
    def game(self, place=roles.GAME):
        lua = robust.make_capturing(place)
        lua.execute(sc.HELPERS)
        lua.execute(SCAN)
        assert lua.eval("runServer()").ok
        return lua

    def test_no_active_prompt_before_the_round(self):
        lua = self.game()
        lua.execute("SWALLOW = true; advance(2)")  # carte construite, aucun joueur : pas de partie
        scan = lua.eval("scanPrompts()")
        self.assertGreater(len(listing(scan.all)), 0, "les invites existent")
        self.assertEqual(listing(scan.enabled), [], "mais aucune n'est active hors partie")

    def test_no_active_prompt_in_the_hub_roles(self):
        for place in (roles.HUB, 0):
            lua = self.game(place)
            lua.execute("SWALLOW = true; advance(20); A = newPlayer('alice'); join(A); advance(300)")
            self.assertEqual(listing(lua.eval("scanPrompts()").enabled), [], place)

    def test_during_the_round_only_reachable_steps_are_active_and_close_and_in_sight(self):
        lua = self.game()
        lua.execute("SWALLOW = true; advance(20); A = newPlayer('alice'); join(A); advance(90)")
        scan = lua.eval("scanPrompts()")
        enabled = listing(scan.enabled)
        self.assertGreater(len(enabled), 5, "la partie a ses invites actives")
        self.assertEqual(listing(scan.far), [], "aucune invite à plus de 8 studs")
        self.assertEqual(listing(scan.noLos), [], "vue directe exigée partout")
        names = " ".join(enabled)
        for future in ("QuestPromptReflet", "QuestPromptHorloge", "QuestPromptStatue"):
            self.assertNotIn(future, names, f"{future} : étape pas encore accessible")
        self.assertIn("QuestPrompt@", names)  # le papier du code (première étape) est actif

    def test_every_prompt_is_inactive_again_after_the_end(self):
        lua = self.game()
        lua.execute("SWALLOW = true; advance(20); A = newPlayer('alice'); join(A); advance(80)")
        for _ in range(4):
            lua.execute("die(A); advance(30)")
        self.assertTrue(any("[Round] fin" in p for p in sc.prints(lua)))
        self.assertEqual(listing(lua.eval("scanPrompts()").enabled), [])


class TestPromptRegistry(unittest.TestCase):
    def test_gate_refresh_round_and_override(self):
        lua = robust.make_capturing(roles.GAME)
        lua.execute(sc.HELPERS)
        assert lua.eval("runServer()").ok
        lua.execute(
            """
            P = require({ __path = "src/server/Prompts.lua" })
            function fake(d) return { Enabled = true, Parent = true, MaxActivationDistance = d, RequiresLineOfSight = false } end
            F = fake(20); G = fake(5)
            BASE = P.count()
            OPEN = false
            P.setGate(function(step) return OPEN end)
            P.register(F, { step = "coffret" })
            P.register(G)
            P.setRound(true)
            """
        )
        self.assertEqual(lua.eval("F.MaxActivationDistance"), 8)
        self.assertEqual(lua.eval("G.MaxActivationDistance"), 5)
        self.assertTrue(lua.eval("F.RequiresLineOfSight"))
        self.assertFalse(lua.eval("F.Enabled"), "étape pas encore accessible")
        self.assertTrue(lua.eval("G.Enabled"))
        lua.execute("OPEN = true; P.refresh()")
        self.assertTrue(lua.eval("F.Enabled"))
        lua.execute("P.set(G, false)")
        self.assertFalse(lua.eval("G.Enabled"))
        lua.execute("P.setRound(false)")
        self.assertFalse(lua.eval("F.Enabled"))
        lua.execute("P.set(G, true)")
        self.assertFalse(lua.eval("G.Enabled"), "hors partie rien ne s'active, même sur demande")
        lua.execute("F.Parent = nil; P.setRound(true)")
        self.assertEqual(int(lua.eval("P.count() - BASE")), 1, "les invites détruites sont oubliées")


class TestClientHidesPromptsDuringCinematics(unittest.TestCase):
    def test_prompt_service_follows_cinematics_and_black_screen(self):
        from client_env import errors, make

        lua = make()
        lua.execute("runClient()")
        lua.execute("advance(3)")
        lua.execute('SERVICE = game:GetService("ProximityPromptService")')
        lua.execute("advance(1)")
        self.assertEqual(errors(lua), [])
        client = open(os.path.join(ROOT, "src", "client", "init.client.lua"), encoding="utf-8").read()
        self.assertIn("ProximityPromptService", client)
        self.assertIn("Cinematic.isPlaying() or blackFrame.BackgroundTransparency < 0.5", client)


if __name__ == "__main__":
    unittest.main()
