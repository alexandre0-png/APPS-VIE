# À faire par toi (Chipe-Œufs, Roblox)

Seulement ce que je ne peux pas faire à ta place : il faut ton compte Roblox, Studio, un navigateur connecté, ou ton autorisation. Tout le reste est fait ou suivi dans `CHANGELOG.md`. Dernière mise à jour : 2026-11-27 (lot 16 : boutique en 8 catégories, passe de combat, offres à l'écran, 8 vendeurs PNJ : tout est à jouer en Studio, voir §1sexies) ; précédente : 2026-11-26 (lot 8A : vol chez Mara/Zed, boutique jusqu'au Légendaire et 7 sons à vérifier en Studio) ; précédente : 2026-11-25 (lot 6 : énigme de la Mère Poule à jouer en Studio et à faire tester par 3 humains ; lot 5 : maison évolutive à voir en Studio) ; précédente : 2026-11-13 (modèles d'œufs à vérifier ; 2026-11-12 : achats : tant que les ID valent 0, ils restent désactivés dans le jeu avec un message clair, rien à faire de plus côté code).

Les cases sont à cocher au fur et à mesure.

## 1. Autoriser les outils de vérification (optionnel, 2 minutes)

Quatre outils sont téléchargés mais l'exécution est refusée par l'autorisation de la session. Au choix :
- [ ] Ajouter une règle d'autorisation Bash pour `stylua`, `selene`, `rojo` et `lune` dans les paramètres de la session, puis me demander de les lancer ;
- [ ] ou les lancer toi-même depuis la racine du dépôt (commandes dans `roblox/tools/VERIFICATION.md`), et me coller les sorties.

## 1bis. Réglages Studio vus dans ton premier lancement (v4)

- [ ] **Game Settings > Security > Enable Studio Access to API Services** : sans lui le jeu tourne en mode mémoire (rien n'est sauvegardé, pas de classement). C'est normal et signalé par un seul avertissement.
- [ ] **Modèles d'œufs refusés** (`Requester does not have permission for Asset`) : legendary 2937230482, orange 147144059, glitch 2937218888. Le jeu utilise alors les apparences construites par le code, aucun effet sur le gameplay. Pour les obtenir : ouvre chaque modèle dans la boutique Roblox (Toolbox / page du modèle) avec ton compte et utilise **Get** / l'ajouter à ton inventaire, ou remplace l'ID par un modèle que tu possèdes ; sinon laisse tel quel.
- [ ] Après le prochain playtest : dis-moi si le rythme te semble trop lent ou trop rapide (prix des œufs dans `Config.EGG_PRICE`, simulation dans `roblox/tools/sim_economy.py`).

## 1ter. Hub et parties (nouveau)

- [ ] **Creator Dashboard, lieu de JEU (87012762353093) : Max Players = 5** (le code refuse un 6e joueur et le renvoie au hub, mais le réglage évite des essais inutiles).
- [ ] Publier **deux fichiers** : `roblox/build/Hub.rbxlx` dans le lieu hub (115261336085924, lieu de départ) et `roblox/build/ChipeOeufs.rbxlx` dans le lieu de jeu (87012762353093), tous deux dans l'expérience « Jeu des oeufs ». Activer **Enable Studio Access to API Services** (réglage de l'expérience, valable pour les deux lieux).
- [ ] Vérifier dans Studio que la téléportation hub → jeu (serveur réservé) fonctionne maintenant que les deux lieux sont dans la même expérience : si elle échoue, le hub affiche « Impossible de lancer la partie » et la sortie contient la raison (`[Party] lancement impossible`).
- [ ] Lire la console serveur à l'arrivée d'un joueur : lignes `[Spawn]` (arrivée, personnage apparu, éventuels replacements) ; si « chargement forcé » ou plusieurs replacements apparaissent, copie-moi la sortie.
- [ ] Identifiants catalogue : œufs et décor du hub intégrés (`Config.Assets.eggs` / `.decor`). Vérifier dans Studio la sortie `[Assets]` (modèles refusés pour permission : ouvre-les avec ton compte dans la boutique et ajoute-les à ton inventaire) et `[Hub] décor catalogue : N modèle(s) chargé(s), M placé(s)`. Sons : 7 identifiants fournis et branchés au lot 8A (`Config.SOUNDS`) ; je n'en invente aucun.
- [ ] Voir en Studio la révélation d'œuf (étoile, rayons, anneaux, « 1 sur N »), le carrousel de la boutique, le style des boutons (contour épais, dégradé) et la bannière de zone ; dis-moi ce qui est trop chargé sur téléphone (`Config.REVEAL.forceReduced`, `Config.UI.glossy = false` pour revenir aux boutons plats).
- [ ] Tester le retour au hub (menu Plus > « Retour au hub ») et les raccourcis manette si tu as une manette (X boutique, Y missions, B fermer).
- [ ] Sons : le crochet `portal` de `Config.SOUNDS` attend encore un `rbxassetid://` vérifié (`secret` est remplacé par `secret_decouvert` au lot 8A, `menu` est branché).
- [ ] Tester dans Studio (Test > Clients and Servers) : entrer dans un portail, compte à rebours, départ ; liste des amis ; interface bien aux bords sur téléphone (émulateur) et PC.
- [ ] **Nouvelle carte 700 x 500 (refonte, lot 2), à parcourir dans Studio (jamais testée en vrai)** : place du marché (halle, fontaine, étals, rose des portails, arches « Retour à la base »), les 5 bases tournées vers la place, l'enclos sauvage, les 4 territoires (Gus x2, Mara, cour de Zed sur le plateau du château), l'arène, les lacs, la rivière du Nord, les 3 secrets déplacés, l'ambiance par territoire, et la sortie `[Builder] carte construite : N Parts` (attendu ≈ 1056).
- [ ] Points à vérifier à la main dans Studio : (1) le **Pont du Château** (rampe de pierre de 18°) se monte en marchant et mène au plateau ; (2) on ne traverse **pas** la rivière du Nord hors des 2 ponts (murs invisibles), ni en passant sous le pont du château ; (3) les **collines** (calottes) se gravissent sans bloquer ; (4) la **cour de Zed** (mur, passage de la herse au sud-ouest) et la porte du donjon (entrée du mode Château) ; (5) les gardiens restent dans leur territoire ; (6) les portails, le tapis de retour et l'arche de SA base (celle d'un autre joueur est refusée, aucun voyage avec un œuf porté).

