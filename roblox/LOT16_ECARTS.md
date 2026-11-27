# Lot 16 : écarts et décisions d'intégration (2026-11-27)

Boutique en 8 catégories, passe de combat de 60 jours, offres à l'écran, 8 vendeurs PNJ, télémétrie I.2. **Rien n'a été joué dans Studio** : vérifié par
`check.py` et les tests lupa (suites `shop`, `season`, `offers`, `sellers`, `lot16`, `lot16_e2e` dans `run.luau`). Revue de sécurité : `LOT16_SECURITE.md`.

## Écarts tranchés (au plus simple et sûr)

| # | Point | Décision |
|---|---|---|
| 1 | `InstantHatch`, `RemoteSteal`, `RemoteStealPack` : « hasard en partie » selon ACHATS_DEFINITIONS | Restent `random = false` (ils ne vendent aucun objet tiré au sort ; leur fiche dit ce qui reste aléatoire). |
| 2 | Tapis doré : 3 s dans le texte, 4 s dans `BELT.golden.interval` ; cumul « jusqu'à 30 min » | Une seule valeur : 4 s (texte corrigé). Durées cumulables sans plafond d'achat : `BELT.golden.maxSeconds` et `SERVER_LUCK.maxSeconds` = garde technique de 30 jours. |
| 3 | Œuf Exclusif : « espèce de l'événement » | Fiche honnête : l'espèce est tirée au sort parmi les espèces Exclusif publiées tant que le lot 11 n'existe pas (texte de `ShopInfo` et de `Shop.eggContentText`). |
| 4 | Coffre royal « sans passe » payé SANS premium (invite lancée hors de la boutique) | Œufs ET premium donnés (décision : équivalent plein). Voir `LOT16_SECURITE.md` (perte de revenu possible de 399 R$ par un tricheur, aucune duplication). |
| 5 | Complément `SeasonUpgradePlus` (400) payé SANS premium | Le premium (399) est donné, jamais plus que le prix payé (pas de « premium + 10 paliers » pour 400). |
| 6 | Débordement | `overflow["rareté"] = n` dans le profil (assaini, sans limite), repris d'un bouton (Bonus > Coffre de débordement : base puis sac). |
| 7 | Plafonds d'achat retirés | Sauvetage de série : plus de limite d'une fois par semaine (`Rewards.streakPlan.canProduct`), proposé seulement quand la série est en danger. Restent des **réserves du moteur** vérifiées AVANT l'invite (pas des plafonds d'achat) : 5 jetons de corbeau au plus, `CALENDAR.catchupMax` rattrapages ; si une course les dépasse après paiement, le reçu reste « NotProcessedYet » (livré plus tard, rien n'est perdu), comme avant. |
| 8 | Pack de départ, poses, premium déjà possédés (course) | Compensation en pièces : max(`COIN_PACK_MIN`, revenu x prix x `PRICING_REF.secondsPerRobux`). |
| 9 | Pack de départ | `random = true` (catalogue ShopData : il contient 3 œufs) : masqué / refusé pour un compte restreint. |
| 10 | Avant le 1er décembre 2026 (début de la saison 1) | Tout ce qui contient le passe (3 produits de saison, Coffres royaux) est masqué et refusé ; l'XP gagnée d'ici là est gardée et comptera pour la saison 1. Date à confirmer (`SeasonData.SEASON.start`). |
| 11 | Espèce Exclusif de saison (palier 30 premium) | Aucune n'existe dans `Config.PETS` : Season donne le trophée cosmétique de repli. Si l'espèce existe mais qu'aucune place n'est libre, un œuf de sa rareté va au débordement. |
| 12 | Poses de victoire | Effet visuel PROVISOIRE (emoji qui monte au-dessus du personnage + petit saut) : de vraies animations Roblox (`Animation` id) restent à créer ; la fiche dit « purement visuelle ». |
| 13 | Vendeurs : rayon 14 à 22 studs | Accepté : 2 vendeurs à 14-22 studs, 6 plus loin (24 à 42). Leurs emprises sont exclues du décor de carte (`Builder.dressDecor` -> `Decor` `deps.occupied`). |
| 14 | Prix affichés sur les vendeurs | Seuls les achats à id réel ET de rareté publiée comptent (les œufs Peu commun / Secret / Exclusif / Divin sans espèce sont exclus). La ligne est la même pour tous (elle ne tient pas compte de PolicyService, la boutique oui). |
| 15 | Offres à l'écran | Décidées par le serveur (`Offers.pick` : événement + essai toutes les 20 s), affichées par le client seulement quand aucun menu n'est ouvert ; l'ancienne offre locale (`Config.boostOffer`) est retirée. |
| 16 | Télémétrie | 6 types : custom, economy, funnel (« Shop » : vue, fiche, invite, reçu), onboarding (arrivée, 1re éclosion, 1re victoire, 1re vue de la boutique), progression (palier de saison), version (`version_<Config.BUILD>`) ; même file <= 1 événement / s / joueur. |
| 17 | Collectionneur | 4 pets suiveurs ; « indice de silhouette » = initiale et longueur du nom dans la collection ; le cadre doré des compteurs n'est pas fait. |

## Écarts de rythme du lot 9 (branche worktree-agent-a3b4cc56539aa6ef0)

Voir la section « Rythme » ajoutée à la fin de la mission (ci-dessous).
