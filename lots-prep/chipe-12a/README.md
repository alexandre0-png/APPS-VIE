# Chipe-Œufs, LOT 12 PARTIE A : moteur de combat PvE refait (modules purs)

Préparé hors de la branche de jeu (copie de travail du commit 91f6907, lot 15 intégré). Rien n'est publié, aucune clé API.
Spec : `obsidian-studio/Jeux/LOTS_9_PLUS.md` D.1 à D.4, D.6, D.7 et « Lot 12 » de K. `Rewards.lua` (cartes D.5) : non touché (autre agent).

## Contenu

| Fichier | Rôle |
|---|---|
| `roblox/src/ReplicatedStorage/Battle.lua` | moteur refait : remplace le fichier existant (même chemin) |
| `roblox/tests/lot12a.luau` | 89 assertions (matrice D.2, charge/spécial D.3, STATS D.4, XP/niveaux D.6, tour D.7, déterminisme, invariants, 2 x 10 000 combats) |
| `roblox/tests/run_lot12a.py` | lanceur lupa (sans Lune) de ce seul fichier |
| `patches/Config.TYPE_WEAK.patch` | 1 ligne de `Config.lua` (voir « Écarts » 4) |
| `patches/run.luau.patch` | adaptation des anciens tests du moteur dans `tests/run.luau` + branchement de `lot12a.luau` |

`Config.TOWER` : AUCUN patch nécessaire, le lot 9 a déjà posé les 45 étages (`floors = 45`, `tiers = {1..8, 10}`, 9 boss dont Reine de Cristal / Démon enchaîné / Séraphin). Vérifié par les tests.

## Brancher (ordre)

1. Copier `roblox/src/ReplicatedStorage/Battle.lua` sur celui du jeu.
2. Copier `roblox/tests/lot12a.luau` et `roblox/tests/run_lot12a.py` dans `roblox/tests/`.
3. Appliquer depuis la racine du dépôt de jeu : `patch -p1 < patches/Config.TYPE_WEAK.patch` puis `patch -p1 < patches/run.luau.patch` (écrits contre 91f6907 ; si `run.luau` a bougé, reprendre à la main les 5 petits hunks, ils sont indépendants).
4. Adaptations des appelants (aucune n'est BLOQUANTE : l'ancien écran tourne sans elles) :

| Fichier | Ligne actuelle (91f6907) | Changement |
|---|---|---|
| `Main.server.lua` ~3890 (défaite PNJ) | `sl.x = math.min(1e7, (sl.x or 0) + out.xp)` | `sl.x = Battle.addXp(sl.x, out.xp)` (plafond au niveau 20, entrée validée) |
| `Main.server.lua` ~3294-3350 `battleFinish` | (aucune XP PvE) | partie B : pour chacun des 3 pets de l'équipe `sl.x = Battle.addXp(sl.x, Battle.xpReward(win, bt.floor, bt.pvp ~= nil))` ; la valeur est calculée côté serveur, jamais lue du client |
| `Main.server.lua` 3456 / 3430 / 3856 | `Battle.new(seed, mine, foes)` | inchangé (`battleUnits(s)` lit déjà `slot.x` : `Battle.unit` en déduit le niveau tout seul, `x` absent = niveau 1) |
| `Main.server.lua` 3474 | `Battle.validate(bt.st, 1, act)` | inchangé : « skill » = le spécial, refusé avec « spécial pas prêt (n/5) » ; un spécial exigé trop tôt par le temps écoulé (10 s) devient une attaque |
| `BattleUi.lua` 142 | `local special = ev.skill ~= nil or FX.hits[ev.side] % every == 0` | `local special = ev.special == true` (le spécial est maintenant l'événement `special`, plus un hit sur 5) ; `readySoon` : `ev.side == 1 and ev.charge == 4` |
| `BattleUi.lua` 265 | barre de vie | ajouter 5 pastilles `u.charge` / `u.chargeMax` (la 5e pulse quand `u.charge == 5`) |
| `BattleUi.lua` 286-291 | `mu.cd > 0 and (sk.name .. " (" .. mu.cd .. ")")` | afficher `Battle.specialName(mu)` et « charge/5 » : `mu.charge .. "/5"` ; condition d'activation `mu.charge >= mu.chargeMax` (l'ancien `cd` est conservé dans la vue = charge restante, donc rien ne casse sans ce changement) |
| `BattleUi.lua` 96 / 203, `unitText` | `Battle.TYPE_EMOJI[u.type]` | inchangé (9 types couverts) ; libellé « Plante » : `Battle.TYPE_LABEL[u.type]` |
| `Data.lua` 520 | `sl.x = math.min(1e7, ...)` | inchangé (le niveau est plafonné à 20 par `levelFromXp`) ; option : `math.min(Battle.XP_CAP, ...)` si Data peut `require` Battle |
| `Config.lua` | `Config.TOWER` | rien (déjà 45 étages) ; `Config.TYPE_WEAK` : patch fourni |

