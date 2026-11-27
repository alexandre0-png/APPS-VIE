# Lot 14 : écarts et décisions d'intégration (classé en direct) — 2026-11-27

Préparation de la gestion : `lots-prep/chipe-14/` (branche `claude/jolly-cannon-w2wx5h`, lecture seule) testée sur le lot 15 (91f6907). Appliquée sur « Lot 13 intégré » (8ef9c43). **Rien n'a été joué dans Studio ni sur le lieu publié.**

## Décisions de la gestion appliquées

- **`Config.PVP_LIVE.enabled = false` PARTOUT** (source, aucun test ni build ne l'active). À n'activer qu'après un test réel à 2 comptes réussi sur le lieu publié (`A_FAIRE_UTILISATEUR.md` §1novies). Tant qu'il est faux : zéro requête MemoryStore de file / bail / comptage (testé dans le vrai `Main`), et le bouton « Combat classé » lance directement le classé enregistré.
- **Seuil `minCCU = 60` joueurs simultanés** : codé et testé avec le faux nuage (59 fermé, 60 ouvert), **jamais testé en production**.
- **Mode serveur `"ranked"`** (pas `"arena"`, qui est déjà la valeur par défaut des parties normales).
- **Un seul joueur arrivé = match annulé sans trophée** (ni gain, ni perte, ni combat du jour consommé), testé dans le vrai `Main` (serveur d'arène factice).
- **`ReserveServerAsync` → `(code, privateServerId)`** : signature supposée ; si seul le code revient, la vérification `PrivateServerId` est sautée (le match et l'appartenance restent vérifiés). À vérifier en Studio.
- **Aucune nouvelle variable locale au niveau racine de `Main`** : `Lot7.Live` (table), comme le patch.

## Fusion avec les lots 12, 13 et 16 (rejets résolus à la main)

| Fichier | Rejet | Résolution |
|---|---|---|
| `Data.lua` | 3 blocs sur 4 (require, commentaire de version, `default()`) : le lot 16 a ajouté des `require` et la version 13, le lot 13 a modifié la ligne `battle` | `require` de `Ranked` ajouté avant `Diag`, commentaire placé avant `VERSION = 13`, `live = Ranked.sanitizeLive(nil, Config.PVP_LIVE)` ajouté à la ligne `battle` du lot 13 (à côté de `duel` et `pve`). Version inchangée (13). |
| `Main.server.lua` | `battleQuit` (le lot 13 y route déjà les duels) | `Lot7.Live.quit(s)` en premier, puis le duel, puis l'ancien abandon. `battleAct` : direct, puis duel, puis tour / classé enregistré / PNJ. |
| `run.luau` | liste des suites du lot 15 modifiée par le lot 12 B | `lot14` et `lot14_e2e` lancés avec les suites du lot 13. |
| `Config.lua` | aucun | `Config.LEAGUES = Config.LEAGUES or {…}` du patch **retiré** (redondant : les ligues du lot 13 ont les mêmes `name` / `min`, lues par `Ranked.league`). |

La boucle « une fois par seconde » du patch (`Lot7.Live.step` + `TeleportInitFailed`) est placée juste après le bloc Duel du lot 13, avant le bloc du lot 15 (même effet que dans la préparation).

## Ajouts d'intégration (au-delà de la préparation)

- **Client** (non fourni par la préparation) : le bouton « 🏆 Combat classé » du panneau Arène envoie `liveQueue` (file fermée = classé enregistré lancé par le serveur) et devient « ✖ Annuler la recherche » pendant l'attente (`liveCancel`). Messages gérés : `liveQueued`, `liveCancel`, `liveFound` (« Adversaire trouvé… téléportation »), `liveFallback` (« Aucun adversaire en ligne de ton niveau. Combattre une équipe enregistrée ? » Oui → `pvpStart`), `liveArena` (attente de l'adversaire), `liveVoid` (« Combat annulé : aucun trophée gagné ni perdu »). Fin de combat en direct : « (forfait) » et « plafond du jour » affichés.
- **Duel local (lot 13) × direct** : un joueur en file classée est « occupé » pour les duels ; aucun duel sur un serveur « ranked ».
- `liveQueue` : un joueur en cours de départ est « occupé ».
- Crochet de test `lot7Hooks.live()` (jamais exposé aux clients).
- `build_place.py` : `Ranked` dans `ReplicatedStorage.Shared`, `PvpLive` dans `ServerScriptService`.

## Écarts de la préparation avec le cahier (repris tels quels)

Module `Ranked.lua` (au lieu de `Matchmaking.lua`) ; déconnexion = forfait immédiat (+ forfait avant 3 tours = 0 trophée pour le gagnant) ; revanche interdite 1 h, entrées du même serveur refusées, plafond 300 trophées gagnés / jour en direct, 15 combats / jour ; pas de carte « colisée seul » pour le serveur d'arène (la carte normale est construite, le combat se joue par l'interface) ; entrée périmée ignorée après 30 s ; `Ranked.seasonReset` fourni mais la remise de saison branchée est celle du lot 13 (`Duel.seasonReset`, même formule).

## Limites connues (de la préparation, inchangées)

- Fermeture du serveur d'arène pendant un combat : aucun forfait appliqué, aucun trophée ne bouge.
- Pendant un déploiement, un serveur ancien efface `battle.live` (compteurs du jour perdus, sans autre effet) : publier les deux lieux ensemble.
- Sur le serveur d'arène, d'autres activités restent techniquement possibles pendant 1 à 3 min (PNJ, tour et classé enregistré bloqués par `pvpPending`).
