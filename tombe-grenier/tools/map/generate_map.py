#!/usr/bin/env python3
"""
Génère src/shared/MapData.lua : source unique de la carte de La Tombe du Grenier.

Tout ce qui décrit la maison (pièces, portes, murs, dalles, escaliers, meubles,
lumières, points de tag, murs invisibles, jardin) est défini ici.
Le serveur (src/server/MapBuilder.lua) construit la carte à partir du fichier généré.

Usage (depuis tombe-grenier/) :
    python3 tools/map/generate_map.py
    python3 -m unittest discover -s tools/map -p "test_*.py"

Unités : studs. Axes : x (ouest -> est), z (nord -> sud), y (hauteur).
Le sud (z = 90) porte la porte d'entrée principale.
"""
import os
from collections import defaultdict

# ----------------------------------------------------------------------------
# Constantes géométriques
# ----------------------------------------------------------------------------
H = 11                                   # hauteur des murs (studs)
T = 1.0                                  # épaisseur des murs (studs)
BASE = {"basement": -12, "ground": 0, "first": 12, "attic": 24}
LEVELS = ["basement", "ground", "first", "attic"]
FOOT = (0, 0, 120, 90)                   # emprise de la maison
STAIR = (50, 10, 58, 40)                 # emprise des escaliers (identique à chaque étage)
STAIR_HOLE = (50, 10, 58, 40)            # trémie dans chaque dalle traversée : toute l'emprise de l'escalier
STAIR_STEPS = 12                         # marches par volée (1 stud de contremarche)
DOOR_W = 4                               # largeur standard d'une porte intérieure
FRONT_DOOR_W = 6                         # largeur de la porte d'entrée
ZONE_MARGIN = 2.5                        # zone libre devant chaque porte

# ----------------------------------------------------------------------------
# Pièces : id, niveau, rectangle (x0, z0, x1, z1), sol, mur, nom
# ----------------------------------------------------------------------------
ROOMS = [
    # Sous-sol
    ("pn",     "basement", (0, 0, 40, 44),    "ardoise",   "brique", "Passage nord"),
    ("cave",   "basement", (40, 0, 80, 90),   "ardoise",   "brique", "Cave centrale"),
    ("ps",     "basement", (80, 0, 120, 90),  "ardoise",   "brique", "Passage sud"),
    ("cel",    "basement", (0, 44, 40, 90),   "ardoise",   "brique", "Cellier"),
    # Rez-de-chaussée
    ("salon",  "ground",   (0, 0, 40, 44),    "carrelage", "papier", "Salon"),
    ("hall",   "ground",   (40, 0, 80, 44),   "carrelage", "brique", "Hall"),
    ("cuis",   "ground",   (80, 0, 120, 44),  "carrelage", "mur",    "Cuisine"),
    ("sam",    "ground",   (0, 44, 40, 90),   "carrelage", "papier", "Salle à manger"),
    ("entree", "ground",   (40, 44, 80, 90),  "carrelage", "brique", "Entrée"),
    ("bureau", "ground",   (80, 44, 120, 90), "carrelage", "bureau", "Bureau"),
    # Premier étage
    ("chp",    "first",    (0, 0, 40, 44),    "carrelage", "mur",    "Chambre des parents"),
    ("palier", "first",    (40, 0, 80, 44),   "carrelage", "brique", "Palier"),
    ("che",    "first",    (80, 0, 120, 44),  "carrelage", "mur",    "Chambre d'enfant"),
    ("cha",    "first",    (12, 44, 40, 90),  "carrelage", "mur",    "Chambre d'ami"),
    ("sdb2",   "first",    (0, 44, 12, 90),   "carrelage", "mur",    "Salle d'eau"),
    ("couloir", "first",   (40, 44, 80, 90),  "carrelage", "brique", "Couloir"),
    ("sdb",    "first",    (80, 44, 120, 68), "carrelage", "mur",    "Salle de bain"),
    ("deb",    "first",    (80, 68, 120, 90), "carrelage", "mur",    "Débarras"),
    # Grenier
    ("gro",    "attic",    (0, 0, 60, 90),    "plancher",  "bois_mur", "Grenier ouest"),
    ("tombe",  "attic",    (60, 0, 120, 90),  "plancher",  "mur",    "Salle de la tombe"),
]

