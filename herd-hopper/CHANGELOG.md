# Journal des modifications

## Passage « relecture complète »
- Tests de logique pure (`tests/pure.spec.luau`) : 14 tests sur Util, Config (biomes, prix, quêtes, mur de lave) et Species. Exécutés avec fengari (`node tools/sim/run.js UNIT`) ; script Lune fourni (`tools/lune/run.luau`).
- Correction : le « pop » du combo modifiait `TextSize`, sans effet avec `TextScaled`. Remplacé par un `UIScale`.
- Correction : le survol d'un bouton remettait sa couleur d'origine (le bouton d'action change de couleur selon l'état). La couleur courante est maintenant mémorisée.
- Réglage : accélération du mur de lave 0,28 → 0,30 pour que son plafond soit atteint avant la fin de la manche (test).
- Astuces tournantes dans le HUD pendant l'attente.

- Outils : Lune, stylua, selene et rojo installés et exécutés. Corrections issues de selene : paramètres inutilisés, branches identiques fusionnées dans `stepAir`.
- Filet de sécurité serveur : un cavalier qui s'éloigne de plus de 4 studs de sa selle est recalé (au cas où la soudure sur pièce ancrée se comporterait autrement dans Studio).

## Choix techniques pris sans validation
- Aucune musique libre de droits n'est fournie : `Config.Audio.Music` est vide (silence), à remplir avec des identifiants possédés.
- selene ne peut pas télécharger la bibliothèque standard Roblox (réseau refusé) : une std minimale écrite à la main (`herd.yml`) la remplace.
- Les achats Robux restent désactivés (id = 0, « Bientôt ») tant que les identifiants Roblox ne sont pas renseignés.

## Versions précédentes
Voir l'historique git : jeu complet, achats Robux, audio, graphisme, durcissement serveur.
