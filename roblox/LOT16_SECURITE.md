# Lot 16 : revue de sécurité (économie, reçus, remotes, mémoire, PolicyService) — 2026-11-27

Périmètre : tout ce que le lot 16 ajoute ou modifie : bloc « Lot 16 » de `Main.server.lua` (`Lot7.L16` : boutique, `ProcessReceipt`, passe de combat, offres,
vendeurs, poses, débordement), hooks (éclosion, quêtes, victoires, tour, suiveurs, sac), `Data.lua` (v13), `Telemetry.lua`, `Rules.upPoints`, `Rewards.streakPlan`,
`Client.client.lua`, modules `Shop`, `ShopData`, `ShopInfo`, `Season`, `SeasonData`, `Offers`, `OffersData`, `SellersData`, `Sellers`. Revue par lecture du code +
tests (`tests/lot16.luau`, `tests/lot16_e2e.luau` avec le vrai `Main.server.lua` et `Data.lua`, suites des modules). **Rien n'a été testé dans Studio ni avec de
vrais joueurs malveillants ; aucun achat réel n'a été fait.**

**Bilan : 0 défaut critique ou élevé restant.**

## Failles trouvées et corrigées pendant l'intégration

| # | Faille | Gravité | Correction |
|---|---|---|---|
| 1 | Le client pouvait lancer lui-même `PromptProductPurchase` sans aucun contrôle de place ni de possession (anciennes cartes de la boutique) : paiement puis `NotProcessedYet` répété (argent bloqué, reçus rejoués) quand la base était pleine. | Élevée (économie / confiance) | Le client n'appelle plus jamais l'invite pour la boutique, le calendrier, la série ni la relance : `RAction shopBuy` -> le SERVEUR vérifie (`Shop.canBuy` : id, PolicyService, rareté publiée, possession, mise à niveau, base + sac) et les réserves du moteur, puis lance l'invite. Un reçu obtenu malgré tout (invite lancée par un client modifié) est géré par `ProcessReceipt` seul : débordement, compensation ou refus, jamais de double crédit. Testé de bout en bout. |
| 2 | Œuf payé alors que la base devenait pleine (course) : ancien comportement `NotProcessedYet` indéfini. | Moyenne | Base, puis sac, puis coffre de débordement (`overflow`, sans limite, assaini, repris d'un bouton) : livré tout de suite, jamais perdu. Testé (course, rejeu, reprise). |
| 3 | Complément `SeasonUpgradePlus` (400 R$) payé sans premium : le brouillon donnait « premium + 10 paliers » (valeur 799). | Moyenne (perte de revenu exploitable) | Seul le premium (399) est donné. |
| 4 | `SellersData.layout` (placement des 8 vendeurs) recalculé à chaque construction, plus de 4 millions d'instructions sans rendre la main (garde du runtime factice) : risque de saccade au démarrage et à la reconstruction. | Faible (performance) | Résultat mémorisé par carte (`SellersData.layout` -> `computeLayout`, table à clés faibles) ; `task.wait()` avant la construction ; `Builder.dressDecor` réutilise le même calcul. |
| 5 | Le sac d'œufs de 20 places (passe EggBagPlus) aurait été tronqué à 10 à la relecture du profil (perte d'œufs). | Moyenne (perte) | `Data` assainit jusqu'à `EGG_BAG.sizePlus` (20) ; la place réelle dépend du passe (`L16.bagCfg`). Même principe pour le 4e suiveur du Collectionneur. |
| 6 | Cosmétiques du passe de combat (« s<n>_… ») effacés à la relecture (Data ne gardait que ceux du calendrier). | Moyenne (perte) | Motif `^s%d+_[%w_]+$`, 40 caractères au plus ; testé (migration). |
| 7 | Tickets d'arène : combats en plus mais récompenses toujours limitées aux 10 répétitions du jour (promesse non tenue). | Faible | Les tickets ajoutent aussi des combats récompensés (`dailyRepeats + tickets du jour`). |
| 8 | Double chance : produit à hasard appliqué même si PolicyService passe à « restreint ». | Faible | Le doublement n'est actif que si `restricted == false` (même règle que les passes à hasard). |

## Contrôles en place (vérifiés)