# ----------------------------------------------------------------------------
# Portes. orient 'v' : mur de ligne x = line, centre sur z = c.
#         orient 'h' : mur de ligne z = line, centre sur x = c.
# puzzle : nom de l'énigme qui ouvre le passage (mur invisible jusque-là).
# front  : porte donnant sur l'extérieur.
# ----------------------------------------------------------------------------
DOORS = [
    # Sous-sol
    dict(level="basement", orient="v", line=40, c=22, w=DOOR_W),
    dict(level="basement", orient="v", line=40, c=67, w=DOOR_W, lock="cellier"),
    dict(level="basement", orient="h", line=44, c=20, w=DOOR_W, lock="cellier"),
    dict(level="basement", orient="h", line=90, c=103, w=DOOR_W),   # porte extérieure : accès par le jardin
    dict(level="basement", orient="v", line=80, c=45, w=DOOR_W, puzzle="grille"),
    # Rez-de-chaussée
    dict(level="ground", orient="v", line=40, c=22, w=DOOR_W),
    dict(level="ground", orient="v", line=80, c=22, w=DOOR_W),
    dict(level="ground", orient="h", line=44, c=20, w=DOOR_W),
    dict(level="ground", orient="h", line=44, c=60, w=DOOR_W),
    dict(level="ground", orient="h", line=44, c=100, w=DOOR_W, lock="bureau"),
    dict(level="ground", orient="v", line=40, c=67, w=DOOR_W),
    dict(level="ground", orient="v", line=80, c=67, w=DOOR_W, lock="bureau"),
    dict(level="ground", orient="h", line=90, c=60, w=FRONT_DOOR_W, front=True),
    # Premier étage
    dict(level="first", orient="v", line=40, c=22, w=DOOR_W),
    dict(level="first", orient="v", line=80, c=22, w=DOOR_W),
    dict(level="first", orient="h", line=44, c=60, w=DOOR_W),
    dict(level="first", orient="v", line=40, c=67, w=DOOR_W, lock="cahier"),
    dict(level="first", orient="v", line=80, c=56, w=DOOR_W, lock="salle de bain"),
    dict(level="first", orient="v", line=12, c=67, w=DOOR_W, lock="cahier"),   # chambre d'ami -> salle d'eau (même verrou)
    dict(level="first", orient="h", line=68, c=100, w=DOOR_W, lock="salle de bain"),
    dict(level="first", orient="v", line=80, c=79, w=DOOR_W),
    # Grenier
    dict(level="attic", orient="v", line=60, c=45, w=DOOR_W),
]

# Volées d'escalier : (niveau bas, niveau haut). Chaque volée monte de BASE[bas] à BASE[haut].
FLIGHTS = [("basement", "ground"), ("ground", "first"), ("first", "attic")]
# Liaison logique entre pièces par les escaliers (pour le contrôle d'accessibilité)
STAIR_LINKS = [("cave", "hall"), ("hall", "palier"), ("palier", "gro")]

