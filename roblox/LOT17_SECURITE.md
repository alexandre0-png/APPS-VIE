# Lot 17 (idées 1, 2, 3) : revue de sécurité courte — 2026-11-28

Revue par lecture du code intégré et par les tests lupa (runtime factice, vrai `Main.server.lua` + `Data.lua`). **Rien n'a été testé dans Studio ni avec de vrais joueurs malveillants.**

## Idée 1 : onboarding en 5 étapes (`Onboarding.lua`, champ de profil `onb`, action `onbSkip`)

| Point | Constat |
|---|---|
| Remote | Une seule action nouvelle, `onbSkip` (sans argument lu). Elle ne fait que TERMINER le tutoriel (`skip = true`), idempotente (refusée si déjà terminé ou passé). Aucun gain, aucune récompense. Débit borné par le dispatcher (`lastAct` 0,08 s). |
| Faits | Le client n'envoie AUCUN fait : présence dans la base (`inPlot` sur la position serveur), éclosions (`d.hatched`), niveau de maison (`s.baseLevel`), revenu réellement versé par le tick, combat de tour ACCEPTÉ. Étapes dans l'ordre, jamais de saut, 3 s minimum par étape, valeurs non numériques / NaN / infinies / négatives refusées. |
| Profil | `onb` assaini à chaque lecture (`Onboarding.migrate`, idempotente, testée sur 12 profils, profils corrompus compris) ; jamais réinitialisé ; v13 inchangée (un serveur ancien ignore le champ, sans perte : au pire il le supprime, et le joueur est alors classé « existant » s'il a éclos ou joué 120 s). |
| Renaissance | `onb` n'est pas dans la liste blanche de remise à zéro du correctif 4c8bcf9 (`coins`, `up`, `slots`, `equip`, `pendingAway`, `last`) : il survit, un tutoriel fini ne repart jamais. Testé (bout en bout). |
| Télémétrie | 6 noms fermés ajoutés à `Telemetry.ONBOARDING` (`tut_step2..5`, `tut_done`, `tut_skip`) : au plus un événement par étape franchie (3 s minimum entre deux) et un pour « Passer » (une fois) ; même file que le reste (<= 1 événement / s / joueur). |
| Mémoire | Un seul compteur de session (`s.onbT`), libéré avec la session. Tick serveur : 1 lecture de position par seconde et par joueur en tutoriel seulement. |

**Bilan idée 1 : 0 défaut critique, élevé ou moyen.**

## Idée 3 : vitrine du pet du jour (`Showcase.lua`, champ de profil `showcase`, DataStore `ChipeOeufs_Showcase_v1`)

| Point | Constat |
|---|---|
| Remote | Aucun remote nouveau. La réclamation part de l'éclosion décidée par le serveur (`hatch`), jamais d'une demande client. |
| Concurrence | `UpdateAsync` sur `Showcase_<jour>` : premier écrit gagne entre serveurs ; un échec DataStore n'accorde jamais de bonus (`error`) ; un appel en cours par joueur (`busy`) ; propriétaire mis en cache par serveur (aucun appel DataStore de plus une fois connu). `task.spawn` + `pcall` : l'éclosion n'attend jamais le DataStore. |
| Bonus | +5 % de revenus pendant 24 h, daté (`ends`), jamais prolongé ni cumulé, une vitrine par joueur et par semaine (`cooldownDays = 7`). `sanitize` ramène une fin lointaine à 24 h et un jour futur à aujourd'hui (profil trafiqué ou horloge). |
| Confidentialité | Le `userId` reste dans l'enregistrement serveur ; la vue publique ne donne que l'espèce et le `DisplayName` assaini (20 caractères, contrôles retirés). |
| Profil | `showcase = { last, ends }`, SANS changement de version (v13) ; assaini à chaque lecture, idempotent, jamais réinitialisé quand il est valide. |
| Renaissance | `showcase` n'est pas dans la liste blanche de remise à zéro (4c8bcf9) : un bonus en cours survit à la renaissance (comme les autres boosts datés), la semaine de recharge aussi (sinon renaître effacerait la limite hebdomadaire). |
| Espèces d'événement | Correctif d'intégration : les espèces marquées `event` (A5 : Loup-garou citrouille, Renne étoilé, Corbeau couronné) sont exclues de la vitrine ; hors fenêtre elles ne sortent d'aucun œuf (vitrine impossible). Testé. |
| Robux | Aucun produit, passe ni achat ne donne la vitrine. **Point à décider (faible)** : un œuf payé de rareté fixe (Œuf Mythique 249 R$, Secret, Exclusif, Divin) peut faire éclore l'espèce du jour, donc donner indirectement le +5 % pendant 24 h. Gain borné (un bonus par semaine, +5 %), aucune force de combat. Noté dans `A_FAIRE_UTILISATEUR.md`. |
| Télémétrie | Aucun événement ajouté (la liste des 16 métriques par joueur est fermée et testée) ; au plus 1 notification par victoire. |

**Bilan idée 3 : 0 défaut critique, élevé ou moyen ; 1 point faible à décider (œufs payés).**

## Idée 2 : évolution des pets (`Evolution.lua`, profil v14 `evo` + `slot.f`, actions `evoPreview` / `evolve`, remote `Evo`) — LIVRÉE DÉSACTIVÉE

| Point | Constat |
|---|---|
| Interrupteur | `Config.EVOLUTION.enabled = false` : `evoPreview` ne répond pas, `evolve` est refusé par `Evolution.plan` (testé de bout en bout). Une forme 2 existante garderait ses bonus. |
| Remote | Le client n'envoie que l'indice d'emplacement et le prix maximal qu'il accepte (`maxCost`, nombre ou absent ; NaN / texte refusés). Doublons sacrifiés, coût (300 s du revenu actuel), interdits : calculés par le serveur. `Evo` est serveur -> client seulement (aucun `OnServerEvent`). |
| Interdits | Suiveur, équipe de combat, copie de la défense PvP, pet déjà en forme 2, Géant / Colossal / Arc-en-ciel / Alien / Céleste ; refus pendant combat, Château, recherche PvP, départ, autre évolution. Le dernier exemplaire d'une espèce n'est jamais sacrifié. |
| Atomicité | Copie « après » sauvegardée (`Data.save`) PUIS octroi (`stillValid` + `apply`, pièces débitées par différence). DataStore en panne : rien ne change (testé). `s.evoBusy` gèle toutes les autres actions du joueur pendant la sauvegarde (sauf `sync`), libéré même en cas d'erreur (`pcall`). |
| Robux | Aucun produit, passe ni invite d'achat (test statique sur `Evolution.lua` et `actions.evolve` ; `ProcessReceipt` ne touche ni `f` ni `evo`). |
| Force | Pv et attaque x1,10 : la forme 2 d'une rareté reste strictement sous la forme 1 de la rareté suivante (1 620 comparaisons + 78 espèces du bestiaire). PvP enregistré et classé en direct : copies `(p, s, m)` sans forme (jamais plus fort). |
| Profil | **v14** (changement voulu). Migration v13 -> v14 idempotente (`evo = {}` s'il manque), `merge` assainit `evo` et `slot.f` (seul `f = 2` sur un pet est gardé). Profil v15 jamais écrasé (testé). `onb` et `showcase` gardés tels quels. **Déployer tous les serveurs ensemble** (même consigne que pendingPick) : un serveur v13 charge un profil v14 sans le sauvegarder. |
| Renaissance | `evo` hors de la liste blanche (4c8bcf9) : le compteur survit ; les formes 2 posées partent avec les emplacements (comme l'XP des pets). Testé. |
| Télémétrie | Aucun événement ajouté (critère « 40 % évoluent en 7 jours » non mesurable tant que l'interface client n'existe pas ; la liste des 16 métriques est fermée et testée). |

**Bilan idée 2 : 0 défaut critique, élevé ou moyen (fonction désactivée, interface client non fournie).**
