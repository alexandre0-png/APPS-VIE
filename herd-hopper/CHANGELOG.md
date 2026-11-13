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
- **Énigme du jour** (accord reçu pour ajouter des énigmes) : une énigme par animal normal, la même pour tous ce jour-là ; la capturer (n'importe quelle version) donne 100 or et 10 os. La réponse n'est jamais envoyée au client.
- **Cinématiques** (moments clés seulement, jamais pendant l'action) : intro de contexte (zoo, cœur rose, but), mini tutoriel au premier lancement (sauter, lasso de saut, cœur, lasso de capture), aperçu à l'ouverture d'une nouvelle zone, cinématique d'un boss capturé. Réglables dans `Config.Cinematics` (général + un interrupteur par type, durée maximale, délai avant passage possible, rejouable depuis le menu Histoire), passables d'un appui, protégées par pcall, interrompues par un départ en expédition (alors non marquées vues). La logique (séquences, durées, passage, reprise, choix de la prochaine) est dans `shared/CinematicPlan` et testée ; l'action serveur `seen` n'accepte que des clés connues. Remplace l'ancienne intro de 8 s.
- **Modèles du catalogue** (3 packs d'animaux, 2 plantes de décor) : `server/Modules/AssetService`. Chargement serveur seulement (`InsertService:LoadAsset`) dans un pcall avec délai maximum, en tâche de fond ; suppression de tout Script, LocalScript, ModuleScript, RemoteEvent, RemoteFunction, BindableEvent, BindableFunction, Humanoid, Animator et Sound ; modèles de plus de 300 pièces ignorés. Un animal habillé garde sa pièce Root (invisible) comme hitbox : cœur rose, lasso, récupération et selle sont inchangés. Chargement raté = animaux actuels conservés. Tout est dans `Config.Assets` (interrupteurs `Enabled`, `Skins`, `Decor`). Simulations F (chargeur factice : scripts retirés, délai dépassé sur un pack, boss capturé) et G (chargeur en panne : mêmes captures).
- **Animations** (demandées après la refonte) : chacune derrière `Config.Animations` (interrupteur général + un par animation) et encapsulée en pcall ; une animation qui échoue est signalée une fois puis ignorée. Ton joyeux, rien de sanglant.
  - Animaux : cycle de marche, pattes repliées en saut, ailes ; trot joyeux et étincelles à l'apparition d'un cœur rose (le cœur « pop » avec rebond) ; capture : l'animal s'envole en tournoyant avec des confettis ; joie au zoo : rebonds, un tour sur eux-mêmes, confettis à l'arrivée en fin d'expédition.
  - Lasso : la corde ondule puis se tend, la boucle se resserre autour de l'animal, le bras du joueur lance (visible par lui seul).
  - Zones : survol de caméra au départ, balayage de couleur entre deux zones. Boss : nuage d'arrivée, piétinements, coup de zoom. Échec : étoiles d'étourdissement à la perte d'une vie ; à la mort, nuage de fumée, personnage estompé, écran grisé un instant.
  - Les maths sont dans `AnimMath` (pures, 5 tests Lune) ; le serveur et le client ne font que les appliquer.
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
