#!/usr/bin/env python3
"""Tests de logique des animations (src/shared/Motion.lua), exécutées avec lupa (Lua 5.4)."""
import os
import unittest

from lupa.lua54 import LuaRuntime

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MOTION = os.path.join(ROOT, "src", "shared", "Motion.lua")


def load():
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(MOTION, encoding="utf-8") as f:
        return lua.execute(f.read())


class TestMotion(unittest.TestCase):
    def setUp(self):
        self.m = load()

    def test_ease_out_bounds(self):
        self.assertAlmostEqual(self.m.easeOut(0), 0)
        self.assertAlmostEqual(self.m.easeOut(1), 1)
        self.assertAlmostEqual(self.m.easeOut(-5), 0)
        self.assertAlmostEqual(self.m.easeOut(9), 1)

    def test_bob_zero_when_still_and_bounded_when_moving(self):
        self.assertEqual(self.m.bob(3.2, False, 0.08), 0)
        for i in range(200):
            v = self.m.bob(i * 0.05, True, 0.08)
            self.assertLessEqual(abs(v), 0.08 + 1e-9)

    def test_breath_between_zero_and_amplitude(self):
        for i in range(200):
            v = self.m.breath(i * 0.1, 0.04)
            self.assertGreaterEqual(v, -1e-9)
            self.assertLessEqual(v, 0.04 + 1e-9)

    def test_shake_decays_to_zero_and_stops(self):
        self.assertEqual(self.m.shake(-0.1, 0.6, 0.25), 0)
        self.assertEqual(self.m.shake(0.6, 0.6, 0.25), 0)
        self.assertEqual(self.m.shake(5, 0.6, 0.25), 0)
        early = max(abs(self.m.shake(0.01 * i, 0.6, 0.25)) for i in range(1, 10))
        late = max(abs(self.m.shake(0.5 + 0.01 * i, 0.6, 0.25)) for i in range(1, 10))
        self.assertGreater(early, late)

    def test_blink_steps_sum_to_duration_and_end_clear(self):
        steps = self.m.blinkSteps(8)
        total = 0.0
        n = 0
        for s in steps.values():
            n += 1
            self.assertGreater(s.seconds, 0)
            self.assertGreaterEqual(s.transparency, 0)
            self.assertLessEqual(s.transparency, 1)
            total += s.seconds
        self.assertEqual(n, 6)
        self.assertAlmostEqual(total, 8, places=6)
        self.assertAlmostEqual(steps[6].transparency, 1)

    def test_blink_finite_durations_no_blocking(self):
        for d in (0.5, 8, 30):
            steps = self.m.blinkSteps(d)
            for s in steps.values():
                self.assertTrue(0 < s.seconds <= d)

    def test_lid_and_sway(self):
        self.assertAlmostEqual(self.m.lidAngle(1, 22), 22)
        self.assertLess(self.m.lidAngle(0.2, 22), self.m.lidAngle(0.9, 22))
        for i in range(100):
            self.assertLessEqual(abs(self.m.swayAngle(i * 0.3, 2.5, 6)), 2.5 + 1e-9)


if __name__ == "__main__":
    unittest.main()