- [ ] **Tapis roulant central (refonte, lot 3), à jouer dans Studio (jamais testé en vrai)** : au centre de la place, le tapis livre un œuf toutes les 5 s (rareté et prix visibles sur l'œuf) ; achat par maintien 0,3 s ; l'œuf passe dans les bras ; œuf de bienvenue gratuit 20 s après l'arrivée (étape 2 de l'onboarding) ; annonce et halo d'un Légendaire+ ; panneau des deux tables de rareté. Vérifier : fluidité du défilement, lisibilité du panneau et des étiquettes sur téléphone, prompts, absence de lag à plusieurs joueurs, que le tapis ne gêne pas la marche.

- [ ] **Difficulté des territoires (refonte, lot 4), à jouer dans Studio (jamais testé en vrai)** : (1) chez Mara : les 3 fils dorés à clochettes (🔔) sonnent quand on les traverse et les 2 loups accourent, les 2 flaques de boue ralentissent ; (2) chez Zed : la herse de la cour monte et descend toutes les 3 s et bloque vraiment quand elle est basse, les 4 dalles rouges et les 2 lanternes tournantes alertent les ours ; (3) le temps de maintien du bouton « Voler l'œuf » : 0,8 s enclos sauvage, 1,3 s Gus, 2,2 s Mara, 3,5 s Zed ; (4) porter un œuf Légendaire+ : colonne de lumière visible de loin, vitesse un peu réduite, compte à rebours « 🧊 Apporte l'œuf » chez Zed et message « L'œuf a refroidi » à 75 s ; (5) boutons « 🔒 Fermer la porte » et « 🐣 Je suis prêt pour le PvP » à gauche de l'écran (PC et téléphone : ne cachent-ils rien ? sinon dis-moi où les mettre), barrière rouge à l'entrée de ta base, badge 🐣 au-dessus de la tête ; (6) dis-moi si les gardiens de Mara et Zed te paraissent trop durs ou trop faciles (simulation lot 8A : Zed 22 % sans amélioration, 94 % avec vitesse 30 ; Mara ~60 % ; Gus ~90 %).

- [ ] **Maison évolutive (refonte, lot 5), à jouer dans Studio (jamais testée en vrai)** : (1) les 20 emplacements (5 x 4) tiennent sur la plateforme et ne passent pas dans la maison : regarde surtout les deux dernières rangées (11 à 20) et dis-moi si la maison doit être plus petite ou posée autrement ; (2) les modèles `house.l2` à `house.l7` : sens (façade vers la place), taille, enfoncement dans la plateforme, sinon le repli procédural s'affiche ; (3) l'animation de montée de niveau (échafaudage, poussière, ancienne maison qui s'enfonce, nouvelle qui monte, bannière, confettis, caméra large, bouton Passer) : durée ressentie, lisibilité sur téléphone ; (4) alarme d'intrusion (niveau 3), chien de garde (niveau 5, ralentissement x0,7 pendant 3 s) ; (5) un ancien profil : niveau de maison inchangé ou plus haut, 8 nouveaux emplacements verrouillés avec leur coût ; (6) le pass « +4 emplacements » (2098181699) lève bien les cadenas après l'achat.

- [ ] **Énigme de la Mère Poule (refonte, lot 6), à jouer dans Studio (jamais testée en vrai)** : fais-la résoudre à **3 testeurs humains, sans aide extérieure, en moins de 10 minutes chacun** (critère d'acceptation du cahier ; un robot de test l'a résolue en suivant seulement le faisceau, mais ça ne remplace pas des humains). Joue-la toi-même une fois en notant : (1) le « ❗ » doré visible de loin au-dessus de la Mère Poule, la carte d'objectif « 🐔 La Mère Poule t'appelle » puis « 📜 Berceuse du jour », la pastille sur l'onglet Énigme ; (2) la bulle de dialogue (texte, « Suivant », boutons, lisible sur téléphone) ; (3) le faisceau jaune : Mère Poule, puis le centre du quart de carte, puis la plume (scintillement à moins de 40 studs) ; les 4 plumes sont-elles atteignables à pied et posées à bonne hauteur (relief, ponton des saules) ? ; (4) l'icône 🪶 sur la mini-carte à moins de 90 studs ; (5) les runes (« La rune … attend sa plume », nombre de runes justes) ; (6) la berceuse : lueurs et notes dans l'ordre, touches sur les pierres (le prompt doit afficher « Chanter »), erreur = suite rejouée, bouton « 🔁 Réécouter » ; (7) la récompense (œuf Épique + pièces + fragment), le changement de jour (minuit UTC) en cours de route ; (8) à 3 joueurs : la « Pluie de chance » gratuite de 5 min. Relever dans la console serveur les lignes `[Riddle] step=… t=… hints=…` : si plus de 40 % des joueurs abandonnent à l'étape 1, rapprocher les plumes (`Config.FEATHER_SPOTS`).
- [x] ~~Son de la plume~~ : fourni et branché au lot 8A (`secret_decouvert`, `plume_ramassee`, 4 notes `berceuse_note1..4`, `poule_glousse`).
- [ ] **Équilibrage et sons (refonte, lot 8A), à jouer dans Studio (jamais testé en vrai)** : (1) chez Zed puis chez Mara, chipe un œuf et reste près du nid : environ 1 s plus tard l'ours (0,9 s pour le loup) doit charger (❗ + grognement) et, s'il te touche, reprendre l'œuf (« ↩️ … a repris l'œuf ») ; si tu fuis vite vers l'entrée, tu le gardes. Dis-moi si c'est lisible et juste. (2) La boutique ne propose plus que Commun à Légendaire (Mythique et Cosmique : seulement au tapis du marché) : la note en bas de la boutique est-elle claire ? (3) Écoute les 7 nouveaux sons : les 4 notes de la berceuse (pierres et « Réécouter »), le ramassage d'une plume, le gloussement de la Mère Poule à chaque page de dialogue (volume bas : trop fort ou trop répétitif ?), le son « secret découvert » (énigme réussie, secret de la carte, plume cachée toute proche). (4) Après 10 min à plusieurs, regarde le nombre de Parts (Ctrl+F1 / statistiques) : la simulation donne ~3 500 au pic avec 5 joueurs.

