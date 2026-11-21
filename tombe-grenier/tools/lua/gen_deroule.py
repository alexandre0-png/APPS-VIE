#!/usr/bin/env python3
"""Génère docs/DEROULE.md à partir de src/shared/Chain.lua et src/shared/Deroule.lua (une seule source de vérité).

Usage : python3 tools/lua/gen_deroule.py        (écrit docs/DEROULE.md)
Le test test_deroule.py vérifie que le fichier est à jour."""

import os

import sys

from lupa.lua54 import LuaRuntime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_syntax import to_lua54  # noqa: E402

ROOT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
)
OUT = os.path.join(ROOT, "docs", "DEROULE.md")


def load():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        "local RS = {Shared = {}} ; game = {GetService = function() return {WaitForChild = function() return RS.Shared end} end}"
    )
    lua.globals().READ = lambda p: open(
        os.path.join(ROOT, *p.split("/")), encoding="utf-8"
    ).read()
    chain = lua.execute(
        to_lua54(
            open(
                os.path.join(ROOT, "src", "shared", "Chain.lua"), encoding="utf-8"
            ).read()
        )
    )
    lua.globals().CHAIN = chain
    lua.execute(
        "game = {GetService = function() return {WaitForChild = function() return {Chain = CHAIN} end} end}"
    )
    # Deroule fait require(Shared.Chain) : require retourne le module déjà chargé
    lua.execute(
        "local real = require; require = function(m) if m == CHAIN then return CHAIN end return real(m) end"
    )
    deroule = lua.execute(
        to_lua54(
            open(
                os.path.join(ROOT, "src", "shared", "Deroule.lua"), encoding="utf-8"
            ).read()
        )
    )
    return chain, deroule, lua


def render():
    chain, deroule, _ = load()
    lines = [
        "# Déroulé de la partie, pièce par pièce",
        "",
        "Fichier généré par `python3 tools/lua/gen_deroule.py` à partir de `src/shared/Chain.lua` et `src/shared/Deroule.lua` ;",
        "ne pas l'éditer à la main (le test `test_deroule.py` vérifie qu'il est à jour).",
        "",
        "Règle : une seule étape est active à la fois, dans l'ordre. Chaque passage reste fermé (trappe, porte, cave) avec le message",
        "« Verrouillé : il te manque … » tant que la dernière étape de sa pièce n'est pas faite. Les objets des étapes futures sont inertes",
        "(invites masquées). Sans progrès pendant 90 s, l'indice de l'étape s'affiche tout seul.",
        "",
        "## Étapes",
        "",
        "| # | Pièce | Objectif (barre du haut) | Objet clé | Passage ouvert | Indice (H) | Voix |",
        "|---|---|---|---|---|---|---|",
    ]
    for i in range(1, len(chain.STEPS) + 1):
        step = chain.STEPS[i]
        info = deroule.STEPS[step.id]
        lines.append(
            f"| {i} | {info.room} | {step.objective} | {info.key} | {info.opens or '—'} | {step.hint} | {info.voice or '—'} |"
        )
    lines += [
        "",
        "## Parties de la maison",
        "",
        "| Partie | Pièces (MapData) | Étapes |",
        "|---|---|---|",
    ]
    for i in range(1, len(deroule.STAGES) + 1):
        stage = deroule.STAGES[i]
        rooms = ", ".join(stage.rooms[j] for j in range(1, len(stage.rooms) + 1))
        steps = ", ".join(stage.steps[j] for j in range(1, len(stage.steps) + 1))
        lines.append(f"| {stage.name} | {rooms} | {steps} |")
    lines += [
        "",
        "## Passages verrouillés",
        "",
        "| Passage | S'ouvre à la fin de l'étape | Message |",
        "|---|---|---|",
    ]
    for gid in ("grenier", "premier", "rez", "cave"):
        gate = deroule.GATES[gid]
        lines.append(f"| {gate.name} | {gate.opensAt} | {gate.text} |")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(render())
    print("écrit", OUT)
