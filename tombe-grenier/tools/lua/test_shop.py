#!/usr/bin/env python3
"""Boutique : catalogue cohérent avec Config.Shop, tout désactivé tant que les identifiants valent 0, aucun achat ne plante."""

import os
import re
import unittest

ROOT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
)


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


class TestShop(unittest.TestCase):
    def setUp(self):
        self.cfg = read("src", "shared", "Config.lua")
        self.block = self.cfg[
            self.cfg.index("Config.Shop = {") : self.cfg.index("Config.Flashlight")
        ]

    def table(self, name):
        body = re.search(name + r" = \{([^}]*)\}", self.block).group(1)
        return dict(re.findall(r"(\w+) = (\d+)", body))

    def test_every_id_is_zero_by_default(self):
        for name in ("GamePasses", "Products"):
            ids = self.table(name)
            self.assertTrue(ids)
            self.assertEqual(
                set(ids.values()),
                {"0"},
                "un identifiant non nul active un achat : à renseigner par l'utilisateur",
            )

    def test_catalogue_matches_ids_with_price_name_description_icon(self):
        passes, products = self.table("GamePasses"), self.table("Products")
        entries = re.findall(
            r'key = "(\w+)",\s*kind = "(\w+)",\s*name = "([^"]+)",\s*description = "([^"]+)",\s*price = (\d+),\s*icon = "([^"]+)"',
            self.block,
        )
        self.assertGreaterEqual(len(entries), 5)
        keys = []
        for key, kind, name, desc, price, icon in entries:
            keys.append(key)
            self.assertIn(key, passes if kind == "pass" else products)
            self.assertGreater(int(price), 0)
            self.assertTrue(icon.endswith(".png"))
            self.assertGreater(len(desc), 20)
        self.assertEqual(
            sorted(keys),
            sorted(list(passes) + list(products)),
            "article sans entrée de catalogue",
        )

    def test_disabled_items_cannot_be_requested_and_never_error(self):
        shop = read("src", "server", "Shop.lua")
        self.assertIn('if typeof(id) == "number" and id ~= 0 then', shop)
        self.assertIn("if not entry then\n\t\treturn false", shop)
        self.assertIn('pcall(function()\n\t\tif entry.kind == "pass"', shop)
        self.assertIn('guarded("Buy"', read("src", "server", "init.server.lua"))

    def test_products_not_sold_in_the_hub(self):
        self.assertIn(
            'entry.kind == "product" and Hub.role() == "hub"',
            read("src", "server", "Shop.lua"),
        )

    def test_client_shows_nothing_without_ids(self):
        client = read("src", "client", "init.client.lua")
        self.assertIn("if #shopItems > 0 then", client)
        self.assertIn("ids[entry.key] ~= 0", client)

    def test_cosmetic_pass_has_no_gameplay_effect(self):
        state = read("src", "server", "PlayerState.lua")
        self.assertIn('LampSkin") == "or"', state)
        self.assertIn("beam.Color", state)

    def test_publication_docs_list_every_item(self):
        pub = read("PUBLICATION.md")
        todo = read("A_FAIRE_UTILISATEUR.md")
        for key in ("LampeRenforcee", "LanterneDoree", "Pile", "Cailloux", "Soutien"):
            self.assertIn(key, pub, key)
            self.assertIn(key, todo, key)
        for size in ("1920×1080", "512×512"):
            self.assertIn(size, pub)


if __name__ == "__main__":
    unittest.main()