- [ ] **Monétisation, corbeau et tapis privé (refonte, lot 7), à jouer dans Studio (jamais testés en vrai)** : (1) à 3 comptes (deux amis + un inconnu) : menu « 🐦‍⬛ Corbeau » (liste des cibles, œufs, jetons), alerte de la victime (carte rouge + son, compte à rebours 8 s), « toucher l'œuf » dans sa base chasse le corbeau (jeton rendu), hors de sa base non, succès = œuf chez le voleur + indemnité + 5 min de bouclier, journal « Qui m'a volé ? » (Plus), réglage « Refuser les corbeaux de mes amis » ; relever combien de corbeaux chaque joueur reçoit par heure (doit rester <= 3) ; (2) l'oiseau procédural (taille, trajet, ailes) ; (3) achats en test purchase : 1 et 3 jetons (refus net au-delà de 5), tapis doré et pluie de chance (cumul, refus au-delà de 30 min), pass Tapis privé (tapis 10 x 3 devant les emplacements, un œuf toutes les 2 min tant que tu bouges, 3 en attente) ; (4) un compte dont les **offres à hasard sont restreintes** (PolicyService) : les 6 offres doivent disparaître de la boutique et des cartes ; (5) les probabilités de `PUBLICATION.md` §3ter sont à recopier sur la fiche de chaque offre à hasard ; (6) lot 7b : avec deux comptes complices (ancienneté >= 3 jours), vérifier qu'un aller-retour de corbeau ne rapporte pas de pièces (indemnité plafonnée à 900 par jour, 0 pour un œuf déjà volé), qu'un compte de moins de 3 jours est refusé, que fermer le serveur (arrêt depuis Creator Hub) rend le jeton d'un corbeau en vol ; (7) relire le questionnaire de maturité (vol d'objets virtuels déjà déclaré, texte prêt dans `PUBLICATION.md` §3ter).

## 1sexies. Boutique, passe de combat, offres et vendeurs (lot 16) : rien n'a été joué en vrai

Les 46 achats sont créés et leurs ids branchés (rien à créer). Il reste à **voir et tester en Studio** (Test > Clients and Servers, achats en mode test) :
- [ ] **Boutique** (Boutique > 💎 Boutique) : les 8 catégories dans l'ordre (Œufs, Chance & boosts, Pièces, Base & confort, Combat & vol, Passe de combat, Packs, Cosmétiques), lisibles sur téléphone ; tri par prix ; pastille « Possédé » ; fiche au clic (définition, détail, probabilités des œufs, « ce que l'achat ne fait pas », bouton « Acheter · N R$ ») ; l'invite Roblox affiche le bon nom et le bon prix.
- [ ] **Achats en mode test, un par un** (vérifier la livraison et le message) : Œuf Peu commun, Œuf Rare, Œuf Épique, Œuf Légendaire, Œuf Mythique, Œuf Ultra Rare, Œuf Secret, Œuf Exclusif, Œuf Divin, Potion express, Tapis doré, Potion de chance, Pluie de chance pour tous, Double chance, Éclosion rapide, Chance +10%, Vitesse +20 %, Tapis privé, Chance +10 % II, Petit sac de pièces, Sac de pièces, Revenus x2, Rattrapage du calendrier, Sauver ma série, Éclosion instantanée, Sac d'œufs +10, Collectionneur, +4 emplacements, Base VIP, Ticket d'arène, Relance immédiate, Corbeau chipeur, 3 Corbeaux chipeurs, Passe de combat premium, Passe de combat + (suite), Passe de combat + 10 paliers, Pack de départ, Pack Légende, Coffre royal sans passe, Coffre royal, Pose de victoire 1, Pose de victoire 2, Pose de victoire 3, Pose de victoire 4, Pose de victoire 5, Pose de victoire 6.
- [ ] **Base ET sac d'œufs pleins** : un œuf ou un pack est refusé AVANT l'invite (« Fais de la place… Rien n'est débité ») ; un achat sans œuf reste possible. Puis : remplis la base pendant qu'une invite d'œuf est ouverte, valide-la : l'œuf doit aller au **coffre de débordement** (Bonus > 📦 Coffre de débordement > Sortir).
- [ ] **Compte restreint (PolicyService)** : tous les achats à hasard (œufs, potions, Double chance, tapis doré, pluie de chance, packs, Chance +10 %, Chance +10 % II, Tapis privé) disparaissent ; Pièces, passes sans hasard, cosmétiques restent.
- [ ] **Passe de combat** (Boutique > 🏅 Passe de combat) : avant le 1er décembre 2026 (UTC) il annonce le début et garde l'XP gagnée ; ensuite : 30 paliers, XP (victoire PvE 20, PvP 30, quête du jour 100, quêtes de la semaine 300, éclosion Épique+ 50, 400/jour au plus), réclamation palier par palier et « Tout réclamer », achat du premium en cours de saison (paliers déjà atteints crédités une seule fois), « mise à niveau » (+ (suite) 400, Coffre royal sans passe 1 100). Date de début à confirmer : 2026-12-01 00:00 UTC (`SeasonData.SEASON.start`).
- [ ] **Offres à l'écran** : 3 par session au plus, 5 min d'écart, jamais pendant un vol, un combat, un œuf porté ou un menu ouvert, aucune juste après un achat ; ✕ toujours visible ; un appui ouvre la même fiche que la boutique.
- [ ] **8 vendeurs PNJ** autour du kiosque (modèles Blender du lot 30, sinon repli procédural) : orientation (étiquette tournée vers le kiosque), étiquettes lisibles à 60 studs, « Parler » ouvre la boutique sur le bon onglet. Écart accepté : 2 vendeurs à 14-22 studs, 6 plus loin (24 à 42 studs) ; aucun ne doit chevaucher le décor.
- [ ] **Poses de victoire** : après une victoire, l'emoji de la pose monte au-dessus du personnage (effet visuel provisoire : de vraies animations Roblox restent à créer, voir `LOT16_ECARTS.md`).
- [ ] **Rythme recalibré (écarts du lot 9)** : après quelques heures de jeu, dis-moi si les maisons 4 à 8, le premier Mythique / Ultra Rare et les prix en pièces te semblent justes (simulation : niveau 7 vers 2 jours, Secret 1 à 2 semaines, Divin vers 2 mois).
- [ ] **Analytics** (après une publication de test) : Creator Hub > Analytics doit recevoir les 6 types d'événements (personnalisés, économie, entonnoir « Shop », onboarding, progression, `version_1.16.0`).

## 1quinquies. Calendrier de 30 jours (lot 9b)

- [ ] **À jouer dans Studio (jamais testé en vrai)** : onglet Bonus > Calendrier (cartes lisibles sur téléphone : grille de 5 colonnes, barre de progression, carte Légendaire), pastille rouge, réclamation du jour, jour manqué et rattrapage, message d'éligibilité (compte de moins d'un jour, moins de 10 min de jeu), changement de jour UTC en cours de partie, base pleine avec un œuf à réclamer. Pour tester plusieurs jours, modifier l'heure du serveur n'est pas possible : demande-moi un mode de test si besoin.
- [ ] Dis-moi si les récompenses (pièces, œufs Légendaire au jour 3 et 25, Mythique au jour 20, tirage du jour 30 : 40 % Mythique / 45 % Ultra Rare / 15 % Secret, Secret remplacé par Ultra Rare tant qu'aucune espèce Secret n'existe) te semblent trop généreuses ou trop avares.

