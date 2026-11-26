# Lot 8B : état réel après intégration (2026-11-26)

Lot 8B intégré : kiosque central, décor de carte (lots 15 à 17), meubles des maisons (lots 18 et 19). Sauvegarde : `git tag backup/roblox-lot8b-2026-11-26`.
**Rien n'a été joué dans Roblox Studio** : vérifié par `tools/check.py`, `tools/run_tests.py` (2 988 assertions, dont les suites kiosque 124, décor 93,
meubles 50 et 9 assertions d'intégration dans le vrai `Main.server.lua`) et les trois runners autonomes `tests/run_kiosk.py`, `run_decor.py`, `run_housedecor.py`.

## Fait
- **Kiosque central** (`Kiosk.lua`, `KioskData.lua`) en x = 14, z = 22 (`Config.Map2.kiosk`, r = 12 d'exclusion du décor) : modèle `hub.kiosk` 90238570290603
  (plafond 220 Parts) ou repli procédural. Construit deux fois par `Main` (repli immédiat au démarrage, puis modèle après `assets.loadGroup("hub")`), idempotent.
  4 prompts validés par le serveur (`Kiosk.handle` : liste blanche, distance mesurée par le serveur 20 studs, pause 0,6 s par joueur) ; remote `Kiosk`
  serveur -> client seulement. Boutique et calendrier rouvrent les panneaux existants ; probabilités / prix et classement : carte de texte (panneau « Kiosque »).
  Classement en cache 30 s (`Data.pvpTop`). Pastille rouge du calendrier branchée sur `Calendar` (vue `Lot7.Cal.snapshot`, toutes les 5 s).
- **Onglet « 🎟 Passe de combat »** dans la Boutique : emplacement seulement (« Bientôt », rien à acheter) ; contenu au lot 16.
- **Décor de carte** (`Decor.lua`, `DecorData.lua`) : `Builder.dressDecor` / `Builder.refreshDecor`, appelé dans la tâche des Assets après le château ;
  budgets `Config.Assets.decorBudgetParts` 1000, `decorFallbackParts` 240, `decorOff`. Le décor ne touche jamais le disque du kiosque (testé dans le vrai Main).
- **Meubles** (`HouseDecor.lua`, `HouseDecorData.lua`) : `applyBase` -> `HouseDecor.apply` sur la nouvelle maison à chaque construction ou montée de niveau
  (tâche séparée, LoadAsset cède la main). Repère exposé par `Builder.baseUpgrade` (attributs `DecorY` / `DecorZ` = `zc` de la maison procédurale, centre du modèle Blender).

## Écarts et décisions
1. **Ambiance `kiosk_ambience`** : jouée par le client (`setLoop`, 30 studs de `Config.Map2.kiosk`, volume général et fondu) et non par un Sound du monde :
   option `noAmbience` ajoutée à `Kiosk.build` (sinon le son aurait été doublé et hors du réglage de volume). L'ancienne boucle près des étals est supprimée.
2. **Pastille du calendrier** commune à tous : allumée dès qu'un joueur présent a une récompense ; le détail par joueur est dans la réponse du prompt.
3. **Tapis Blender** : avec le kiosque réel (hors du rectangle du tapis), le tapis du décor est maintenant planifié (le test du décor qui supposait le kiosque
   au centre de la place a été adapté). **Buissons de la couronne : 3 au lieu de 4** (plus que 3 places libres avec kiosque + tapis).
4. **Catégorie du rapport F3** : `decor` s'affiche « décor de carte », `hub` « kiosque » (test du décor adapté).
5. **Meubles : correction d'une course** : `HouseDecor` relit le repère de la maison APRÈS chaque chargement (pendant l'animation de montée, la maison attend sous
   le sol) et s'arrête si la maison a été démolie pendant le chargement.
6. **Repère des meubles** pour les maisons Blender (niveaux 2 à 7) : plancher supposé à y = 1,6 et centre = centre de la boîte du modèle ; niveaux 1 et 8 :
   centre de la dalle (y = 1,02). Origine réelle des modèles inconnue : à vérifier dans Studio.
7. **Budget de Parts** : la formule du test « Budget mobile » inclut maintenant le décor de carte (1000 + 240) et le kiosque (220) : 6 450 <= 7 000. Les meubles
   (au plus 136 Parts réservées par maison de niveau 8) ne sont pas dans cette formule : le cumul de TOUS les pires cas (5 maisons de niveau 8 entièrement en
   modèles Blender) dépasserait 7 000 d'environ 130. Mesure dans le runtime factice (10 min, 5 joueurs) : 3 784 Parts sans joueur, pic 3 944.
8. `Builder.build()` retourne une table : le kiosque est posé dans `world.folder` (dossier World).
9. Test « Plan : pièces = minutes de revenu (plancher 500) » (lot 9b) : il échouait sur l'ancienne base des worktrees (ca484b2 : le test attendait l'œuf
   Ultra Rare 5 au jour 30, avant le recalibrage J30). Déjà corrigé sur la branche par le correctif du lot 9b (0951c0e / 2291d2b : œuf 6) ; il passe, rien à changer.

## Non fait (volontairement, lot 16)
- Vendeurs PNJ et catégories de la boutique ; contenu du passe de combat.
- Arène liée à BattleUi ; entrée de donjon. Travail partiel antérieur de 8A : `git stash@{0}` (non appliqué, non touché).

## À tester dans Studio
Voir `A_FAIRE_UTILISATEUR.md` §3sexies : orientation des panneaux du kiosque, échelle des 29 décors, meubles dans les maisons, FPS mobile à 5 joueurs, rendu.
