---
type: audit
jeu: 2
maj: 2026-11-27
---
# Chipe-Œufs : audit des étapes restantes (lecture seule, 2026-11-27)

Périmètre : Jeu 2, univers 10776613087 (hub 115261336085924, partie 87012762353093). Dernier publié en privé : commit fa4e42b « Lot 14 intégré » (partie v45, hub v52). La tête de la branche de jeu (`claude/lucid-wozniak-o23lf0`) est 56ceec1 : quatre commits WIP « non vérifié : ne pas publier » sont venus après (voir A1).
Sources lues : `Jeux/Jeu-2-Chipe-Oeufs.md`, `Jeux/LOTS_9_PLUS.md` (K, L), `Jeux/REFONTE_CHIPE_OEUFS.md`, `Jeux/IDEES_CHIPE_OEUFS.md`, `lots-prep/INTEGRATION_11_12.md` et `lots-prep/*/README.md`, `roblox/A_FAIRE_UTILISATEUR.md` et les notes `LOT*_ECARTS.md`, `LOT*_SECURITE.md`, `RYTHME_NOTES.md`, `CHANGELOG.md`, `PUBLICATION.md` de la branche de jeu, `Studio/Procedure-publication.md`, `Assets/Assets-crees.md`, `PUBLICATION_A_COLLER.md`, `A-faire-utilisateur.md`, `Archive/Grenier-supprime.md`.

Légende : état = fait / en cours / non commencé. « Non commencé » pour un test Studio veut dire : rien n'a été joué dans Studio depuis le lot 2 (toutes les notes de lot l'écrivent). **[OUBLI POTENTIEL]** = présent dans la spec ou dans une note, absent des commits ou des fichiers de suivi (A_FAIRE, CHANGELOG, ECARTS).
Numéros « §… » = sections de `roblox/A_FAIRE_UTILISATEUR.md` (branche de jeu). Les puces de lots 3, 4, 5, 6, 7 et 8A de ce fichier sont dans le §1ter, sans numéro propre.

## Référence : lots livrés (non comptés comme restants)

| Lot | État | Commit / version |
|---|---|---|
| 1 à 8B (refonte) | fait, privé | lots 1-2 v32/39, 3-4 v33/40, 5 v34/41, 6 v35/42, 7 v36/43, 7b v37/44, 8A v38/45, 8B+9b+10 v40/47 |
| 9 (10 raretés, profil v11) | fait, privé | 15fb5a7, v39/46 |
| 9b (calendrier 30 j) | fait, privé | 2aa0afb |
| 10 (compteur, éclosions, sons, icônes) | fait, privé | 2aa0afb |
| 15 | fait, privé | 91f6907, v41/48 |
| 16 | fait, privé | 1387552, v42/49 |
| 11 + 12 | fait, privé | f7ff0f5, v43/50 |
| 13 | fait, privé | 8ef9c43 (+ palier 1500 : 1d8a7bd), v44/51 |
| 14 (classé en direct, DÉSACTIVÉ) | fait, privé | fa4e42b, v45/52 |
| 30 modèles/sons/icônes (lots 20 à 30), 46 achats | faits, téléversés | Assets-crees.md |

---

## (a) Code : lots, idées, écarts connus

