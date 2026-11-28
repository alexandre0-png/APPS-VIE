# Lot 15 : écarts avec la spécification et décisions prises (intégration du 2026-11-27)

Spec : `LOTS_9_PLUS.md` sections F, G et « Lot 15 » de K ; brief `LOT15_INTEGRATION.md` (ses décisions priment). Rien n'a été joué dans Studio.

## Décisions tranchées (les 4 points « à valider » des notes d'intégration)

| # | Question | Décision (au plus simple et sûr) | Pourquoi |
|---|---|---|---|
| 1 | Plumes d'événement et plumes du calendrier (lot 9b) : une ou deux monnaies ? | **Deux monnaies distinctes** : `d.event.p` (événement) et `d.plumes` (calendrier). | Fusionner donnerait au calendrier (30 j) un accès à l'Œuf Exclusif à 150 plumes et casserait le plafond par jour de l'événement. |
| 2 | Plumes d'un événement terminé | **Remises à zéro** au début de l'événement suivant (pas de report), plafond 3 Œufs Exclusifs par événement, plafonds par jour : missions 40, victoires PvE 20, connexion 5. | Pas de thésaurisation d'une année sur l'autre ; un report pourra être ajouté dans `Rewards.plumeSync`. |
| 3 | Série : « deuxième jour manqué dans la semaine » | **Les deux cas mènent au sauvetage** : 1 jour manqué alors que la grâce de la semaine est déjà prise, OU 2 jours manqués d'affilée ; 3 jours ou plus : jour 1. | Le plus favorable au joueur sans ouvrir d'abus (le sauvetage payant reste 1 fois par semaine, et jamais déclenché par le client). |
| 4 | Quota de PNJ : compté à l'apparition ou à la réponse ? | **À l'apparition** (même sans réponse), avec `npc.nextAt` absolu ; Kaï hors quota (1 fois par semaine, lundi UTC). | Se reconnecter ou changer de serveur ne relance jamais une rencontre (testé de bout en bout). |

## Écarts d'intégration

- **Remotes** : un seul remote nouveau, `Npc` (serveur -> client). Les demandes du client passent par le remote `Action` existant (`npcAnswer`, `npcOff`, `daily`, `bagPlace`, `bonusClaim`, `weeklyClaim`, `plumeBuy`), comme tout le reste du jeu (anti-spam 0,08 s, `pcall`). Les noms `NpcAnswer`, `NpcSetting`, `StreakClaim`… des notes sont donc des actions, pas des RemoteEvents.
- **Données** : copiées dans le bloc « LOT 15 » de `Config.lua` ; `Lot15Data.lua` supprimé (un seul endroit à modifier). `EVENTS` (week-end, heure dorée) renommé **`TIMED_EVENTS`** : `Config.EVENTS` existait déjà (événements serveur alien / or / chance / marathon) et aurait été écrasé.
- **Calendrier (lot 9b)** : réutilisé tel quel (`CalSys.claim`, sauvegarde puis octroi). Seul changement : base pleine -> l'œuf va dans le sac d'œufs au lieu d'un refus (repli de `giveEgg` si le joueur remplit tout pendant la sauvegarde). `Rewards.calendarClaim` (enveloppe pure) reste testé mais n'est pas appelé par le serveur. La table de récompenses lue est `Config.CALENDAR.rewards` actuelle (non modifiée par ce lot).
- **Cartes D.5 (lot 12) absentes** : victoire contre Lina / Bruno = pièces (5 min de revenu x 0,6, plancher 500) + 60 % de chance d'un Œuf de la rareté moyenne de l'équipe (plafond Légendaire) ; Kaï = pièces + Œuf Mythique garanti (ramené à une rareté publiée). À remplacer par les 3 cartes au choix quand `Rewards` D.5 existera.
- **Nouveaux types de quêtes du jour** (`pve`, `duel`, `npcTrade`, `typeWin`, `odds`) : **non ajoutés** à `QUEST_TYPES` (données présentes dans `Config.QUESTS.newTypes`) : `duel`, `typeWin` et `odds` dépendent des lots 12-14. Les quêtes de la semaine et la quête bonus sont branchées.
- **XP x2 (jour 5 de la série)** et **XP de saison** : stockés (`d.xp2Until`, `d.seasonXp`) mais sans effet tant que l'XP des pets (lot 12) et la passe de saison (lot 16) n'existent pas. Défaite contre un PNJ : +5 au champ `x` des pets de l'équipe.
- **Ratio `battle.pve`** : n'existe pas encore (lot 12/13) ; non incrémenté.
- **Boss d'événement à la tour** : non fait (lot 12, tour refaite).
- **Type « en forme »** : +20 % d'attaque des pets de ce type au départ d'un combat PvE (tour, PNJ), pas de multiplicateur dans le moteur `Battle` (inchangé). Les 6 types de `Battle` sont ramenés aux noms de la rotation (Nature = Plante) ; Glace, Foudre, Terre n'ont encore aucune espèce.
- **Espèce vedette** : poids x2 appliqué exactement (`Rewards.featuredPick` : bascule après le tirage uniforme de l'espèce, testé à ±1 point sur 60 000 tirages) ; le compteur « 1 sur N » figé (lot 10) ne compte pas ce bonus, par principe ; le menu 🎲 n'affiche que les raretés (inchangé).
- **Week-end chanceux** : +5 points d'amélioration (gratuits, hors plafond des bonus payants) et tapis toutes les 4 s (valeur `Config.BELT.interval` ajustée par le serveur pendant le week-end).
- **Heure dorée** (18-19 h UTC) : même effet que la ruée vers l'or (revenus x2), sans annonce serveur dédiée ; affichée dans le menu Bonus.
- **Espèces des PNJ** (Koala, Ours brun, Renard à neuf queues) : absentes jusqu'au lot 11 ; seulement des signatures d'affichage. Les équipes adverses n'utilisent que des espèces existantes.
- **Puissance adverse** : somme des puissances (`Battle.power`) de l'équipe du joueur x U(0,9 ; 1,1) (Kaï x 1,3), répartie sur 3 pets ; la vitesse n'est pas mise à l'échelle (approximation).
- **PNJ visibles du seul joueur interpellé** (créés par le client) : pas de PNJ serveur qui gênerait les autres joueurs ; les modèles Blender sont publiés par le serveur dans `ReplicatedStorage.NpcTemplates` (repli procédural côté client).
- **« Cinématique »** côté serveur = grande éclosion récente (`TIER_GATE.fullCine`, 20 s) ; côté client, la carte de dialogue attend la fin de toute caméra scriptée et la fin d'un portage d'œuf.
- **Calendrier mural `hub.calendar`** : branché près du kiosque (décalage `Config.CALENDAR_BOARD`, tourné vers le centre de la place, hauteur 7) avec un prompt « Calendrier » qui ouvre le même panneau que le kiosque (validé par `Kiosk.handle`, distance au kiosque). Si le modèle ne charge pas : rien n'est posé (le kiosque garde son prompt). Orientation et emplacement à vérifier dans Studio.
- **Décors d'événement** (`event.pumpkin`, `event.xmasTree`, `event.springArch`) : posés sur la place (`Config.EVENT_DECOR_SPOT`) pendant l'événement limité correspondant (repli procédural : une grosse boule colorée et le nom de l'événement). L'événement d'été (`event.summerGate`) n'a pas de modèle : repli procédural.
- **Produit `StreakRestore`** : ajouté avec l'ID 0 (désactivé) ; à créer dans le Creator Hub (A_FAIRE_UTILISATEUR.md).