Événements nouveaux que le client doit tolérer (la boucle actuelle de `BattleUi` ignore les `t` inconnus et lit `Battle.describe`, déjà étendu) : `hit` porte maintenant `charge` et, pour un spécial, `special = true` et `name` ; `discharge` (Gel), `splash` (Chaîne d'éclairs). La vue contient en plus `charge`, `chargeMax`, `level` ; `guard` reste un booléen.

## Ce que fait le module (résumé)

- 9 types, `BEATS` (x1,5 / x0,67, 3 triangles) et `BEATS2` (x1,25 / x0,8), `typeMul`, `TYPE_LABEL` (Nature = « Plante »), `SPECIAL_NAME` par type (`Battle.specialName(unit)`).
- Charge `u.charge` 0..5 : +1 par attaque, +2 si le coup est x1,25 ou mieux, plafond 5 ; un pet étourdi ne charge pas ; la charge suit le pet au changement ; spécial refusé avant 5, consomme 5. 9 spéciaux (`strike drain heal guard stun focus freeze chain bulwark`), `Battle.TYPE_SKILL` donne freeze / chain / bulwark aux types Glace / Foudre / Terre.
- `STATS[r]` inchangé (lot 9) ; `Battle.rawUnit(spec)` (construction directe : tests et lot 11) ; niveau lu dans `slot.x`, `levelMul`, `xpTo`, `levelFromXp`, `addXp`, `xpReward`.
- 40 tours max. Journal déterministe : `Battle.new(seed, ...)` (graine injectable), Park-Miller 48271 mod 2^31-1 (vecteur de référence x(10000) = 399268537 testé, produits < 2^47 donc exacts), 4 tirages d'échauffement (`Battle.seedState`), aucun tirage dans l'IA.
- `Battle.DAMAGE_MUL = 1.6` (voir « Écarts » 1).

## Écarts avec la spec (à trancher)

1. **Durée des combats : `DAMAGE_MUL = 1.6` ajouté.** Avec les STATS imposées (6 à 7 coups pour mettre un pet à terre) et la formule D.3 nue, un 3 contre 3 dure ~18 tours (mesuré), hors de la cible 8-14. Le multiplicateur s'applique aux deux camps (aucun rapport de force ne change). Mesures finales : 12,1 tours en moyenne (mono-type), 13,0 (espèces réelles), 0 fin par limite de 40 tours. Réglage unique, `Battle.DAMAGE_MUL`.
2. **STATS r = 1 : 50/8/12 (code du lot 9) et non 60/10/12 (D.4).** Le lot 9 l'a baissé à dessein (règle puissance x1,25 entre raretés, test existant `STATS[1].hp == 50`). r = 3..7 sont bien identiques à l'ancienne formule (testé). r = 2 et r = 8..10 : valeurs du code (D.4 en donne d'autres, 73/12/13, 470/64/23...) : non touchées. `PROFILES` / `profileStats` : conservés, non branchés (les brancher changerait les stats des pets migrés).
3. **XP cumulée niveau 20 : 34 742 et non « ~ 9 600 ».** `floor(40 x L^1,6)` donne 34 742 cumulés ; la formule est appliquée telle quelle. Pour ~9 600 : `Battle.XP_BASE = 11` (9 560). Décision de design à prendre avant le lot 12B (rythme : combat gagné étage f = 20 + 5 f XP par pet).
4. **`Config.TYPE_WEAK` (lot 15, astuces des PNJ « le type X craint le type Y ») contredisait la matrice** (ex. Lumière « craint » Ombre alors que Lumière bat Ombre ; Terre « craint » Plante : aucune relation). Patch d'une ligne : table = type qui BAT chacun (primaire). Testé.
5. **Noms de spéciaux** : `Battle.SPECIAL_NAME` (dans le module pur) plutôt que `Config.TYPE_SPECIAL_NAME` (Battle ne dépend pas de Config) ; si l'on préfère Config, `Battle.specialName` est le seul point de lecture à changer.
6. `Battle.SPECIES_TYPE` / `SPECIES_SKILL` : toujours 18 entrées (lot 11 les prolonge à 78 espèces ; Plante s'écrit `Nature` dans les données).
7. Focus : « attaque +40 % pendant 3 tours » = 3 tours COMPLETS suivants (`focus = 4` posé, décrémenté en fin de tour).

## Résultats (dans la copie de travail, base 91f6907 + ces fichiers)
- `python3 roblox/tools/run_tests.py` (lupa, depuis la copie `prep12a`) : **3329 réussis, 0 échoué**, code de sortie 0 (suite complète : anciens tests du moteur adaptés par `patches/run.luau.patch`, arène serveur de bout en bout avec le vrai `Main.server.lua`, tests des lots 9 à 15 inchangés).
- `lune run roblox/tests/run.luau` (PATH=/tmp/claude-0/cargo-out/bin) : **3329 réussis, 0 échoué**, mêmes mesures qu'avec lupa.
- `python3 roblox/tests/run_lot12a.py` seul : **89 assertions réussies, 0 échec** (aussi 89 sous Lune). Ces 89 assertions font partie des 3329.
- Mesures de l'équilibrage (10 000 combats IA contre IA, même rareté parmi r = 1, 3, 4, 5, 6, 7, 8, 10, équipes mono-type, compétences aléatoires) : victoires par type de 48,6 % (Feu) à 51,4 % (Plante), durée moyenne 12,09 tours, 0 fin par limite de tours, camp A 50,2 %. Avec les 18 espèces réelles (équipes mixtes, 10 000 combats) : types de 49,2 % à 50,9 %, durée moyenne 13,02 tours.
- Non exécutable ici : `luau-analyze` (absent), `selene` (std Roblox indisponible hors réseau) ; `stylua --check` : l'ancien `Battle.lua` n'est déjà pas conforme (lignes longues), pas de reformatage imposé.
- Analysé seulement (non exécuté) : adaptations de `Main.server.lua` / `BattleUi.lua` du tableau « Brancher » (aucun de ces fichiers n'est modifié ici), comportement réel dans Studio.

## À tester dans Studio
1. Arène, étage 1 : lancer un combat, appuyer sur « Spécial » avant 5 attaques : bouton grisé / refus « spécial pas prêt » ; après 5 attaques neutres (ou 4 avec un coup « avantage ») le spécial part et la charge retombe à 0.
2. Contre un adversaire dont le type est battu en secondaire (x1,25, ex. Feu contre Glace) : le texte d'efficacité apparaît et la charge monte de 2.
3. Changer de pet au milieu d'un combat chargé : la charge du pet reste la même au retour.
4. Un combat complet de l'étage 1 à l'étage 15 avec une équipe de la bonne rareté : durée ressentie 8-14 tours, aucun écran vide quand un événement `splash` / `discharge` arrive (Chaîne d'éclairs, Gel) : vérifier que BattleUi ignore proprement les événements inconnus.
5. Pet avec `slot.x` élevé (modifier le profil de test) : ses PV s'affichent x1,285 au niveau 20, rien de plus au-delà.
6. Étage 35, 40, 45 : adversaires générés (raretés 7, 8, 10), boss nommés, combat terminable.
