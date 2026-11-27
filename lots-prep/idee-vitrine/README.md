# Idée 3 : Vitrine « pet du jour » (Chipe-Œufs, jeu 2)

Base : commit `fa4e42b` (lot 14 intégré). Rien n'est appliqué à la branche de jeu : modules, tests et patchs prêts à brancher. Aucune clé, aucune publication.

## Règles implémentées (module pur `roblox/src/ReplicatedStorage/Showcase.lua`)
- Sélection : chaque jour UTC, une espèce de `Config.PETS` de rareté >= 6, déterministe (Park-Miller sur le numéro de jour, même résultat partout), jamais la même deux jours de suite.
- Premier joueur : choix « enregistrement dédié » (le champ `dex` n'a pas de date, donc pas exploitable). Le premier joueur qui fait ÉCLORE l'espèce du jour la possède : `UpdateAsync` sur la clé `Showcase_<jour>` du DataStore `ChipeOeufs_Showcase_v1`, premier écrit gagne.
- Bonus : +5 % de revenus pendant 24 h (daté, `showcase.ends`). Un seul bonus actif (jamais prolongé ni cumulé), une vitrine par jour, une par semaine et par joueur (`cooldownDays = 7`).
- Propriétaire absent : la réclamation exige d'être connecté ; si le profil n'a pas enregistré le bonus (arrêt serveur), `onLogin` l'accorde une fois, le même jour UTC seulement.
- Confidentialité : le `userId` reste dans l'enregistrement serveur ; `publicView` ne renvoie que espèce et nom assaini (contrôles retirés, 20 caractères). Aucun Robux, produit ou achat.
- Interrupteur : `Config.SHOWCASE.enabled = false` coupe tout (aucun bonus, aucun appel DataStore).

## Brancher (depuis la racine du dépôt de jeu, sur `fa4e42b` ou équivalent)
1. Copier `roblox/src/ReplicatedStorage/Showcase.lua`, `roblox/tests/showcase.luau`, `roblox/tests/run_showcase.py` à leur place dans `roblox/`.
2. `patch -p1 < patches/01-config.patch` (Config.SHOWCASE), `02-data.patch` (champ de profil), `03-main.patch` (multiplicateur, réclamation à l'éclosion, onLogin), `04-run-tests.patch` (ajoute `showcase` dans run.luau).
3. Le module `Shared` de Rojo prend `ReplicatedStorage/*.lua` : aucun changement de `default.project.json`.
4. Lancer `python3 roblox/tests/run_showcase.py`, puis les suites complètes.

Données : champ `showcase = { last, ends }`, SANS changement de version (v13 reste v13, comme le lot 14 : un serveur ancien ignore le champ). Profil v13 sans champ = valeurs neuves ; champ valide jamais réinitialisé ; `Showcase.sanitize` est idempotent, ramène un jour futur à aujourd'hui et une fin de bonus lointaine à 24 h.
Main : `L15.SC` (ajouté dans la table `L15` existante : pas de nouvelle variable locale, limite des 200 locales), `gmult` multiplié par `L15.SC.multiplier`, bloc `task.spawn` après la mise à jour du `dex` dans l'éclosion, bloc `task.spawn` après `d.lastSeen = today`.

## Résultats
- `python3 roblox/tools/run_tests.py` (lupa, copie `fa4e42b` + patchs) : 4297 réussis, 0 échec, code 0.
- `lune run roblox/tests/run.luau` (Lune, même copie) : « Tests Config : 4297 réussis, 0 échoués ».
- `python3 roblox/tests/run_showcase.py` : 84 assertions, 0 échec. Mutation (cooldown désactivé) : 5 échecs, donc les tests détectent la régression.
- Patchs : `patch -p1 --dry-run` OK sur une copie neuve de `fa4e42b` (4 fichiers), puis application réelle : arbre identique à la copie de travail.
- `stylua --check` OK sur Showcase.lua et showcase.luau. Main.server.lua : stylua plante (opérateur `//`), à l'identique sur `fa4e42b` sans patch. `selene` : impossible hors ligne (dump de l'API Roblox indisponible). `luau-analyze` absent. Non exécutés.

## Écarts et limites
- Pas d'affichage au hub : `publicView(rec, jour)` fournit espèce et nom ; le hub (autre place) doit lire `Showcase_<jour>` en lecture seule (GetAsync) puis dessiner le panneau. Non fait, hors patchs demandés.
- Seule l'éclosion déclenche la réclamation (pas échange, vol, récompense de passe) pour limiter l'abus. Un joueur à plusieurs comptes peut en revanche multiplier ses chances ; le gain reste de +5 %.
- Nom affiché = `DisplayName` (déjà filtré par Roblox) ; si le nom doit être masqué pour les joueurs qui le souhaitent, ajouter un réglage.
- Si deux serveurs réclament en même temps, UpdateAsync tranche ; un échec DataStore n'accorde jamais de bonus (retombée : « error »).
- Un rare « race » (bonus reçu d'une autre source pendant l'appel) laisse la vitrine à ce joueur sans bonus (`blocked:race`).

## À tester dans Studio
1. Serveur publié (DataStore actif), un joueur A : faire éclore l'espèce du jour (Config.PETS de rareté >= 6) : notification « Vitrine du jour », revenus/s +5 % (comparer avant/après), `showcase.ends` = maintenant + 24 h.
2. Deux serveurs, joueurs A et B éclosant la même espèce à quelques secondes : un seul gagne, l'autre n'a ni bonus ni message.
3. A éclôt l'espèce le lendemain : pas de bonus (semaine). Attendre 7 jours UTC (ou changer l'horloge du faux serveur) : de nouveau possible.
4. A gagne puis quitte avant l'enregistrement (arrêt serveur forcé) ; reconnexion le même jour : bonus accordé une fois ; reconnexion le lendemain : rien.
5. Studio sans accès API : aucune erreur bloquante à l'éclosion (pcall) et aucun bonus.
6. `Config.SHOWCASE.enabled = false` : aucun bonus ni appel DataStore.
