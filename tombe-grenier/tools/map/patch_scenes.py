#!/usr/bin/env python3
"""Ajoute les éléments fixes des scènes : miroirs, télévision, photo d'introduction.
Script ponctuel, déjà appliqué à generate_map.py."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "generate_map.py")

FIXED = '''    # Éléments de scène fixes : miroir inquiétant (tombe), miroir fissuré (salle de bain),
    # télévision (salon), photo d'introduction (au-dessus du cercueil)
    props.append(dict(tag="Mirror", name="miroir inquiétant", pos=(119.2, 31, 30), size=(0.4, 6, 4)))
    props.append(dict(tag="Mirror", name="miroir fissuré", pos=(119.2, 17.5, 56), size=(0.4, 3, 3)))
    props.append(dict(tag="TV", name="télévision", pos=(13, 4.2, 33.4), size=(4, 2.4, 0.3)))
    props.append(dict(tag="IntroPhoto", name="photo de l'introduction", pos=(90, 30, 45), size=(1, 0.1, 1.4)))

'''


def main():
    src = open(PATH, encoding="utf-8").read()
    marker = "    # Porte d'entrée (bloquante"
    assert src.count(marker) == 1
    if "miroir inquiétant" not in src:
        src = src.replace(marker, FIXED + marker, 1)
    open(PATH, "w", encoding="utf-8").write(src)
    print("patched", PATH)


if __name__ == "__main__":
    main()
