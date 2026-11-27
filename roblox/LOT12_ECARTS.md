# Lots 11 + 12 : écarts et décisions d'intégration (2026-11-27)

Bestiaire de 78 espèces (lot 11), moteur de combat refait (lot 12 A), cartes de récompense, XP de pet et écran de combat (lot 12 B), intégrés sur le lot 16
à partir du patch combiné de la gestion (préparé sur le lot 15). **Rien n'a été joué dans Studio** : vérifié par `check.py` et les tests lupa
(`run_tests.py`, `run_lot11.py`, `run_lot12a.py`, `run_lot12b.py`). Revue de sécurité : `LOT12_SECURITE.md`. Écarts propres à chaque lot : README « Brancher »
des dossiers `lots-prep/chipe-11`, `chipe-12a`, `chipe-12b`, `combined-11-12` de la branche de gestion (repris ci-dessous quand ils restent vrais).

## Fusion avec le lot 16 (4 rejets du patch, résolus à la main)

| Fichier | Rejet | Résolution |
|---|---|---|
| `Config.lua` | `PRICING.EggDivine.timeToAffordCoin` recalibré par le lot 11 (687 360 / 651 900 / 406 560) | **Non repris** : le lot 16 a recalibré la même ligne après ses écarts de rythme (625 440 / 589 620 / 293 700). Le test « Règle (3) EggDivine » (médiane de 5 graines, tolérance 2 %) passe avec les 78 espèces : la valeur du lot 16 reste juste. |
| `Data.lua` | `require` de `BattleRewards` et `PetXp` | Ajoutés après `Rewards` (le lot 16 avait inséré `SeasonMod` au même endroit). |
| `Main.server.lua` (hunk 4) | `luckPoints` lit la carte `luck10` | Reporté dans la nouvelle formule du lot 16 (Chance +10 % II, Double chance) : `luck10` = même effet que la potion de chance (`luckUntil`). |
| `Main.server.lua` (hunk 7) | Tour : 3 cartes au lieu de `Config.towerReward` | Reporté dans la condition du lot 16 (`TW.dailyRepeats + tickets d'arène`) : les tickets d'arène ajoutent donc des tirages de cartes. XP de pet (tour) via `PetXp`, `sendPick` après l'envoi de `end`. |
| `build_place.py` | `Bestiary`, `PetXp`, `BattleRewards` dans `SHARED` | Ajoutés après les modules du lot 16. |

## Décisions prises pendant l'intégration

