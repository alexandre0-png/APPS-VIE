#!/usr/bin/env python3
"""Pack animations : VfxKit (préréglages, qualité par appareil), CinematicKit (durées, restauration garantie, passage,
demandes simultanées, danger) et UiFx, exécutés sur les vrais modules (logique pure puis faux client)."""
import os
import re
import sys
import unittest

from lupa.lua54 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_syntax import to_lua54  # noqa: E402
from client_env import errors, make, warns  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
REQUIRED_PRESETS = ("aura_runique", "aura_ailes", "onde_de_choc", "pilier_revelation", "bouclier", "etincelles", "spirale_montee", "portail_torii")
REQUIRED_PLANS = ("reveil_cercueil", "apparition_monstre", "objet_precieux", "porte_ouvre", "sortie_soussol", "enfant_retrouve", "fuite_finale")


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


def pure(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("typeof = type")
    return lua, lua.execute(to_lua54(read(*path.split("/"))))


class TestVfxKitLogic(unittest.TestCase):
    def setUp(self):
        self.lua, self.V = pure("src/shared/VfxKit.lua")

    def test_required_presets_exist_and_reference_known_models(self):
        names = [self.V.names()[i] for i in range(1, len(self.V.names()) + 1)]
        for p in REQUIRED_PRESETS:
            self.assertIn(p, names)
        models = set(k for k in self.V.MODELS.keys())
        for name in names:
            preset = self.V.PRESETS[name]
            self.assertGreater(preset.duration, 0)
            for i in range(1, len(preset.pieces) + 1):
                piece = preset.pieces[i]
                self.assertIn(piece.model, models, name)
                self.assertEqual(len(piece.fade), 3, name)

    def test_quality_by_device(self):
        t = self.lua.table_from
        self.assertEqual(self.V.quality(t({"touch": True, "width": 640, "height": 360})), "bas")
        self.assertEqual(self.V.quality(t({"touch": True, "width": 1366, "height": 1024})), "moyen")
        self.assertEqual(self.V.quality(t({"touch": False, "width": 1920, "height": 1080})), "haut")
        self.assertEqual(self.V.quality(t({"touch": True, "width": 640, "height": 360}), "haut"), "haut")

    def test_phone_limits_three_effects_forty_particles_no_beam(self):
        low = self.V.QUALITY.bas
        self.assertLessEqual(low.maxConcurrent, 3)
        self.assertLessEqual(low.maxParticles, 40)
        self.assertFalse(low.beam)
        for name in ("aura_runique", "pilier_revelation", "portail_torii", "etincelles", "spirale_montee"):
            plan = self.V.plan(name, "bas")
            self.assertFalse(plan.beam, name)
            self.assertFalse(plan.highlight, name)
            self.assertLessEqual(len(plan.pieces), 2, name)
            if plan.particles:
                self.assertLessEqual(plan.particles.count, 40, name)

    def test_high_quality_keeps_beam_for_presets_that_declare_it(self):
        self.assertTrue(self.V.plan("pilier_revelation", "haut").beam)
        self.assertTrue(self.V.plan("bouclier", "haut").highlight)

    def test_cold_themes_and_unknown_preset(self):
        r, g, b = self.V.color("froid", "primary")
        self.assertGreater(b, r)  # teinte froide
        self.assertIsNone(self.V.plan("inconnu", "haut"))

    def test_models_declared_in_config_and_loader(self):
        cfg, loader = read("src", "shared", "Config.lua"), read("src", "server", "ModelLoader.lua")
        for key in ("VfxCercle", "VfxAiles", "VfxHalo", "VfxRayons", "VfxEtoile", "VfxCristaux", "VfxOnde", "VfxTorii", "VfxSpirale", "VfxPilier", "VfxEtincelles", "VfxCone", "VfxBouclier"):
            self.assertRegex(cfg, rf"\b{key} = \d{{9,}}")
            self.assertRegex(loader, rf'\b{key} = "vfx ')
        self.assertIn('ReplicatedStorage:FindFirstChild("Vfx")', loader)


class TestCinematicKitLogic(unittest.TestCase):
    def setUp(self):
        self.lua, self.K = pure("src/shared/CinematicKit.lua")

    def plans(self):
        return {n: self.K.PLANS[n] for n in REQUIRED_PLANS}

    def test_all_required_plans_are_valid_and_under_eight_seconds(self):
        for name, plan in self.plans().items():
            errs = self.K.validate(plan)
            self.assertEqual(len(errs), 0, f"{name} : {[errs[i] for i in range(1, len(errs) + 1)]}")
            self.assertLessEqual(self.K.total(plan.shots), 8, name)

    def test_total_is_the_sum_of_the_shots(self):
        for name, plan in self.plans().items():
            s = sum(plan.shots[i].t for i in range(1, len(plan.shots) + 1))
            self.assertAlmostEqual(self.K.total(plan.shots), s, places=6, msg=name)

    def test_clamp_never_exceeds_eight_seconds(self):
        long = self.lua.table_from([self.lua.table_from({"t": 5}), self.lua.table_from({"t": 5}), self.lua.table_from({"t": 5})])
        clamped = self.K.clamp(long, 100)
        self.assertLessEqual(self.K.total(clamped), 8)
        self.assertEqual(len(clamped), 2)
        self.assertAlmostEqual(self.K.total(self.K.clamp(long, 3)), 3)

    def test_validate_rejects_bad_plans(self):
        t = self.lua.table_from
        self.assertGreater(len(self.K.validate(t({"shots": t([t({"t": 0, "look": t([0, 0, 0])})])}))), 0)
        self.assertGreater(len(self.K.validate(t({"shots": t([t({"t": 9, "look": t([0, 0, 0])})])}))), 0)
        self.assertGreater(len(self.K.validate(t({"shots": t([t({"t": 2})])}))), 0)
        self.assertGreater(len(self.K.validate(None)), 0)

    def test_easing_endpoints(self):
        for name in ("linear", "Sine", "Quad", "Quint", "Back", "Elastic"):
            self.assertAlmostEqual(self.K.ease(name, 0), 0, places=6, msg=name)
            self.assertAlmostEqual(self.K.ease(name, 1), 1, places=6, msg=name)

    def test_sample_travelling_orbit_dolly(self):
        t = self.lua.table_from
        anchor = t([10, 5, 20])
        travel = t({"t": 2, "path": "travelling", "from": t([0, 0, 0]), "to": t([0, 0, 10]), "look": t([0, 0, -5]), "fov": t([50, 80]), "ease": "linear"})
        eye0, look0, fov0 = self.K.sample(travel, 0, anchor)
        eye1, _, fov1 = self.K.sample(travel, 1, anchor)
        self.assertAlmostEqual(eye0[3], 20)
        self.assertAlmostEqual(eye1[3], 30)
        self.assertAlmostEqual(fov0, 50)
        self.assertAlmostEqual(fov1, 80)
        orbit = t({"t": 2, "path": "orbite", "radius": 3, "sweep": 90, "look": t([0, 0, 0]), "ease": "linear", "height": 1})
        for alpha in (0, 0.5, 1):
            eye, _, _ = self.K.sample(orbit, alpha, anchor)
            dist = ((eye[1] - 10) ** 2 + (eye[3] - 20) ** 2) ** 0.5
            self.assertAlmostEqual(dist, 3, places=5)  # rayon constant : vraie orbite
        focus = t([0, 0, 0])
        _, look, _ = self.K.sample(t({"t": 1, "path": "dolly", "from": t([0, 0, 1]), "to": t([0, 0, 1]), "look": t([0, 0, 0]), "focus": True}), 0.5, anchor, focus)
        self.assertAlmostEqual(look[1], 0)  # regarde la cible (focus), pas l'ancrage

    def test_locate(self):
        shots = self.K.PLANS.reveil_cercueil.shots
        i, a = self.K.locate(shots, 0.5)
        self.assertEqual(i, 1)
        i2, _ = self.K.locate(shots, shots[1].t + 0.1)
        self.assertEqual(i2, 2)
        self.assertIsNone(self.K.locate(shots, self.K.total(shots) + 0.1))

    def test_danger_refuses(self):
        t = self.lua.table_from
        ok = {"health": 100, "monsterDistance": 80}
        self.assertTrue(self.K.allowed(t(ok)))
        for bad in ({"chasing": True}, {"hidden": True}, {"busy": True}, {"health": 0}, {"monsterDistance": 5}):
            self.assertFalse(self.K.allowed(t(dict(ok, **bad))), bad)
        self.assertFalse(self.K.allowed(None))


RUN = r"""
KIT = REQUIRE("src/shared/CinematicKit.lua")
DONE = {}
function startPlan(name, extra)
  local cam = workspace.CurrentCamera
  CAM = cam
  local ctx = { gui = findGui("TombeHUD"), state = function() return { health = 100, monsterDistance = 90 } end, onDone = function(why) table.insert(DONE, why) end }
  for k, v in pairs(extra or {}) do ctx[k] = v end
  return KIT.run(name, ctx)
end
function restored()
  local cam = workspace.CurrentCamera
  local char = LOCAL.Character
  local hum = char:FindFirstChildOfClass("Humanoid")
  return cam.CameraType == "CameraType.Custom" and cam.FieldOfView == 70 and hum.PlatformStand ~= true and not findGui("BarreHaut") and not findGui("PasserCinematique") and not KIT.isPlaying()
end
"""


class TestCinematicRuntime(unittest.TestCase):
    def boot(self):
        lua = make()
        lua.execute("runClient()")
        lua.execute("advance(2)")
        lua.execute(RUN)
        return lua

    def check(self, lua):
        self.assertEqual(errors(lua), [])
        self.assertEqual([w for w in warns(lua) if w.startswith("[Client]") or "[Cinematic]" in w], [])

    def test_every_plan_runs_ends_within_eight_seconds_and_restores_everything(self):
        for name in REQUIRED_PLANS:
            lua = self.boot()
            self.assertTrue(lua.eval('startPlan("%s")' % name), name)
            self.assertEqual(lua.eval("CAM.CameraType"), "CameraType.Scriptable")
            self.assertIsNotNone(lua.eval('findGui("BarreHaut")'), name)
            t0 = float(lua.eval("clock()"))
            lua.execute("advance(8.8)")
            self.assertTrue(lua.eval("restored()"), f"{name} : caméra ou personnage non restaurés")
            self.assertEqual(lua.eval("#DONE"), 1, name)
            self.assertLessEqual(float(lua.eval("clock()")) - t0, 9.0)
            self.check(lua)

    def test_skip_with_a_key_restores_immediately(self):
        lua = self.boot()
        lua.execute('startPlan("fuite_finale"); advance(1.5)')
        self.assertFalse(lua.eval("restored()"))
        lua.execute('keyDown("KeyCode.Space")')
        self.assertTrue(lua.eval("restored()"))
        self.assertEqual(str(lua.eval("DONE[1]")), "passée")
        lua.execute("advance(10)")
        self.assertEqual(lua.eval("#DONE"), 1, "passée puis terminée : une seule fois")
        self.check(lua)

    def test_skip_with_the_button(self):
        lua = self.boot()
        lua.execute('startPlan("porte_ouvre"); advance(1)')
        lua.execute('findGui("PasserCinematique").Activated:Fire()')
        self.assertTrue(lua.eval("restored()"))
        self.check(lua)

    def test_skip_during_every_shot(self):
        for at in (0.2, 2.6, 5.5):
            lua = self.boot()
            lua.execute('startPlan("fuite_finale"); advance(%s); KIT.skip()' % at)
            self.assertTrue(lua.eval("restored()"), at)
            self.check(lua)

    def test_two_cinematics_requested_together_only_the_first_plays(self):
        lua = self.boot()
        self.assertTrue(lua.eval('startPlan("porte_ouvre")'))
        self.assertFalse(lua.eval('startPlan("objet_precieux")'))
        lua.execute("advance(5)")
        self.assertTrue(lua.eval("restored()"))
        self.assertEqual(lua.eval("#DONE"), 1)
        self.assertTrue(lua.eval('startPlan("objet_precieux")'), "une nouvelle demande est possible ensuite")
        self.check(lua)

    def test_refused_when_the_player_is_in_danger(self):
        lua = self.boot()
        self.assertFalse(lua.eval('startPlan("porte_ouvre", { state = function() return { chasing = true, health = 100 } end })'))
        self.assertTrue(lua.eval("restored()"))
        self.assertFalse(lua.eval('startPlan("porte_ouvre", { state = function() return { monsterDistance = 4, health = 100 } end })'))
        self.assertFalse(lua.eval('startPlan("porte_ouvre", { state = function() return { health = 0 } end })'))

    def test_error_in_a_frame_restores(self):
        lua = self.boot()
        lua.execute('startPlan("apparition_monstre", { focus = function() error("cible perdue") end }); advance(2)')
        self.assertTrue(lua.eval("restored()"))
        self.assertEqual(errors(lua), [])

    def test_character_death_during_a_plan_restores(self):
        lua = self.boot()
        lua.execute('startPlan("porte_ouvre"); advance(1); LOCAL.Character:FindFirstChildOfClass("Humanoid").Died:Fire()')
        self.assertTrue(lua.eval("restored()"))
        self.assertEqual(str(lua.eval("DONE[1]")), "mort")

    def test_character_removed_during_a_plan_restores(self):
        lua = self.boot()
        lua.execute('startPlan("porte_ouvre"); advance(1); LOCAL.CharacterRemoving:Fire()')
        self.assertTrue(lua.eval("restored()"))

    def test_unknown_plan_and_missing_gui(self):
        lua = self.boot()
        self.assertFalse(lua.eval('startPlan("inconnu")'))
        self.assertFalse(lua.eval('startPlan("porte_ouvre", { gui = false })'))
        self.assertTrue(lua.eval("restored()"))

    def test_old_cinematic_system_and_kit_share_the_camera_politely(self):
        lua = self.boot()
        lua.execute('startPlan("porte_ouvre"); advance(1)')
        self.assertTrue(lua.eval("KIT.isPlaying()"))
        self.check(lua)


class TestVfxRuntime(unittest.TestCase):
    def boot(self):
        lua = make()
        lua.execute("runClient()")
        lua.execute("advance(2)")
        lua.execute('VFX = REQUIRE("src/shared/VfxKit.lua")')
        return lua

    def test_every_preset_plays_with_fallback_shapes_without_error(self):
        lua = self.boot()
        for name in ("aura_runique", "aura_ailes", "onde_de_choc", "pilier_revelation", "bouclier", "etincelles", "spirale_montee", "portail_torii", "lueur_enigme"):
            self.assertTrue(lua.eval('VFX.play("%s", Vector3.new(10, 5, 10), { quality = "haut", adornee = workspace })' % name), name)
            lua.execute("advance(4)")
        self.assertEqual(errors(lua), [])
        self.assertEqual([w for w in warns(lua) if not w.startswith(("[Boot]", "[Spawn]"))], [])

    def test_phone_never_runs_more_than_three_effects_at_once(self):
        lua = self.boot()
        started = [bool(lua.eval('VFX.play("aura_runique", Vector3.new(0, 0, 0), { quality = "bas" })')) for _ in range(6)]
        self.assertEqual(sum(started), 3)
        lua.execute("advance(5)")
        self.assertEqual(int(lua.eval("VFX.activeCount()")), 0, "les effets sont comptés puis libérés")
        self.assertTrue(lua.eval('VFX.play("aura_runique", Vector3.new(0, 0, 0), { quality = "bas" })'))

    def test_bad_arguments_never_raise(self):
        lua = self.boot()
        self.assertFalse(lua.eval('VFX.play("inconnu", Vector3.new(0, 0, 0), {})'))
        self.assertFalse(lua.eval('VFX.play("aura_runique", nil, {})'))
        self.assertFalse(lua.eval('VFX.play("aura_runique", "pas un point", nil)'))
        self.assertEqual(errors(lua), [])

    def test_effects_are_cleaned_up(self):
        lua = self.boot()
        lua.execute('VFX.play("onde_de_choc", Vector3.new(0, 0, 0), { quality = "haut" })')
        n = int(lua.execute('local k = 0 for _, d in ipairs(workspace:GetChildren()) do if string.sub(d.Name, 1, 4) == "Vfx_" then k = k + 1 end end return k'))
        self.assertEqual(n, 1)


class TestUiFx(unittest.TestCase):
    def boot(self):
        lua = make()
        lua.execute("runClient()")
        lua.execute("advance(2)")
        lua.execute('FX = REQUIRE("src/client/UiFx.lua") ; HUD = findGui("TombeHUD")')
        return lua

    def test_all_gestures_run_without_error(self):
        lua = self.boot()
        lua.execute(
            """
            local b = Instance.new("TextButton"); b.Parent = HUD
            local l = Instance.new("TextLabel"); l.Parent = HUD
            FX.bounceIn(b); FX.press(b); FX.shine(b); FX.floatText(HUD, "Trouvé"); FX.vignette(HUD); FX.pulseScreen(false); FX.pulseScreen(true)
            FX.countUp(l, 0, 5, 0.5, function(n) return "n=" .. n end)
            advance(3)
            LABEL = l
            """
        )
        self.assertEqual(errors(lua), [])
        self.assertEqual(str(lua.eval("LABEL.Text")), "n=5")

    def test_disabled_animations_do_nothing(self):
        lua = self.boot()
        lua.execute('REQUIRE("src/shared/Config.lua").Animations.Enabled = false')
        self.assertFalse(lua.eval('FX.bounceIn(HUD)'))
        self.assertFalse(lua.eval('FX.floatText(HUD, "x")'))
        self.assertFalse(lua.eval("FX.pulseScreen(false)"))

    def test_each_flag_cuts_its_own_gesture(self):
        lua = self.boot()
        for flag, call in (("UiBounce", "FX.bounceIn(HUD)"), ("UiPress", "FX.press(HUD)"), ("UiShine", "FX.shine(HUD)"), ("UiFloat", 'FX.floatText(HUD, "x")'), ("UiPulse", "FX.vignette(HUD)")):
            lua.execute('REQUIRE("src/shared/Config.lua").Animations.%s = false' % flag)
            self.assertFalse(lua.eval(call), flag)
            lua.execute('REQUIRE("src/shared/Config.lua").Animations.%s = true' % flag)


class TestWiring(unittest.TestCase):
    def test_client_triggers_effects_plans_and_ui(self):
        client = read("src", "client", "init.client.lua")
        for needle in ('playVfx("aura_runique"', 'playVfx("onde_de_choc"', 'runPlan("reveil_cercueil")', 'runPlan("apparition_monstre"', 'runPlan("fuite_finale")', "PLAN_FOR_STEP", "UiFx.bounceIn", "UiFx.press", "UiFx.shine", "UiFx.countUp", "UiFx.floatText", "lueur_enigme", "spirale_montee"):
            self.assertIn(needle, client)

    def test_reveal_carries_the_finished_step(self):
        self.assertIn("step = lastStepSeen", read("src", "server", "Quests.lua"))

    def test_catalogue_exists_and_lists_every_preset_and_plan(self):
        doc = read("ANIMATIONS.md")
        for name in REQUIRED_PRESETS + REQUIRED_PLANS:
            self.assertIn(name, doc)


if __name__ == "__main__":
    unittest.main()