## 1quater. Passage en public

- [ ] Suivre la liste de `roblox/PUBLICATION.md` §5 (fiche, descriptions, accroches, vérifications dans l'ordre, lancement progressif privé puis amis puis public).
- [ ] Au premier playtest, me dire si les modèles Blender (gardiens, pièges, herses, pales, bancs, lampadaires, chevaliers, sol) ont la bonne taille et le bon sens : devant supposé = -Z, pics dessinés sortis.

- [ ] Au premier playtest, regarder les effets 3D et cinématiques (`roblox/ANIMATIONS.md`) : taille et lisibilité des effets, position des caméras (éclosion, château, survol du hub), gêne éventuelle ; chaque famille se coupe par un drapeau (`Config.Animations.vfx3d`, `Config.Cinematics.*`).

## 2. Ouvrir la place dans Studio et publier

- [ ] Studio : **File > Open from File** → `roblox/build/ChipeOeufs.rbxlx`.
- [ ] Te connecter, puis **File > Publish to Roblox As…** → *Create new experience*. Titre : `Chipe-Œufs : Vole des Œufs ! 🥚`. Description, genre et appareils : copier depuis `roblox/publication/LISTING.md` §1.
- [ ] **Home > Game Settings > Security** : activer **Enable Studio Access to API Services**.
- [ ] **Game Settings** : **Max Players = 10** ; **Avatar = R15**.

## 3. Playtest dans Studio (indispensable avant de passer en public)

- [ ] **Test > Clients and Servers**, 2 joueurs. Parcourir la liste de `roblox/publication/LISTING.md` §5 (histoire, zones, vol entre joueurs, achats, sauvegarde, téléphone).
- [ ] Vérifier les cinématiques en jeu (intro puis tutoriel au premier lancement, skip, retour de la caméra, plan de la première zone et du premier pet rare) : lisibilité des légendes sur téléphone, durée ressentie, et me dire si une cinématique doit être raccourcie ou coupée (`Config.Cinematics`).
- [ ] Vérifier les animations en jeu (œufs, visages des pets, menus, barrière de zone, confettis) et me dire lesquelles gênent ou saccadent : chacune se coupe avec un drapeau de `Config.Animations`.
- [ ] Vérifier les modèles d'œufs en jeu : apparaissent-ils (sinon lire les lignes `[Assets]` de la fenêtre Output : ID refusé, modèle non autorisé pour ton compte, vide...) ? Taille, aspect et rareté associée te conviennent-ils ? Les IDs doivent être des modèles que ton compte a le droit d'utiliser (disponibles dans la boutique, utilisables dans Studio). Correspondance et IDs modifiables dans `Config.Assets` ; `Enabled = false` les coupe.
- [ ] Vérifier à l'œil le monument du Grand Nid (runes, panneau d'énigme lisible des deux côtés) et la résolution de l'énigme du jour.
- [ ] Me dire ce qui ne va pas (erreurs rouges de la fenêtre Output, comportements étranges, équilibrage trop dur ou trop facile) : je corrige.

