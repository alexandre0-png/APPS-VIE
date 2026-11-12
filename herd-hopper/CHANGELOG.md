# Journal des modifications

## Refonte « Saute-Zoo » (principe changé selon le nouveau brief)
Version précédente conservée : tag git local `saute-troupeau-v1` (commit `0347c98`). Le tag n'a pas pu être poussé (le serveur de dépôt n'accepte que la branche) ; le commit reste dans l'historique de la branche.

Décisions prises sans validation, pour combler un brief parfois flou :
- **Monnaies** : l'or (parties, caisse du zoo) paie les améliorations du zoo et l'équipement ; les os (doublons, boss, histoire) paient les améliorations des animaux. Le brief parle d'« os » pour les animaux : retenu tel quel.
- **Expédition** : les joueurs prêts partent ensemble (4 min max). Zone de départ = vote des joueurs prêts parmi les zones débloquées par le nombre d'animaux différents (0, 4, 9, 15). Le mur de lave est supprimé : le danger devient le sol mortel de chaque zone.
- **Vies** : 1 par défaut, +1 avec le pass, +1 par « Continuer » acheté. Toucher le sol perd une vie ; à zéro, mort avec une fenêtre de 12 s pour acheter « Continuer ». Un animal disparu ou une accroche avortée ne coûtent pas de vie.
- **Cœur** : 22 % des animaux (plus avec « Appâts à cœurs »), toujours sur un boss. Gagner la confiance = rester en selle ; ensuite 4 s pour appuyer sur RÉCUPÉRER, sinon le cœur disparaît et l'animal te désarçonne.
- **Lasso de capture** : 3 par expédition (+1 par niveau du Sac à lassos, +2 avec le pass), visée assistée côté client, tout revalidé côté serveur ; 90 % de réussite, -15 % par variante ; interdit sur les boss.
- **Boss** : un par zone, apparaît à l'approche de la fin de la zone ; confiance cumulée sur 9 s en selle, il te projette en arrière toutes les 3 s (il file devant, on peut le relasser). Une seule variante, très rentable.
- **Zoo** : une parcelle par joueur dans un parc central ; revenu par minute = 6 × valeur × variante × (1 + 0,4 par niveau), multiplié par les visiteurs ; la caisse se remplit même hors ligne (20 min de stockage de base). Les visiteurs sont affichés côté client, uniquement chez le propriétaire.
- **Histoire** : 11 chapitres (zoo hérité d'une tante) avec objectifs lus dans le profil. Quêtes quotidiennes adaptées au zoo.
- **Robux** : 4 pass (Zoo Premium, Or x2, Vie supplémentaire, Lasso doré) et 7 produits (or, os, boost x2, Continuer). Le pass Zoo Premium inclut les cornes VIP. Rien d'indispensable : la partie de base reste gratuite.
- **Sauvegarde** : nouvelles clés (`SauteZoo_*`) pour ne pas mélanger avec l'ancien schéma.
- Bugs trouvés par la simulation et corrigés : relance du boss impossible (le boss te projetait devant lui), fenêtre de re-lasso du boss trop courte, caisse du zoo recalculée rétroactivement lors d'une capture, d'une amélioration ou de l'achat d'un boost (l'or déjà gagné est maintenant figé dans une caisse avant tout changement de taux).

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