- **Un crédit par reçu** : circuit existant inchangé (`receipts[rid]` + `pendingReceipts`, `PurchaseGranted` seulement après une sauvegarde réussie, second appel concurrent refusé après l'attente de PolicyService). `L16.grant` ne cède jamais la main entre le contrôle et l'écriture. Toute condition qui empêche la livraison (œuf d'une rareté sans espèce, passe avant le début de la saison) est testée AVANT la moindre modification (`NotProcessedYet`, rien n'est changé). Tests : rejeu du même reçu = 1 crédit (œuf, pièces, premium).
- **Plus aucun plafond d'achat**, mais : achats uniques (`once` : Pack de départ, poses ; passes ; premium par saison) refusés avant l'invite et compensés en pièces en cas de course ; Double chance x2 puis 70 points au plus (`Shop.luckTotal`) ; réserves du moteur (corbeau, rattrapages) vérifiées avant l'invite.
- **PolicyService** : tout achat `random` est masqué côté client, refusé avant l'invite (`Shop.canBuy` : restreint ou réponse absente / en échec = refus) et refusé dans `ProcessReceipt` (`Lot7.awaitPolicy`). 21 achats à hasard listés et testés un par un (`tests/lot16.luau`), plus un compte restreint et un compte dont l'appel échoue de bout en bout.
- **Œufs Secret / Exclusif / Divin** : rareté fixe affichée, `random = true`, masqués et refusés tant qu'aucune espèce n'est publiée (`notLive`) ou si PolicyService restreint.
- **Aucune force vendue** : test statique du bloc lot 16 de Main (ni `Battle.STATS`, ni `slot.x`, ni `shield`, ni trophées, ni défense écrits) ; aucune fiche ne vend XP de pet, stats, protection ou trophées. L'XP de saison vient d'événements validés par le serveur (victoires, quêtes, éclosions), plafonnée à 400 par jour.
- **Remotes** : aucune nouvelle RemoteEvent (réponses par `Kiosk`, demandes par `Action` : anti-rafale global 0,08 s + pauses par action : achat 1 s, réclamation 0,25 s, vue 0,5 s, coffre 0,3 s). Entrées validées : clés de catalogue (chaîne <= 40, présente dans `Config.SHOP`), paliers (entier 1..30), piste (« free » / « premium »), pose (entier 0..6 et possédée), drapeaux booléens. Le client n'envoie jamais un montant, une rareté ou une récompense.
- **Vendeurs** : distance mesurée par le serveur sur la position construite (16 studs), liste blanche des 8 actions, pause de 0,8 s par joueur (table à clés faibles, oubliée au départ).
- **Offres à l'écran** : décidées par le serveur (`Offers.pick`), jamais pendant un combat, le château, un œuf porté ; 3 par session, 300 s d'écart, aucune pendant 600 s après un achat ; jamais un achat possédé, sans id, masqué (PolicyService, rareté sans espèce) ni un œuf Secret / Exclusif / Divin. L'achat repasse par `shopBuy` (aucune confiance au client).
- **Mémoire** : `offerState` et `gaps` par joueur vidés à `PlayerRemoving` (`L16.leave`) ; `Sellers.forget` ; boucle des offres sous `pcall` toutes les 20 s ; côté client, l'effet de pose est détruit par `Debris` (1,8 s), une seule carte d'offre (jeton), aucune connexion créée par rendu.
- **Données (v13)** : migration idempotente (relecture testée), anciens profils et champs corrompus assainis (`overflow` : clés 1..10, entiers ; `once` : clés du catalogue `once` ; `emote`, `arenaTk`, `doubleUntil` bornés ; `season` assaini par `Season.migrate`, l'ancien `seasonXp` versé une seule fois). Profil d'une version plus récente (v14) jamais écrasé (garde existante, testée).
- **Télémétrie** : aucune donnée personnelle (identifiant d'entonnoir aléatoire, pas d'UserId), `pcall` sur chaque envoi, <= 1 événement / s / joueur (file de 16), types et étapes en liste blanche.

## Risques acceptés (non critiques)

- **Coffre royal « sans passe » (1 100 R$) payé sans premium** par une invite lancée hors de la boutique (client modifié) : œufs + premium donnés (décision de l'utilisateur, « équivalent plein ») ; un tricheur économise 399 R$. Aucune duplication.
- Les étiquettes de prix des vendeurs sont communes à tous (elles ne tiennent pas compte de PolicyService) ; la boutique, elle, masque les achats à hasard.
- La compensation en pièces d'un achat unique payé deux fois dépend du revenu du joueur (plancher 5 000 pièces).
- Non testé en conditions réelles : invites Roblox, comptes restreints réels, plusieurs serveurs, AnalyticsService.