| # | Étape | État | Source | Prochaine action |
|---|---|---|---|---|
| A1 | Combat UI « face à face » (BattleLayout, BattleScene, BattleUi, tests battlelayout) : 4 commits WIP (195af59, 7b8965a, 8ba7efc, 56ceec1) **[OUBLI POTENTIEL]** : absent de la spec, de CHANGELOG, de A_FAIRE et des notes ECARTS | en cours | `git log origin/claude/lucid-wozniak-o23lf0` | Terminer, Lune + `check.py`, QA + sécurité, ligne CHANGELOG et A_FAIRE, commit non-WIP. Ne rien publier avant : la tête ≠ le publié. |
| A2 | Plancher du tapis doré : +15 % visé, +13 % mesuré (le test ne vérifie que +5 %) | non commencé | `LOT16_ECARTS.md` « Manque » ; `RYTHME_NOTES.md` | Décision D6, puis recalibrer les poids `BELT.weights.golden` ou accepter et corriger le texte de la règle. |
| A3 | Maison niveau 4 : médiane 30:03 pour une cible 40 min (30-50), pire cas 28:28 sous la tolérance | non commencé | `LOT16_ECARTS.md` ; `RYTHME_NOTES.md` | Relever le seuil `BASE_LEVELS2[4]` ou accepter (D6) ; relancer `tests/Economy.lua` sur 5 graines. |
| A4 | Revenu Exclusif (R9) supérieur au Secret (R8), contraire au texte A.4 | non commencé | `lots-prep/chipe-11/README.md` « Écarts » ; `LOT12_ECARTS.md` | Décision D5, puis `INCOME_RANGE` et `PRICING` si changement. |
| A5 | Espèces d'événement/saison (Loup-garou citrouille, Renne étoilé, Corbeau couronné) tirables à tout moment : `Rules.rollPet` tire uniformément parmi toutes les espèces d'une rareté, aucun filtre `event` **[OUBLI POTENTIEL]** | non commencé | `chipe-11/README.md` (« relève du lot 15 ») ; `Bestiary.lua` ; `Rules.lua` l.103 ; `LOT16_ECARTS.md` n°3, 11 | Filtrer les espèces `event` hors de leur fenêtre (ou trancher en D7) ; test sur `rollPet`. |
| A6 | Interface du bestiaire : filtres rareté et type, silhouettes noires (B.7 n°3) | non commencé | `chipe-11/README.md` « Non fait » ; `LOT12_ECARTS.md` « Non branché » ; `LOTS_9_PLUS.md` lot 11 | Écrire l'UI Index (78 en grille), test client. |
| A7 | `tools/blender_check.py`, mise à jour de `BLENDER_REQUESTS.md`, protocole C.3 (rendu, vote B/L, FPS mobile) **[OUBLI POTENTIEL]** | non commencé | `LOTS_9_PLUS.md` lot 11 (fichiers, acceptation) ; `chipe-11/README.md` | Écrire l'outil, consigner le style B/L, mesurer le nombre réel de Parts des 60 modèles. |
| A8 | Classement « tirage le plus rare » (`ChipeOeufs_Rarest_v1`) **[OUBLI POTENTIEL]** : aucune occurrence dans `src/` | non commencé | `LOTS_9_PLUS.md` lot 10 et I.1 n°2 | Implémenter (Data + kiosque Classement) ou le retirer de la spec. |
| A9 | `Config.Debug.forceHatch` (acceptation du lot 10, test 3 de `chipe-11`) **[OUBLI POTENTIEL]** : absent, seul `Debug.AssetReport` existe | non commencé | `LOTS_9_PLUS.md` lot 10 ; `chipe-11/README.md` test 3 | Ajouter le crochet (hors production), pour tester les éclosions r1..r10 en Studio. |
| A10 | Revues QA et sécurité indépendantes des lots 8A, 8B, 9, 9b et 10 **[OUBLI POTENTIEL]** : des notes `LOT*_SECURITE.md` n'existent que pour 12 à 16 (et la revue du lot 7) ; le lot 9 contient la migration v11 | non commencé | `CLAUDE.md` (étape 3) ; `LOTS_9_PLUS.md` K | Lancer `roblox-security-reviewer` et `roblox-qa-tester` sur 9 (migration), 9b (calendrier, reçus) et 10 ; consigner dans une note. |
| A11 | Quêtes du jour `duel`, `typeWin`, `odds`, `pve`, `npcTrade` : données présentes, non ajoutées à `QUEST_TYPES` (dépendaient des lots 12-14, maintenant livrés) **[OUBLI POTENTIEL]** | non commencé | `LOT15_ECARTS.md` « Écarts d'intégration » | Brancher dans `QUEST_TYPES`, tests, vérifier l'XP de passe de la quête du jour. |
| A12 | Boss d'événement à la tour | non commencé | `LOT15_ECARTS.md` | Spécifier puis faire, ou retirer. |
| A13 | Potion de chance « tous les 5 étages » de `towerReward` non reprise avec les cartes | non commencé | `LOT12_ECARTS.md` ; `chipe-12b/README.md` écart 5 | Décision D8. |
| A14 | `PetXp.carry` (XP au vol/vente), XP de Dresseur, niveau de pet dans l'inventaire | non commencé | `LOT12_ECARTS.md` « Non branché » ; `combined-11-12/README.md` | Vérifier que le slot volé garde ses champs `x` ; ajouter l'affichage du niveau. |
| A15 | Lot 13 : badge de ligue au-dessus de la tête ; modèles `arena.podium`, `arena.banner`, `arena.board` ; titre « Champion de la saison » non stocké | non commencé | `LOT13_ECARTS.md` « Non fait » ; `LOTS_9_PLUS.md` J.1 et lot 13 | Créer les 3 modèles (Blender) et le champ de profil du titre, si voulu. |
| A16 | Lot 14 : carte « colisée seul » du serveur `ranked` (la carte normale est construite) ; forfait à la fermeture du serveur (BindToClose) ; seuil et activation de `PvpLive.enabled` | non commencé | `LOT14_ECARTS.md` ; `chipe-14/README.md` « Limites » ; `LOTS_9_PLUS.md` lot 14 | Après le test de §1novies : décider (D4). `enabled = false` jusque-là (tests qui vérifient `false`). |
| A17 | Modèles J.1 jamais créés : `arena.queuePortal`, `hub.hatchAltar`, `house.museum`, `shop.eggStand`, `event.summerGate` (repli procédural) **[OUBLI POTENTIEL]** | non commencé | `LOTS_9_PLUS.md` J.1 ; `Assets-crees.md` (lots 29, 30 : aucun) ; `LOT15_ECARTS.md` | Dire lesquels on garde ; créer ceux-là (script Blender) et les téléverser. |
| A18 | Spec B.7 : pose de victoire (provisoire), montée de niveau d'un pet (anneau + « Niv. N »), silhouette du bestiaire, musée des raretés (maison 6+), réaction des pets proches à un Divin, coffre du jour 7 qui s'ouvre | non commencé (pose : provisoire) | `LOTS_9_PLUS.md` B.7 ; `LOT16_ECARTS.md` n°12 | Faire le tri avec le propriétaire (D9) ; vraies `Animation` pour les 6 poses. |
| A19 | Notifications Roblox (« Experience Notifications », Open Cloud `user-notifications`) pour 2 messages ; clé API en secret **[OUBLI POTENTIEL]** | non commencé | `LOTS_9_PLUS.md` I.1 | Décision D10, puis code + clé via `request_credential`. |
| A20 | Fonctionnalités F de la refonte absentes de `src/` et de CHANGELOG : pêche aux pontons (F7), canards (F8), cycle jour/nuit (F10, « après playtest mobile »), « J'aime cette base » (F12), feux d'artifice niveau 8 (F13), panneaux directionnels (F4) **[OUBLI POTENTIEL]** : le lot 8 les listait (« décors F.4 à F.13 ») | non commencé | `REFONTE_CHIPE_OEUFS.md` F et lot 8 ; `LOT8B_ECARTS.md` | Vérifier ce qui existe déjà (moulin F9 fait, mini-carte F11 faite), retirer ou planifier le reste (D9). |
| A21 | Lot 8 : arène reliée à `BattleUi` (gradins, tableau des meilleurs étages) et entrée du donjon (F5, F6), écrits « Non fait (lot 16) » **[OUBLI POTENTIEL]** | non commencé | `LOT8B_ECARTS.md` « Non fait » ; `REFONTE_CHIPE_OEUFS.md` F5, F6, lot 8 | Vérifier dans le code ; si absent, planifier. La bande de spectateurs du duel (lot 13) couvre une partie de F5. |
| A22 | Interception d'un porteur (`Config.INTERCEPT.enabled = false`) | non commencé (volontaire) | `REFONTE_CHIPE_OEUFS.md` F14 | Laisser coupé ; test en playtest avant tout changement (D9). |
| A23 | Idée 1 : évolution des pets en « forme 2 » | non commencé | `IDEES_CHIPE_OEUFS.md` n°1 | Après l'onboarding ; attendre le go (D9). |
| A24 | Idée 2 : onboarding guidé des 5 premières minutes (déjà 3 étapes d'onboarding et un œuf de bienvenue) | non commencé | `IDEES_CHIPE_OEUFS.md` n°2 | À mesurer d'abord (entonnoir `onboarding` de la télémétrie), puis spécifier. Priorité 1 de l'ordre proposé. |
| A25 | Idée 3 : vitrine « pet du jour » | non commencé | `IDEES_CHIPE_OEUFS.md` n°3 | Après 1 et 2. |
| A26 | Idée 4 : cosmétiques de maison (toits, façades, boîtes aux lettres) | non commencé | `IDEES_CHIPE_OEUFS.md` n°4 | Après deux semaines de mesures. |
| A27 | Idée 5 : seconde vignette centrée sur le « 1 sur N » (image `vignettes/chipe-oeufs-v3-compteur-1920x1080.png` générée) | en cours (image faite, non téléversée) | `IDEES_CHIPE_OEUFS.md` n°5 ; `vignettes/` | Voir C5. |
| A28 | Saisons 2 à 6 : espèces Exclusif de saison absentes (trophée de repli) ; données `Config.SEASONS[n]` | non commencé | `LOT12_ECARTS.md` n°3 ; `LOT16_ECARTS.md` n°11 | À créer avant la fin de la saison 1 (60 jours après le 1er décembre). |
| A29 | Cadre doré des compteurs « 1 sur N » et indice de silhouette complet du passe Collectionneur | non commencé | `LOT16_ECARTS.md` n°17 | Finir ou retirer de la fiche du produit. |
| A30 | Revue hebdomadaire des métriques (D1, D7, durée de session, conversion, ARPPU…) et alertes de décision | non commencé (la télémétrie existe) | `LOTS_9_PLUS.md` I.2 | Après publication : tableau chaque lundi, une seule modif d'équilibrage par semaine. |
| A31 | Tests de non-fuite d'instances (50 éclosions), FPS ≥ 30 et mémoire < 1,2 Go (risque L5), compte de Parts avec 5 maisons de niveau 8 en modèles Blender (dépasse 7 000 d'environ 130 dans le pire cas) | non commencé (mesuré seulement en simulation) | `LOTS_9_PLUS.md` L5 ; `LOT8B_ECARTS.md` n°7 | Mesure réelle en B34, puis réduire le budget des meubles si besoin. |
| A32 | Outils de vérification : `selene` n'a pas pu s'exécuter (dump d'API hors ligne), `stylua --check` plante sur `//` (bug connu) | non commencé | `chipe-13/README.md` ; `Studio/Pieges.md` n°7 | Lancer `scripts/check-game.sh` sur une machine avec accès réseau au dump. |

---

## (b) Studio : tests à faire par l'utilisateur

Rien de ce qui suit n'a été joué en vrai. Se tester via Test > Clients and Servers (2 à 3 clients). Le test d'achat se fait en mode test. Le téléport hub vers partie ne marche que depuis roblox.com (`Studio/Pieges.md` n°3).

| # | Étape | État | Source | Prochaine action |
|---|---|---|---|---|
| B1 | Réglage Enable Studio Access to API Services (sinon mode mémoire) | non commencé | A_FAIRE §1bis | Cocher dans Game Settings > Security. |
| B2 | Téléportation hub vers jeu, lignes `[Party]` et `[Spawn]`, `[Hub] décor catalogue`, `[Assets]` | non commencé | A_FAIRE §1ter (3 premières puces) | Jouer depuis roblox.com, copier la sortie si échec. |
| B3 | Révélation d'œuf, boutons, bannière de zone, portail, manette, Max Players | non commencé | A_FAIRE §1ter | Parcours rapide, noter ce qui est trop chargé sur téléphone. |
| B4 | **Migration v11 à v13** avec un compte qui a déjà joué, dans un lieu PRIVÉ (même pets, maison jamais plus basse, tour 30 vers 35) | non commencé | A_FAIRE §3quater (1re puce) ; `LOTS_9_PLUS.md` L1 | À faire avant tout passage en public. |
| B5 | Carte 700 x 500 : pont du château, rivière, collines, cour de Zed, gardiens | non commencé | A_FAIRE §1ter (2 puces carte) | Parcourir, signaler. |
| B6 | Tapis central (lot 3) : défilement, achat, œuf de bienvenue, panneau, lag à plusieurs | non commencé | A_FAIRE §1ter (puce Tapis) | Jouer. |
| B7 | Difficulté des territoires (lot 4) : clochettes, herse, temps de maintien, colonne de lumière, boutons à gauche | non commencé | A_FAIRE §1ter (puce Difficulté) | Jouer, dire si Mara/Zed trop durs. |
| B8 | Maison évolutive (lot 5) : 20 emplacements, modèles `house.l2..l7`, animation, alarme, chien, ancien profil, pass +4 | non commencé | A_FAIRE §1ter (puce Maison) | Jouer. |
| B9 | Énigme de la Mère Poule (lot 6) : **3 humains, sans aide, moins de 10 min** (critère d'acceptation) + relever `[Riddle] step=…` | non commencé | A_FAIRE §1ter (puce Énigme) ; `REFONTE` lot 6 | Trouver 3 testeurs ; abandon > 40 % à l'étape 1 = rapprocher les plumes. |
| B10 | Équilibrage et 7 sons (lot 8A) : charge du nid chez Zed/Mara, boutique jusqu'au Légendaire, Parts au pic (~3 500) | non commencé | A_FAIRE §1ter (puce 8A) | Jouer. |
| B11 | Monétisation (lot 7) : 3 comptes, corbeau (≤ 3 par heure), tapis privé, compte restreint, indemnité plafonnée 900/jour, arrêt serveur | non commencé | A_FAIRE §1ter (puce Monétisation) | Jouer à 3 comptes. |
| B12 | Calendrier de 30 jours (lot 9b) | non commencé | A_FAIRE §1quinquies | Jouer ; demander un mode de test pour plusieurs jours. |
| B13 | Gus clément, arbres/chemins/protections, village, étiquette « Blender N/M », carte compacte, revenu inactif, éclosions, machine à sous | non commencé | A_FAIRE §3ter | Parcourir ; repasser `Config.Debug.AssetReport` à `false` ensuite (E9). |
| B14 | Lot 9 : œufs Blender r1..r10, rythme 25-30 min, rythme du lot 16 (événements `house_level_reached_l4..l8`), boutique 5 puis 10 œufs, prix Robux = `Config.PRODUCTS`, 12 événements Analytics | non commencé | A_FAIRE §3quater | Jouer, puis comparer aux cibles après publication. |
| B15 | Lot 10 : éclosion de chaque rareté, « 1 sur N », combat (intro, effets, sons), sons de kiosque, `[Assets] icônes d'interface : N/42` | non commencé | A_FAIRE §3quinquies | Jouer (A9 aiderait). |
| B16 | Lot 8B : kiosque (4 panneaux), échelle des 29 décors, meubles des maisons, FPS mobile, rendu | non commencé | A_FAIRE §3sexies | Jouer ; donner le nombre de Parts des modèles « trop lourds ». |
| B17 | Lot 15 : rencontres PNJ, modèles PNJ, échange Pip/Nora, combats Lina/Bruno/Kaï (lundi), réglage « ne plus être interpellé », série de 7 jours, sac d'œufs, calendrier mural, événements | non commencé | A_FAIRE §3septies | Jouer (30 min). |
| B18 | Lot 16 : boutique 8 catégories, **46 achats un par un** en mode test, base + sac pleins, compte restreint, passe de combat (début le 1er déc.), offres à l'écran, 8 vendeurs, poses, rythme, 6 types d'événements Analytics | non commencé | A_FAIRE §1sexies | Jouer ; c'est le plus gros bloc de tests. |
| B19 | Lots 11 + 12 : choix de 3 cartes, boss = œuf, reconnexion avant 15 s, spécial au 6e tour, efficacité, tours 35/40/45, **mobile 360 px**, 78 espèces, boutique Secret/Exclusif/Divin, palier 30 premium, XP de pet | non commencé | A_FAIRE §1septies | Jouer ; publier les deux lieux en même temps. |
| B20 | Lot 13 : défi (touche G), refus, duel complet, spectateur, quitter en plein duel, quotas, fin de saison (1000 vers 600) | non commencé | A_FAIRE §1octies | Jouer à 2-3 clients. |
| B21 | Lot 14 : test réel à 2 comptes sur le lieu publié, COPIE de test avec `enabled = true` et `minCCU = 2` ; signature de `ReserveServerAsync` ; absent/départ ; file seule ; quotas MemoryStore | non commencé | A_FAIRE §1novies | À faire avant toute activation (D4). |
| B22 | Fréquentation : événements `ccu_sample_arena` / `_castle` / `_ranked` dans Analytics, somme vs seuil de 60 joueurs | non commencé | A_FAIRE §1novies ; `PUBLICATION.md` §5 A | Après publication, lire le Creator Hub. |
| B23 | Tailles et sens des modèles Blender (gardiens, pièges, herses, pales), effets 3D et cinématiques (`ANIMATIONS.md`) | non commencé | A_FAIRE §1quater | Premier playtest. |
| B24 | Ouvrir la place et publier : File > Open from File, Publish As… (ancienne procédure : l'expérience existe déjà, le §2 est périmé) | à reclasser | A_FAIRE §2 | Supprimer ou réécrire (E11). |
| B25 | Playtest général à 2 puis 5 joueurs ; cinématiques, animations, modèles d'œufs, monument du Grand Nid | non commencé | A_FAIRE §3 | Sortie sans erreur rouge pendant 15 min. |
| B26 | Modèles d'œufs catalogue refusés (2937230482, 147144059, 2937218888) : ajouter à l'inventaire ou accepter le repli procédural | non commencé | A_FAIRE §1bis ; `A-faire-utilisateur.md` ; `Pieges.md` n°10 | « Get » dans la boutique avec le compte propriétaire. |
| B27 | Son `portal` de `Config.SOUNDS` : crochet muet, aucun `rbxassetid://` vérifié **[OUBLI POTENTIEL]** : non repris par le lot 28 (37 sons) | non commencé | A_FAIRE §1ter (puce Sons) ; `Assets-crees.md` lot 28 | Générer un son de portail (audio_synth) ou accepter le silence. |
| B28 | Sons du lot 20 (énigme, 7 sons) notés « Reviewing » le 25 nov, jamais confirmés « Approved » **[OUBLI POTENTIEL]** | à vérifier | `Assets-crees.md` lot 20 | Lecture `moderationState` par l'API (`GET /assets/v1/assets/{id}`). |
| B29 | Compte restreint (PolicyService) : toutes les offres à hasard disparaissent | non commencé | A_FAIRE §1sexies ; §1ter (lot 7) | Test avec un compte de test restreint. |
| B30 | Passage des deux lieux ensemble (serveurs mixtes) et `Config.PVP_LIVE.enabled = false` vérifié par `grep` avant publication | non commencé | `INTEGRATION_11_12.md` ; `PUBLICATION.md` §5 A | À chaque publication. |
| B31 | Passe de combat : date de début 2026-12-01 00:00 UTC à confirmer, avant elle tout ce qui contient le passe est masqué | non commencé | A_FAIRE §1sexies ; `LOT16_ECARTS.md` n°10 | Décision D2 puis test le 1er décembre. |
| B32 | Lot 11 : profil à 18 espèces (Index x/78, bonus de collection +30 %, puis +35 % à la 24e), types projetés (Hérisson, Souris, Léopard des neiges) | non commencé | `chipe-11/README.md` tests 4, 5 | Jouer. |
| B33 | Manette (si Console cochée) : X boutique, Y missions, B fermer, G défi | non commencé | A_FAIRE §1ter ; §1octies | Si pas de manette, décocher Console (D11). |
| B34 | Performance mobile : émulateur 360x640 et 844x390, 5 joueurs, 35 pets, éclosion Divin, combat ; vrai téléphone si possible | non commencé | `LOTS_9_PLUS.md` L5 ; `PUBLICATION.md` §5 C | Mesurer FPS, mémoire ; interrupteurs : `Config.REVEAL.forceReduced`, `Config.Assets.decorOff`. |
| B35 | Vérification de l'ordre des deux `PlayerRemoving` et du forfait avant sauvegarde | non commencé | `chipe-13/README.md` ; `LOT13_ECARTS.md` | Couvert par B20 (quitter en plein duel). |

---

## (c) Creator Hub, textes, visuels

| # | Étape | État | Source | Prochaine action |
|---|---|---|---|---|
| C1 | Coller le texte final dans l'expérience 10776613087 (nom, description courte et longue) | non commencé (texte rédigé : description 931 caractères, nom 27, courte 76, dans les limites) | `PUBLICATION_A_COLLER.md` | Corriger le fichier d'abord (C2), puis coller. |
| C2 | `PUBLICATION_A_COLLER.md` : deux blocs « TEXTE MIS À JOUR » identiques en titre ; le premier garde les genres (« Horreur »), appareils, « 2 par serveur » et les 5 accroches du Grenier ; le texte du Grenier (univers 10776611603) est périmé **[OUBLI POTENTIEL]** | non commencé | `PUBLICATION_A_COLLER.md` (commit 276bd8a) | Le premier bloc a le texte le plus récent (kiosque, duel, passe de combat) mais de mauvaises métadonnées ; le second a les bonnes (genres Adventure, Fantasy, Comedy, joueurs max 5, accroches) mais un texte plus ancien. Garder la description du premier, reprendre les métadonnées du second, supprimer le second bloc et la section Grenier. |
| C3 | Nom de l'expérience : le fichier propose « Chipe-Œufs : Pets & Arène », `LISTING.md` et A_FAIRE disent « Vole des Œufs ! » | non commencé | `PUBLICATION_A_COLLER.md` ; A_FAIRE §2 | Décision D1. |
| C4 | Icône 512 et 4 miniatures 1920x1080 : celles de `roblox/publication/art/` datent de la version à 18 pets ; des versions plus récentes sont dans `vignettes/` (v2, v3) | non commencé | A_FAIRE §5 ; `vignettes/` | Choisir les images, téléverser dans Creator Hub > Media. |
| C5 | Seconde miniature « 1 sur N » (test A/B) | non commencé | `IDEES_CHIPE_OEUFS.md` n°5 ; `vignettes/chipe-oeufs-v3-compteur-1920x1080.png` | Téléverser avec C4. |
| C6 | 2 à 3 vraies captures d'écran après playtest (la modération exige des images représentant le jeu) | non commencé | A_FAIRE §5 | Après B25. |
| C7 | Icônes des 23 achats du lot 16 (images générées dans `vignettes/icones-achats/lot16/`, 25 fichiers) **[OUBLI POTENTIEL]** : seules les 16 premières icônes sont notées comme téléversées | non commencé | `Procedure-publication.md` (16 icônes) ; commits 9928d71, 8812b08 ; `Assets-crees.md` (rien) | `PATCH` imageFile sur chaque produit/passe ; noter dans Assets-crees. |
| C8 | Renommer le produit ExclusiveEgg (3734229320) en « Œuf Mythique » ; mettre à jour les descriptions Tapis privé (3 min) et Tapis doré (4 s) **[OUBLI POTENTIEL]** : demandé en A_FAIRE §4 (« Lot 9 »), aucune trace d'exécution | non commencé | A_FAIRE §4 (lignes Œuf Mythique, Tapis privé, Tapis doré) | `PATCH` nom/description par l'API de produits (ou à la main). |
| C9 | Probabilités à recopier sur la fiche de chaque offre à hasard (§3ter de PUBLICATION) | non commencé | A_FAIRE §1ter (puce 7, point 5) ; `PUBLICATION.md` §3ter | Copier les tables dans les descriptions des produits. |
| C10 | Prix du Creator Hub = `Config.PRODUCTS[*].robux` (46 achats) | non commencé | A_FAIRE §3quater (puce Prix Robux) | Comparer l'API (liste des produits) au code. |
| C11 | Questionnaire de maturité : à (re)faire honnêtement (vol d'objets, duel, PNJ, achats à hasard) | non commencé | A_FAIRE §6 ; `PUBLICATION.md` §3ter | Propriétaire seul. |
| C12 | Vérification d'email/âge/identité si exigée (monétisation, DevEx) | non commencé | A_FAIRE §6 | Propriétaire seul. |
| C13 | « Allow Third Party Teleports » sur les expériences ; « Enable Studio Access to API Services » | non commencé | `A-faire-utilisateur.md` | Cocher dans Game Settings. |
| C14 | Tableau Analytics : 12 événements personnalisés, 6 types, `ccu_sample_*`, `version_1.16.0` | non commencé | A_FAIRE §3quater, §1sexies | Après la première publication de test. |
| C15 | Lancement progressif : privé, puis amis 24 h, puis public ; surveiller la première heure | non commencé | `PUBLICATION.md` §5 E ; A_FAIRE §1quater | Après D3. |
| C16 | Passer l'expérience en Public (l'API ne le permet pas : `PATCH` répond 200 sans rien changer) | non commencé | A_FAIRE §6 ; `Procedure-publication.md` | Propriétaire seul, après « publie en live » (D3). |
| C17 | Genres, appareils (Console seulement après test à la manette), joueurs max 5 | non commencé | `PUBLICATION_A_COLLER.md` ; `PUBLICATION.md` §1 | Selon D11. |
| C18 | `StreamingEnabled` (facultatif, téléphones d'entrée de gamme) | non commencé | A_FAIRE §7 | À évaluer avec B34 ; `Pieges.md` n°5 le garde coupé. |
| C19 | Sons/modèles facultatifs du §7 (Creator Store) | non commencé | A_FAIRE §7 | Aucune action requise : les 37 sons et les modèles sont créés. |

---

## (d) Décisions en attente de l'utilisateur

| # | Décision | État | Source | Prochaine action |
|---|---|---|---|---|
| D1 | Nom de l'expérience : « Pets & Arène » ou « Vole des Œufs ! » | non commencé | `PUBLICATION_A_COLLER.md` vs A_FAIRE §2 | Choisir. |
| D2 | Date de début de la saison 1 : 2026-12-01 00:00 UTC (`SeasonData.SEASON.start`) | non commencé | A_FAIRE §1sexies ; `LOT16_ECARTS.md` n°10 | Confirmer ou changer ; c'est dans quatre jours. |
| D3 | Phrase « publie en live » : passage en public (aucun lot ne l'a reçue) | non commencé | `PUBLICATION_A_COLLER.md` (titre) ; Jeu-2 note (« Reste : tests en Studio, puis vignettes, textes ») | Après B4, B18-B21, C1-C11. |
| D4 | Activation du classé en direct (`PVP_LIVE.enabled`) et seuil 60 joueurs simultanés | non commencé | A_FAIRE §1novies ; `LOT14_ECARTS.md` | Seulement après B21 et B22. |
| D5 | Exclusif (R9) plus rentable que Secret (R8) : garder ou inverser | non commencé | `chipe-11/README.md` | Choisir. |
| D6 | Écarts de rythme : tapis doré +13 % (cible +15 %), maison 4 à 28 min, risque 900 pièces/jour par paire complice | non commencé | `LOT16_ECARTS.md` ; Jeu-2 note (lot 7b) | Accepter ou faire recalibrer ; aussi après les mesures réelles de B14. |
| D7 | Espèces d'événement : exclues du tirage hors événement, ou tirables | non commencé | A5 | Choisir. |
| D8 | Potion de chance des étages multiples de 5 de la tour | non commencé | A13 | Garder à côté des cartes, ou non. |
| D9 | Quelles idées et fonctionnalités F/B.7 on fait : évolution (A23), onboarding (A24), vitrine (A25), cosmétiques (A26), pêche/canards/jour-nuit/J'aime/feux d'artifice (A20), musée et poses animées (A18), interception (A22) | non commencé | `IDEES_CHIPE_OEUFS.md` (ordre proposé : onboarding, évolution, vitrine, puis cosmétiques et vignette B) | Donner l'ordre ou dire « rien de plus » ; aucune n'est livrée sans test Studio. |
| D10 | Notifications d'expérience (rétention) : oui ou non | non commencé | A19 | Choisir. |
| D11 | Console cochée ou non (aucun test manette) ; appareils annoncés | non commencé | `PUBLICATION_A_COLLER.md` ; A_FAIRE §1ter | Choisir. |
| D12 | Politique des « Paid Random Items » : A_FAIRE §4 recommandait de ne lancer d'abord que Revenus x2, Éclosion rapide et Sac de pièces, mais **tous les ids sont branchés** et les offres à hasard sont en vente (hasard affiché, masquées pour compte restreint) **[OUBLI POTENTIEL]** : décision jamais retirée du fichier | non commencé | A_FAIRE §4 (dernière puce) ; `PUBLICATION.md` §3ter | Valider par écrit la politique ou remettre `id = 0` sur les offres à hasard avant le passage en public. |
| D13 | Incohérence du journal : « œufs Secret/Exclusif/Divin jamais vendus en Robux » (26 nov) alors que EggSecret 1 499, EggExclusive 3 499, EggDivine 6 999 R$ sont créés et confirmés (prix confirmés le même jour) **[OUBLI POTENTIEL]** | non commencé | `Journal/Decisions.md` ligne 26 nov ; `Jeu-2-Chipe-Oeufs.md` ; `CHANGELOG.md` règle 3 | Trancher, puis corriger Decisions.md ou retirer les 3 produits. |
| D14 | Jeu 1 Hôpital (public) : fournir le `.rbxl` ou coller les scripts de la session ; blocage « pas de fichier de lieu » | non commencé | `Jeu-1-Hopital.md` ; `A-faire-utilisateur.md` | Hors Jeu 2 : réponse du propriétaire attendue. |
| D15 | Jeux 3 et 4 (zoo, PvP) en pause : correspondance numéro/expérience « à confirmer », achats à `id = 0` | non commencé | `Jeux-3-et-4.md` | Hors Jeu 2 : confirmer ou reporter. |

---

## (e) Nettoyage : Grenier, anciennes clés, achats inutiles, dépôt

| # | Étape | État | Source | Prochaine action |
|---|---|---|---|---|
| E1 | Supprimer l'expérience du Grenier (univers 10776611603, hub 77452764500707, partie 88091909899710) : l'API ne le permet pas | non commencé | `Archive/Grenier-supprime.md` | Propriétaire : Creator Hub, supprimer l'expérience. |
| E2 | Supprimer les achats du Grenier avec elle : passes LampeRenforcee 2094131168, LanterneDoree 2096725189 ; produits Pile 3734229107, Cailloux 3734229116, Soutien 3734229125 | non commencé | `Archive/Grenier-supprime.md` | Propriétaire, avec E1 (un achat ne se supprime pas par API, il se retire de la vente). |
| E3 | Supprimer l'ancien hub de Chipe-Œufs (lieu 106358102689021, univers 10776613783) marqué « obsolète » | non commencé | `Jeu-2-Chipe-Oeufs.md` | Propriétaire, après vérification que plus rien ne les référence. |
| E4 | Supprimer les anciennes clés API devenues inutiles (une seule clé active, la v2 du 21 nov) | non commencé | `A-faire-utilisateur.md` ; `Procedure-publication.md` | Propriétaire : Creator Hub > API Keys. |
| E5 | Achats inutiles de Chipe-Œufs : aucun repéré (46 créés = 46 au catalogue, vérifié par comptage : 10 passes, 36 produits) ; vérifier côté hub qu'il n'existe pas d'essai oublié | non commencé | `Assets-crees.md` ; `PUBLICATION.md` §3bis | Lister les passes/produits par l'API et comparer au catalogue. |
| E6 | Expériences des jeux abandonnés (Festin du t-rex 10776614241 et son hub 10776614638 ; Jeux 4, 6, 8 supprimés « rien d'effacé côté Roblox ») | non commencé | `Jeux-3-et-4.md` | Décision avec D15, puis suppression par le propriétaire. |
| E7 | Branche `claude/tombe-grenier-animations-5ilizr` et sessions archivées conservées « tant que l'utilisateur ne demande pas la suppression » | non commencé | `Archive/Grenier-supprime.md` | Attendre l'ordre ; ne rien supprimer sans lui. |
| E8 | Dépôt de jeu : `git stash@{0}` (travail partiel 8A non appliqué), tags `backup/roblox-lot*`, `lots-prep/` (lots 11 à 14 tous intégrés) | non commencé | `LOT8B_ECARTS.md` « Non fait » ; `INTEGRATION_11_12.md` | Après le passage en public : archiver `lots-prep/`, supprimer le stash si confirmé inutile. |
| E9 | `Config.Debug.AssetReport = true` publié (étiquette « Blender N/M ») | non commencé | A_FAIRE §3ter (puce Capture du hub) ; `Config.lua` l.1905 | Repasser à `false` après la capture, avant le public. |
| E10 | Notes de suivi périmées : `A-faire-utilisateur.md` (vault, 2026-11-20, parle du Grenier) ne reflète pas A_FAIRE_UTILISATEUR ; `Jeu-2-Chipe-Oeufs.md` « Dernier publié : 087efed (hub v14, partie v9) » ; `RYTHME_NOTES.md` titré « NON INTÉGRÉ » alors que le lot 16 l'a intégré ; `LOT16_ECARTS.md` dit que `RYTHME_NOTES.md` manque ; `Jeux/LOT10_INTEGRATION.md` ; `INTEGRATION_11_12.md` | non commencé | fichiers cités | Mettre à jour en un seul commit (après les décisions) ; `00-INDEX.md` n'est pas daté depuis le 20 nov. |
| E11 | `roblox/A_FAIRE_UTILISATEUR.md` : §2 (création de l'expérience, Max Players 10) et §4 (créer 5 passes et 6 produits ; `StreakRestore` « à créer », alors que les 46 achats existent, dont StreakRestore 3736703610) sont périmés **[OUBLI POTENTIEL]** : risque de refaire des achats en double | non commencé | A_FAIRE §2, §4 ; `Assets-crees.md` | Réécrire §4 en « fait » et supprimer §2 (côté session Jeu 2). |
| E12 | `Studio/Procedure-publication.md` : ne mentionne ni « publier les deux lieux d'un coup » (serveurs mixtes), ni les tags `backup/`, ni la règle « jamais un commit WIP », ni la restauration | non commencé | `Procedure-publication.md` ; `INTEGRATION_11_12.md` | Ajouter ces trois lignes. |
| E13 | Fichiers d'objets Grenier restants : `battement_coeur` et `grincement_porte` jamais téléversés (sans objet) ; assets du Grenier dans `Assets-crees.md` | non commencé | `Assets-crees.md` | Marquer obsolètes (ne rien supprimer des assets déjà téléversés). |
| E14 | Anciennes API de Chipe-Œufs : `Config.TRAVEL`, alias `Config.Map`, `Config.PVP.rewards` / `pvpSeasonReward` plus lus par `Main`, `Piste d'entraînement` | non commencé | `REFONTE` lot 2 ; `LOT13_ECARTS.md` | Retirer après le public, quand les tests historiques sont adaptés. |

---

## Oublis potentiels (récapitulatif)

A1 combat face à face non suivi · A5 espèces d'événement tirables partout · A7 `blender_check.py`, BLENDER_REQUESTS, protocole C.3 · A8 classement « tirage le plus rare » · A9 `Debug.forceHatch` · A10 revues QA/sécurité des lots 8A, 8B, 9, 9b, 10 · A11 quêtes `duel`/`typeWin`/`odds` · A17 modèles J.1 manquants · A19 notifications d'expérience · A20 fonctionnalités F7, F8, F10, F12, F13, F4 · A21 arène/donjon du lot 8 · B27 son `portal` · B28 sons du lot 20 jamais confirmés Approved · C2 texte à coller avec erreurs du Grenier · C7 icônes du lot 16 non téléversées · C8 renommage ExclusiveEgg et descriptions des tapis · D12 politique « Paid Random Items » contredite par les ids branchés · D13 Decisions.md contredit les 3 produits Robux · E11 A_FAIRE §2 et §4 périmés.
