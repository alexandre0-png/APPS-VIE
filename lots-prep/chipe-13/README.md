# Chipe-Œufs, lot 13 : duel local, intro de combat, ligues (préparation)

Spec : `obsidian-studio/Jeux/LOTS_9_PLUS.md` E.1, E.2, E.4, B.4 et « Lot 13 » de K. Base : commit 91f6907 de la branche de jeu (non modifiée). Aucune clé, aucune publication.
Préparé hors de la branche de jeu : modules purs + patchs, aucune intégration bloquante.

## Contenu
- `roblox/src/ReplicatedStorage/Duel.lua` : module PUR (aucun service Roblox, horloge injectée). Refus de défi (6 cas de E.2 + soi-même + occupé), carnet des défis (délai 20 s, cooldown 120 s, plafond 3 en attente, un seul défi accepté), forfait (2 tours sans action), récompenses (10/jour, 3/paire), ratio V/D, ligues, remise de saison, données d'intro B.4.
- `roblox/tests/lot13.luau` (79 assertions), `run_lot13.py` (lupa), `run_lot13.luau` (Lune).
- `patches/01-config.patch` : `Config.DUEL`, `Config.LEAGUES`, `Config.LEAGUE_SEASON` (données).
- `patches/02-data.patch` : `battle.duel = { w, l, day, n, pairs }` et `battle.pve = { w, l }` (défauts + lecture assainie, sans changement de version : champs facultatifs, profils anciens relus sans perte).
- `patches/03-main.patch` : bloc serveur additif avant `Players.PlayerRemoving` : `actions.duelChallenge(s, userId)`, `actions.duelAnswer(s, { from, accept })`, `duelTurnDone`, `duelFinish` (exposés en `L15.duelTurnDone/duelFinish`), nettoyage au départ d'un joueur.
- BattleIntro.lua : **aucun patch** (voir décisions). `IntroPlan.lua` (lot 10) réutilisé tel quel.

## Brancher
1. Depuis la racine de `roblox/` de la branche de jeu : `for p in lots-prep/chipe-13/patches/*.patch; do patch -p1 < $p; done` (chemins `roblox/src/...`, donc depuis le dossier PARENT de `roblox/`). Testé en `--dry-run` sur une copie neuve de 91f6907 : 3 patchs sans décalage ; sur la tête actuelle de wt/o2 (lot 16) : ils passent avec décalage de lignes (Config +23, Data +11/+50, Main +548), sans rejet.
2. Copier `roblox/src/ReplicatedStorage/Duel.lua` dans `roblox/src/ReplicatedStorage/` (sous `Shared` en jeu, comme Config) et `roblox/tests/lot13.luau`, `run_lot13.py`, `run_lot13.luau` dans `roblox/tests/`.
3. Dans `tests/run.luau`, après le bloc lot 10 : `luau.load(fs.readFile("roblox/tests/lot13.luau"), { debugName = "lot13" })()({ check = check, suite = suite, luau = luau, fs = fs })`.
4. Reste à écrire à l'intégration (volontairement hors patch, trop dépendant de l'arène) : placement des deux joueurs sur le sable (±10 en X) et caméra de duel, boucle de tours (`Battle.new` / `Battle.turn(st, a, b)`, action par défaut Attaque, appel de `L15.duelTurnDone` puis `L15.duelFinish(id, "a"|"b"|nil)`), diffusion `RBattle` aux spectateurs, UI client du message `{ k = "duelAsk", from, fromId, seconds }` (boutons Accepter/Refuser qui envoient `duelAnswer`), prompt « Défier » (envoie `duelChallenge`), option « Refuser automatiquement » dans Réglages, badge de ligue au-dessus de la tête, modèles `arena.podium/banner/board`.
5. Intro B.4 : `IntroPlan.plan({ mode, me = Duel.introSide(mode, battle, { name, userId, trophies, pets }, Config.LEAGUES), foe = ... })`. Aucune modification de `BattleIntro.lua` : `IntroPlan` affiche déjà nom, ligue, trophées, ratio, 3 pets ; `Duel.leagueText` fournit « 🥇 Or » (≤ 16 caractères).
6. Fin de saison (E.4) : remplacer `math.floor(pv.trophies / 4)` (Main, `pvpState`) par `Duel.seasonReset(pv.trophies, Config.LEAGUE_SEASON.resetAbove, Config.LEAGUE_SEASON.resetFactor)` et `Config.pvpSeasonReward` par `Duel.seasonReward(Config.LEAGUE_SEASON.rewards, trophies)` (le titre « Champion de la saison n » est une donnée `title`, à afficher/stocker côté Main). Non patché : touche au lot 9/16 et à l'économie, décision du coordinateur.
7. `battle.pve.w/l` : la mise à jour après un combat PvE (`battleFinish`) n'est PAS dans le patch (ratio PvE affiché 0 V / 0 D tant que non branché) ; une ligne `pve.w += 1` / `pve.l += 1` dans la branche victoire/défaite non-PvP de `battleFinish`.

