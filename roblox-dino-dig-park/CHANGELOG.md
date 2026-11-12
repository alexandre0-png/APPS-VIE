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

## Accessibilité
- Fouille au clavier (touche F) et à la manette (bouton X), maintenable, active seulement dans la zone de fouille. Le bouton à l'écran reste pour le tactile.
- Note : `tests/run_integration.js` dure environ 2 minutes (VM Lua interprétée en JS).

## Tycoon évolutif
- Niveau du parc (1 à 6) : il vient du nombre de dinos différents découverts, il ne s'achète pas. Des portes restent fermées tant que le niveau manque : enclos 3 à 6, incubateurs 3 et 4, ouvriers 3 et 4, hélipad, hôtel, grande roue, œufs Volcan et Cosmique. Enclos fermés visibles (barrières rouges et blanches, panneau), boutons marqués « 🔒 Niveau N ».
- Montée de niveau : récompense en fossiles, effets visuels et sonores.
- Aventure du Professeur Rex : 9 chapitres dans l'ordre (creuser, éclore, collecter, enclos, ouvrier, collection, niveau 4, os dorés, renaissance), récompenses fossiles, pièces ou œufs. Panneau « Aventure » et objectif guidé.
- Monétisation sans blocage : Mode turbo (vitesse de marche), Boost x2 10 min, Pack de départ, en plus des passes existantes. Les IDs restent à 0 tant que tu ne les renseignes pas.
- Choix : le niveau dépend des découvertes (et non de l'argent) pour que les portes aient un vrai sens ; la simulation montre qu'un joueur actif atteint le niveau 3 en ~7 min et le niveau 6 en ~1 h 20, sans blocage.

## Énigmes
- Énigme du jour du Professeur : 12 questions sur les dinosaures et le jeu, choix multiple, indice après 2 erreurs, une récompense par jour (fossiles selon le niveau), série de jours, Œuf Jungle tous les 3 jours de série. La bonne réponse n'est jamais envoyée au client : la validation est côté serveur (type, bornes, délai de 1,5 s).
- Chapitre d'aventure « Le premier mystère » lié aux énigmes résolues.
- Correction du mini-moteur de test : FireClient n'atteint plus que le joueur visé (il diffusait à tous), ce qui rend les tests client plus fidèles.