## 3ter. À regarder dans Studio après les derniers lots (rien de tout ceci n'a été vu)

- [ ] **Gus clément** : se faire attraper une fois (retour à la base, message « Gus t'a attrapé, réessaie ! », aucun œuf perdu), vérifier l'anneau jaune de vision au sol et que la base et le haut de la rampe ne sont jamais ciblés.
- [ ] **Arbres, chemins, protections d'œufs** (lot 11) : orientation de la tuile de virage (hypothèse : entrée −X, sortie −Z), hauteur de l'œuf dans le dôme, rendu de la vitre.
- [ ] **Village** (lot 12) : taille et orientation des maisons, du pont et de l'île sakura dans le hub, bords de la mare, décor de la carte.
- [ ] **Capture du hub avec l'étiquette « Blender N/M »** (bas à gauche) après republication ; un clic sur l'étiquette ou F4 ouvre le détail des échecs (nom, ID, message). Si des modèles sont refusés pour droits d'accès, ouvrir chacun avec le compte propriétaire de l'expérience et l'ajouter à l'inventaire / le rendre disponible pour l'expérience. Repasser `Config.Debug.AssetReport` à `false` ensuite.
- [ ] **Carte compacte** : portails de voyage rapide au Grand Nid (z = -45) et au pied des rampes, flèche de la boussole, rampe de Zed orientée vers le sud, trajets à pied (bases 7 s, zones 8 à 13 s).
- [ ] **Revenu** : vérifier « 💤 Inactif » après 90 s sans bouger et la carte « Gains pendant ton absence » à la reconnexion.
- [ ] **Éclosions** : un œuf Épique donne un Épique (5 % de « AMÉLIORÉ ! » vers Légendaire).
- [ ] **Écran machine à sous** : lisibilité des trois rouleaux sur téléphone, emoji 🪽 affiché, durée acceptable (sinon `Config.REVEAL.slot.enabled = false`).

## 3quater. Lot 9 : 10 raretés, rythme recalibré, mesures (rien de tout ceci n'a été vu en jeu)

- [ ] **Migration v11** : se connecter avec un compte qui a déjà joué (profil v10) dans un lieu privé AVANT de publier : mêmes pets, œufs toujours en incubation (nouvelle apparence), même niveau de maison (jamais plus bas), étage de la tour remappé (30 -> 35), titre « Ancien Cosmique » si un Cosmique avait été découvert.
- [ ] **Œufs Blender r1..r10** : taille de chaque œuf dans son emplacement (l'échelle se fait sur la pièce `Coque`), couronne / auréole / ailes qui dépassent sans toucher les voisins, coques de verre de l'Ultra Rare et du Divin, cubes en orbite, emblème (rune-œuf) lisible ; rapport « Blender N/M » : les 10 œufs doivent être chargés (plafond 40 Parts).
- [ ] **Rythme** : faire une première session de 25 à 30 min sans achat : maison niveau 3 atteinte, premier Épique obtenu, énigme du jour commencée (non simulée). Noter les temps réels du premier Rare (~3 min) et du premier Épique (~15 min).
- [ ] **Rythme du lot 16** (maisons 4 à 8, Secret, Divin, `RYTHME_NOTES.md`) : après publication, comparer les événements `house_level_reached_l4..l8` et `tier_first_reached_r8 / r10` aux cibles (40 min, 2 h, 6 h, 2 jours, 10 jours ; Secret 1 à 2 semaines ; Divin environ 2 mois) : la simulation n'en est qu'une estimation.
- [ ] **Boutique** : 5 œufs proposés (Commun, Rare, Épique, Légendaire, Mythique ; le Peu commun apparaîtra avec ses espèces au lot 11) ; texte « sera possible une fois cette rareté découverte ».
- [ ] **Prix Robux** : vérifier que les prix réglés sur le Creator Hub sont ceux de `Config.PRODUCTS[*].robux` (ils servent au calcul de la règle pièces / Robux et aux paliers de mesure ; Sac de pièces 99 R$).
- [ ] **Creator Hub > Analytics > Custom events** : après la publication, vérifier que les 12 événements arrivent (noms ci-dessous, sans aucune donnée personnelle) et créer un tableau : `first_hatch_seconds`, `tier_first_reached_rN`, `house_level_reached_lN`, `session_length`, `retention_day1`, `retention_day7`, `daily_quest_completed`, `purchase_tier_pN`, `coins_spent_egg` (événement économique), `hatch_tier_rN`, `puzzle_solved`, `tower_floor_reached`.

## 3quinquies. Lot 10 : écran d'éclosion, compteur « 1 sur N », combat, sons et icônes (rien de tout ceci n'a été vu en jeu)

- [ ] **À jouer dans Studio (jamais testé en vrai)** : (1) fais éclore un œuf de chaque rareté disponible : écran d'éclosion (secousse de l'œuf, éclats, bandeau, compteur « 1 sur N » qui monte), carte du pet à la révélation, tap pour passer après 1,5 s, sons `egg_shake` puis `hatch_r1..r10`, `jackpot_rare` à partir de Secret ; sur téléphone, fluidité (30 images/s visées) et lisibilité ; (2) liste des pets : « 🎲 1 sur N » sous chaque pet, « — » pour un pet éclos AVANT cette version ; (3) un tirage à 1 sur 1 000 ou plus : panneau « ✦ 1 sur N ✦ » au-dessus du pad visible des autres joueurs pendant 6 s ; (4) combat de la Tour et classé : intro (deux bandeaux, VS, avantage), effets par type à chaque attaque, « Super efficace ! », sons d'attaque, `special_ready` / `special_hit`, `battle_win` / `battle_lose`, icône de type à droite des barres ; (5) calendrier : son à l'ouverture de l'onglet, au jour réclamé et aux jalons, icônes des cartes (sinon emojis) ; (6) près du tapis du marché et du kiosque central (lot 8B : l'ambiance a été déplacée des étals vers le kiosque) : boucles `belt_loop` / `kiosk_ambience` qui montent et descendent avec la distance ; (7) console serveur : ligne `[Assets] icônes d'interface : N/42` (si 0, les Decals ne sont pas chargeables par la place : dis-le moi, l'interface garde les emojis).

## 3sexies. Lot 8B : kiosque central, décor de carte (lots 15 à 17), meubles des maisons (lots 18 et 19) (rien de tout ceci n'a été vu en jeu)

- [ ] **Kiosque (place du marché, au sud-est du centre : x 14, z 22)** : le modèle Blender `hub.kiosk` s'affiche-t-il (console : `[Assets] kiosque central : modèle Blender`) ou le repli procédural ? **Orientation des 4 panneaux** : le comptoir « Boutique » doit regarder la halle (ouest) ; Calendrier à l'opposé, Probabilités et Classement sur les côtés ; chaque prompt (touche E) au bon panneau et lisible. Essaie les 4 : Boutique ouvre la boutique (nouvel onglet « 🎟 Passe de combat » : « Bientôt », rien à acheter), Calendrier ouvre Bonus > Calendrier, Probabilités et Classement ouvrent une carte de texte. Pastille rouge au-dessus du panneau du calendrier quand une récompense est prête. Ambiance `kiosk_ambience` audible près du kiosque seulement (30 studs), réglée par le volume général.
- [ ] **Échelle des décors** (29 modèles des lots 15 à 17, dossier `World/BlenderDecor`) : dôme posé sur les piliers de la halle sans trou, Grand Œuf aligné sur son monument, colisée tourné vers l'entrée de l'arène, tuiles du tapis sous les œufs (œufs bien visibles), étals, bannières, lampadaires, panneaux (libellés lisibles), îlots de sakura et nénuphars à la bonne hauteur d'eau ; rien posé sur le kiosque, les chemins ou l'eau. Rapport F3, catégorie « décor de carte » : si des modèles sont « trop lourds », donne-moi leur nombre de Parts.
- [ ] **Meubles des maisons** : monte une base de niveau (1 à 8) : les meubles apparaissent dans la maison (repère au centre du bâtiment), ne traversent ni les murs ni la porte, suivent l'animation de montée de niveau ; avec les maisons Blender (niveaux 2 à 7) dis-moi si les meubles sont décalés (le centre réel des modèles n'est pas connu).
- [ ] **FPS mobile** : 5 joueurs sur téléphone sur la place (kiosque + décor) et dans des maisons de haut niveau : 30 images/s visées ; dis-moi si ça rame (un décor se coupe par `Config.Assets.decorOff`).
- [ ] **Rendu général** : couleurs et matériaux des modèles cohérents avec le style du jeu, aucune pièce flottante ou enterrée.

