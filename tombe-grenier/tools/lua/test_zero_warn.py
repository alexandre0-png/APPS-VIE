#!/usr/bin/env python3
"""Zéro message d'erreur : 4 minutes virtuelles d'une partie duo (serveur réel) et du client réel ; tout `warn(` ou
`error(` inattendu fait échouer la batterie. Seules les traces [Boot] et [Spawn] sont tolérées."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_boot_async as boot  # noqa: E402
import test_client as client  # noqa: E402
from client_env import errors as c_errors  # noqa: E402
from client_env import warns as c_warns  # noqa: E402

ALLOWED = ("[Boot]", "[Spawn]")
WARN_HOOK = """WARNLOG = {}
warn = function(...) local a = {} for i = 1, select("#", ...) do a[i] = tostring((select(i, ...))) end table.insert(WARNLOG, table.concat(a, " ")) end"""


def unexpected(messages):
    return [m for m in messages if not m.startswith(ALLOWED)]


class TestZeroWarn(unittest.TestCase):
    def duo(self, load_asset):
        lua = boot.server(load_asset)
        lua.execute(WARN_HOOK)
        lua.execute("SWALLOW = true; advance(20); join(newPlayer('alice')); join(newPlayer('bob')); advance(240)")
        return lua

    def collect(self, lua):
        out = [str(lua.eval("WARNLOG[%d]" % i)) for i in range(1, int(lua.eval("#WARNLOG")) + 1)]
        out += [str(lua.eval("ERRORS[%d]" % i)) for i in range(1, int(lua.eval("#ERRORS")) + 1)]
        return out

    def test_duo_without_any_model(self):
        bad = unexpected(self.collect(self.duo("return nil")))
        self.assertEqual(bad, [], "\n".join(bad[:5]))

    def test_duo_with_every_model_loaded(self):
        stub = 'local m = Instance.new("Model"); m.Name = "X"; local p = Instance.new("Part"); p.Size = Vector3.new(2, 2, 2); p.Parent = m; local c = Instance.new("Model"); m.Parent = c; return c'
        bad = unexpected(self.collect(self.duo(stub)))
        self.assertEqual(bad, [], "\n".join(bad[:5]))

    def test_client_four_minutes(self):
        lua = client.boot()
        for name, payload in client.EVENTS:
            client.fire(lua, name, payload)
            lua.execute("advance(2)")
        lua.execute("advance(240)")
        bad = unexpected(c_warns(lua)) + c_errors(lua)
        self.assertEqual(bad, [], "\n".join(bad[:5]))


if __name__ == "__main__":
    unittest.main()
