#!/usr/bin/env python3
"""Passe 3 : tension, difficulté par mode, tutoriel, rangs, défis, graines (modules purs, via lupa)."""
import os
import re
import unittest

import sys

from lupa.lua54 import LuaRuntime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SHARED = os.path.join(ROOT, "src", "shared")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


class Base(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.Config = self.lua.execute(to_lua54(read(os.path.join(SHARED, "Config.lua"))))

    def mod(self, name):
        return self.lua.execute(to_lua54(read(os.path.join(SHARED, name + ".lua"))))


class TestTension(Base):
    def test_three_phases_in_order(self):
        T = self.mod("Tension")
        cfg = self.Config.Tension
        for mode in ("solo", "duo"):
            ph = cfg.Phases[mode]
            self.assertEqual(T.compute(cfg, mode, 1, 0).name, "calme")
            self.assertEqual(T.compute(cfg, mode, ph.calm + 1, 0).name, "montee")
            self.assertEqual(T.compute(cfg, mode, ph.rise + 1, 0).name, "pic")

    def test_curve_is_monotonic_and_bounded(self):
        T = self.mod("Tension")
        cfg = self.Config.Tension
        prev = None
        for t in range(0, 1500, 10):
            c = T.compute(cfg, "solo", t, 0)
            if prev is not None:
                for k in ("events", "hear", "chase", "volume"):
                    self.assertGreaterEqual(c[k], prev[k] - 1e-9, f"{k} baisse à t={t}")
                self.assertLessEqual(c.gap, prev.gap + 1e-9)
            prev = c
        lv = cfg.Levels
        self.assertAlmostEqual(T.compute(cfg, "solo", 0, 0).events, lv.calme.events)
        self.assertAlmostEqual(T.compute(cfg, "solo", 5000, 0).events, lv.pic.events)

    def test_progress_advances_but_never_rewinds(self):
        T = self.mod("Tension")
        cfg = self.Config.Tension
        self.assertEqual(T.compute(cfg, "solo", 10, 0.5).name, "montee")
        self.assertEqual(T.compute(cfg, "solo", 10, 1).name, "pic")
        self.assertEqual(T.compute(cfg, "solo", 5000, 0).name, "pic")
        self.assertGreaterEqual(T.compute(cfg, "solo", 300, 0).u, T.compute(cfg, "solo", 200, 0).u)

    def test_duo_peaks_earlier_than_solo(self):
        T = self.mod("Tension")
        cfg = self.Config.Tension
        self.assertLess(cfg.Phases.duo.rise, cfg.Phases.solo.rise)
        t = (cfg.Phases.duo.rise + cfg.Phases.solo.rise) / 2
        self.assertEqual(T.compute(cfg, "duo", t, 0).name, "pic")
        self.assertEqual(T.compute(cfg, "solo", t, 0).name, "montee")

    def test_disabled_is_neutral(self):
        T = self.mod("Tension")
        cfg = self.Config.Tension
        cfg.Enabled = False
        c = T.compute(cfg, "solo", 3000, 1)
        for k in ("events", "hear", "chase", "volume", "gap"):
            self.assertEqual(c[k], 1)

    def test_runtime_neutral_before_start(self):
        T = self.mod("Tension")
        self.assertEqual(T.current().events, 1)

    def test_config_levels_complete(self):
        for name in ("calme", "montee", "pic"):
            for k in ("events", "hear", "chase", "volume", "gap"):
                self.assertGreater(self.Config.Tension.Levels[name][k], 0)
        for mode in ("solo", "duo"):
            ph = self.Config.Tension.Phases[mode]
            self.assertLess(ph.calm, ph.rise)

    def test_wired_into_systems(self):
        for f in ("Ambience", "FallingObjects", "MonsterAI", "Lights"):
            src = read(os.path.join(ROOT, "src", "server", f + ".lua"))
            self.assertTrue("Tension" in src, f)


class TestBalance(Base):
    def test_solo_and_duo_differ(self):
        B = self.mod("Balance")
        m = self.Config.Monster
        solo = B.compute(m, 3, self.Config.Balance, "solo")
        duo = B.compute(m, 3, self.Config.Balance, "duo")
        for k in ("ChaseSpeed", "HearRange", "LoseTargetTime", "SearchTime", "SurpriseGap", "lives", "hintDelay"):
            self.assertNotEqual(solo[k], duo[k], k)

    def test_apply_is_idempotent(self):
        B = self.mod("Balance")
        first = B.apply(self.Config, "duo")
        chase = self.Config.Monster.ChaseSpeed
        B.apply(self.Config, "duo")
        self.assertEqual(self.Config.Monster.ChaseSpeed, chase)
        B.apply(self.Config, "solo")
        B.apply(self.Config, "duo")
        self.assertEqual(self.Config.Monster.ChaseSpeed, chase)
        self.assertEqual(self.Config.Player.Lives, first.lives)

    def test_values_stay_playable(self):
        for mode in ("solo", "duo"):
            b = self.Config.Balance[mode]
            self.assertGreater(b.chase * self.Config.Monster.ChaseSpeed, self.Config.Player.SprintSpeed - 1.5,
                               "le monstre doit rester menaçant")
            self.assertLessEqual(b.chase, 1.1)
            self.assertGreaterEqual(b.lives, 2)
            self.assertGreaterEqual(b.hintDelay, 60)

    def test_hint_delay_is_applied_by_quests(self):
        src = read(os.path.join(ROOT, "src", "server", "Quests.lua"))
        self.assertTrue("CFG.HintDelay" in src)  # CFG = Config.Quests, modifié par Balance.apply

    def test_round_start_applies_balance(self):
        src = read(os.path.join(ROOT, "src", "server", "init.server.lua"))
        self.assertTrue("Balance.apply" in src)


class TestRanks(Base):
    def test_ranks_increase(self):
        R = self.mod("Ranks")
        pts = [r.points for r in R.LIST.values()]
        self.assertEqual(pts, sorted(pts))
        self.assertEqual(pts[0], 0)
        self.assertEqual(R.rankName(0), "Visiteur")
        self.assertEqual(R.rankName(60), "Rôdeur")
        self.assertEqual(R.rankName(10**6), "Gardien du grenier")
        self.assertIsNone(R.toNext(10**6))
        self.assertEqual(R.toNext(0), 20)

    def test_award_and_rank_up(self):
        R = self.mod("Ranks")
        C = self.mod("Challenges")
        p = R.newProfile()
        result = self.lua.table(ending="truth", mode="duo", challenges=self.lua.table_from(["verite"]))
        out = R.award(self.Config.Ranks, p, result, C.titles())
        # 10 + 40 + 15 + 5
        self.assertEqual(out.gained, 70)
        self.assertEqual(p.points, 70)
        self.assertEqual(out.rankUp, "Rôdeur")
        self.assertEqual(p.runs, 1)
        self.assertEqual(p.endings.truth, 1)
        self.assertTrue(p.challenges.verite)
        self.assertEqual(R.label(p), "Rôdeur · Porteur de vérité")

    def test_normalize_rejects_garbage(self):
        R = self.mod("Ranks")
        p = R.normalize(self.lua.table(points=-5, runs="x", endings=self.lua.table(a="y"), seeds=self.lua.table_from([1, "a"])))
        self.assertEqual(p.points, 0)
        self.assertEqual(p.runs, 0)
        self.assertEqual(len(p.seeds), 1)
        self.assertEqual(R.normalize(None).points, 0)

    def test_endings_have_points(self):
        for ending in ("lose", "sealed", "truth"):
            self.assertIn(ending, self.Config.Ranks.PointsPerEnding)
        quests = read(os.path.join(ROOT, "src", "server", "Quests.lua"))
        for ending in re.findall(r'endFn\("(\w+)"\)', quests):
            self.assertIn(ending, self.Config.Ranks.PointsPerEnding)


class TestChallenges(Base):
    def result(self, **kw):
        base = dict(ending="truth", mode="solo", duration=1200, deaths=1)
        base.update(kw)
        return self.lua.table(**base)

    def test_evaluation(self):
        C = self.mod("Challenges")
        ids = list(C.evaluate(self.result(), None).values())
        self.assertEqual(sorted(ids), ["solitaire", "verite"])
        ids = list(C.evaluate(self.result(deaths=0, duration=600, mode="duo"), None).values())
        self.assertEqual(sorted(ids), ["duo_fidele", "express", "sans_mort", "verite"])
        self.assertEqual(list(C.evaluate(self.result(ending="lose", deaths=0), None).values()), [])
        self.assertEqual(list(C.evaluate(self.result(ending="sealed"), None).values()), ["piege"])

    def test_completed_not_counted_twice(self):
        C = self.mod("Challenges")
        done = self.lua.table(verite=True, solitaire=True)
        self.assertEqual(len(C.evaluate(self.result(), done)), 0)

    def test_daily_cycles_over_all_challenges(self):
        C = self.mod("Challenges")
        n = len(C.LIST)
        seen = {C.daily(d).id for d in range(n)}
        self.assertEqual(len(seen), n)

    def test_every_challenge_is_reachable(self):
        C = self.mod("Challenges")
        cases = [self.result(deaths=0, duration=600, mode="duo"), self.result(), self.result(ending="sealed")]
        got = set()
        for r in cases:
            got |= set(C.evaluate(r, None).values())
        self.assertEqual(got, {c.id for c in C.LIST.values()})


class TestReplay(Base):
    def test_daily_seed_is_stable_and_valid(self):
        R = self.mod("Replay")
        d = R.day(1_800_000_000)
        self.assertEqual(R.dailySeed(d), R.dailySeed(d))
        self.assertNotEqual(R.dailySeed(d), R.dailySeed(d + 1))
        for day in range(0, 40000, 997):
            s = R.dailySeed(day)
            self.assertTrue(1 <= s <= 2147483646)

    def test_fresh_avoids_recent(self):
        R = self.mod("Replay")
        history = self.lua.table_from([5, 6, 7])
        values = iter([7, 6, 5, 9])
        seed = R.fresh(history, 3, lambda: next(values))
        self.assertEqual(seed, 9)

    def test_fresh_terminates_when_all_draws_repeat(self):
        R = self.mod("Replay")
        history = self.lua.table_from([1])
        self.assertEqual(R.fresh(history, 5, lambda: 1), 1)

    def test_push_bounded(self):
        R = self.mod("Replay")
        h = self.lua.table_from([])
        for i in range(1, 30):
            R.push(h, i, 10)
        self.assertEqual(len(h), 10)
        self.assertEqual(h[10], 29)


class TestTutorial(Base):
    def ctx(self, **kw):
        base = dict(elapsed=0, now=0, quietUsed=False, hidden=False, chased=False, battery=100)
        base.update(kw)
        return self.lua.table(**base)

    def test_three_hints_in_context_and_once(self):
        T = self.mod("Tutorial")
        cfg = self.Config.Tutorial
        st = T.newState()
        self.assertEqual(len(T.HINTS), 3)
        self.assertIsNone(T.next(cfg, st, self.ctx(elapsed=5)))
        self.assertEqual(T.next(cfg, st, self.ctx(elapsed=50, now=50)).id, "quiet")
        # même contexte, trop tôt : rien ; plus tard : pas de doublon
        self.assertIsNone(T.next(cfg, st, self.ctx(elapsed=60, now=60)))
        self.assertIsNone(T.next(cfg, st, self.ctx(elapsed=100, now=100)))
        self.assertEqual(T.next(cfg, st, self.ctx(elapsed=100, now=100, chased=True)).id, "hide")
        self.assertEqual(T.next(cfg, st, self.ctx(elapsed=200, now=200, battery=20)).id, "lamp")
        self.assertTrue(T.done(st))

    def test_cooldown_between_hints(self):
        T = self.mod("Tutorial")
        cfg = self.Config.Tutorial
        st = T.newState()
        self.assertIsNotNone(T.next(cfg, st, self.ctx(elapsed=50, now=50, battery=10)))
        self.assertIsNone(T.next(cfg, st, self.ctx(elapsed=51, now=51, battery=10)))
        self.assertIsNotNone(T.next(cfg, st, self.ctx(elapsed=51 + cfg.Cooldown, now=51 + cfg.Cooldown, battery=10)))

    def test_player_who_knows_gets_no_hint(self):
        T = self.mod("Tutorial")
        st = T.newState()
        self.assertIsNone(T.next(self.Config.Tutorial, st, self.ctx(elapsed=90, now=90, quietUsed=True)))

    def test_disabled(self):
        T = self.mod("Tutorial")
        cfg = self.Config.Tutorial
        cfg.Enabled = False
        self.assertIsNone(T.next(cfg, T.newState(), self.ctx(elapsed=90, now=90, battery=5)))


class TestProfile(Base):
    def profile_module(self):
        return self.lua.execute(to_lua54(read(os.path.join(ROOT, "src", "common", "Profile.lua"))))

    def fake_store(self):
        data = {}
        py = self

        def get(key):
            return data.get(key), True

        def set_(key, value):
            data[key] = value
            return True

        return data, py.lua.table(get=get, set=set_)

    def test_roundtrip_through_store(self):
        P = self.profile_module()
        R = self.mod("Ranks")
        data, store = self.fake_store()
        cache = P.newCache(store, R)
        p = cache.load("p1")
        self.assertEqual(p.points, 0)
        R.award(self.Config.Ranks, p, self.lua.table(ending="sealed", mode="solo", challenges=self.lua.table_from(["piege"])), self.mod("Challenges").titles())
        self.assertTrue(cache.save("p1"))
        again = P.newCache(store, R).load("p1")
        self.assertEqual(again.points, p.points)
        self.assertEqual(again.title, "Pris au piège")
        self.assertTrue(again.challenges.piege)

    def test_store_failure_keeps_a_playable_profile(self):
        P = self.profile_module()
        R = self.mod("Ranks")
        store = self.lua.table(get=lambda key: (None, False), set=lambda key, v: False)
        cache = P.newCache(store, R)
        p = cache.load("p2")
        self.assertEqual(p.points, 0)
        self.assertFalse(cache.save("p2"))
        self.assertEqual(cache.get("p2").runs, 0)

    def test_no_store_at_all(self):
        P = self.profile_module()
        R = self.mod("Ranks")
        cache = P.newCache(None, R)
        self.assertEqual(cache.load("x").points, 0)
        self.assertFalse(cache.save("x"))

    def test_hub_and_game_both_load_profiles(self):
        hub = read(os.path.join(ROOT, "src", "hub", "init.server.lua"))
        game = read(os.path.join(ROOT, "src", "server", "init.server.lua"))
        self.assertTrue("Profile.load" in hub and "attachLabel" in hub)
        self.assertTrue("Profile.load" in game and "awardPlayers" in game)


if __name__ == "__main__":
    unittest.main()
