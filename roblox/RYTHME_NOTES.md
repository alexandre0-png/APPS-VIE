# Lot 16 : correction des écarts de rythme du lot 9 (NON INTÉGRÉ)

Branche de worktree, sauvegarde `git tag backup/roblox-lot16-rythme-2026-11-27` (sur 91f6907). Tout ce qui suit vient de la simulation
(`tests/Economy.lua`, joueur-robot, temps de jeu ACTIF, graines 1 à 5 comme les tests). **Rien n'a été joué dans Studio.**

## Diff de Config.lua (blocs économiques seulement)

| Valeur | Avant (lot 9) | Après (lot 16) |
|---|---|---|
| `EGG_PRICE[6]` Mythique | 370 000 000 | **609 975 778** |
| `EGG_PRICE[7]` Ultra Rare | 70 000 000 000 | **42 933 105 815** |
| `EGG_PRICE[8]` Secret (tapis x 0,6) | 80 000 000 000 | **75 000 000 000** (règle 3 : sinon x12,04 sur une graine) |
| `HATCH[4]` / `[6]` / `[7]` (s) | 113 / 450 / 600 | **106,14 / 527 / 560** (suite toujours croissante) |
| Revenus Épique Panda / Hibou / Manchot | 32 / 45 / 60 | **33,727 / 52,072 / 56,694** |
| Revenu Légendaire Tigre | 230 | **287** |
| Revenus Mythique Dragon / Kraken | 1 100 / 2 300 | **862 / 1 803** (T-Rex 1 600 inchangé) |
| Seuils maison niv. 4 à 8 (`BASE_LEVELS2`) | 1 234 / 2 008 / 4 135 / 17 029 / 45 562 | **1 092 / 1 866 / 4 695 / 17 754 / 64 000** |
| `BELT.weights.normal` r7 / r8 / r10 | 0,2 / 0,008 / 0,005 | **0,20875 / 0,004 / 0,00025** (r1 inchangé : la somme repliée sur l'Ultra Rare reste 0,213) |
| `BELT.weights.golden` r7 / r8 / r10 | 0,45 / 0,018 / 0,0115 | **0,469925 / 0,009 / 0,000575** (x2,25 / x2,25 / x2,3 du standard) |
| `ODDS.REF` r7 / r8 / r9 / r10 | 0,2 / 0,008 / 0,006 / 0,005 | **0,20875 / 0,004 / 0,001 / 0,00025** (REF = tapis standard, test du lot 10 ; r9 reste entre Secret et Divin) |
| `PRICING` | coûts 370 M / 48 Md / 1 080 Md | **610 M / 45 Md / 1 080 Md**, `timeToAffordCoin` recalculés (`sim_economy.py prix`) |

Rien d'autre : `BASE_WEIGHTS2`, `needTier`, prix r1..r5 (le lot 15 les vérifie), tapis privé, `BOOST_CAP`, Robux inchangés.
Les valeurs à décimales sont celles trouvées par la recherche (arrondir change les trajectoires : la simulation est chaotique, voir plus bas).

Règles de design tenues (tests) : revenus strictement croissants (Lion 170 >= 1,8 x Manchot 56,7 ; Dragon 862 >= 1,8 x Licorne 330 ; Alien 9 000 >= 1,8 x Kraken 1 803),
fourchettes `INCOME_RANGE` respectées, combat inchangé, règle (3) : débutant entre x6,2 et x11,8 du temps Robux sur chaque graine.

## Outil de simulation (tests/Economy.lua)

1. **Défaut du générateur trouvé** : avec Park-Miller 16807, un tirage très proche de 1 est toujours suivi d'un tirage > 0,16 (pas de repli
   modulo). Un œuf Divin n'était donc acheté que si son tirage tombait dans une petite bande ; sous 0,002 % de poids, **jamais** (0 Divin en 120 jours).
   Le « Divin 10 à 16 jours » du lot 9 était en partie un artefact. Correction : second flux Park-Miller 48271 (produit < 2^47) pour (a) la décision
   d'achat (part de 50 %) des raretés >= Secret, (b) le partage Ultra Rare / Secret / Exclusif / Divin une fois que le flux principal a décidé
   « >= Ultra Rare ». Le flux principal est consommé comme avant : **sans projection, les mesures du lot 9 sont identiques au bit près**.
2. `log.affordBelt[8|10]` : premier passage du tapis où le robot pourrait payer l'œuf Secret / Divin (aucun tirage consommé).

## Mesures avant / après (graines 1 à 5, test)