## 3septies. Lot 15 : PNJ, série de 7 jours, quêtes, sac d'œufs, événements (rien de tout ceci n'a été vu en jeu)

- [ ] **PNJ (30 min de jeu)** : après 8 min, environ 3 rencontres en 30 min ; le PNJ apparaît à ~25 studs sur la place ou un chemin (jamais dans un territoire ni sur une base), marche vers toi, bulle ❗, carte de dialogue en bas de l'écran ; **jamais pendant un vol, en portant un œuf, poursuivi par un gardien, au château ou pendant une cinématique** ; son `npc_ping` seul. Dis-moi si c'est gênant ou trop fréquent.
- [ ] **Modèles des PNJ** (Pip, Lina, Bruno, Kaï, Nora) : console serveur `[Assets] PNJ publiés aux clients : N/5` ; échelle (hauteur ~6 studs, Pip et sa charrette 9 studs de large), orientation face au joueur pendant la marche (sinon ils marchent de dos : dis-le moi), repli procédural (bonhomme coloré) si 0/5.
- [ ] **Échange avec Pip / Nora** : « Voir l'offre » montre ce que tu donnes et reçois (avec « 1 sur N »), 2ᵉ confirmation pour un pet Épique ou mieux ; les pièces et les pets sont bien retirés, l'œuf / le pet bien reçu (base, sinon sac d'œufs). **Combat contre Lina / Bruno / Kaï (lundi)** : il faut une équipe (bouton ⚔️) ; victoire = pièces (+ œuf parfois), défaite = rien de perdu.
- [ ] **Réglage « Ne plus être interpellé »** (menu Plus) : plus aucun PNJ ; le remettre fait revenir les PNJ (après le délai normal).
- [ ] **Série de 7 jours** (menu Bonus, remplace l'ancien bonus quotidien) : réclamation par bouton, pastille rouge sur Bonus, texte de chaque jour ; manque un jour (grâce), puis deux (écran de sauvetage : 3 missions / repartir du jour 1). Le bouton payant n'apparaît qu'après la création du produit (§4).
- [ ] **Sac d'œufs** : base pleine, réclame la série ou le calendrier : l'œuf va dans le sac (« Sac d'œufs N/10 ») ; « Poser » le remet dans la base quand une place se libère.
- [ ] **Calendrier mural** (près du kiosque, place du marché) : le modèle `hub.calendar` (30 cases, jour 1 en haut à gauche, coffre devant) s'affiche-t-il, à la bonne taille (7 studs de haut), tourné vers la place, sans chevaucher le kiosque ? Son prompt « Calendrier » ouvre le calendrier. Sinon dis-moi où le mettre.
- [ ] **Événements** : week-end (samedi et dimanche UTC) : tapis toutes les 4 s ; 18 h - 19 h UTC : revenus x2 ; Halloween / Noël / printemps : décor sur la place (citrouille, sapin, arche) et plumes d'événement dans le menu Bonus.

## 4. Créer les achats sur le Creator Hub et me donner les ID

Creator Hub → ton expérience → **Monetization**. Les prix sont des suggestions (Roblox prélève 30 %). Après création, colle chaque ID dans `Config.PASSES` / `Config.PRODUCTS` (clés `Coins2x`, `Lucky`, `Fast`, `Speed`, `VipBase`, `StarterPack`, `ExclusiveEgg`, `Revive`, `InstantHatch`, `LuckPotion`, `CoinPack`) et envoie-les-moi. Une icône est prête pour les 6 premiers achats dans `roblox/publication/art/`.

| Type | Nom exact | Prix | Description | Icône |
|---|---|---|---|---|
| Game Pass | Revenus x2 | 199 R$ | Double tous tes revenus de pièces, pour toujours. | `pass_coins2x_512.png` |
| Game Pass | Chance +10% | 149 R$ | Augmente de 10 points tes chances d'obtenir un pet de rareté supérieure. | `pass_lucky_512.png` |
| Game Pass | Éclosion rapide | 149 R$ | Les œufs éclosent 25 % plus vite, pour toujours. | `pass_fast_512.png` |
| Game Pass | Vitesse +20 % | 149 R$ | Cours 20 % plus vite, pour toujours. | (à créer) |
| Game Pass | Base VIP | 399 R$ | Boucliers d'œufs x2 et bonus quotidien x2, pour toujours. | (à créer) |
| Developer Product | Pack de départ | 99 R$ | Achat unique : 20 000 pièces, 3 œufs Rares et une potion de chance. | (à créer) |
| Developer Product | Œuf Mythique | 249 R$ | Un œuf Mythique (rareté fixe) placé dans ta base (il faut une place libre, sinon l'achat est livré plus tard automatiquement). **Lot 9 : renommer le produit existant « Œuf exclusif Mythique » en « Œuf Mythique » sur le Creator Hub** (pour ne pas le confondre avec la rareté Exclusif). | (à créer) |
| Developer Product | Relance immédiate | 49 R$ | Au Château : repars aussitôt là où tu es tombé, pv rétablis. Le retour gratuit au début de la salle reste disponible. | (à créer) |
| Developer Product | Éclosion instantanée | 49 R$ | Fait éclore tous tes œufs tout de suite. | `product_instanthatch_512.png` |
| Developer Product | Potion de chance | 99 R$ | +25 points de chances d'obtenir un pet supérieur pendant 15 minutes. | `product_luckpotion_512.png` |
| Developer Product | Sac de pièces | 99 R$ | Offre 20 minutes de tes revenus (minimum 5 000 pièces). | `product_coinpack_512.png` |
| Game Pass | +4 emplacements | 249 R$ | 4 emplacements d'œufs en plus dans ta base, pour toujours (jusqu'à 20). | créé et en vente |
| Game Pass | Tapis privé | 299 R$ | Un petit tapis au milieu de ta base : un œuf gratuit toutes les 3 min tant que tu joues. **Lot 9 : mettre à jour la description (2 min -> 3 min)**. | créé et en vente |
| Developer Product | Pluie de chance pour tous | 129 R$ | 10 min de +5 points de chance d'amélioration pour tout le serveur. | créé et en vente |
| Developer Product | Tapis doré | 99 R$ | 10 min : le tapis du marché livre un œuf toutes les 4 s (table dorée affichée), cumulable jusqu'à 30 min. **Lot 9 : mettre à jour la description (3 s -> 4 s)**. | créé et en vente |
| Developer Product | Œuf Secret | 1 499 R$ | Un œuf Secret (rareté fixe) placé dans ta base. Espèce, taille et mutation tirées au sort : probabilités affichées avant l'achat. Aucun bonus de combat. | créé (3736452048) ; offre masquée tant qu'aucune espèce Secret n'existe (lot 11) |
| Developer Product | Œuf Exclusif | 3 499 R$ | Un œuf Exclusif (rareté fixe) placé dans ta base. Probabilités affichées avant l'achat. Aucun bonus de combat. | créé (3736452061) ; masqué jusqu'à la 1re espèce Exclusif |
| Developer Product | Œuf Divin | 6 999 R$ | Un œuf Divin (rareté fixe) placé dans ta base. Probabilités affichées avant l'achat. Aucun bonus de combat. | créé (3736452072) ; masqué jusqu'aux espèces Divin |
| Developer Product | Corbeau chipeur | 79 R$ | 1 jeton de vol à distance (rendu si la victime chasse le corbeau). | créé et en vente |
| Developer Product | 3 Corbeaux chipeurs | 199 R$ | 3 jetons de vol à distance. | créé et en vente |
| Developer Product | Rattrapage du calendrier | 29 R$ | Rattrape UN jour manqué du calendrier de 30 jours. | créé et en vente (id 3736695392, rien à faire) |
| Developer Product | Sauver ma série | 29 R$ | Sauve ta série de 7 jours après 2 jours manqués (une fois par semaine). Aucun hasard. | **à créer (lot 15)** : colle l'ID dans `Config.PRODUCTS.StreakRestore.id` (tant qu'il vaut 0, le bouton est caché ; le sauvetage gratuit par les 3 missions reste disponible) |

- [ ] Créer les 5 Game Passes et les 6 Developer Products du tableau ci-dessus (colonne « ID à renseigner » : `PUBLICATION.md` §3bis donne la ligne exacte de `Config.lua` pour chacun).
- [ ] Copier chaque **ID** dans `roblox/src/ReplicatedStorage/Config.lua`, champ `id = 0` de la ligne correspondante (les 11 clés sont listées plus haut). Ou me donner les 11 ID et je m'en charge, puis je régénère la place.
- [ ] Tester chaque achat avec le **test purchase** de Studio.
- [ ] **Décision à prendre** : lire la politique Roblox sur les « Paid Random Items » avant d'activer **Chance +10%**, **Potion de chance** et **Éclosion instantanée** (elles touchent à des tirages aléatoires payés). Les probabilités sont déjà affichées dans le jeu (menu Plus). Prudence : ne lancer d'abord que Revenus x2, Éclosion rapide et Sac de pièces (laisser les autres à `id = 0`).

## 5. Téléverser les images

Creator Hub → ton expérience → **Media** (ou *Basic Settings > Icon / Thumbnails*).

- [ ] Icône : `roblox/publication/art/icon_512.png`.
- [ ] Miniatures : `thumb_1_hero_1920x1080.png` (en premier), `thumb_2_vol_1920x1080.png`, `thumb_3_pets_1920x1080.png`, `thumb_4_histoire_1920x1080.png`.
- [ ] Après ton playtest, **prendre 2 à 3 vraies captures d'écran du jeu** et les ajouter (Roblox modère les images : elles doivent représenter le jeu).

## 6. Conformité et compte

- [ ] Répondre au **questionnaire de maturité** (Creator Hub → expérience → Settings) : seul le créateur peut le faire, et honnêtement (le jeu contient des poursuites de chiens en dessin animé, des vols entre joueurs, des achats Robux avec tirages).
- [ ] Si Roblox le demande : **vérification de l'email, de l'âge ou de l'identité** (nécessaire pour certaines fonctions de monétisation et pour retirer des gains via DevEx). C'est entre toi et Roblox, je ne peux rien y faire.
- [ ] Passer l'expérience en **Public** (Creator Hub → expérience → Access) seulement après les points 3 et 4.

## 7. Facultatif

- [ ] **Sons** : chercher des sons dans le Creator Store et coller leurs ID (`rbxassetid://…`) dans `Config.SOUNDS` (par défaut, sons intégrés Roblox non vérifiés).
- [ ] **Modèles 3D** des pets et des rivaux (Creator Store ou Blender) si tu veux un rendu plus distinctif.
- [ ] **Activer `StreamingEnabled`** (Workspace > Properties) pour les téléphones d'entrée de gamme.