# ----------------------------------------------------------------------------
# Meubles : (nom, x0, z0, x1, z1, hauteur, matériau). Un « armoire » devient une cachette.
# ----------------------------------------------------------------------------
FURNITURE = {
    # Sous-sol
    "pn": [
        ("caisses", 3, 3, 10, 9, 3, "bois"),
        ("étagère", 30, 3, 38, 10, 7, "bois"),
        ("barriques", 13, 28, 17, 32, 3, "bois"),
    ],
    "cave": [
        ("barriques", 62, 4, 68, 10, 3, "bois"),
        ("étagère", 44, 50, 48, 70, 7, "bois"),
        ("établi", 64, 60, 74, 64, 3, "bois"),
        ("caisses", 62, 76, 70, 82, 3, "bois"),
        ("étagère", 72, 20, 78, 30, 7, "bois"),
    ],
    "ps": [
        ("étagère", 84, 4, 90, 12, 6, "bois"),
        ("coffre", 110, 10, 116, 16, 3, "metal"),
        ("caisses", 100, 60, 108, 68, 3, "bois"),
        ("table", 88, 76, 98, 82, 2.5, "bois"),
    ],
    "cel": [
        ("étagère", 3, 50, 8, 70, 7, "bois"),
        ("cuves", 12, 74, 20, 80, 4, "metal"),
        ("caisses", 26, 50, 34, 56, 3, "bois"),
        ("tonneau", 26, 70, 30, 74, 3, "bois"),
    ],
    # Rez-de-chaussée
    "salon": [
        ("canapé", 6, 6, 18, 11, 3, "tissu"),
        ("fauteuil", 24, 8, 28, 12, 3, "tissu"),
        ("table basse", 8, 16, 18, 22, 1.5, "bois"),
        ("meuble TV", 6, 34, 20, 38, 2.5, "bois"),
        ("cheminée", 30, 2, 38, 6, 5, "pierre"),
        ("bibliothèque", 0.5, 18, 2.5, 30, 8, "bois"),
    ],
    "hall": [
        ("console", 62, 2, 72, 4, 3, "bois"),
        ("plante", 42, 2, 45, 5, 4, "vert"),
        ("portemanteau", 72, 30, 74, 32, 6, "bois"),
    ],
    "cuis": [
        ("cuisinière", 84, 2, 94, 6, 3, "metal"),
        ("frigo", 106, 2, 110, 6, 6, "metal"),
        ("îlot", 88, 14, 100, 22, 3, "bois"),
        ("table", 104, 14, 114, 22, 2.5, "bois"),
        ("placards", 112, 24, 119, 32, 7, "bois"),
    ],
    "sam": [
        ("table", 8, 60, 22, 70, 2.5, "bois"),
        ("chaise", 6, 57, 8, 59, 2, "bois"),
        ("chaise", 16, 57, 18, 59, 2, "bois"),
        ("chaise", 6, 71, 8, 73, 2, "bois"),
        ("chaise", 16, 71, 18, 73, 2, "bois"),
        ("buffet", 1, 80, 6, 88, 5, "bois"),
    ],
    "entree": [
        ("console", 44, 50, 48, 54, 3, "bois"),
        ("penderie", 72, 50, 74, 52, 7, "bois"),
        ("guéridon", 60, 70, 64, 74, 1, "bois"),
        ("banc", 48, 80, 56, 82, 1.5, "bois"),
    ],
    "bureau": [
        ("bureau", 92, 56, 104, 62, 2.5, "bois"),
        ("chaise", 94, 63, 96, 65, 2.5, "bois"),
        ("bibliothèque", 113, 50, 119.5, 56, 8, "bois"),
        ("coffre", 106, 76, 116, 82, 3, "metal"),
        ("canapé", 86, 80, 96, 84, 3, "tissu"),
    ],
    # Premier étage
    "chp": [
        ("lit double", 6, 6, 18, 18, 3, "tissu"),
        ("chevet", 1.5, 6, 3.5, 8, 2, "bois"),
        ("chevet", 20.5, 6, 22.5, 8, 2, "bois"),
        ("armoire", 28, 1, 39, 5, 8, "bois"),
        ("commode", 30, 12, 38, 16, 3, "bois"),
    ],
    "palier": [
        ("console", 62, 4, 72, 7, 3, "bois"),
        ("lampadaire", 44, 4, 46, 6, 5, "metal"),
        ("chaise", 66, 30, 68, 32, 3, "bois"),
        ("vitrine", 74, 30, 78, 36, 7, "bois"),
    ],
    "che": [
        ("lit", 96, 4, 108, 12, 2.5, "tissu"),
        ("bureau", 86, 6, 94, 12, 3, "bois"),
        ("coffre à jouets", 86, 36, 92, 42, 2.5, "bois"),
        ("cheval à bascule", 100, 30, 108, 36, 3, "bois"),
        ("armoire", 110, 2, 119, 8, 8, "bois"),
    ],
    "cha": [
        ("lit", 14, 50, 24, 62, 2.5, "tissu"),
        ("chevet", 26, 50, 28, 52, 2, "bois"),
        ("bureau", 28, 52, 36, 58, 2.5, "bois"),
        ("chaise", 32, 72, 34, 76, 2, "bois"),
        ("armoire", 30, 80, 38, 88, 8, "bois"),
    ],
    "sdb2": [
        ("baignoire", 1, 46, 8, 52, 2.5, "porcelaine"),
        ("lavabo", 1, 60, 5, 64, 3, "porcelaine"),
        ("WC", 8, 60, 11, 63, 2.5, "porcelaine"),
        ("armoire de toilette", 1, 80, 4, 86, 6, "bois"),
    ],
    "couloir": [
        ("console", 44, 80, 54, 83, 3, "bois"),
        ("table ronde", 60, 60, 64, 64, 2.5, "bois"),
        ("étagère", 70, 46, 74, 50, 8, "bois"),
    ],
    "sdb": [
        ("baignoire", 106, 45.5, 117, 52, 2.5, "porcelaine"),
        ("lavabo", 86, 46, 92, 50, 3, "porcelaine"),
        ("WC", 88, 58, 92, 62, 2.5, "porcelaine"),
        ("armoire de toilette", 114, 58, 119, 64, 6, "bois"),
    ],
    "deb": [
        ("étagères", 106, 80, 118, 88, 8, "bois"),
        ("caisses", 86, 70, 92, 76, 3, "bois"),
        ("carton", 110, 70, 116, 74, 2, "carton"),
        ("bidon", 86, 84, 90, 88, 3, "metal"),
        ("boîte en carton", 100, 72, 104, 76, 3, "carton"),
    ],
    # Grenier
    "gro": [
        ("étagère", 1, 4, 4, 12, 8, "bois"),
        ("étagère", 1, 20, 4, 28, 8, "bois"),
        ("commode", 14, 2, 24, 6, 4, "bois"),
        ("table", 28, 10, 36, 16, 3, "bois"),
        ("lit enfant", 20, 66, 30, 76, 3, "bois"),
        ("table", 44, 70, 50, 76, 3, "bois"),
        ("caisses", 8, 60, 16, 68, 4, "bois"),
        ("armoire", 4, 82, 14, 89, 8, "bois"),
        ("boîte en carton", 44, 30, 48, 34, 3, "carton"),
        ("chaise", 22, 40, 24, 42, 3, "bois"),
        ("malle", 4, 36, 8, 42, 3, "bois"),
        ("miroir sur pied", 2, 46, 4, 48, 6, "bois"),
        ("berceau", 34, 46, 42, 54, 3, "bois"),
        ("caisse de jouets", 14, 38, 20, 44, 2, "bois"),
        ("pile de cartons", 36, 60, 42, 66, 3, "carton"),
    ],
    "tombe": [
        ("cercueil", 86, 42, 94, 48, 2, "bois_sombre"),
        ("cheval à bascule", 100, 10, 108, 16, 3, "bois"),
        ("coffre verrouillé", 66, 62, 74, 66, 3, "metal"),
        ("table ronde", 92, 70, 98, 76, 3, "bois"),
        ("armoire", 114, 70, 119, 80, 8, "bois"),
    ],
}

# ----------------------------------------------------------------------------
# Points de tag (serveur). Chaque point : tag, nom, position, taille, attributs.
# Les positions sont calculées à partir des niveaux ci-dessous (voir build_props).
# ----------------------------------------------------------------------------
GARDEN_TREES = [(-35, -35), (-48, 20), (-30, 110), (-45, 140), (-12, -40), (140, -35),
                (165, 20), (160, 110), (140, 140), (128, 130), (-20, 130), (150, 60)]


# ----------------------------------------------------------------------------
# Utilitaires géométriques
# ----------------------------------------------------------------------------
def room_list(level=None):
    return [r for r in ROOMS if level is None or r[1] == level]


def room_by_id(rid):
    for r in ROOMS:
        if r[0] == rid:
            return r
    raise KeyError(rid)


def inside(rect, x, z):
    x0, z0, x1, z1 = rect
    return x0 <= x < x1 and z0 <= z < z1