| Jalon | Cible (±25 %) | Avant (lot 9) | Après (lot 16) |
|---|---|---|---|
| 1re éclosion | 10-15 s | 12 s | 12 s |
| Rare / Épique | 3 / 15 min | 2:17-3:25 / 12:35-15:10 | identiques |
| Légendaire | 1,5-2 h | 1,2-1,6 h | 1,3-1,6 h |
| Mythique | 6-10 h | 7,1-9,8 h | 9,4-12,3 h |
| Ultra Rare | 2-3 j | 2,3-3,5 j | 2,7-3,5 j |
| Maison 2 / 3 | 3 / 12 min | 2:37-2:53 / 11-14 min | identiques |
| Maison 4 | 40 min (30-50) | 33 min-1,2 h | **28:28-38:58** (médiane 30:03) |
| Maison 5 | 2 h (1,5-2,5) | 1,1-2,6 h | **1,9-2,1 h** |
| Maison 6 | 6 h (4,5-7,5) | 4,6-5,6 h | **4,9-6,5 h** |
| Maison 7 | 2 j (36-60 h) | 21,6 h-3,1 j, médiane ~1 j | **37,6-47,1 h, médiane 44,1 h** |
| Maison 8 | 10 j (7,5-12,5) | 6,7-10,2 j | **8,8-10,5 j** |
| Secret (projection) | 1-2 semaines | 4,5-10,7 j | **7,9-11,9 j** ; espérance 7,6-8,9 j |
| Divin (projection) | ≈ 2 mois | 10-16 j | **espérance 55,5-59,4 j** ; tirages réels (10 graines, 120 j) : 14,8 / 19 / 28 / 29 / 43 / 61 / 82 / 92 / 103 / > 120 j (médiane ~52 j) |

Tapis (mesure fine, 20 graines, 60 h, moyenne géométrique de cinq jalons d'accès : premier Légendaire, premier Mythique, maisons 5, 6, 7) :
doré **+13,0 %**, privé **+30,7 %**, tout cumulé **+22,8 %** (60 graines : +10,6 / +18,7 / +15,6 %). Revenu gagné (100 graines) : doré +6 à +13 %,
privé +3 à +6 %, très bruité.

## Tests (tests/run.luau, bloc économique)

- Maisons 5 à 8 : pire cas des 5 graines à ±25 % ET médiane à ±25 % (niveau 7 compris) ; niveau 4 : borne du lot 9 conservée (x0,4-x2, médiane).
- Secret : chaque graine entre 5,25 et 17,5 jours (était 3) ; espérance entre 5,25 et 17,5 jours ; Divin : espérance 45-75 jours sur chaque graine, `ODDS.REF` = tapis.
- Planchers : tapis privé >= +10 % de vitesse d'accès et <= BOOST_CAP ; cumul <= BOOST_CAP (+60 %) ; doré >= +5 % (plancher +15 % non atteint).
- Le plafond « privé <= +20 % » du lot 9 sur 5 graines (premier Légendaire / Mythique) devient une information bornée par BOOST_CAP : sans
  toucher au tapis privé, cette mesure passe de +0,9 / -0,9 % (lot 9) à +12,5 / +29,1 % : elle ne mesure que la variance.
- `sellValue` du Dragon lu dans Config (1 100 -> 862).

`run_tests.py` : **3 244 assertions, 0 échec** (3 239 avant, +5) ; `check.py` : aucun problème ; `build_place.py` relancé (rbxlx régénérés).

## Écarts restants (hors cible, documentés)

1. **Maison niveau 4** : 2 graines sur 5 à 28:28 et 28:33 (borne 30:00, cible 40 min) ; médiane 30:03. Aucune combinaison trouvée qui tienne aussi
   les niveaux suivants et les premiers pets (chaque changement de l'ère Épique rebat toute la suite).
2. **Tapis doré** : +13 % de vitesse d'accès (plancher +15 %). Un tapis plus rapide (3,5 s, 3 s) ou plus de tirages rares n'augmente pas la mesure :
   la boutique (jusqu'au Mythique) fixe le rythme et le robot n'achète au tapis que s'il bat la boutique. Il faudrait changer la règle d'achat du
   robot ou le rôle du tapis doré (décision de design), pas une valeur.
3. **Robustesse** : le passage « pire cas à ±25 % » est obtenu sur les 5 graines des tests par recherche locale ; la simulation est chaotique
   (un seuil changé de 2 % déplace le niveau 8 de plusieurs jours). Graines 6 à 15 (hors réglage), dans ±25 % : avant / après :
   maison 4 : 5 / 4 sur 10 ; maison 5 : 2 / 2 ; maison 6 : 8 / 7 ; **maison 7 : 0 / 8** ; maison 8 : 7 / 9 (une graine ne l'atteint pas en 300 h) ;
   Mythique 9 / 9 ; Ultra Rare 9 / 7. Le gain réel et robuste est le niveau 7 (médiane 29,8 h -> 39,4 h) et le niveau 8 ; les niveaux 4 et 5 restent
   très dispersés.
4. **Mythique** plus tard (9,4-12,3 h au lieu de 7,1-9,8 h) : dans la cible élargie (4,5-12,5 h), mais près du haut.
5. **Divin** : c'est l'espérance qui vaut ≈ 2 mois ; un joueur réel peut l'avoir en 2 semaines ou en 4 mois (tirage à 0,00025 %). Aucune
   autre source en pièces que le tapis. L'Œuf Divin Robux (6 999 R$) reste vendu.
6. Le tapis privé dépasse +20 % sur la mesure à 20 graines (+30,7 %) ; il reste sous BOOST_CAP (+60 %).

## Prochaines améliorations

1. Joueur-robot : règle d'achat au tapis (doré) et prise des œufs du tapis privé plus réalistes, puis mesurer sur 20+ graines plutôt que 5.
2. Remplacer les tests « pire cas sur 5 graines » par des bornes sur quantiles à 20 graines (plus stables, moins de surajustement).
3. Vérifier en jeu avec les événements Analytics (`house_level_reached_lN`, `tier_first_reached_rN`).
