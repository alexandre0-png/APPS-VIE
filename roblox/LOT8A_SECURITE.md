# Lot 8A : revue QA et sécurité tracée (équilibrage : vol, économie, performance, sons) — 2026-11-28

Périmètre : dispatcher `RAction` (limiteur, liste des actions), `actions.buyEgg`, `buyUp`, `sell`, `sellEgg`, `sellDupes`, achat au tapis (`beltBuy`, `Belt.tryBuy`), vol aux nids et chez les joueurs (`ProximityPromptService` : `Nest`, `Pad`), boucliers, protection débutant, prix (`Config.EGG_PRICE`, `SHOP_MAX_TIER`, `Belt.price`), renaissance. Revue par **lecture du code réel** (`Main.server.lua`, `Belt.lua`, `Config.lua`) + tests lupa existants (`run.luau` : économie, simulation `Economy.lua`, `SimSteal.lua`). **Rien n'a été joué dans Studio ni avec un client modifié réel.**

**Bilan : 1 défaut élevé trouvé et corrigé (renaissance, commit 4c8bcf9), 0 défaut critique.**

| Sujet | Risque | Constat | État |
|---|---|---|---|
| Arguments forgés | rareté, emplacement, clé d'amélioration texte / NaN / décimal | `buyEgg` : entier 1..#TIERS, rareté publiée, `<= SHOP_MAX_TIER` ; `sell*` : `validSlot` puis contenu relu dans le profil ; `buyUp` : clé de `Config.UPGRADES`, niveau max. | OK (tests `run.luau` : noms d'actions et arguments invalides) |
| Prix côté client | Achat à prix réduit | Tous les prix viennent de `Config` côté serveur (`EGG_PRICE`, `Belt.price` = prix x 0,6, `u.cost(l)`) ; pièces relues dans le profil. Exclusif (9) : prix 0 mais jamais en boutique (`SHOP_MAX_TIER` = 6) ni au tapis (poids 0, testé A5). | OK |
| Rafale | Spam d'actions / de prompts | `RAction` : 1 action / 0,08 s par joueur, `pcall` par action ; tapis : anti-rafale 0,25 s + `Belt.tryBuy` (délai d'achat, 1 Légendaire+ par minute, œuf déjà pris = refus). | OK |
| Distance | Achat / vol à distance | Tapis : `BELT_REACH` mesuré sur le serveur ; nid : 18 studs ; base d'un joueur : 20 studs du socle ; personnage vivant, non étourdi. | OK |
| Duplication d'œuf | Vendre un œuf pendant qu'un voleur le porte | Le socle est vidé (`slots[i] = false`) AVANT de remplir le sac du voleur : l'œuf n'existe qu'à un endroit. | OK |
| Vol abusif | Voler un débutant, un œuf protégé | Protection débutant des deux côtés, porte fermée, bouclier d'œuf et délai de grâce relus côté serveur. | OK |
| Renaissance | Perte de possessions payées | `actions.rebirth` reconstruisait un profil neuf et ne recopiait qu'une liste partielle : achats uniques (`once`), passe de combat, calendrier, sac d'œufs, coffre de débordement, cosmétiques, titres, Double chance, temps de jeu (la protection débutant revenait)... perdus. | **Élevé, corrigé** : remise à zéro par liste blanche (`coins`, `up`, `slots`, `equip`, `pendingAway`, `last`), test de bout en bout `rebirth_e2e.luau`. |
| Revente d'œufs gratuits | Ferme à pièces | `sellEgg` rend 25 % du prix boutique ; œufs gratuits (départ, tapis privé, bienvenue) : gain négligeable (11 pièces pour l'œuf de départ), plafonné par leur rythme. | Accepté (non bloquant) |
| Performance | Boucles par image | Revenus et éclosions dans la boucle `Heartbeat` (par joueur, O(emplacements)) ; gardiens bornés (`pendingCharges` <= 64). | OK (pas de mesure Studio) |

## Limites connues
- `actions.sell` ne retire pas l'indice de `d.equip` (contrairement à `sellDupes`) : `rebuildFollowers` ignore les emplacements vides ; sans effet de triche.
- Mesures de performance réelles (FPS mobile) : à faire dans Studio (A_FAIRE §3).