def room_at(level, x, z):
    for rid, lv, rect, *_ in ROOMS:
        if lv == level and inside(rect, x, z):
            return rid
    return None


def overlaps(a, b):
    """Recouvrement strict de deux rectangles (x0, z0, x1, z1)."""
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def subtract(rect, hole):
    """Rectangle moins un trou : liste de rectangles couvrant rect \\ hole."""
    x0, z0, x1, z1 = rect
    hx0, hz0, hx1, hz1 = hole
    ix0, ix1 = max(x0, hx0), min(x1, hx1)
    iz0, iz1 = max(z0, hz0), min(z1, hz1)
    if ix0 >= ix1 or iz0 >= iz1:
        return [rect]
    out = []
    if z0 < iz0:
        out.append((x0, z0, x1, iz0))
    if iz1 < z1:
        out.append((x0, iz1, x1, z1))
    if x0 < ix0:
        out.append((x0, iz0, ix0, iz1))
    if ix1 < x1:
        out.append((ix1, iz0, x1, iz1))
    return out


def door_zone(d):
    """Zone libre devant une porte (pas de meuble dedans)."""
    line, c = d["line"], d["c"]
    if d["orient"] == "v":
        return (line - ZONE_MARGIN, c - 3, line + ZONE_MARGIN, c + 3)
    return (c - 3, line - ZONE_MARGIN, c + 3, line + ZONE_MARGIN)


def box(x0, x1, y0, y1, z0, z1, mat, name=None, **extra):
    d = dict(x0=x0, x1=x1, y0=y0, y1=y1, z0=z0, z1=z1, mat=mat)
    if name:
        d["name"] = name
    d.update(extra)
    return d


# ----------------------------------------------------------------------------
# Murs : lignes de murs = tronçons couverts par au moins une pièce
# ----------------------------------------------------------------------------
def wall_runs(level):
    """Retourne [(orient, line, a, b)] : tronçons de mur continus du niveau."""
    lines = defaultdict(list)  # (orient, coord) -> [(a, b)]
    for _, lv, (x0, z0, x1, z1), *_ in room_list(level):
        lines[("h", z0)].append((x0, x1))
        lines[("h", z1)].append((x0, x1))
        lines[("v", x0)].append((z0, z1))
        lines[("v", x1)].append((z0, z1))

    runs = []
    for (orient, coord), segs in lines.items():
        pts = sorted({p for s in segs for p in s})
        covered = []
        for p, q in zip(pts, pts[1:]):
            if any(a <= p and q <= b for a, b in segs):
                covered.append((p, q))
        # fusion des intervalles contigus
        cur = None
        for p, q in covered:
            if cur and cur[1] == p:
                cur = (cur[0], q)
            else:
                if cur:
                    runs.append((orient, coord, cur[0], cur[1]))
                cur = (p, q)
        if cur:
            runs.append((orient, coord, cur[0], cur[1]))
    return runs


def doors_on(level, orient, line):
    return [d for d in DOORS if d["level"] == level and d["orient"] == orient and d["line"] == line]


def wall_material(level, orient, line, a, b):
    """Matière d'un tronçon de mur : celle de la pièce qu'il borde (brique prioritaire)."""
    mid = (a + b) / 2
    sides = []
    for p in (line - 0.5, line + 0.5):
        x, z = (p, mid) if orient == "v" else (mid, p)
        sides.append(room_at(level, x, z))
    if level == "basement":
        return "beton" if "cel" in sides else "rouille"
    walls = [room_by_id(rid)[4] for rid in sides if rid]
    if "brique" in walls:
        return "brique"
    for w in walls:
        if w != "mur":
            return w
    return "mur"


def wall_pieces(level):
    """Pièces de mur (boîtes), portes percées, linteaux au-dessus des portes."""
    base = BASE[level]
    pieces = []
    for orient, line, a, b in wall_runs(level):
        mat = wall_material(level, orient, line, a, b)
        doors = sorted(doors_on(level, orient, line), key=lambda d: d["c"])
        # Segments à construire, en retirant les ouvertures de porte
        segs = []
        cur = a
        for d in doors:
            lo, hi = d["c"] - d["w"] / 2, d["c"] + d["w"] / 2
            if not (a <= lo and hi <= b):
                raise ValueError(f"porte hors mur : {level} {orient} {line} c={d['c']}")
            segs.append((cur, lo, False))
            pieces.append(_lintel(orient, line, lo, hi, base, mat))
            cur = hi
        segs.append((cur, b, True))
        for s, e, is_last in segs:
            if e <= s:
                continue
            start = s - 0.5 if s == a else s
            end = e + 0.5 if (e == b) else e
            pieces.append(_wall_box(orient, line, start, end, base, mat))
    return pieces


def _wall_box(orient, line, s, e, base, mat):
    if orient == "v":
        return box(line - T / 2, line + T / 2, base, base + H, s, e, mat, "mur")
    return box(s, e, base, base + H, line - T / 2, line + T / 2, mat, "mur")


def _lintel(orient, line, lo, hi, base, mat):
    if orient == "v":
        return box(line - T / 2, line + T / 2, base + 7, base + H, lo, hi, mat, "linteau")
    return box(lo, hi, base + 7, base + H, line - T / 2, line + T / 2, mat, "linteau")


