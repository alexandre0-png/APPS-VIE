#!/usr/bin/env python3
"""Mobile : le vrai client est exécuté sur 4 tailles d'écran simulées ; aucun élément fixe ne dépasse l'écran et les
boutons tactiles ne se chevauchent pas et mesurent au moins 44 px."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from client_env import errors, make  # noqa: E402

SIZES = {"téléphone paysage 640x360": (640, 360), "grand téléphone 844x390": (844, 390), "tablette 1024x768": (1024, 768), "grande tablette 1366x1024": (1366, 1024)}

MEASURE = r"""
function measure(W, H)
  local hud = findGui("TombeHUD")
  local rects, buttons = {}, {}
  for _, d in ipairs(hud:GetDescendants()) do
    local isGui = d.ClassName == "TextButton" or d.ClassName == "TextLabel" or d.ClassName == "Frame" or d.ClassName == "ImageLabel"
    if isGui and d.Size and d.Position then
      local s = 1
      for _, c in ipairs(d:GetChildren()) do if c.ClassName == "UIScale" then s = c.Scale end end
      local par = d.Parent
      local pw, ph = W, H
      -- un parent non plein écran change la référence : on ne mesure que les enfants directs du HUD
      if par == hud then
        local w = d.Size.X.Scale * pw + d.Size.X.Offset * s
        local h = d.Size.Y.Scale * ph + d.Size.Y.Offset * s
        local ax, ay = d.AnchorPoint.X, d.AnchorPoint.Y
        local x = d.Position.X.Scale * pw + d.Position.X.Offset - ax * w
        local y = d.Position.Y.Scale * ph + d.Position.Y.Offset - ay * h
        local r = { name = d.Name .. ":" .. tostring(d.Text or ""), x = x, y = y, w = w, h = h, button = d.ClassName == "TextButton", class = d.ClassName }
        table.insert(rects, r)
      end
    end
  end
  return rects
end
"""


def rects(W, H):
    lua = make()
    lua.execute("workspace.CurrentCamera.ViewportSize = Vector2.new(%d, %d)" % (W, H))
    lua.execute("runClient()")
    lua.execute("advance(3)")
    lua.execute(MEASURE)
    assert errors(lua) == [], errors(lua)
    out = []
    r = lua.eval("measure(%d, %d)" % (W, H))
    for i in range(1, len(r) + 1):
        e = r[i]
        out.append({"name": str(e.name), "x": e.x, "y": e.y, "w": e.w, "h": e.h, "button": bool(e.button)})
    return out


def overlap(a, b):
    return a["x"] < b["x"] + b["w"] - 0.5 and b["x"] < a["x"] + a["w"] - 0.5 and a["y"] < b["y"] + b["h"] - 0.5 and b["y"] < a["y"] + a["h"] - 0.5


class TestLayout(unittest.TestCase):
    def test_no_fixed_element_leaves_the_screen(self):
        for label, (W, H) in SIZES.items():
            for r in rects(W, H):
                if r["w"] >= W * 0.98 and r["h"] >= H * 0.98:
                    continue  # voile plein écran
                if r["name"].startswith("Document"):
                    continue  # feuille de lecture : part volontairement du bas de l'écran (animation)
                self.assertGreaterEqual(r["x"], -1, f"{label} : {r['name']} dépasse à gauche")
                self.assertGreaterEqual(r["y"], -1, f"{label} : {r['name']} dépasse en haut")
                self.assertLessEqual(r["x"] + r["w"], W + 1, f"{label} : {r['name']} dépasse à droite")
                self.assertLessEqual(r["y"] + r["h"], H + 1, f"{label} : {r['name']} dépasse en bas")

    def test_touch_buttons_do_not_overlap_and_are_big_enough(self):
        for label, (W, H) in SIZES.items():
            buttons = [r for r in rects(W, H) if r["button"] and r["w"] < 200]
            self.assertGreaterEqual(len(buttons), 6, label)
            for r in buttons:
                self.assertGreaterEqual(r["w"], 44, f"{label} : {r['name']} trop étroit ({r['w']:.0f})")
                self.assertGreaterEqual(r["h"], 44, f"{label} : {r['name']} trop bas ({r['h']:.0f})")
            for i, a in enumerate(buttons):
                for b in buttons[i + 1 :]:
                    self.assertFalse(overlap(a, b), f"{label} : « {a['name']} » chevauche « {b['name']} »")


if __name__ == "__main__":
    unittest.main()