| # | Point | Décision |
|---|---|---|
| 1 | Revenus des 18 espèces historiques : le lot 16 (écarts de rythme du lot 9) a changé Panda, Hibou, Manchot, Tigre, Dragon, Kraken ; `Bestiary.lua` portait encore les valeurs du lot 15, donc le garde-fou de `Config` refusait le bestiaire (repli silencieux sur 18 espèces, 6 tests en échec) | `Bestiary.PETS[1..18]` aligné sur `Config.PETS` (valeurs du lot 16). Les fourchettes `INCOME_RANGE`, la croissance de 1,8 entre raretés et l'absence de doublon restent vérifiées (lot 11 : 55 + 13 assertions). |
| 2 | Hook `giveEgg` des cartes Œuf (arbitrage de la gestion) | Place libre cherchée AVANT : base -> `giveEgg` ; base pleine -> sac d'œufs puis coffre de débordement (`Lot7.L16.storeEgg`) ; jamais l'ancien `giveEgg` (demi-prix) ni la conversion en pièces. Le README 12 B disait « base pleine : pièces au prix plein » : remplacé (l'œuf est toujours gardé). |
| 3 | Espèce Exclusif de la saison (palier 30 premium) | `SeasonData.SPECIES[1]` = « Corbeau couronné » (espèce Exclusif du bestiaire marquée `event = "saison1"`). Saisons 2 à 6 : noms prévus gardés (« Yéti d'Aurore »…), espèces pas encore créées : trophée Exclusif de repli. Loup-garou citrouille et Renne étoilé restent des espèces d'événement (Halloween / Noël). |
| 4 | Offres Secret / Exclusif / Divin / Peu commun du lot 9 et du lot 16 | Visibles maintenant (les 10 raretés ont des espèces) ; toujours masquées et refusées sans espèce (testé avec et sans bestiaire). Le calendrier J30 tire vraiment du Secret (40 / 45 / 15 %) ; le repli Ultra Rare reste testé (Config seul). |
| 5 | Une seule source d'XP | `PetXp` (exposant 1,1, `MAX_XP` 9 734) ; `Battle.unit` lit `PetXp.level(slot.x)`, `Battle.levelMul` délègue à `PetXp.statMul` ; anciennes fonctions d'XP de `Battle` supprimées. |
| 6 | STATS, `DAMAGE_MUL`, `Config.TYPE_WEAK` | STATS r = 1 50/8/12, r = 3..7 inchangés ; `DAMAGE_MUL` 1,6 (deux camps) ; `TYPE_WEAK` = type qui BAT chacun (patch d'une ligne). |

## Tests existants adaptés (sans les affaiblir)

| Test | Pourquoi | Adaptation |
|---|---|---|
| `lot12a` : « aucun produit ne mentionne l'XP » | « Potion express » (lot 16) contient « xp » | Recherche du MOT « xp » (`%f[%w]xp%f[%W]`) ; « expérience », `def.xp`, `def.petXp` toujours refusés. |
| `lot12a` : « ProcessReceipt sans STATS » | Un commentaire du lot 16 contenait le texte `Battle.STATS` | Commentaire reformulé (« stats de combat ») ; le test cherche toujours `Battle.STATS` dans tout `Main`. |
| `lot12b` : version de profil | Le lot 16 migre en v13 | Attendu 13 (le lot 12 B n'ajoute toujours aucune version) ; mêmes contrôles de `pendingPick`, `boosts`, `trainer`, `slot.x`. |
| `run.luau` : pack de départ en double (lot 16) | Avec 78 espèces le joueur de test gagne 34 pièces/s : la compensation légitime (revenu x temps Robux) dépasse 20 000 | On vérifie le montant EXACT de la compensation (± revenu de l'appel) et qu'aucun second pack n'est ajouté. |

Nouveaux tests (lot 11 x lot 16, dans `lot11.luau`, 13 assertions) : offres visibles / masquées selon le bestiaire, `Shop.canBuy` Secret, espèce de saison 1 et repli des saisons 2 et sans bestiaire, tirage J30 sur 200 000 tirages Park-Miller, `Odds.validate`, `Odds.forPet` sur les 78 espèces (N croissant par rareté), `HatchPlan.plan`/`check` pour les 78, 60 modèles Blender + plafond de 40 Parts.

## Repris des préparations (toujours vrais)

- Équilibrage : 100 000 combats sur les 78 espèces : écart des espèces jusqu'à 12 points de 50 % (seuil 12 au lieu de 10), types à moins de 4 points ; `lot12a` (espèces réelles, 10 000 combats) : types de 44,5 % à 54 %, 13,0 tours en moyenne.
- Revenus de la table C.2 ramenés dans `INCOME_RANGE` (l'Exclusif R9 rapporte plus que le Secret R8, contraire au texte A.4 : à trancher côté design).
- Repli procédural : au plus 60 Parts par pet procédural (mesuré par `lot11`) ; modèles Blender refusés au-delà de 40 Parts (`petsMaxPartsNew`), le pet reste alors procédural. Le nombre réel de Parts des 60 modèles n'est pas connu hors Studio.
- Combat de PNJ : XP = formule PvE étage 0 x 0,6 (12 gagné / 3 perdu) ; carte Expérience non doublée par l'effet XP x2 ; potion de chance de `towerReward` tous les 5 étages non reprise (D.5 ne la prévoit pas).
- Non branché : `PetXp.carry` (aucun pet ne se vole aujourd'hui), XP de Dresseur, niveau de pet dans l'inventaire, interface du bestiaire (filtres, silhouettes).
- Serveurs mixtes : publier les deux lieux d'un coup (un serveur du lot 16 perdrait un `pendingPick`).
