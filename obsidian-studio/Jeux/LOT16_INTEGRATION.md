# Lot 16 : brief d'intégration (préparé par la gestion, 2026-11-27)

Spec : `LOTS_9_PLUS.md` sections H (monétisation), I (rétention/mesure), G.5 (saison), « Lot 16 » de K. Ordre fixé par l'utilisateur : 8, 9b, 10 d'abord, puis 15, puis 16, puis 11–14. Revue sécurité (`roblox-security-reviewer`) OBLIGATOIRE : 0 défaut critique/élevé.

## Décisions qui PRIMENT sur H
1. **Œufs Secret / Exclusif / Divin vendus** (décision utilisateur, déjà créés et branchés au lot 9) : EggSecret 3736452048 (1 499), EggExclusive 3736452061 (3 499), EggDivine 3736452072 (6 999). Ils sont `random = true` (espèce/taille/mutation), la RARETÉ est fixe et affichée avant achat ; masqués + refusés côté serveur si `ArePaidRandomItemsRestricted` ou si l'appel PolicyService échoue. H.1.2 et la ligne « jamais en vente » de H.2 sont donc corrigées : seules restent non vendables l'XP de pet, les stats, la protection anti-vol, les trophées.
2. **CalendarCatchup** (29 R$) existe déjà : 3736695392 (branché au 9b). `StreakRestore` (29) à créer par la gestion.
3. **Ordre des raretés** : toujours via `Config.TIERS` (10 niveaux) et TIER_GATE, jamais de rang en dur. Les noms d'œufs de la liste H (EggR2…EggR7) correspondent aux rangs réels des 10 raretés du lot 9 : vérifier la correspondance (r7 = Ultra Rare).
4. **Prix en pièces vs Robux** : règle utilisateur (pièces 4–12× plus longues que Robux) : ne pas casser le recalibrage du lot 9 ; tests de non-régression de l'économie.
5. **Écarts de rythme du lot 9 à corriger dans ce lot** : maisons 4–8 pire cas dans ±25 %, niv.7 médiane ~2 j, Divin ~2 mois, Secret ~1 sem, planchers tapis (+15 % doré, +10 % privé) testés.
6. Produits à id = 0 jusqu'à ce que la gestion les crée par l'API (liste ci-dessous) ; tests d'ids adaptés ; liste exacte dans `PUBLICATION.md`. NE PAS demander à l'utilisateur de créer des produits.

## Produits à créer par la gestion (ids à brancher dès réception)
Palier 1 : CoinPackS 19, EggR2 15, EggR3 25, LuckPotionMini 29, EggR4 49, ArenaTickets 19, StreakRestore 29, EmoteVictory1..6 39.
Palier 2 : EggR5 99, DoubleLuck 149 ; pass EggBagPlus 149.
Palier 3 : SeasonPremium 399, SeasonPremiumPlus 799 ; passes Collector 249, Lucky2 349.
Palier 4 : EggR7 799, BundleLegend 999, BundleRoyal 1 499 (création après confirmation directe de l'utilisateur pour les prix ≥ 799).

## Étapes
1. `Config.PRODUCTS/PASSES` (H.2) avec `id = 0`, `random`, plafonds `buys` (jour/semaine/mois).
2. `Shop.lua` pur : plafonds, éligibilité, texte des tables (`Config.eggContentText`).
3. `Main.server.lua` `ProcessReceipt` : plafonds AVANT octroi, course → compensation en pièces/jeton, reçu rejoué = 1 seul crédit, PolicyService, aucun produit r8/r9 aléatoire hors décision 1.
4. UI boutique 4 onglets (Œufs, Chance, Passes, Saison), fiche de chaque œuf avec sa table, offres contextuelles `Config.OFFERS` (3/session, 300 s).
5. Saison : `Config.SEASON` (28 jours, 30 paliers, XP saison), passe premium créditant les paliers déjà atteints une seule fois.
6. `Telemetry.lua` (I.2) : 6 types d'événements, ≤ 1/s/joueur ; `Config.BUILD`.
7. Tests de la section « Lot 16 » de K + Double chance plafonnée à 70 + aucun produit ne touche `Battle.STATS`, `slot.x`, protections.
8. Revue sécurité, rapport : écarts, À tester dans Studio.

---
## ADDENDUM (décisions utilisateur du 2026-11-27) : PRIMENT sur tout ce qui précède

### A. Plus de plafonds d'achat
- Supprimer les plafonds jour/semaine/mois de H.2 (10/jour, 5/jour, 3/jour, 1/semaine, 1/mois, `buys` par période). **Seule exception : ce qui ne s'obtient qu'une fois** (passes permanents, Pack de départ, chaque pose de victoire, passe de saison premium une fois par saison, `SeasonPremiumPlus`/complément une fois par saison, avantages à vie). Le Coffre royal et le Pack Légende ne sont plus limités.
- Gardes qui RESTENT (équilibre et sécurité, pas des plafonds d'achat) : Double chance plafonnée à 70 points (puissance) ; durées de bonus cumulables sans limite ; contrôle de place avant l'invite d'achat d'un œuf (base/sac d'œufs pleins → l'achat est refusé AVANT paiement avec un message « fais de la place ») ; débordement après paiement (course) → l'œuf va dans un coffre de débordement (`overflow`, sans limite, récupérable plus tard), jamais perdu ; un seul crédit par reçu ; PolicyService pour tout produit `random`.
- Tous les textes (`ShopInfo`, définitions) cessent de parler de « plafond ».
- Mise en garde produit : sans plafonds, l'écran d'achat des œufs aléatoires doit toujours afficher la table de probabilités et une confirmation claire du prix ; pas d'offre à l'écran après un achat répété (pas de relance incitative).

### B. Passe de combat (saison) qui change tous les 2 mois
- Remplace la « saison de 28 jours » de G.5 : **saison de 60 jours** (`Config.SEASON.days = 60`, début = date UTC fixe, enchaînement automatique, les saisons suivantes sont des données `Config.SEASONS[n]`).
- Nom affiché : « Passe de combat ». Piste gratuite + piste premium (SeasonPremium 399, SeasonPremiumPlus 799, complément 400 : ids déjà créés ; le même produit est revendu à chaque saison via `season.premium = n`).
- 30 paliers, XP de saison orientée combat : victoire PvE 20, victoire PvP/duel 30, quête du jour 100, quêtes de la semaine 300, éclosion Épique+ 50 ; plafond d'XP/jour ≈ 400 (mesuré par un joueur-robot : un joueur actif régulier finit les 30 paliers en ~45 jours, un joueur occasionnel y arrive en ~60 j avec la piste gratuite jusqu'au palier 20).
- Récompenses : pièces, œufs jusqu'à Épique (gratuit) / Mythique (premium), jetons de combat, parchemins XP, cosmétiques et auras de la saison, **espèce Exclusif fixe de la saison** au palier 30 premium, 1 Légendaire au palier 30 gratuit.
- Thème par saison (rotation de 6 : Feu, Glace, Foudre, Ombre, Nature, Ciel) : décor, bannière, aura et espèce de saison changent ; fin de saison : écran récapitulatif, récompenses non réclamées perdues SAUF celles réclamables pendant 7 jours de grâce ; les cosmétiques de saison ne reviennent pas (étiquetés « Saison N »).
- Tests : bascule de saison à l'heure UTC, un achat de premium en cours de saison crédite les paliers déjà atteints une seule fois, rien ne chevauche deux saisons, XP plafonnée/jour, profil sans saison migré.
