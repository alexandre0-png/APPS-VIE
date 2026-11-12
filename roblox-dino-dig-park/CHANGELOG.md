# Journal des changements et décisions

## Vérifications outillées (étape qualité)
- stylua 2.6.0 (--check) : tout `src/` formaté, 0 écart. Config dans `stylua.toml`.
- selene 0.31.0 : 0 erreur, 0 avertissement. Choix : le std Roblox officiel exige un téléchargement de l'API dump, inaccessible ici ; j'ai écrit un std minimal (`roblox.yml`) qui déclare les globaux utilisés.
- rojo 7.7.1 : `rojo build` OK, `DinoDigPark.rbxlx` reconstruit.
- Lune non utilisé : les tests de logique pure tournent sur une VM Lua 5.3 (fengari, `tests/run.js` et `tests/run_integration.js`). Écart connu : Lua 5.3 n'est pas Luau (pas de types ni de `task`, simulés par le mock).
- Revue manuelle : toutes les boucles infinies contiennent un `task.wait` ; aucune API dépréciée (`wait`, `spawn`, `FilteringEnabled` absents) ; connexions liées à la durée de vie des instances ou du joueur ; RemoteEvents validés côté serveur (type, bornes, propriétaire, distance, délai par action).

## Fonctionnalités
- Graphisme : éclairage, correction de couleur, rayons de soleil, lumières des lampadaires, pulsation des boutons, particules, dégradés d'interface.
- Grande roue animée, sons selon la rareté, panneau de bienvenue.
- Scripts : délais par action, débounce d'achat corrigé, double sauvegarde évitée.