# ----------------------------------------------------------------------------
# Dalles et escaliers
# ----------------------------------------------------------------------------
def floor_slabs(level):
    """Dalle de sol du niveau : y in [base-1, base], trémie d'escalier si besoin."""
    base = BASE[level]
    holes = []
    if level in ("ground", "first", "attic"):
        holes.append(STAIR_HOLE)            # arrivée de la volée qui monte jusqu'ici
    out = []
    for rid, lv, rect, floor, _, _ in room_list(level):
        pieces = [rect]
        for h in holes:
            nxt = []
            for p in pieces:
                nxt.extend(subtract(p, h))
            pieces = nxt
        for x0, z0, x1, z1 in pieces:
            out.append(box(x0, x1, base - 1, base, z0, z1, floor, "dalle"))
    return out


def roof():
    x0, z0, x1, z1 = FOOT
    return [box(x0, x1, BASE["attic"] + H, BASE["attic"] + H + 1, z0, z1, "plafond_grenier", "toit")]


def stair_steps():
    """Volées d'escalier : marches pleines de 2,5 studs de long et 1 stud de haut."""
    x0, z0, x1, z1 = STAIR
    steps = []
    run = (z1 - z0) / STAIR_STEPS      # 30 / 12 = 2,5 studs de marche
    for lo, hi in FLIGHTS:
        b0 = BASE[lo]
        for i in range(STAIR_STEPS):
            zs = z1 - i * run          # départ en bas de volée (z grand)
            ze = zs - run              # arrivée vers le haut (z petit)
            top = b0 + (i + 1)
            steps.append(box(x0, x1, b0, top, ze, zs, "bois", "marche"))
    return steps


# ----------------------------------------------------------------------------
# Meubles (boîtes) et cachettes
# ----------------------------------------------------------------------------
BED_CLEARANCE = 1.2   # espace libre sous le sommier (on peut s'y glisser)
LEG = 0.6


def furniture_boxes():
    out = []
    for rid, items in FURNITURE.items():
        lv = room_by_id(rid)[1]
        base = BASE[lv]
        for name, x0, z0, x1, z1, h, mat in items:
            if name.startswith("lit"):
                # Lit sur quatre pieds : le sommier flotte, l'espace dessous reste libre
                out.append(box(x0, x1, base + BED_CLEARANCE, base + h, z0, z1, mat, name))
                for lx in (x0, x1 - LEG):
                    for lz in (z0, z1 - LEG):
                        out.append(box(lx, lx + LEG, base, base + BED_CLEARANCE, lz, lz + LEG, mat, "pied de lit"))
            else:
                out.append(box(x0, x1, base, base + h, z0, z1, mat, name))
    return out


def hiding_spots():
    """Cachettes : armoires (debout), dessous des lits (posture basse), boîtes en carton."""
    spots = []
    for rid, items in FURNITURE.items():
        lv = room_by_id(rid)[1]
        base = BASE[lv]
        for name, x0, z0, x1, z1, h, mat in items:
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            if name == "armoire":
                spots.append(dict(tag="Hiding", name="armoire " + rid, kind="armoire",
                                  pos=(cx, base + 1.5, cz), size=(2, 2, 2)))
            elif name.startswith("lit"):
                spots.append(dict(tag="Hiding", name="sous le lit " + rid, kind="sous le lit",
                                  posture="low", pos=(cx, base + 0.5, cz), size=(2, 0.8, 2)))
            elif name == "boîte en carton":
                spots.append(dict(tag="Hiding", name="boîte " + rid, kind="boîte",
                                  pos=(cx, base + 1.5, cz), size=(2, 2, 2)))
    return spots


# ----------------------------------------------------------------------------
# Points de tag, lumières, repères du monstre, murs invisibles, jardin
# ----------------------------------------------------------------------------
# ----------------------------------------------------------------------------
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

NOTE_SLOTS = [
    _s("grenier, étagère ouest", (2.5, 32.1, 6), (0.6, 0.1, 0.8)),
    _s("chambre des parents, chevet", (2.5, 14.1, 6.5), (0.6, 0.1, 0.8)),
    _s("cuisine, îlot", (92, 3.1, 16), (0.6, 0.1, 0.8)),
    _s("cave, étagère", (45.5, -4.9, 63), (0.6, 0.1, 0.8)),
    _s("chambre d'enfant, bureau", (88, 15.1, 11), (0.6, 0.1, 0.8)),
]

BATH_KEY_SLOTS = [
    _s("salon, bibliothèque", (1.5, 8.1, 24), (0.6, 0.1, 0.5)),
    _s("chambre des parents, commode", (34, 15.1, 14), (0.6, 0.1, 0.5)),
    _s("bureau, bibliothèque", (118, 8.1, 51.5), (0.6, 0.1, 0.5)),
]

DECOY_KEY_SLOTS = [
    _s("salle à manger, buffet", (3.5, 5.1, 84), (0.8, 0.1, 0.5)),
    _s("cuisine, placards", (115.5, 7.1, 28), (0.8, 0.1, 0.5)),
    _s("cave, caisses", (66, -8.9, 79), (0.8, 0.1, 0.5)),
]

