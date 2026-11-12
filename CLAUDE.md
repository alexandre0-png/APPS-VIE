# Orchestration des jeux Roblox

Ce dépôt contient aussi des jeux Roblox, un dossier par jeu (`jeu-1/`, `jeu-2/`…). Pour toute demande sur un jeu, la session principale orchestre ces sous-agents (un sous-agent ne peut pas en lancer un autre) :

1. `roblox-game-auditor` (lecture seule) : seulement pour un audit ou quand la demande est large (« améliore le jeu 3 »). Produit un backlog priorisé.
2. `roblox-game-dev` : implémente la demande dans le dossier du jeu visé.
3. En parallèle, une fois le code écrit : `roblox-qa-tester` (outils et tests) et `roblox-security-reviewer` (Remotes, DataStore, économie).
4. Si l'un des deux remonte un défaut : renvoyer à `roblox-game-dev` avec la liste exacte, puis relancer l'étape 3. Boucler jusqu'à zéro défaut critique/élevé, maximum 3 tours ; au-delà, signaler le blocage.
5. Rapport final dans le format défini dans `roblox-game-dev` (Exécuté / Analysé / À tester dans Studio).

Outils : `scripts/setup-roblox-toolchain.sh` installe stylua, selene, lune, rojo ; `scripts/check-game.sh <jeu>` les exécute.
Ne jamais mélanger deux jeux dans un même commit, sauf demande « Tous les jeux ».
