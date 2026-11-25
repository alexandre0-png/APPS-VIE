---
type: jeu
jeu: 3
statut: prive-publie
---
# Jeu 2 : Chipe-Œufs (ancien Jeu 3)
- Univers **10776613087**.
- **Hub** : lieu **115261336085924** (lieu de départ).
- **Partie** : lieu **87012762353093** « Partie Chipe-Oeufs » (Max Players 5).
- Dossier `roblox/`, branche `claude/lucid-wozniak-o23lf0`.
- Session : `session_0164z8QSjguKxoDaDm6aN2MU`.
- **Dernier publié** : commit 087efed (hub v14, partie v9).
- Obsolète : lieu 106358102689021 et univers 10776613783 (ancien hub séparé).

## Contenu
- 1 à 5 joueurs, amis qui rejoignent en cours de partie via liste blanche serveur (identifiants de parties en GUID).
- Retour au hub depuis le menu Plus. Manette : X boutique, Y missions, Select Plus, B fermer.
- Décor du hub : 13 modèles catalogue. Œufs : voir [[Assets/IDs-catalogue]].
- Tests : `lune run roblox/tests/run.luau` (1431 réussis), `python3 roblox/tools/check.py`.
- Sons : crochets muets, aucun identifiant inventé.

- 21 nov : commit ebb5271 (pets Tigre, Kraken, Calmar, Wyrm). Publié en privé : hub v27, partie v21.
- 21 nov (après-midi) : retours utilisateur envoyés à la session (sol du hub qui scintille, pets trop gros, bâtiment évolutif par rareté d'œuf, zones et gardiens plus durs et espacés style île en terrasses de la vidéo, placement planifié, icône de recyclage). En cours, rien publié.
- 21 nov : commits c8b2e04..8b00c87 (sol, échelles, icônes, base à 8 niveaux, placement, zones) publiés : partie v22, hub v28. Reste : relief en terrasses et terrain (demandé à la session), branchement du lot 10 Blender.
- 21 nov : publié partie v23, hub v29 (85d539d eau/ponts, 9c2b19b 27 modèles). Demandé : Gus plus clément, nouveaux arbres/chemins/protections d'œufs (lot 11), déplacement des domaines + culling client.
- 21 nov : boutique créée par API (univers 10776613087) : passes Coins2x 2093291260 (199), Lucky 2093447290 (149), Fast 2097173053 (149), Speed 2092253306 (149), VipBase 2094209172 (399) ; produits StarterPack 3734229313 (99), ExclusiveEgg 3734229320 (249), Revive 3734229323 (49), InstantHatch 3734229329 (49), LuckPotion 3734229337 (99), CoinPack 3734229339 (99). Commit 51509b7 publié : partie v27, hub v33.
- 21 nov (soir) : retours test traités (d26b53e chargement Blender parallèle + diagnostic « Blender N/M », facc4fa revenu actif seulement, beecd9c œuf = rareté du pet (5 % d'amélioration annoncée), 6fbfc9c carte réduite à 188-269 studs + 3 portails + boussole, 71c5b7e mobs). Publié : partie v28, hub v34. Économie non recalibrée (progression plus lente). Pets v2 chibi mis à jour en place.
- 25 nov : PvE (179ad1b..9aeb2c5) publié v30/v37 ; PvP asynchrone (6f83287) publié v31/v38. REFONTE demandée par l'utilisateur d'après carte parchemin : cahier des charges dans Jeux/REFONTE_CHIPE_OEUFS.md (agent Opus). Nouveaux achats créés par API (univers 10776613087) : passes ExtraSlots 2098181699 (249), PrivateBelt 2098265697 (299) ; produits ServerLuck 3736121217 (129), GoldenBelt 3736121227 (99), RemoteSteal 3736121232 (79), RemoteStealPack 3736121238 (199). Modèles lots 15 et 16 dans Assets/Assets-crees.md.
- 25 nov : refonte lots 1-2 (927200a, 7a4cbbd, c29c48c, 18c492f, f94b9a7) publiés : partie v32, hub v39. Nouvelle carte 700x500 (MapGeo), 7 gardiens par territoire, voyage rapide TRAVEL2. Reste : lots 3 à 8 (tapis central, difficulté, maison évolutive, énigme Mère Poule, monétisation, équilibrage).
