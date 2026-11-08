#!/usr/bin/env python3
"""Remplace les emplacements fixes d'objets par des listes de candidats (emplacements variables).
Script ponctuel : déjà appliqué à generate_map.py, conservé pour l'historique. Ne pas relancer."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "generate_map.py")

NEW_PROPS = '''# ----------------------------------------------------------------------------
# Emplacements variables : chaque partie en tire un sous-ensemble (voir Luau MapBuilder.placeRound).
# Chaque emplacement = point posé sur un meuble (y = dessus) ou sur le sol.
# ----------------------------------------------------------------------------
def _s(name, pos, size=(1, 1, 1)):
    return dict(name=name, pos=pos, size=size)


def _i(kind, name, pos, size=(1, 1, 1)):
    return dict(kind=kind, name=name, pos=pos, size=size)


PHOTO_SLOTS = [
    _s("salon, table basse", (13, 1.6, 19), (1.4, 0.1, 1.0)),
    _s("grenier, table", (36, 27.1, 15), (1.4, 0.1, 1.0)),
    _s("couloir, table ronde", (62, 14.6, 62), (1.4, 0.1, 1.0)),
    _s("chambre d'ami, bureau", (29, 14.6, 54), (1.4, 0.1, 1.0)),
    _s("chambre des parents, chevet", (2.5, 14.1, 7), (1.4, 0.1, 1.0)),
    _s("chambre d'enfant, bureau", (90, 15.1, 9), (1.4, 0.1, 1.0)),
    _s("salle à manger, table", (15, 2.6, 65), (1.4, 0.1, 1.0)),
    _s("cuisine, îlot", (94, 3.1, 18), (1.4, 0.1, 1.0)),
    _s("salle de la tombe, table ronde", (95, 27.1, 73), (1.4, 0.1, 1.0)),
    _s("cave, barriques", (65, -8.9, 7), (1.4, 0.1, 1.0)),
    _s("cave, établi", (69, -8.9, 62), (1.4, 0.1, 1.0)),
    _s("cellier, tonneau", (28, -8.9, 72), (1.4, 0.1, 1.0)),
]

KEY_SLOTS = [
    _s("grenier, tiroir de la commode", (19, 28.1, 4), (0.8, 0.1, 0.5)),
    _s("chambre des parents, commode", (34, 15.1, 14), (0.8, 0.1, 0.5)),
    _s("salle à manger, buffet", (3.5, 5.1, 84), (0.8, 0.1, 0.5)),
    _s("cuisine, placards", (115.5, 7.1, 28), (0.8, 0.1, 0.5)),
    _s("cave, caisses", (66, -8.9, 79), (0.8, 0.1, 0.5)),
]

BATTERY_SLOTS = [
    _s("palier, console", (67, 15.2, 5.5), (0.6, 0.5, 0.4)),
    _s("cuisine, plan de travail", (109, 2.6, 18), (0.6, 0.5, 0.4)),
    _s("grenier, caisses", (12, 28.1, 64), (0.6, 0.5, 0.4)),
    _s("chambre des parents, sol", (10, 0.1, 32), (0.6, 0.5, 0.4)),
]

FALL_SLOTS = [
    _s("grenier, étagère ouest", (3, 32, 8)),
    _s("grenier, étagère nord", (3, 32, 24)),
    _s("palier, lampadaire", (45, 20, 5)),
    _s("cave, étagère est", (46, -4, 60)),
    _s("cave, étagère sud", (75, -4, 25)),
    _s("cellier, étagère", (5, -4, 60)),
]

SPAWN_SLOTS = [
    _s("grenier, bout sud", (30, 25.5, 85), (2, 1, 2)),
    _s("grenier, centre ouest", (20, 25.5, 35), (2, 1, 2)),
    _s("grenier, bord ouest", (8, 25.5, 50), (2, 1, 2)),
]

INTERACTABLE_SLOTS = {
    "journal": [
        _i("journal intime", "grenier, table", (34, 27.2, 11), (1, 0.2, 1.4)),
        _i("journal intime", "salon, table basse", (14, 1.6, 20), (1, 0.2, 1.4)),
    ],
    "bougies": [
        _i("bougies et lampe à pétrole", "grenier, table", (30, 27.6, 14), (0.6, 0.8, 0.6)),
        _i("bougies et lampe à pétrole", "couloir, table ronde", (60, 14.6, 60), (0.6, 0.8, 0.6)),
        _i("bougies et lampe à pétrole", "cave, établi", (72, -8.6, 61.5), (0.6, 0.8, 0.6)),
    ],
    "peluche": [
        _i("peluche ancienne", "grenier, lit d'enfant", (25, 27.2, 71), (1, 1.4, 1)),
        _i("peluche ancienne", "chambre d'enfant, lit", (102, 14.7, 8), (1, 1.4, 1)),
        _i("peluche ancienne", "chambre d'ami, lit", (11, 14.7, 56), (1, 1.4, 1)),
    ],
    "gramophone": [
        _i("gramophone ancien", "grenier, table", (47, 27.2, 73), (1.4, 1.2, 1.4)),
        _i("gramophone ancien", "palier, console", (67, 15.2, 5.5), (1.4, 1.2, 1.4)),
    ],
}

# Pièces qui peuvent être plongées dans le noir. Le hall, l'entrée, le palier, le grenier et la
# tombe restent éclairés : ce sont les passages obligés.
DARK_ELIGIBLE = ["pn", "cave", "ps", "cel", "salon", "cuis", "sam", "bureau",
                 "chp", "che", "cha", "couloir", "sdb", "deb"]
DARK_COUNT = 4

# Décor : tapis et tableaux (non collisionnables)
DECOR = [
    box(10, 30, 0, 0.05, 24, 34, "tissu", "tapis salon", deco=True),
    box(17, 23, 4, 8, 0.8, 1.2, "bois_sombre", "tableau salon", deco=True),
    box(8, 30, 12, 12.05, 20, 34, "tissu", "tapis chambre des parents", deco=True),
    box(10, 16, 16, 20, 0.8, 1.2, "bois_sombre", "tableau chambre des parents", deco=True),
    box(62, 68, 16, 20, 0.8, 1.2, "bois_sombre", "tableau palier", deco=True),
    box(30, 36, 28, 32, 0.8, 1.2, "bois_sombre", "tableau grenier", deco=True),
]


def build_props():
    props = []
    # Repères de patrouille : centre de chaque pièce et de chaque porte intérieure
    for rid, lv, rect, *_ in ROOMS:
        cx, cz = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
        props.append(dict(tag="Waypoint", name="wp " + rid, pos=(cx, BASE[lv] + 0.5, cz), size=(1, 1, 1)))
    for d in DOORS:
        if d.get("front"):
            continue
        b = BASE[d["level"]]
        x, z = (d["line"], d["c"]) if d["orient"] == "v" else (d["c"], d["line"])
        props.append(dict(tag="Waypoint", name="wp porte", pos=(x, b + 0.5, z), size=(1, 1, 1)))

    # Une lampe par pièce ; l'allumage et la couleur sont tirés à chaque partie
    for rid, lv, rect, *_ in ROOMS:
        cx, cz = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
        props.append(dict(tag="Lamp", room=rid, name="lampe " + rid,
                          pos=(cx, BASE[lv] + H - 1.5, cz), size=(1, 1, 1)))

    # Porte d'entrée (bloquante jusqu'à l'ouverture de la sortie)
    props.append(dict(tag="ExitDoor", name="porte principale", pos=(60, 5, 90), size=(FRONT_DOOR_W, 10, 0.6)))

    # Murs invisibles : périmètre du jardin, portail (énigme), grille du sous-sol (énigme)
    inv = []
    inv.append(dict(name="clôture nord", x0=-60.5, x1=180.5, z0=-60.5, z1=-59.5, y0=-1, y1=30))
    inv.append(dict(name="clôture sud ouest", x0=-60.5, x1=55, z0=149.5, z1=150.5, y0=-1, y1=30))
    inv.append(dict(name="clôture sud est", x0=65, x1=180.5, z0=149.5, z1=150.5, y0=-1, y1=30))
    inv.append(dict(name="clôture ouest", x0=-60.5, x1=-59.5, z0=-60, z1=150, y0=-1, y1=30))
    inv.append(dict(name="clôture est", x0=179.5, x1=180.5, z0=-60, z1=150, y0=-1, y1=30))
    inv.append(dict(name="portail", x0=55, x1=65, z0=149.5, z1=150.5, y0=-1, y1=30, puzzle="portail"))
    inv.append(dict(name="grille sud", x0=79.5, x1=80.5, z0=43, z1=47, y0=-12, y1=-1, puzzle="grille"))
    return props, inv


'''

NEW_BUILD = '''def build():
    walls, slabs = [], []
    for lv in LEVELS:
        walls += wall_pieces(lv)
        slabs += floor_slabs(lv)
    slabs += roof()
    props, inv = build_props()
    plates, path, trees = garden()
    return dict(
        walls=walls, slabs=slabs, steps=stair_steps(), furniture=furniture_boxes(),
        decor=DECOR, hiding=hiding_spots(), props=props, invisible=inv,
        garden=dict(plates=plates, path=path, trees=trees),
        spawn=dict(pos=(90, BASE["attic"] + 0.5, 45), size=(4, 1, 4)),
        slots=dict(photo=PHOTO_SLOTS, key=KEY_SLOTS, battery=BATTERY_SLOTS, fall=FALL_SLOTS,
                   monster=SPAWN_SLOTS, interactable=INTERACTABLE_SLOTS,
                   dark_eligible=DARK_ELIGIBLE, dark_count=DARK_COUNT),
        rooms=[dict(id=r[0], level=r[1], x0=r[2][0], z0=r[2][1], x1=r[2][2], z1=r[2][3], name=r[5])
               for r in ROOMS],
        base=BASE, H=H, stair=STAIR,
    )


'''


def main():
    src = open(PATH, encoding="utf-8").read()
    a = src.index("def build_props():")
    b = src.index("def garden():")
    src = src[:a] + NEW_PROPS + src[b:]

    c = src.index("def build():")
    d = src.index("# ----------------------------------------------------------------------------\n# Écriture du module Luau")
    src = src[:c] + NEW_BUILD + src[d:]
    open(PATH, "w", encoding="utf-8").write(src)
    print("patched", PATH)


if __name__ == "__main__":
    main()