BATTERY_SLOTS = [
    _s("palier, console", (67, 15.2, 5.5), (0.6, 0.5, 0.4)),
    _s("cuisine, plan de travail", (109, 2.6, 18), (0.6, 0.5, 0.4)),
    _s("grenier, caisses", (12, 28.1, 64), (0.6, 0.5, 0.4)),
    _s("chambre des parents, sol", (10, 0.1, 32), (0.6, 0.5, 0.4)),
    _s("cave, au sol derrière les caisses", (50, -11.9, 85), (0.6, 0.5, 0.4)),
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

# Documents de l'histoire (lecture seule, sans logique au-delà de la quête)
INTERACTABLE_SLOTS["journal"].append(_i("journal intime", "chambre des parents, commode", (36, 15.1, 15), (1, 0.2, 1.4)))
INTERACTABLE_SLOTS["cahier"] = [
    _i("cahier d'écolier", "chambre d'enfant, bureau", (89, 15.1, 8), (0.8, 0.2, 1.1)),
    _i("cahier d'écolier", "couloir, console", (49, 15.1, 81.5), (0.8, 0.2, 1.1)),
    _i("cahier d'écolier", "passage sud, table", (93, 2.6, 79), (0.8, 0.2, 1.1)),
]
INTERACTABLE_SLOTS["photo_famille"] = [
    _i("photo de famille", "salon, cheminée", (34, 5.1, 4), (1.2, 0.1, 1.0)),
    _i("photo de famille", "bibliothèque du bureau", (116, 8.1, 53), (1.2, 0.1, 1.0)),
    _i("photo de famille", "palier, vitrine", (76, 19.1, 33), (1.2, 0.1, 1.0)),
]

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
    box(44, 76, 12, 12.05, 62, 68, "tissu", "tapis couloir", deco=True),
    box(56, 62, 15, 19, 44.6, 45.0, "bois_sombre", "tableau couloir", deco=True),
    box(72, 78, 15, 19, 44.6, 45.0, "bois_sombre", "tableau couloir 2", deco=True),
    box(49.5, 58.5, 24, 25, 9.4, 9.8, "bois", "garde-corps grenier", deco=True),
    box(49.4, 49.8, 24, 25, 9.8, 40.5, "bois", "garde-corps grenier", deco=True),
    box(58.2, 58.6, 24, 25, 9.8, 40.5, "bois", "garde-corps grenier", deco=True),
    # Dessins d'enfant au mur de la chambre (silhouette sans visage)
    box(84, 88, 13, 17, 0.8, 1.0, "carton", "dessin d'enfant", deco=True),
    box(92, 96, 13, 17, 0.8, 1.0, "carton", "dessin d'enfant", deco=True),
    box(100, 104, 13, 17, 0.8, 1.0, "carton", "dessin d'enfant", deco=True),
    box(0.5, 1.4, 1, 9, 8, 12, "tissu", "rideau salon", deco=True),
    box(0.5, 1.4, 13, 21, 8, 12, "tissu", "rideau chambre des parents", deco=True),
    box(118.6, 119.5, 13, 21, 8, 12, "tissu", "rideau chambre d'enfant", deco=True),
    box(0.5, 1.4, 25, 33, 60, 64, "tissu", "rideau grenier", deco=True),
    box(100, 104, 1, 9, 0.5, 1.4, "tissu", "rideau cuisine", deco=True),
]


STATUE_ROOMS = ("salon", "cuis", "bureau")   # trois statues : salon, cuisine, bureau
STATUE_HEIGHT = 2.2
MANNEQUIN_HEIGHT = 1.9
BREATH_PANEL = (38.4, 34.5, 39.4, 37.5)   # panneau du mur qui respire (côté salon du mur du hall)


def _clear(x0, z0, x1, z1, y0, y1, margin=0.8):
    """Vrai si la boîte ne touche aucun meuble (y compris la marge)."""
    for b in furniture_boxes():
        if b["y1"] <= y0 or b["y0"] >= y1:
            continue
        if b["x1"] + margin <= x0 or b["x0"] - margin >= x1:
            continue
        if b["z1"] + margin <= z0 or b["z0"] - margin >= z1:
            continue
        return False
    return True


def _near_door(level, x, z, dist=3.0):
    import math
    for d in DOORS:
        if d["level"] != level:
            continue
        cx, cz = (d["line"], d["c"]) if d["orient"] == "v" else (d["c"], d["line"])
        if math.hypot(x - cx, z - cz) < dist + d["w"] / 2:
            return True
    return False


def _in_stair(x, z, m=2.0):
    x0, z0, x1, z1 = STAIR
    return x0 - m < x < x1 + m and z0 - m < z < z1 + m


def _floor_spot(rid, half, height):
    """Premier emplacement libre au sol de la pièce (à son étage) : sans meuble, sans porte, hors escalier."""
    room = next(r for r in ROOMS if r[0] == rid)
    level, (rx0, rz0, rx1, rz1) = room[1], room[2]
    base = BASE[level]
    x = rx0 + 2.0
    while x <= rx1 - 2.0:
        z = rz0 + 2.0
        while z <= rz1 - 2.0:
            if (not _in_stair(x, z) and not _near_door(level, x, z)
                    and _clear(x - half, z - half, x + half, z + half, base, base + height)):
                return (x, z)
            z += 0.5
        x += 0.5
    raise RuntimeError(f"pas de place libre dans {rid}")


