#!/usr/bin/env python3
"""Ajoute les éléments de quête au générateur : papier du code, fausses clés, documents,
coffret à bijoux, malle, plaque du cercueil. Script ponctuel, déjà appliqué."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "generate_map.py")

NOTE_BLOCK = '''NOTE_SLOTS = [
    _s("grenier, étagère ouest", (2.5, 32.1, 6), (0.6, 0.1, 0.8)),
    _s("chambre des parents, chevet", (2.5, 14.1, 6.5), (0.6, 0.1, 0.8)),
    _s("cuisine, îlot", (92, 3.1, 16), (0.6, 0.1, 0.8)),
    _s("cave, étagère", (45.5, -4.9, 63), (0.6, 0.1, 0.8)),
    _s("chambre d'enfant, bureau", (88, 15.1, 11), (0.6, 0.1, 0.8)),
]

DECOY_KEY_SLOTS = [
    _s("salle à manger, buffet", (3.5, 5.1, 84), (0.8, 0.1, 0.5)),
    _s("cuisine, placards", (115.5, 7.1, 28), (0.8, 0.1, 0.5)),
    _s("cave, caisses", (66, -8.9, 79), (0.8, 0.1, 0.5)),
]

'''

LORE_BLOCK = '''# Documents de l'histoire (lecture seule, sans logique au-delà de la quête)
INTERACTABLE_SLOTS["journal"].append(_i("journal intime", "chambre des parents, commode", (36, 15.1, 15), (1, 0.2, 1.4)))
INTERACTABLE_SLOTS["cahier"] = [
    _i("cahier d'écolier", "chambre d'enfant, bureau", (89, 15.1, 8), (0.8, 0.2, 1.1)),
    _i("cahier d'écolier", "chambre d'ami, bureau", (25, 14.6, 57), (0.8, 0.2, 1.1)),
    _i("cahier d'écolier", "couloir, console", (49, 15.1, 81.5), (0.8, 0.2, 1.1)),
]
INTERACTABLE_SLOTS["photo_famille"] = [
    _i("photo de famille", "salon, cheminée", (34, 5.1, 4), (1.2, 0.1, 1.0)),
    _i("photo de famille", "bibliothèque du bureau", (116, 8.1, 53), (1.2, 0.1, 1.0)),
    _i("photo de famille", "palier, vitrine", (76, 19.1, 33), (1.2, 0.1, 1.0)),
]

'''

FIXED_PROPS = '''    # Éléments fixes de l'histoire : coffret à code, plaque du cercueil, malle et sa clé
    props.append(dict(tag="Coffret", name="coffret à bijoux", pos=(95, 27.1, 73), size=(1.6, 0.8, 1.2)))
    props.append(dict(tag="Plaque", name="plaque du cercueil", pos=(90, 26.1, 42.5), size=(2.2, 0.8, 0.2)))
    props.append(dict(tag="Key", name="clé rouillée (malle)", pos=(70, 27.3, 64), size=(0.8, 0.1, 0.5)))

'''


def cut_block(src, start_marker):
    """Supprime le bloc « NAME = [ ... ]\\n\\n » qui commence par start_marker."""
    a = src.index(start_marker)
    b = src.index("\n]\n", a) + len("\n]\n")
    if src[b:b + 1] == "\n":
        b += 1
    return src[:a] + src[b:]


def main():
    src = open(PATH, encoding="utf-8").read()

    # a) suppression des anciennes clés aléatoires, remplacées par la clé de la malle
    src = cut_block(src, "KEY_SLOTS = [")

    # b) papier du code et fausses clés, avant les piles
    marker = "BATTERY_SLOTS = ["
    src = src.replace(marker, NOTE_BLOCK + marker, 1)

    # c) documents, avant la zone des pièces sombres
    marker = "# Pièces qui peuvent être plongées dans le noir"
    src = src.replace(marker, LORE_BLOCK + marker, 1)

    # d) éléments fixes, avant la porte d'entrée
    marker = "    # Porte d'entrée (bloquante"
    src = src.replace(marker, FIXED_PROPS + marker, 1)

    # e) slots exportés
    old = "photo=PHOTO_SLOTS, key=KEY_SLOTS, battery=BATTERY_SLOTS"
    assert src.count(old) == 1, "slots : motif introuvable"
    src = src.replace(old, "photo=PHOTO_SLOTS, note=NOTE_SLOTS, decoy=DECOY_KEY_SLOTS, battery=BATTERY_SLOTS")

    open(PATH, "w", encoding="utf-8").write(src)
    print("patched", PATH)


if __name__ == "__main__":
    main()
