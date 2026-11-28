# Lot 10 : notes (fichiers nouveaux, hors intégration)

> **Intégré le 2026-11-26** : voir CHANGELOG.md, entrée « LOT 10 intégré » (branchements, décisions, écarts). Les sections ci-dessous décrivent les modules eux-mêmes.

Partie « fichiers nouveaux » du lot 10 (spec `LOTS_9_PLUS.md`, A.1, B.1 à B.6, K). Aucun fichier du lot 9 n'est touché. L'intégration dans Reveal, Main, Data, Config et les clients se fait après le lot 9. **Rien n'a été testé dans Roblox Studio** : tout ce qui suit est vérifié par analyse statique (`luau-compile`, dump d'API officiel) et par le runtime factice (lupa).

## Fichiers

| Fichier | Rôle |
|---|---|
| `src/ReplicatedStorage/Odds.lua` | Compteur « 1 sur N » (pur, Config passée en paramètre) |
| `src/ReplicatedStorage/HatchPlan.lua` | Plan pur des 10 éclosions (remplace `CinematicKit.hatchPlan` pour le nouvel écran) |
| `src/ReplicatedStorage/IntroPlan.lua` | Plan pur de l'intro de combat |
| `src/ReplicatedStorage/TypeFx.lua` | Données `DATA` des 9 types (futur `Config.TYPE_FX`), coûts, texte d'efficacité |
| `src/StarterPlayerScripts/HatchFx.lua` | Exécute un plan d'éclosion (UI + zoom caméra + teinte) |
| `src/StarterPlayerScripts/BattleIntro.lua` | Exécute le plan d'intro de combat |
| `src/StarterPlayerScripts/TypeFx.lua` | Exécute les effets d'attaque par type |
| `tests/lot10.luau` | Suites (forme `return function(env)`), Config fictif à 10 raretés |
| `tests/run_lot10.py` | Lanceur lupa de `lot10.luau` (sans toucher `run.luau`) : `python3 roblox/tests/run_lot10.py` |

## Brancher (une ligne par module)

- **Odds** : serveur, à l'éclosion, `slot.o = Odds.forPet(Config, petIdx, s, m)` (une seule fois, jamais recalculé), `slot.ov = Config.ODDS.version` ; client `Odds.label(slot.o)` ; annonces `Odds.fx(n, r, Config)` (champs `announceServer`, `announceWorld`, `pillar`, `banner`, `secretSound`, `billboard`). Exige `Config.ODDS = { version = 1, billboardMin = 1000, REF = { 50, 25, 14, 7, 2.9, 0.85, 0.2, 0.04, 2, 0.01 } }` (+ `specialMin` optionnel), `Config.SIZES/MUTS[i].weight`, `Config.PETS[i].tier`. Remplacer `Config.fmtOdds` par `Odds.label` (ou l'appeler) : le séparateur de milliers est ici l'espace insécable U+00A0.
- **HatchPlan** : `HatchPlan.plan(slot.r, slot.o, { reduced = mobile, firstTime = premiereFoisCetteRareteHaute, still = oeufPorteOuPoursuite })`.
- **HatchFx** : `HatchFx.play(screenGui, plan, { colors = {main, second}, rarityName, petText, slot = {rarity, size, mut, pools}, fmtOdds = Odds.label, sound = function(key, volume) end, onReveal, onDone, hide = { autresGuis } })` ; en-tête du fichier pour le détail. Les clés de son demandées : `plan.sound.key`, `"fanfare"` (r >= 8), `"secret"` (N >= 1 M), `"divine"` (r10, `Config.SOUNDS.divine`, id vide = silence). `onReveal` est le point où afficher la carte du pet (garanti une fois, même au passage).
- **IntroPlan + BattleIntro** : `BattleIntro.play(gui, IntroPlan.plan(info, { fmtOdds = Odds.label }), { thumbnail = fn(userId) -> image, sound, onDone = demarrerLeCombat })`.
- **TypeFx (données)** : `Config.TYPE_FX = require(ReplicatedStorage.TypeFx).DATA` ; `TypeFx.efficacy(mult)` donne le texte et la couleur RGB.
- **TypeFx (client)** : `TypeFx.play(gui, Config.TYPE_FX[typeAttaquant], estSpecial, { from = Vector2, to = Vector2, reduced, shakeFrame, sound, onDone })` et `TypeFx.floatText(gui, texte, rgb, x, y)`.

