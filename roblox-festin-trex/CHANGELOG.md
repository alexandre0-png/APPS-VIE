# Journal des changements — Festin du T-Rex

## Version actuelle (branche claude/roblox-autonomous-studio-dipvjg)
- Jeu complet : lancers serveur-autoritaires, T-Rex animé (5 stades), festins, 3 événements, 6 améliorations,
  6 nourritures, œufs/compagnons, quêtes, série de connexion, secrets, évolution, classement.
- Monétisation : 3 Game Passes + 3 produits (désactivés tant que leurs IDs valent 0 dans `Config.Monetization`).
- Données : verrou de session, `UpdateAsync`, 3 essais, version de profil + table de migrations.
- Graphisme : heure dorée, brume, lampadaires, assiette du T-Rex, interface avec dégradés/animations, traînées.
- Page du jeu : textes, icône, 3 miniatures, icônes de passes/produits (`PUBLISH.md`, `dist/store/`).

- Histoire (Config.Story), zones à débloquer (Config.Chests, coffre quotidien par zone, condition niveau/évolution),
  éligibilité testable dans `Economy.chestStatus`.

- Énigme du jour (`RiddleLogic`, panneau 🧩) : 12 QCM, 3 essais/jour, réponses gardées côté serveur (anti-triche), tests ajoutés.

## Décisions techniques notables
- **Outils externes** : `luau-lsp`/`luau`/stylua/selene/rojo téléchargés mais leur exécution a été refusée par le
  bac à sable ; **pas de contournement**. Remplacés par `tools/blockcheck.py` et `tools/undefcheck.py`
  (contrôles structurels exécutés). Les tests `tests/test_all.luau` restent à lancer avec le CLI Luau/Lune.
- **Test corrigé** : « bonus compagnon cumulé » équipait 4 compagnons alors que la limite est 3 (4 dès l'évolution 5) ;
  l'attendu du test était faux, pas le code.
- **Trajectoires** : simulées une fois côté serveur (raycasts), rejouées côté client → aucun objet réseau par projectile.
- **Données** : ajouts de clés gérés par `Util.reconcile` (sans changement de version) ; tout changement non additif
  doit incrémenter `Config.DataVersion` et ajouter une migration.

## Non exécuté (bloqué par la permission du bac à sable)
`luau-lsp` (types Roblox), `luau` (tests `tests/run.sh`), `stylua`, `selene`, `rojo build`.
Aucun contournement. Remplacés par `tools/blockcheck.py` et `tools/undefcheck.py` (exécutés). Les tests Luau ne sont pas
portés en Python : un port ne testerait pas le vrai code.

## Reste à faire par le propriétaire
Voir **A_FAIRE_UTILISATEUR.md** (liste tenue à jour).

## Ancienne liste
1. Lancer le jeu dans Roblox Studio (jamais exécuté) et corriger d'après la fenêtre Output.
2. Lancer `tests/run.sh` (CLI Luau) et `tools/check.sh` (luau-lsp) ; stylua signale du style à reformater.
3. Fournir Universe ID et Place ID, puis `python3 tools/publish_place.py --universe <ID> --place <ID> --go`.
4. Créer passes/produits sur le Creator Dashboard et coller leurs IDs dans `Config.Monetization`.
5. Téléverser icône et miniatures (`dist/store/`) ; ajouter de vraies captures d'écran.
