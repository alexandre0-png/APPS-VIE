#!/usr/bin/env python3
"""Hub et téléportations : files d'attente par borne (solo, duo, plus de deux joueurs), échecs de téléportation avec
essais répétés, repli public, retour au hub depuis la partie sans joueur coincé. Le vrai script du hub tourne dans le faux Roblox."""
import os
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_spawn_map as base  # noqa: E402
import test_spawn_roles as roles  # noqa: E402
import test_robust as robust  # noqa: E402
from check_syntax import to_lua54  # noqa: E402

ROOT = base.ROOT


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


def pure(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    return lua, lua.execute(to_lua54(read(*path.split("/"))))


class TestNextGroup(unittest.TestCase):
    def setUp(self):
        self.lua, self.R = pure("src/shared/HubRules.lua")
        self.cfg = self.lua.table_from({"DuoWait": 60, "HubWait": 30, "MaxPlayers": 2, "AutoStart": True})

    def players(self, *rows):
        return self.lua.table_from([
            self.lua.table_from({"id": i, "joinedAt": j, "queue": q, "queuedAt": a}) for i, j, q, a in rows
        ])

    def ids(self, group):
        return None if group is None else [group[i] for i in range(1, len(group) + 1)]

    def test_without_autostart_nobody_leaves_without_a_pad(self):
        cfg = self.lua.table_from({"DuoWait": 60, "HubWait": 30, "MaxPlayers": 2})  # AutoStart absent = faux
        for now in (0, 30, 1000, 100000):
            self.assertIsNone(self.R.nextGroup(self.players(*[(i, 0, None, 0) for i in range(1, 4)]), now, cfg))
        # une borne reste le seul déclencheur
        self.assertEqual(self.ids(self.R.nextGroup(self.players((1, 0, "solo", 1)), 2, cfg)), [1])

    def test_solo_press_leaves_alone_and_does_not_drag_the_others(self):
        g = self.R.nextGroup(self.players((1, 0, None, 0), (2, 0, "duo", 5), (3, 0, "solo", 9)), 10, self.cfg)
        self.assertEqual(self.ids(g), [3])

    def test_two_in_duo_queue_leave_together_first_come_first_served(self):
        g = self.R.nextGroup(self.players((1, 0, "duo", 5), (2, 0, "duo", 3), (3, 0, "duo", 4)), 6, self.cfg)
        self.assertEqual(self.ids(g), [2, 3])

    def test_never_more_than_two(self):
        for now in (0, 100, 1000):
            g = self.R.nextGroup(self.players(*[(i, 0, "duo", i) for i in range(1, 6)]), now, self.cfg)
            self.assertLessEqual(len(self.ids(g)), 2)
        g = self.R.nextGroup(self.players(*[(i, 0, None, 0) for i in range(1, 6)]), 100, self.cfg)
        self.assertLessEqual(len(self.ids(g)), 2)

    def test_lone_duo_waits_then_goes_solo(self):
        p = self.players((1, 0, "duo", 10))
        self.assertIsNone(self.R.nextGroup(p, 69, self.cfg))
        self.assertEqual(self.ids(self.R.nextGroup(p, 70, self.cfg)), [1])

    def test_free_players_wait_hubwait_then_go_in_arrival_order(self):
        p = self.players((2, 5, None, 0), (1, 3, None, 0))
        self.assertIsNone(self.R.nextGroup(p, 32, self.cfg))
        self.assertEqual(self.ids(self.R.nextGroup(p, 33, self.cfg)), [1, 2])

    def test_empty_and_waiting_cases(self):
        self.assertIsNone(self.R.nextGroup(self.players(), 100, self.cfg))
        self.assertIsNone(self.R.nextGroup(self.players((1, 0, None, 0)), 5, self.cfg))

    def test_every_player_ends_up_in_a_group(self):
        """Simulation : à chaque tour le groupe part ; tout le monde finit par partir, sans doublon."""
        left = {i: ("duo" if i % 2 else None) for i in range(1, 8)}
        sent = []
        now = 0
        while left and now < 1000:
            rows = [(i, 0, q, 1) for i, q in left.items()]
            g = self.R.nextGroup(self.players(*rows), now, self.cfg)
            if g is None:
                now += 5
                continue
            for i in self.ids(g):
                sent.append(i)
                del left[i]
        self.assertEqual(sorted(sent), list(range(1, 8)))


class TestRetry(unittest.TestCase):
    def setUp(self):
        self.lua, self.Retry = pure("src/shared/Retry.lua")
        self.lua.execute("SLEPT = {}; CALLS = 0")

    def run_retry(self, fails, delays):
        fn = self.lua.eval("function(fails) return function() CALLS = CALLS + 1 if CALLS <= fails then error('boom') end return true end end")(fails)
        sleep = self.lua.eval("function(t) table.insert(SLEPT, t) end")
        return self.Retry.run(fn, self.lua.table_from(delays), sleep)

    def test_success_first_try_never_sleeps(self):
        ok, tries, err = self.run_retry(0, [2, 5])
        self.assertTrue(ok)
        self.assertEqual(tries, 1)
        self.assertEqual(int(self.lua.eval("#SLEPT")), 0)

    def test_retries_with_growing_pauses_then_succeeds(self):
        ok, tries, err = self.run_retry(2, [2, 5])
        self.assertTrue(ok)
        self.assertEqual(tries, 3)
        self.assertEqual([self.lua.eval("SLEPT[1]"), self.lua.eval("SLEPT[2]")], [2, 5])

    def test_gives_up_after_the_last_delay_with_the_error(self):
        ok, tries, err = self.run_retry(99, [2, 5])
        self.assertFalse(ok)
        self.assertEqual(tries, 3)
        self.assertIn("boom", err)

    def test_false_result_counts_as_failure(self):
        fn = self.lua.eval("function() return false end")
        ok, tries, err = self.Retry.run(fn, self.lua.table_from([1]), self.lua.eval("function() end"))
        self.assertFalse(ok)
        self.assertEqual(tries, 2)


def make_hub(place):
    """Faux Roblox + script réel ; les invites des bornes sont conservées (PROMPTS[nom de la pièce]) et la
    téléportation est scriptée (CALLS : journal ; FAIL.reserve / FAIL.teleport / FAIL.private : échecs restants)."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().READ = lambda p: base.to_lua54(base.read(*p.split("/")))
    lua.globals().EXISTS = lambda p: os.path.exists(os.path.join(base.ROOT, *p.split("/")))
    stub = base.STUB.replace(
        "function methods.GetFullName(self) return self.Name end",
        "function methods.GetFullName(self) return self.Name end function methods.GetAttributeChangedSignal() return { Connect = function() end } end function methods.Play() end function methods.Stop() end function methods.GetAttributes(self) return self._attrs end function methods.IsDescendantOf() return false end",
    ).replace(
        'if k == "Parent" then return rawget(t, "_parent") end',
        'if k == "Parent" then return rawget(t, "_parent") end if k == "Triggered" and rawget(t, "ClassName") == "ProximityPrompt" then return { Connect = function(_, f) local par = rawget(t, "_parent"); PROMPTS[par and par.Name or "?"] = f end } end if k == "OnServerEvent" or k == "Touched" or k == "CharacterAdded" or k == "OnClientEvent" or k == "PromptTriggered" then return { Connect = function() end } end if k == "FireClient" or k == "FireAllClients" or k == "FireServer" then return function() end end',
    )
    lua.execute("PROMPTS = {}; CALLS = {}; FAIL = { reserve = 0, teleport = 0, private = 0 }")
    lua.execute(stub)
    lua.execute("math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end")
    lua.execute("game.PlaceId = %d" % place)
    lua.execute('game:GetService("RunService").IsStudio = function() return false end')
    lua.execute('local cs = game:GetService("CollectionService"); cs.RemoveTag = function() end; cs.GetTags = function() return {} end')
    lua.execute("game.BindToClose = function() end")
    lua.execute(roles.SCHEDULER)
    lua.execute(roles.HUB_INIT)
    lua.execute(roles.SERVER_INIT)
    lua.execute(
        """
        local ts = game:GetService("TeleportService")
        local function names(list) local t = {} for _, p in ipairs(list) do t[#t + 1] = p.Name end return table.concat(t, ",") end
        ts.ReserveServer = function(self, place)
          CALLS[#CALLS + 1] = { fn = "reserve", at = clock() }
          if FAIL.reserve > 0 then FAIL.reserve = FAIL.reserve - 1 error("Reserve refusé") end
          return "code" .. #CALLS
        end
        ts.TeleportToPrivateServer = function(self, place, code, list)
          CALLS[#CALLS + 1] = { fn = "private", place = place, who = names(list), at = clock() }
          if FAIL.private > 0 then FAIL.private = FAIL.private - 1 error("Privé refusé") end
        end
        ts.TeleportAsync = function(self, place, list)
          CALLS[#CALLS + 1] = { fn = "async", place = place, who = names(list), at = clock() }
          if FAIL.teleport > 0 then FAIL.teleport = FAIL.teleport - 1 error("Téléportation refusée") end
        end
        local realtypeof = typeof
        typeof = function(v) if type(v) == "table" and rawget(v, "UserId") then return "Instance" end return realtypeof(v) end
        function press(name, player) PROMPTS[name](player) end
        function player(name) for _, p in ipairs(game:GetService("Players"):GetPlayers()) do if p.Name == name then return p end end end
        """
    )
    return lua


def calls(lua, fn=None):
    out = []
    for i in range(1, int(lua.eval("#CALLS")) + 1):
        c = lua.eval("CALLS[%d]" % i)
        if fn is None or c.fn == fn:
            out.append(c)
    return out


HUB = roles.HUB
GAME = roles.GAME


class TestHubQueues(unittest.TestCase):
    def start(self, *names):
        lua = make_hub(HUB)
        lua.execute("SWALLOW = true; runHub()")
        for n in names:
            lua.execute("join(newPlayer('%s'))" % n)
        lua.execute("advance(3)")
        return lua

    def test_pads_exist_and_are_wired(self):
        lua = self.start("alice")
        self.assertTrue(lua.eval("PROMPTS['Zone solo'] ~= nil and PROMPTS['Zone duo'] ~= nil"))

    def test_solo_press_sends_only_the_presser(self):
        lua = self.start("alice", "bob", "carol")
        lua.execute("press('Zone solo', player('bob')); advance(8)")
        sent = calls(lua, "private")
        self.assertEqual([c.who for c in sent], ["bob"])
        self.assertEqual(sent[0].place, roles.GAME)
        self.assertEqual(robust.errors(lua), [])

    def test_two_players_in_duo_go_together_and_a_third_stays(self):
        lua = self.start("alice", "bob", "carol")
        lua.execute("press('Zone duo', player('alice')); advance(2); press('Zone duo', player('bob')); advance(8)")
        sent = calls(lua, "private")
        self.assertEqual(len(sent), 1)
        self.assertEqual(sorted(sent[0].who.split(",")), ["alice", "bob"])
        self.assertEqual(robust.errors(lua), [])

    def test_lone_duo_player_goes_solo_after_the_wait(self):
        lua = self.start("alice")
        lua.execute("press('Zone duo', player('alice')); advance(50)")
        self.assertEqual(calls(lua, "private"), [])
        lua.execute("advance(15)")
        self.assertEqual([c.who for c in calls(lua, "private")], ["alice"])

    def test_pressing_the_same_pad_twice_leaves_the_queue(self):
        lua = self.start("alice")
        lua.execute("require({ __path = 'src/shared/Config.lua' }).Game.AutoStart = true")
        lua.execute("press('Zone duo', player('alice')); press('Zone duo', player('alice')); advance(45)")
        sent = calls(lua, "private")
        self.assertTrue(sent, "sorti de la file : le délai du hub sans borne s'applique (30 s), pas celui du duo (60 s)")
        self.assertLess(sent[0].at, 50)

    def test_player_who_leaves_while_queued_is_not_sent(self):
        lua = self.start("alice", "bob")
        lua.execute("press('Zone duo', player('alice')); local a = player('alice'); a.Parent = nil; advance(100)")
        self.assertTrue(all("alice" not in c.who.split(",") for c in calls(lua, "private") + calls(lua, "async")))

    def test_without_a_pad_nobody_is_ever_launched(self):
        lua = self.start("alice", "bob")
        lua.execute("advance(600)")
        self.assertEqual(calls(lua, "private"), [])
        self.assertEqual(calls(lua, "async"), [])

    def test_no_pad_players_leave_after_the_hub_wait_at_most_two(self):
        lua = self.start("alice", "bob", "carol")
        lua.execute("require({ __path = 'src/shared/Config.lua' }).Game.AutoStart = true")
        lua.execute("advance(40)")
        sent = calls(lua, "private")
        self.assertTrue(sent)
        self.assertLessEqual(len(sent[0].who.split(",")), 2)


class TestTeleportFailures(unittest.TestCase):
    def start(self):
        lua = make_hub(HUB)
        lua.execute("SWALLOW = true; runHub(); join(newPlayer('alice')); advance(3)")
        return lua

    def test_reservation_failure_is_retried_then_succeeds(self):
        lua = self.start()
        lua.execute("FAIL.reserve = 1; press('Zone solo', player('alice')); advance(12)")
        self.assertEqual(len(calls(lua, "reserve")), 2)
        self.assertEqual(len(calls(lua, "private")), 1)
        self.assertEqual(calls(lua, "async"), [], "pas de repli public si le second essai privé réussit")

    def test_private_failure_falls_back_to_public_with_message_and_retries(self):
        lua = self.start()
        lua.execute("FAIL.private = 99; FAIL.teleport = 1; press('Zone solo', player('alice')); advance(30)")
        publics = [c for c in calls(lua, "async") if c.place == roles.GAME]
        self.assertGreaterEqual(len(publics), 2, "repli public avec nouvel essai")
        self.assertEqual(robust.errors(lua), [])

    def test_everything_fails_then_the_loop_keeps_retrying_and_nobody_is_stuck(self):
        lua = self.start()
        lua.execute("FAIL.reserve = 99; FAIL.teleport = 99; press('Zone solo', player('alice')); advance(5)")
        # La file est vidée par le départ ; le joueur reste au hub (aucune erreur, aucun blocage)
        self.assertTrue(lua.eval("player('alice').Character ~= nil"))
        self.assertEqual(robust.errors(lua), [])
        lua.execute("FAIL.reserve = 0; FAIL.teleport = 0; press('Zone solo', player('alice')); advance(8)")
        self.assertTrue(any(c.who == "alice" for c in calls(lua, "private")), "le joueur peut relancer après l'échec")


class TestReturnToHub(unittest.TestCase):
    """Dans le lieu de jeu, fin de partie : tout le monde repart au hub, avec essais, repli et veilleur."""

    def start(self):
        lua = robust.make_capturing(GAME)
        lua.execute(
            """
            CALLS = {}; FAIL = { teleport = 0 }
            local ts = game:GetService("TeleportService")
            local function names(list) local t = {} for _, p in ipairs(list) do t[#t + 1] = p.Name end return table.concat(t, ",") end
            ts.TeleportAsync = function(self, place, list)
              CALLS[#CALLS + 1] = { fn = "async", place = place, who = names(list), at = clock() }
              if FAIL.teleport > 0 then FAIL.teleport = FAIL.teleport - 1 error("refusé") end
            end
            local realtypeof = typeof
            typeof = function(v) if type(v) == "table" and rawget(v, "UserId") then return "Instance" end return realtypeof(v) end
            HUBMOD = function() return require({ __path = "src/common/Hub.lua" }) end
            function player(name) for _, p in ipairs(game:GetService("Players"):GetPlayers()) do if p.Name == name then return p end end end
            """
        )
        self.assertTrue(lua.eval("runServer()").ok)
        lua.execute("SWALLOW = true; join(newPlayer('alice')); join(newPlayer('bob')); advance(20)")
        return lua

    def test_return_succeeds_first_try(self):
        lua = self.start()
        lua.execute("HUBMOD().sendPlayersToHub({ player('alice'), player('bob') })")
        sent = [c for c in calls(lua, "async") if c.place == roles.HUB]
        self.assertEqual(len(sent), 1)
        self.assertEqual(sorted(sent[0].who.split(",")), ["alice", "bob"])

    def test_return_retries_then_succeeds(self):
        lua = self.start()
        lua.execute("FAIL.teleport = 2; HUBMOD().sendPlayersToHub({ player('alice') })")
        self.assertEqual(len([c for c in calls(lua, "async") if c.place == roles.HUB]), 3)

    def test_total_failure_tries_each_player_alone_then_keeps_trying_until_they_leave(self):
        lua = self.start()
        lua.execute("FAIL.teleport = 12; HUBMOD().sendPlayersToHub({ player('alice'), player('bob') })")
        alone = [c for c in calls(lua, "async") if c.place == roles.HUB and "," not in c.who]
        self.assertEqual(sorted(c.who for c in alone), ["alice", "bob"])
        # le veilleur recommence toutes les 25 s tant que des joueurs sont là
        lua.execute("advance(60)")
        groups = [c for c in calls(lua, "async") if c.place == roles.HUB and c.who == "alice,bob"]
        self.assertGreaterEqual(len(groups), 3)
        # tous partis : le veilleur s'arrête
        lua.execute("player('alice').Parent = nil; player('bob').Parent = nil")
        before = len(calls(lua, "async"))
        lua.execute("advance(100)")
        self.assertEqual(len(calls(lua, "async")), before, "plus aucune tentative quand plus personne n'est là")

    def test_players_already_gone_are_not_teleported(self):
        lua = self.start()
        lua.execute("player('bob').Parent = nil; HUBMOD().sendPlayersToHub({ player('alice'), player('bob') })")
        sent = [c for c in calls(lua, "async") if c.place == roles.HUB]
        self.assertEqual([c.who for c in sent], ["alice"])
        lua.execute("HUBMOD().sendPlayersToHub({})")


if __name__ == "__main__":
    unittest.main()
