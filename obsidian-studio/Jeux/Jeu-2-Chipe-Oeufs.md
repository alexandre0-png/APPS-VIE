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
- 25 nov (soir) : refonte lots 3-4 (tapis central, difficulté des territoires) + correctif 2e7013a (GetServerTimeNow du banc de test) publiés : partie v33, hub v40. Lune 2176/0. À faire côté session : régénérer build/ChipeOeufs.rbxlx (check.py signale 2 fichiers périmés). Modèles lots 15-19 prêts (maisons, dôme, tapis, grand œuf, arène, accessoires, décor, meubles).
- 25 nov (nuit) : refonte lot 5 (4c098aa, maison évolutive 8 niveaux, profil v10) publié : partie v34, hub v41. Lune 2208/0. Reste : lots 6 à 8 puis lots 9 à 16.
- 25 nov (nuit) : refonte lot 6 (7534174, énigme de la Mère Poule 3 étapes, Lune 2317/0) publié : partie v35, hub v42. Reste : lot 7 (monétisation, corbeau, revue sécurité), lot 8, puis lots 9 à 16.
- 26 nov : refonte lot 7 (07896da : monétisation honnête, Corbeau chipeur, reçus idempotents, PolicyService) publié EN PRIVÉ : partie v36, hub v43 (Lune 2402/0). REVUE SÉCURITÉ INDÉPENDANTE (agent roblox-security-reviewer) : 0 critique, 1 ÉLEVÉ (indemnité du corbeau exploitable avec 2-3 comptes : œuf volé puis revolé), 2 MOYENS (pass à hasard actif après reconnexion pour compte restreint ; jeton en vol perdu à l'arrêt du serveur), 6 faibles. NE JAMAIS PASSER EN PUBLIC avant correction (envoyée à la session Jeu 2).
- 26 nov : mini-lot 7b (2905e87 : correctifs de la revue de sécurité : indemnité corbeau plafonnée 900/jour, pass à hasard désactivés si compte restreint, jetons rendus à l'arrêt, faibles) publié en privé : partie v37, hub v44. Lune 2446/0. 0 défaut critique/élevé restant selon la session ; complice peut encore toucher 900/jour. Reste : lot 8A/8B puis lots 9-16.
- 26 nov : prix confirmés par l'utilisateur (Divin abaissé à 6 999). Produits créés par API : EggSecret 3736452048 (1 499 R$), EggExclusive 3736452061 (3 499), EggDivine 3736452072 (6 999). Achats existants : passes Coins2x 2093291260, Lucky 2093447290, Fast 2097173053, Speed 2092253306, VipBase 2094209172, ExtraSlots 2098181699, PrivateBelt 2098265697 ; produits StarterPack 3734229313, ExclusiveEgg 3734229320, Revive 3734229323, InstantHatch 3734229329, LuckPotion 3734229337, CoinPack 3734229339, ServerLuck 3736121217, GoldenBelt 3736121227, RemoteSteal 3736121232, RemoteStealPack 3736121238.
- 26 nov : lot 8A (3ffbc71 : alarme du nid Mara/Zed, économie, perf, 7 sons) publié en privé : partie v38, hub v45 (Lune 2471/0). Rythme recalibré demandé (maison niv.2 3 min -> niv.8 ~10 j ; Légendaire 1h30-2h ; Mythique 6-10h) pour le lot 9. Lot 9 en cours.

## Lot 9 publié (privé) — 2026-11-26
Commit 15fb5a7 : 10 raretés, œufs r1..r10, migration profil v11, recalibrage du rythme, règles revenu/force, produits Secret/Exclusif/Divin (cachés tant que les espèces du lot 11 n'existent pas). Vérifié : Lune 2548/0, run_tests, check.py, builds Rojo. En ligne : partie v39 / hub v46 (privé).
Écarts de rythme à corriger : maisons 4–8 pire cas hors ±25 %, niv.7 ~1 j (cible 2), planchers tapis (+15 % doré / +10 % privé) non testés, Divin 10–16 j (cible ~2 mois), Secret pire cas 4,5 j (cible ~1 sem).

## Lots 9b + 10 + 8B publiés (privé) — 2026-11-27
Commit 2aa0afb (contient 9b : calendrier 30 jours, J30 Mythique 40 / Ultra Rare 45 / Secret 15 avec repli Ultra Rare ; 10 : compteur « 1 sur N », HatchFx, BattleIntro, TypeFx, 37 sons, 42 icônes ; 8B : kiosque central, décor carte/tapis, meubles par niveau). Vérifié : Lune 2988/0, run_tests code 0, check.py aucun problème, builds Rojo. En ligne : partie v40 / hub v47 (privé). Non testé dans Studio.
Reste : lots 15 (modules purs prêts, e30ec74), 16 (catégories boutique, vendeurs PNJ lot 30, ShopInfo, passe de combat 60 jours, mise à niveau, plus de plafonds, écarts de rythme), puis 11–14.

## Lot 15 publié (privé) — 2026-11-27
Commit 91f6907 « Lot 15 intégré » : PNJ, série 7 jours, quêtes bonus et hebdomadaires, rotation, événements, sac d'œufs, profil v12. Vérifié : Lune 3239/0, run_tests code 0, check.py aucun problème, builds Rojo. En ligne : partie v41 / hub v48 (privé). Non testé dans Studio.
