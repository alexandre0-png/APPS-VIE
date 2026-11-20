"""Exécute les VRAIS scripts client dans un faux client Roblox complet : toute erreur d'exécution, même absorbée par
l'isolation `[Client] module X : erreur`, fait échouer le test."""
import unittest

from client_env import errors, make, warns

EVENTS = [
    ("HUD", {"sanity": 80, "stamina": 50, "battery": 0.5, "phase": "play"}),
    ("Inventory", {"photos": 1, "photosRequired": 3, "hasKey": True, "smallKey": True, "caveKey": False, "docs": 2, "docsTotal": 5}),
    ("Hint", {"text": "Cherche la clé"}),
    ("Objective", {"text": "Trouve les photos"}),
    ("Journal", {"lines": ["Entrée 1", "Entrée 2"]}),
    ("Message", {"text": "Bonjour"}),
    ("Flashback", {"kind": "enfant"}),
    ("Keypad", None),
    ("Effect", {"kind": "Hit"}),
    ("Effect", {"kind": "Scare"}),
    ("Effect", {"kind": "Read"}),
    ("Effect", {"kind": "Cine", "name": "apparition"}),
    ("Effect", {"kind": "Intro"}),
    ("Effect", {"kind": "Blackout", "duration": 1}),
    ("Effect", {"kind": "RoundEnd", "reason": "win", "text": "Fini"}),
    ("Effect", {"kind": "RoundEnd", "reason": "caught", "text": "Perdu"}),
]
KEYS = ["LeftControl", "LeftShift", "F", "C", "H", "J", "G", "U", "Escape"]


def boot():
    lua = make()
    lua.execute("runClient()")
    lua.execute("advance(3)")
    return lua


def fire(lua, name, payload):
    g = lua.globals()
    if payload is None:
        lua.execute('serverFire("%s", nil)' % name)
    else:
        g._p = lua.table_from(payload) if isinstance(payload, dict) else payload
        lua.execute('serverFire("%s", _p)' % name)


class TestRealClient(unittest.TestCase):
    def check(self, lua):
        bad = errors(lua) + [w for w in warns(lua) if "[Client]" in w or "INFINITE" in w]
        self.assertEqual(bad, [], "\n".join(bad[:5]))

    def test_boot_builds_the_hud_without_error(self):
        lua = boot()
        self.check(lua)
        self.assertGreater(int(lua.eval("guiCount()")), 10)
        self.assertIsNotNone(lua.eval('findGui("TombeHUD")'))

    def test_every_server_event_is_handled(self):
        lua = boot()
        for name, payload in EVENTS:
            fire(lua, name, payload)
            lua.execute("advance(1)")
        self.check(lua)

    def test_malformed_payloads_never_crash(self):
        lua = boot()
        for name in ("HUD", "Inventory", "Hint", "Objective", "Journal", "Message", "Effect", "Flashback"):
            for bad in ("'x'", "42", "true", "{}", "nil"):
                lua.execute('serverFire("%s", %s)' % (name, bad))
        lua.execute("advance(2)")
        self.check(lua)

    def test_inputs_and_long_run(self):
        lua = boot()
        for k in KEYS:
            lua.execute('keyDown("Enum.KeyCode.%s")' % k)
            lua.execute("advance(0.3)")
            lua.execute('keyUp("Enum.KeyCode.%s")' % k)
        lua.execute("advance(60)")
        self.check(lua)

    def test_broken_style_modules_never_block_the_hud(self):
        lua = make()
        real = lua.globals().READ

        def broken(path):
            if path.endswith(("Theme.lua", "UiStyle.lua", "Zones.lua", "Opening.lua", "Reveal.lua")):
                return "error('module cassé')"
            return real(path)

        lua.globals().READ = broken
        lua.execute("runClient()")
        lua.execute("advance(5)")
        self.assertEqual(errors(lua), [])
        self.assertTrue(any("[Client] module Theme" in w for w in warns(lua)), warns(lua))
        self.assertIsNotNone(lua.eval('findGui("TombeHUD")'))
        fire(lua, "HUD", {"sanity": 50})
        lua.execute("advance(2)")
        self.assertEqual(errors(lua), [])

    def test_objective_arrow_follows_the_server_target(self):
        lua = boot()
        lua.execute("LOCAL:SetAttribute('ObjectiveTarget', Vector3.new(20, 27, 45))")
        lua.execute("advance(1)")
        arrow = lua.eval('findGui("FlecheObjectif")')
        self.assertIsNotNone(arrow)
        self.assertTrue(arrow.Visible)
        lua.execute("LOCAL:SetAttribute('ObjectiveTarget', nil)")
        lua.execute("advance(1)")
        self.assertFalse(arrow.Visible)
        self.check(lua)

    def test_a_failing_handler_is_isolated(self):
        lua = boot()
        # un gestionnaire qui lève une erreur ne bloque pas le suivant
        lua.execute('serverFire("Effect", { kind = "Cine", name = 12 })')
        lua.execute("advance(1)")
        fire(lua, "HUD", {"sanity": 50})
        lua.execute("advance(1)")
        self.assertEqual(errors(lua), [])
        self.assertIsNotNone(lua.eval('findGui("TombeHUD")'))


if __name__ == "__main__":
    unittest.main()
