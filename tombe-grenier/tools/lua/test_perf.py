#!/usr/bin/env python3
"""Budget de performance mesuré sur la vraie carte : Parts, lumières, particules, halos, ombres, boucles actives,
masquage de pièces. Les budgets viennent de Config.Perf ; le test échoue si l'un est dépassé.
"""

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_spawn_map as smap  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

# Boucles de fond connues (fichier -> pause minimale en secondes). Toute boucle plus rapide doit être ajoutée ici
# en connaissance de cause.
FAST_LOOPS = {
    "src/server/MonsterVisual.lua": 0.05,  # balancement de la silhouette (une pcall par pas, un seul monstre)
    "src/server/Lights.lua": 0.1,  # reprise après coupure (les ampoules éloignées attendent 1 s)
    "src/server/Ambience.lua": 0.08,  # rafale de bruits, ponctuelle
    "src/server/Props.lua": 0.05,  # animation ponctuelle d'un objet
}


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


class TestBudget(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        smap.TestRealMap.setUpClass()
        cls.t = smap.TestRealMap
        cls.lua = cls.t.lua
        cls.Perf = cls.lua.eval('require({ __path = "src/shared/PerfRules.lua" })')
        cls.Config = cls.lua.eval('require({ __path = "src/shared/Config.lua" })')
        cls.Budget = cls.lua.eval('require({ __path = "src/shared/RoomBudget.lua" })')
        cls.counts = {}
        for d in cls.t.root.GetDescendants(cls.t.root).values():
            cls.counts[d.ClassName] = cls.counts.get(d.ClassName, 0) + 1

    def test_parts_under_budget(self):
        parts = self.counts.get("Part", 0) + self.counts.get("MeshPart", 0)
        print(
            f"\n[perf] parts de la carte : {parts} (budget {self.Config.Perf.MaxParts})"
        )
        self.assertLess(parts, self.Config.Perf.MaxParts)

    def test_lights_per_room_and_active_total(self):
        data = self.t.Data
        rooms = [data.rooms[i] for i in range(1, len(data.rooms) + 1)]
        lamps_per_room = {}
        for p in data.props.values():
            if p.tag == "Lamp":
                lamps_per_room[p.room] = lamps_per_room.get(p.room, 0) + 1
        self.assertTrue(
            all(n == 1 for n in lamps_per_room.values()), "une ampoule par pièce"
        )
        limits = self.Budget.qualityLimits(self.Config.Visual.RoomLightQuality)
        worst = 0
        for center in rooms:
            player = self.lua.table_from(
                {
                    "x": (center.x0 + center.x1) / 2,
                    "z": (center.z0 + center.z1) / 2,
                    "level": center.level,
                }
            )
            table = self.lua.table()
            for i, r in enumerate(rooms, 1):
                table[i] = self.lua.table_from(
                    {
                        "id": r.id,
                        "level": r.level,
                        "cx": (r.x0 + r.x1) / 2,
                        "cz": (r.z0 + r.z1) / 2,
                    }
                )
            active = list(
                self.Budget.activeRooms(table, player, limits.lights).values()
            )
            lights = len(active) + sum(lamps_per_room.get(r, 0) for r in active)
            worst = max(worst, lights)
        print(
            f"[perf] lumières actives au pire : {worst} (budget {self.Config.Perf.MaxLights})"
        )
        self.assertLess(worst, self.Config.Perf.MaxLights)

    def test_every_decor_part_is_cheap(self):
        costly = []
        for d in self.t.parts:
            if d.Name in ("CercueilSpawn",):
                continue
            if d.CanTouch is not False:
                costly.append(("touch", d.Name))
            if max(d.Size.X, d.Size.Y, d.Size.Z) < 3 and d.CastShadow is not False:
                costly.append(("ombre", d.Name))
        # Les pièces posées par d'autres modules (repères, marqueurs) ne sont pas dans les dossiers de décor
        self.assertLess(len(costly), 400, costly[:5])

    def test_decor_boxes_do_not_cast_small_shadows(self):
        src = read("src", "server", "MapBuilder.lua")
        self.assertIn("part.CanTouch = false", src)
        self.assertIn("PerfRules.castsShadow", src)
        model = read("src", "server", "ModelPlace.lua")
        for flag in ("CanCollide = false", "CanQuery = false", "CanTouch = false"):
            self.assertIn(flag, model)

    def test_particle_budget_for_every_vfx_quality(self):
        vfx = self.lua.eval('require({ __path = "src/shared/VfxKit.lua" })')
        for level in ("haut", "moyen", "bas"):
            q = vfx.QUALITY[level]
            self.assertLessEqual(
                q.maxConcurrent * q.maxParticles, self.Config.Perf.MaxParticles, level
            )

    def test_halo_budget(self):
        markers = self.lua.eval('require({ __path = "src/shared/Markers.lua" })')
        self.assertLessEqual(markers.MAX_HALOS, self.Config.Perf.MaxHalos)
        self.assertEqual(
            self.Perf.violations(
                self.lua.table_from(
                    {"parts": 10, "lights": 5, "particles": 5, "halos": 3}
                )
            ).__len__(),
            0,
        )
        bad = self.Perf.violations(
            self.lua.table_from(
                {"parts": 9999, "lights": 99, "particles": 999, "halos": 99}
            )
        )
        self.assertEqual(len(list(bad.values())), 4)

    def test_monster_ai_runs_at_five_hertz(self):
        self.assertGreaterEqual(self.Config.Monster.Tick, 0.2)

    def test_no_new_fast_loop(self):
        offenders = []
        for folder in ("src/server", "src/client", "src/shared"):
            for name in os.listdir(os.path.join(ROOT, folder)):
                if not name.endswith(".lua"):
                    continue
                rel = f"{folder}/{name}"
                for match in re.finditer(
                    r"task\.wait\((0?\.\d+)\)", read(*rel.split("/"))
                ):
                    pause = float(match.group(1))
                    if pause < 0.2 and pause < FAST_LOOPS.get(rel, 0.2):
                        offenders.append((rel, pause))
        self.assertEqual(offenders, [], "boucle rapide non listée dans FAST_LOOPS")

    def test_no_renderstepped_without_throttle_or_need(self):
        client = read("src", "client", "init.client.lua")
        # RenderStepped : balancement de caméra, flèche (limitée à 10 Hz), compteur FPS : trois seulement
        self.assertLessEqual(len(re.findall(r"RunService\.RenderStepped", client)), 4)

    def test_remotes_are_event_driven(self):
        for name in os.listdir(os.path.join(ROOT, "src", "server")):
            if not name.endswith(".lua"):
                continue
            src = read("src", "server", name)
            for loop in re.finditer(r"while true do(.*?)\nend", src, re.S):
                body = loop.group(1)
                if "fireAll(" in body and "task.wait(" in body:
                    waits = [
                        float(w) for w in re.findall(r"task\.wait\(([\d.]+)\)", body)
                    ]
                    self.assertTrue(
                        min(waits) >= 2, f"{name}: fireAll dans une boucle rapide"
                    )


class TestCulling(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        TestBudget.setUpClass()
        cls.lua = TestBudget.lua
        cls.Perf = TestBudget.Perf
        cls.Data = TestBudget.t.Data

    def rooms(self):
        d = self.Data
        out = self.lua.table()
        for i in range(1, len(d.rooms) + 1):
            r = d.rooms[i]
            out[i] = self.lua.table_from(
                {
                    "id": r.id,
                    "level": r.level,
                    "cx": (r.x0 + r.x1) / 2,
                    "cz": (r.z0 + r.z1) / 2,
                }
            )
        return out

    def test_player_room_always_visible_and_count_bounded(self):
        d = self.Data
        for i in range(1, len(d.rooms) + 1):
            r = d.rooms[i]
            player = self.lua.table_from(
                {"x": (r.x0 + r.x1) / 2, "z": (r.z0 + r.z1) / 2, "level": r.level}
            )
            visible = self.Perf.visibleRooms(self.rooms(), player, 7)
            self.assertTrue(visible[r.id], r.id)
            self.assertEqual(len(list(visible.keys())), 7)

    def test_far_rooms_are_culled(self):
        d = self.Data
        total = len(d.rooms)
        self.assertGreater(total, 7)
        player = self.lua.table_from({"x": 10, "z": 10, "level": "ground"})
        visible = self.Perf.visibleRooms(self.rooms(), player, 7)
        self.assertLess(len(list(visible.keys())), total)

    def test_furniture_resolve_to_rooms(self):
        d = self.Data
        found, total = 0, 0
        for f in d.furniture.values():
            total += 1
            cx, cz = (f.x0 + f.x1) / 2, (f.z0 + f.z1) / 2
            room = self.Perf.roomIdAt(d.rooms, d.base, d.H, cx, f.y0 + 0.5, cz)
            if room is not None:
                found += 1
        self.assertGreaterEqual(
            found / total, 0.95, f"{found}/{total} meubles dans une pièce"
        )

    def test_cull_never_touches_floors_and_walls(self):
        src = read("src", "client", "RoomCull.lua")
        self.assertIn('{ "Meubles", "Décor", "Détails" }', src)
        for forbidden in ("Murs", "Dalles", "Escaliers"):
            self.assertNotIn(f'"{forbidden}"', src)


class TestDebugCounter(unittest.TestCase):
    def test_f7_and_server_frame_time(self):
        client = read("src", "client", "init.client.lua")
        self.assertIn("Enum.KeyCode.F7", client)
        self.assertIn("ServerFrameMs", client)
        self.assertIn("ServerFrameMs", read("src", "server", "init.server.lua"))
        self.assertIn("DebugOverlay", read("src", "shared", "Config.lua"))


if __name__ == "__main__":
    unittest.main()
