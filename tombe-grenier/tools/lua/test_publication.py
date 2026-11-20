#!/usr/bin/env python3
"""PUBLICATION.md : limites de la fiche (description courte 100 caractères, longue 1000) et sections obligatoires."""
import os
import re
import unittest

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


class TestPublication(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(ROOT, "PUBLICATION.md"), encoding="utf-8") as f:
            self.doc = f.read()

    def quote(self, title):
        m = re.search(re.escape(title) + r".*?:\n((?:>.*\n)+)", self.doc)
        self.assertIsNotNone(m, title)
        return re.sub(r"^> ?", "", m.group(1), flags=re.M).strip()

    def test_short_description_limit(self):
        self.assertLessEqual(len(self.quote("**Description courte**")), 100)

    def test_long_description_limit(self):
        self.assertLessEqual(len(self.quote("**Description longue**")), 1000)

    def test_five_hooks_and_sections(self):
        hooks = re.findall(r"^\d\. « .* »$", self.doc, flags=re.M)
        self.assertEqual(len(hooks), 5)
        for part in ("Avertissement", "questionnaire de maturité", "Tableau d'audit", "Checklist avant passage en public"):
            self.assertIn(part, self.doc)

    def test_every_audit_proof_exists(self):
        tests = set(re.findall(r"`(test_\w+\.py)`", self.doc))
        for t in tests:
            self.assertTrue(os.path.exists(os.path.join(ROOT, "tools", "lua", t)), t)


if __name__ == "__main__":
    unittest.main()