def puzzle_props():
    """Statues (énigme de la pièce du rez-de-chaussée) et mur qui respire (sensation, récompense)."""
    out = []
    for rid in STATUE_ROOMS:
        x, z = _floor_spot(rid, 0.5, STATUE_HEIGHT)
        out.append(dict(tag="Statue", name="statue ancienne " + rid, pos=(x, STATUE_HEIGHT / 2, z), size=(1, STATUE_HEIGHT, 1)))
    # Mannequin du couloir (étage) : sa tête se retourne à l'approche
    mx, mz = _floor_spot("couloir", 0.4, MANNEQUIN_HEIGHT)
    out.append(dict(tag="Mannequin", name="mannequin du couloir", pos=(mx, BASE["first"] + MANNEQUIN_HEIGHT / 2, mz),
                    size=(0.8, MANNEQUIN_HEIGHT, 0.6)))
    x0, z0, x1, z1 = BREATH_PANEL
    if not _clear(x0, z0, x1, z1, 0, 3, margin=0.2):
        raise RuntimeError("le panneau du mur qui respire touche un meuble")
    out.append(dict(tag="Respire", name="mur qui respire", pos=((x0 + x1) / 2, 1.5, (z0 + z1) / 2),
                    size=(x1 - x0, 3, z1 - z0)))
    return out


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

    # Éléments fixes de l'histoire : coffret à code, plaque du cercueil, malle et sa clé
    props.append(dict(tag="Coffret", name="coffret à bijoux", pos=(95, 27.1, 73), size=(1.6, 0.8, 1.2)))
    props.append(dict(tag="Plaque", name="plaque du cercueil", pos=(90, 26.1, 42.5), size=(2.2, 0.8, 0.2)))
    props.append(dict(tag="Key", name="clé rouillée (malle)", pos=(70, 27.3, 64), size=(0.8, 0.1, 0.5)))

    # Éléments de scène fixes : miroir inquiétant (tombe), miroir fissuré (salle de bain),
    # télévision (salon), photo d'introduction (au-dessus du cercueil)
    props.append(dict(tag="Mirror", name="miroir inquiétant", pos=(119.2, 31, 30), size=(0.4, 6, 4)))
    props.append(dict(tag="Mirror", name="miroir fissuré", pos=(119.2, 17.5, 56), size=(0.4, 3, 3)))
    props.append(dict(tag="TV", name="télévision", pos=(13, 4.2, 33.4), size=(4, 2.4, 0.3)))
    # Horloge du hall (progression V2) : à régler sur la date de la plaque, côté mur nord
    props.append(dict(tag="Horloge", name="horloge du hall", pos=(60, 4.5, 1.1), size=(1.0, 1.6, 0.3)))
    # Énigme optionnelle (cuisine) : une étiquette donne un code, le compteur du mur l'attend
    props.append(dict(tag="Interactable", kind="étiquette de la réserve", name="étiquette de la réserve", pos=(118.6, 3.2, 14), size=(0.2, 0.5, 0.6)))
    props.append(dict(tag="Compteur", name="compteur de la cuisine", pos=(118.6, 2.8, 30), size=(0.4, 1.0, 1.0)))
    props.append(dict(tag="IntroPhoto", name="photo de l'introduction", pos=(90, 30, 45), size=(1, 0.1, 1.4)))

    # Tasse de café pleine (cuisine) : objet de décor à examiner
    props.append(dict(tag="Interactable", kind="tasse de café", name="tasse de café", pos=(109, 2.7, 16), size=(0.6, 0.5, 0.6)))

    props.append(dict(tag="CaveDoor", name="porte métallique de la cave", pos=(80, -6.5, 45), size=(0.8, 11, 4)))

    # Disjoncteurs : trois interrupteurs à actionner dans le bon ordre pour rétablir le courant
    props.append(dict(tag="Switch", name="interrupteur cellier", pos=(41.2, -6, 60), size=(0.4, 1, 0.6)))
    props.append(dict(tag="Switch", name="interrupteur cave", pos=(60, -6, 1.2), size=(0.6, 1, 0.4)))
    props.append(dict(tag="Switch", name="interrupteur passage sud", pos=(118.8, -6, 80), size=(0.4, 1, 0.6)))

    # Téléphone du salon : il sonne parfois, avec des consignes contradictoires
    props.append(dict(tag="Phone", name="téléphone du salon", pos=(17.2, 1.6, 17.8), size=(0.7, 0.4, 0.6)))

    # Porte d'entrée (bloquante jusqu'à l'ouverture de la sortie)
    props.append(dict(tag="ExitDoor", name="porte principale", pos=(60, 5, 90), size=(FRONT_DOOR_W, 10, 0.6)))

    # Murs invisibles : périmètre du jardin, portail (énigme), grille du sous-sol (énigme)
    inv = []
    # Clôture resserrée : on tourne autour de la façade, on atteint le portail, on ne sort pas de la carte
    inv.append(dict(name="clôture nord", x0=-8.5, x1=128.5, z0=-8.5, z1=-7.5, y0=-1, y1=30))
    inv.append(dict(name="clôture sud ouest", x0=-8.5, x1=55, z0=149.5, z1=150.5, y0=-1, y1=30))
    inv.append(dict(name="clôture sud est", x0=65, x1=128.5, z0=149.5, z1=150.5, y0=-1, y1=30))
    inv.append(dict(name="clôture ouest", x0=-8.5, x1=-7.5, z0=-8, z1=150, y0=-1, y1=30))
    inv.append(dict(name="clôture est", x0=127.5, x1=128.5, z0=-8, z1=150, y0=-1, y1=30))
    inv.append(dict(name="portail", x0=55, x1=65, z0=149.5, z1=150.5, y0=-1, y1=30, puzzle="portail"))
    inv.append(dict(name="grille sud", x0=79.5, x1=80.5, z0=43, z1=47, y0=-12, y1=-1, puzzle="grille"))
    props += puzzle_props()
    # Trappe au pied de l'escalier du sous-sol, dans la maison : elle ne s'ouvre pas
    props.append(dict(tag="Trappe", name="trappe de la cave (intérieur)", pos=(54, 1.25, 9.5), size=(8, 2.5, 2)))
    # Trappe au sommet de l'escalier du grenier : fermée tant que la malle n'est pas ouverte
    props.append(dict(tag="TrappeGrenier", name="trappe du grenier", pos=(54, 25.25, 9.5), size=(8, 2.5, 2)))
    # Trappe au sommet de l'escalier du premier étage : fermée jusqu'à la mélodie de la boîte à musique
    props.append(dict(tag="TrappePalier", name="trappe du premier étage", pos=(54, 13.25, 9.5), size=(8, 2.5, 2)))
    return props, inv


