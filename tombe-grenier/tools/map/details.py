"""Passe 2 : détails narratifs de chaque pièce.

Ce module ne contient que des données : un catalogue d'objets et, pour chaque pièce, la liste de
ce qui y raconte l'histoire de la maison. generate_map.place_details() les pose de façon
déterministe (même carte à chaque génération), hors des portes, des escaliers, des meubles, des
emplacements d'objets et des repères de jeu. Tout est décoratif : aucune collision, aucun tag.

Modes de pose :
  flat  : à plat sur le sol (taches, papiers, empreintes) ; dimensions (sx, sy, sz) = largeur x, épaisseur, largeur z.
  floor : objet posé au sol contre un mur ; mêmes dimensions.
  wall  : plaque collée au mur ; (sx, sy, sz) = largeur le long du mur, hauteur, épaisseur ; `y` = hauteur du centre.

L'histoire : une famille a quitté la maison dans la précipitation après la mort de l'enfant ;
le grenier garde la chambre secrète et la tombe. Les traces vont du sous-sol (terre, eau) vers le
haut (empreintes de petits pieds, griffures), les affaires de l'enfant sont dispersées partout.
"""

# kind : mode, taille, matériau (clé de MATERIALS dans MapBuilder.lua), couleur éventuelle, transparence éventuelle
CATALOG = {
    # À plat
    "tache sombre":    dict(mode="flat", size=(2.2, 0.03, 1.6), mat="tache"),
    "traînée":         dict(mode="flat", size=(0.7, 0.03, 4.0), mat="tache"),
    "empreintes":      dict(mode="flat", size=(1.2, 0.02, 3.0), mat="terre", col=(70, 60, 50)),
    "papiers épars":   dict(mode="flat", size=(1.8, 0.04, 1.4), mat="papiers"),
    "flaque":          dict(mode="flat", size=(2.4, 0.03, 2.2), mat="eau", t=0.35),
    "cendres":         dict(mode="flat", size=(2.0, 0.05, 2.0), mat="cendre"),
    "verre brisé":     dict(mode="flat", size=(1.3, 0.04, 1.1), mat="verre", t=0.5),
    "terre":           dict(mode="flat", size=(2.2, 0.06, 1.6), mat="terre"),
    "craie au sol":    dict(mode="flat", size=(2.6, 0.02, 2.6), mat="craie"),
    "fleurs fanées":   dict(mode="flat", size=(1.2, 0.08, 1.2), mat="fleurs"),
    # Posés au sol, contre un mur
    "valise ouverte":  dict(mode="floor", size=(2.6, 1.0, 1.8), mat="valise"),
    "chaise renversée": dict(mode="floor", size=(1.6, 1.6, 1.6), mat="bois_sombre"),
    "seau":            dict(mode="floor", size=(1.1, 1.3, 1.1), mat="metal"),
    "tas de linge":    dict(mode="floor", size=(2.0, 0.8, 2.0), mat="linge"),
    "bougie fondue":   dict(mode="floor", size=(0.5, 0.5, 0.5), mat="cire"),
    "caisse défoncée": dict(mode="floor", size=(2.0, 1.5, 2.0), mat="bois"),
    "pile de journaux": dict(mode="floor", size=(1.3, 1.4, 1.0), mat="papiers"),
    "poupée":          dict(mode="floor", size=(0.8, 0.5, 0.8), mat="linge", col=(200, 180, 160)),
    "jouet cassé":     dict(mode="floor", size=(1.2, 0.5, 1.2), mat="jouet"),
    "tricycle":        dict(mode="floor", size=(2.0, 1.6, 1.2), mat="metal", col=(120, 40, 35)),
    "bocaux renversés": dict(mode="floor", size=(1.6, 0.9, 1.4), mat="verre", t=0.4, col=(120, 140, 100)),
    # Collés au mur
    "toile d'araignée": dict(mode="wall", size=(2.6, 2.6, 0.05), mat="toile", t=0.7, y=8.2),
    "griffures":       dict(mode="wall", size=(1.4, 2.4, 0.04), mat="tache", col=(30, 22, 20), y=4.0),
    "cadre retourné":  dict(mode="wall", size=(1.2, 1.6, 0.12), mat="bois_sombre", y=5.0),
    "dessin à la craie": dict(mode="wall", size=(2.6, 2.4, 0.03), mat="craie", y=3.5),
    "toise":           dict(mode="wall", size=(0.5, 5.0, 0.05), mat="bois", col=(150, 120, 80), y=2.8),
    "affiche déchirée": dict(mode="wall", size=(2.0, 2.6, 0.04), mat="papiers", y=5.0),
    "horloge arrêtée": dict(mode="wall", size=(1.4, 1.4, 0.2), mat="bois_sombre", y=7.0),
    "calendrier":      dict(mode="wall", size=(1.2, 1.6, 0.06), mat="papiers", col=(190, 175, 140), y=5.0),
    "miroir voilé":    dict(mode="wall", size=(2.0, 3.4, 0.1), mat="linge", col=(160, 160, 160), y=4.2),
}

# Pièce -> objets, dans l'ordre de pose. Chaque pièce raconte un morceau de l'histoire.
ROOM_DETAILS = {}


ROOM_DETAILS["pn"] = ["toile d'araignée", "flaque", "caisse défoncée", "empreintes", "terre"]
