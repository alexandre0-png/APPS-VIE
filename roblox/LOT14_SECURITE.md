# Lot 14 : revue de sécurité courte (classé en direct) — 2026-11-27

Périmètre : actions `liveQueue`, `liveCancel`, routage `battleAct` / `battleQuit`, arrivée sur un serveur `ranked` (`arenaJoin`), départ (`onLeave` avant la sauvegarde), transport `PvpLive` (MemoryStore, `ReserveServerAsync`, `TeleportAsync`), assainissement `battle.live`. Revue par lecture du code + tests lupa (`lot14.luau` : règles pures et faux nuage multi-serveurs ; `lot14_e2e.luau` : vrai `Main.server.lua` + `Data.lua`). **Rien n'a été testé en ligne, dans Studio ni avec un client modifié.** La fonction est **désactivée** (`Config.PVP_LIVE.enabled = false`).

**Bilan : 0 défaut critique ou élevé.**

| Sujet | Risque | État |
|---|---|---|
| Interrupteur | Activation accidentelle, coût MemoryStore | `enabled = false` dans la source ; désactivé = aucune requête de file, bail ni comptage (testé dans le vrai `Main`) ; même activé, file fermée sous 60 joueurs simultanés ou si le comptage est absent / périmé. |
| TeleportData forgé | Rejoindre une arène, voler une place | Le serveur d'arène ne croit que l'enregistrement `PvpMatch_v1` (match non expiré, membre, `PrivateServerId` si renvoyé) ; intrus renvoyé chez lui (testé). Le mode `ranked` n'est pris que par le premier arrivant. |
| Actions de combat | Jouer pour l'autre, actions multiples | Côté pris dans la session serveur (`s.liveSide`), action analysée par `Ranked.parseAction` et validée par le moteur ; action d'un tiers ignorée (test du faux nuage). |
| Trophées | Nourrissage entre complices, farm | Forfait avant 3 tours = 0 pour le gagnant (testé dans le vrai `Main` : 0 / -15) ; revanche interdite 1 h ; même serveur refusé ; serveur partagé < 10 min refusé ; plafond 300 gagnés / jour ; 15 combats / jour ; un seul arrivé = annulé sans trophée. Aucun produit, pass ou boost (test : aucun Robux dans `Ranked` / `PvpLive`). |
| Sauvegarde / téléportation | Perte de progression, duplication | Sauvegarde TERMINÉE avant tout téléport (échec = pas de téléport, remise en file) ; profil `noSave` jamais écrit ; forfait écrit dans le profil AVANT la sauvegarde de départ. |
| Pannes MemoryStore | Erreur qui remonte dans `Main`, double match | Chaque appel dans un `pcall` ; bail d'apparieur par `UpdateAsync` ; réservation d'entrée unique ; test 8 serveurs / 40 joueurs / 20 % de pannes et lectures périmées : jamais deux leaders, aucun joueur dans deux arènes. |
| Fuites | Tables par joueur | `L.queued` purgé quand la session disparaît ; `peersSeen` purgé après 10 min ; retours gérés par `L.home` (tentatives bornées, puis expulsion propre « progression sauvegardée »). |
| Données | Profil corrompu | `Ranked.sanitizeLive` (entiers bornés, 20 adversaires récents au plus), sans changement de version. |
| Interaction avec le lot 13 | Duel pendant la file ou dans l'arène | Joueur en file = occupé pour les duels ; serveur `ranked` = aucun duel (testé). |

## Hypothèses à vérifier (non testables ici)

- `TeleportService:ReserveServerAsync` renvoie `(code, privateServerId)` (sinon la vérification `PrivateServerId` est sautée, le reste tient).
- Quotas MemoryStore réels sous charge (estimation < 15 % de la limite à 60 et 1 000 joueurs).