## Décisions prises en autonomie
- **Ratio compté même sans récompense** : un duel (hors annulé) incrémente `w` ou `l` même si le quota du jour ou de la paire est atteint ; seules les pièces sont plafonnées. Un duel annulé (deux joueurs inactifs) ne compte pas.
- **Quotas par joueur**, indépendants : un joueur sous quota est payé même si son adversaire est au plafond. `pairs` ne contient que les duels récompensés (≤ 10 clés/jour), remis à zéro au changement de jour UTC.
- **Deux inactifs en même temps** (2 tours chacun) : duel annulé, aucune récompense, aucun V/D.
- **Départ d'un joueur en duel** : forfait (l'autre gagne). Le perdant parti n'est pas crédité (son profil est déjà en sauvegarde) ; l'ordre d'exécution de deux `PlayerRemoving` n'est pas garanti : à vérifier dans Studio.
- **Défis** : max 3 en attente par cible, 1 sortant par joueur (nouveau défi possible après les 20 s), états relus à l'acceptation (`Duel.answer(..., ctx)`) ; défis croisés A->B et B->A : un seul duel. Contextes (`carrying`, `chased`, `pending` = offre PNJ en cours = dialogue, château, protection débutant) lus via `L15.ctx` existant.
- **Remise de saison** : « trophées = floor(trophées × 0,6) au-delà de 300 » interprété comme `max(300, floor(t × 0,6))` pour t > 300 ; t ≤ 300 inchangé (pas de chute sous 300). L'existant (`floor(t/4)`) n'est pas modifié.
- **Récompenses de saison étendues** : `eggTier` = indice de `Config.TIERS` actuel (3 Rare, 4 Épique, 5 Légendaire, 6 Mythique, 7 Ultra Rare) ; 1500 : 1 000 000 pièces + potion (le montant en pièces du palier 1500 n'est pas dans la spec : valeur d'équilibrage à valider).
- **Ligues** : icônes 🥉🥈🥇💎👑, couleurs en `Color3` (donnée seule).
- **Ratios par mode** : classé = `pvp.wins/losses + live.w/l`, duel = `duel.w/l`, PvE = `pve.w/l`, tour = étage atteint V / 0 D, PNJ = valeurs fixes passées par l'appelant.

## Résultats
Exécutés sur une copie de 91f6907 avec les 3 patchs + Duel.lua + tests appliqués (PATH=/tmp/claude-0/cargo-out/bin pour Lune) :
- `python3 roblox/tests/run_lot13.py <racine patchée>` : **79 assertions réussies, 0 échec**, code 0.
- `lune run roblox/tests/run_lot13.luau` (vrai Luau) : **79 assertions réussies, 0 échec**.
- `python3 roblox/tools/run_tests.py` (suite complète, vrai Main.server.lua + Data.lua patchés chargés par les tests du lot 15) : **3239 réussis, 0 échoué**, code 0.
- `lune run roblox/tests/run.luau` (suite complète) : **3239 réussis, 0 échoué**.
- Contrôle de compilation Luau (`luau.load` de Lune) de Main.server.lua, Data.lua, Config.lua, Duel.lua patchés : OK. `rojo build game.project.json` : OK (Duel présent dans le modèle).
- Mutation : `afkA` jamais remis à 0 dans `noteTurn` -> 2 échecs détectés (forfait et compteur) ; les tests nuls hors valeurs par défaut sont couverts par la suite « valeurs par défaut ».
- Les 79 assertions couvrent : 13 refus (6 cas de E.2 des deux côtés + soi-même + occupé), distance limite 30, cooldown 120 s, délai 20 s, deux défis vers la même cible (un seul accepté), défis croisés, plafond d'attente, forfait au 2e tour inactif (A, B, double, remise à zéro), 10/jour et 3/paire, passage de jour UTC, ratio exact et arrondi (3721 couples identiques à IntroPlan), aucun trophée touché, ligues (seuils 0/299/300/599/600/999/1000/1499/1500), saison, intro B.4 avec IntroPlan.

## Écarts et limites
- `run_tests.py`/`run.luau` n'incluent pas lot13 (à brancher, étape 3) ; lot13 tourne seul.
- Non exécuté : `selene` (échec du téléchargement du dump d'API Roblox hors ligne), `stylua --check` (plante sur `//` de Luau dans Main.server.lua, existant ; Duel.lua est au style des modules existants, lignes longues), aucun playtest Studio.
- Le bloc Main est analysé et compilé, pas exécuté : `L15.ctx`, `getRoot`, `isNewbie`, `notify`, `income`, `sessions`, `RBattle`, `actions`, `serverMode` sont des locales du haut de fichier existantes (vérifiées par lecture) ; `L15.ctx` lit `L15.book(s)` (offre PNJ en cours).
- Message `duelAsk` sans client : aucun joueur ne peut encore accepter tant que l'UI n'existe pas.

## À tester dans Studio (Test > 2 clients)
1. Joueur A à moins de 30 studs de B : `duelChallenge` -> B reçoit `duelAsk` ; accepter -> les deux sont occupés ; un 3e joueur C qui défie B reçoit « Un combat est déjà en cours ».
2. A défie B et C défie B en même temps : B accepte A, le défi de C est annulé avec notification.
3. Refus : porter un œuf, être poursuivi par un gardien, avoir une offre PNJ ouverte, être en château, être sous protection débutant, être à 40 studs : message de refus à chaque fois.
4. Duel complet (une fois la boucle de tours écrite) : un spectateur voit les `RBattle` ; ne rien choisir 2 tours = forfait, l'autre gagne ; vérifier +1 min de revenus au gagnant, +15 s au perdant, aucun changement de trophées (panneau Arène).
5. 11e duel du jour : plus de pièces ; 4e contre le même joueur : plus de pièces ; ratio V/D dans l'intro mis à jour.
6. Quitter pendant un duel : l'autre gagne, pas d'erreur dans la sortie ; vérifier l'ordre des deux `PlayerRemoving`.
7. Rejoindre avec un profil ancien (sans `battle.duel`) : relu sans erreur, `duel` = 0/0.