def garden():
    plates = [
        box(-8, 128, -1, 0, -8, 0, "herbe", "pelouse nord"),
        box(-8, 100, -1, 0, 90, 150, "herbe", "pelouse sud ouest"),
        box(106, 128, -1, 0, 90, 150, "herbe", "pelouse sud est"),
        box(100, 106, -1, 0, 104, 150, "herbe", "pelouse sud centre"),
        box(-8, 0, -1, 0, 0, 90, "herbe", "pelouse ouest"),
        box(120, 128, -1, 0, 0, 90, "herbe", "pelouse est"),
    ]
    path = [box(55, 65, -0.4, 0, 90, 150, "pierre", "allée")]
    # Escalier extérieur qui descend au sous-sol par la porte du mur sud (x 100..106, z 90..104)
    steps = []
    for k in range(12):
        steps.append(box(100, 106, -12, -(k + 1), 104 - (k + 1), 104 - k, "pierre", "marche extérieure"))
    steps.append(box(100, 106, -13, -12, 90, 92, "pierre", "palier extérieur"))
    trees = []
    for x, z in GARDEN_TREES:
        trees.append(dict(x=x, z=z))
    return plates, path, trees, steps


# ----------------------------------------------------------------------------
# Construction complète
# ----------------------------------------------------------------------------
# Pièces fermées par une énigme : aucun indice ni document indispensable ne s'y trouve
LOCKED_ROOM_IDS = ("sdb", "bureau", "cha", "sdb2", "cel")


def _in_locked_room(slot):
    x, y, z = slot["pos"]
    for r in ROOMS:
        if r[0] not in LOCKED_ROOM_IDS:
            continue
        x0, z0, x1, z1 = r[2]
        b = BASE[r[1]]
        if x0 <= x <= x1 and z0 <= z <= z1 and b - 1 <= y <= b + H + 1:
            return True
    return False


def _open_pool(slots):
    return [s for s in slots if not _in_locked_room(s)]


def build():
    walls, slabs = [], []
    for lv in LEVELS:
        walls += wall_pieces(lv)
        slabs += floor_slabs(lv)
    slabs += roof()
    props, inv = build_props()
    plates, path, trees, garden_steps = garden()
    return dict(
        walls=walls, slabs=slabs, steps=stair_steps(), furniture=furniture_boxes(),
        decor=DECOR, hiding=hiding_spots(), props=props, invisible=inv,
        garden=dict(plates=plates, path=path, trees=trees, steps=garden_steps),
        spawn=dict(pos=(90, BASE["attic"] + 0.5, 45), size=(4, 1, 4)),
        slots=dict(photo=_open_pool(PHOTO_SLOTS), note=_open_pool(NOTE_SLOTS), decoy=DECOY_KEY_SLOTS, bathkey=BATH_KEY_SLOTS, battery=BATTERY_SLOTS, fall=FALL_SLOTS,
                   monster=SPAWN_SLOTS, interactable={k: _open_pool(v) for k, v in INTERACTABLE_SLOTS.items()},
                   dark_eligible=DARK_ELIGIBLE, dark_count=DARK_COUNT),
        rooms=[dict(id=r[0], level=r[1], x0=r[2][0], z0=r[2][1], x1=r[2][2], z1=r[2][3], name=r[5])
               for r in ROOMS],
        doors=[dict(level=d["level"], orient=d["orient"], line=d["line"], c=d["c"], w=d["w"],
                    puzzle=d.get("puzzle"), front=bool(d.get("front")), lock=d.get("lock")) for d in DOORS],
        base=BASE, H=H, stair=STAIR,
    )


# ----------------------------------------------------------------------------
# Écriture du module Luau
# ----------------------------------------------------------------------------
def to_lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        if isinstance(v, float) and v.is_integer():
            return str(int(v))
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            if x is None:
                continue  # clé absente plutôt que nil
            if not k.isidentifier():
                raise ValueError(f"clé Lua invalide : {k}")
            parts.append(f"{k} = {to_lua(x)}")
        return "{" + ", ".join(parts) + "}"
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(to_lua(x) for x in v) + "}"
    raise TypeError(type(v))


def write_lua(data, path):
    header = ("-- GÉNÉRÉ par tools/map/generate_map.py : ne pas éditer à la main.\n"
              "-- Modifier le générateur, puis relancer : python3 tools/map/generate_map.py\n")
    body = "return " + to_lua(data) + "\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(header + body)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.normpath(os.path.join(here, "..", "..", "src", "shared", "MapData.lua"))
    data = build()
    write_lua(data, out)
    print(f"écrit : {out}")
    print(f"murs={len(data['walls'])} dalles={len(data['slabs'])} marches={len(data['steps'])} "
          f"meubles={len(data['furniture'])} points={len(data['props'])}")


if __name__ == "__main__":
    main()