Aucun module client ne fait de `require` : tout est injecté, rien ne s'exécute à l'import.

## Décisions (prises en autonomie)

1. **Durées** : r10 passe de 9,0 s (spec B.3) à **8,0 s** (plafond demandé) ; les 9 autres suivent B.3 exactement. L'intro de combat dure **3,0 s** avec décompte (2,2 s sans), au lieu de 3,5 s (spec B.4), passable après 1 s.
2. **Budget d'objets** : la spec dit « 30 Parts ». L'écran est 100 % interface (Frames/TextLabels, aucune Part 3D) : le plan plafonne donc à **30 objets d'effet** (`plan.objects`) et **40 objets/s** (`plan.peakRate`, mesuré sur une grille de 0,05 s) ; les plus gros `n` sont réduits d'un cran jusqu'au respect (ex. r10 : rayons 16 -> 12 environ). La version réduite (mobile) **divise par deux les particules** (`plan.particles`, arrondi bas) ; bandeau, texte, ailes et pilier restent. Plafond dur supplémentaire de **220 instances** par éclosion (échafaudage et décorations compris), 120 pour l'intro, 80 par effet de type.
3. **Compteur** : le serveur doit stocker l'entier retourné (une décimale seulement si N < 10, comme la spec). N est plafonné à 2^53 (classement OrderedDataStore). `n_r` = espèces de `Config.PETS` dont `tier == r`, hors `published == false` / `hidden == true` ; on peut aussi passer `nr` explicitement (le serveur fige `slot.o`, donc `n_r` qui change plus tard ne réécrit pas l'ancien chiffre).
4. **Compteur de l'éclosion** : monte de 1 à N en 0,8 s (12 paliers, ease out cubique) ; limité à `durée - revealAt` pour les éclosions courtes (r1 : 0,7 s). Pas de rebond « son » : l'appelant joue `secret` si `plan.secretSound`.
5. **Non passable** : seulement `firstTime` (décidé par l'appelant, par joueur et par rareté) ET r >= 8. Sinon tap après 1,5 s (`plan.skipAfter`). Un tap avant est ignoré.
6. **Caméra** : seul le champ de vision est animé (zoom r5 et r10 ; `still = true` le supprime). Le FOV d'origine est mémorisé par le premier zoom actif et restitué par le dernier (éclosions qui se chevauchent : bug trouvé par le test de 200 éclosions et corrigé). Si `FieldOfView` n'est pas un nombre, la caméra n'est jamais touchée. La désaturation r9 et la teinte rouge r6 passent par un `ColorCorrectionEffect` temporaire détruit à la fin (ne touche pas l'interface, donc le pet reste coloré).
7. **Types** : 9 types de D.2 avec le nom « Plante » ; l'ancien nom « Nature » est un alias (`TypeFx.canonical`). Chaque couche d'un effet crée exactement `n` objets, coût `1 + somme(n)` (base <= 14, spécial <= 30).
8. **Nom en double** : `ReplicatedStorage/TypeFx` (données) et `StarterPlayerScripts/TypeFx` (client) ont le même nom comme demandé ; ils sont dans des dossiers différents et le client ne fait pas de `require`. Si `build_place.py` mappe par nom seul, renommer l'un des deux (par ex. `TypeFxData`).

## Vérifications exécutées

- `luau-compile` sur les 7 modules : OK. `check.py` : syntaxe, classes et enums Roblox, variables inutilisées : sans erreur pour ces fichiers (le contrôle « place à jour » échoue tant que `build_place.py` n'est pas relancé par le coordinateur).
- `python3 roblox/tests/run_lot10.py` : 106 assertions, 0 échec (lupa, Lua 5.x, **pas Luau**).
- Mutations sur une copie (répertoire temporaire du scratchpad), chacune détectée : formule `n_r+1` (4 exemples en échec), durée r10 à 9 s (4 échecs), caméra non restituée (4 échecs), interface non restituée (2 échecs).

## À tester dans Studio (non testé)

Rendu réel des 10 animations (positions, tailles, lisibilité mobile), emojis (👑 🥚 💧 🍃 ❄ ☁ ✦) selon la police, fluidité mobile (>= 30 FPS pendant r10), `ColorCorrectionEffect` dans Lighting, `ImageLabel` du portrait avec `rbxthumb://`, secousse de l'écran de combat, sons (`secret`, `fanfare`, `divine`).
