# Achats intégrés à créer (Creator Hub > Monetization)

Tous les prix sont fixes, aucun contenu aléatoire. Le jeu fonctionne à 100 % sans acheter.
Les IDs obtenus se collent dans `src/ReplicatedStorage/Shared/MonetizationIds.lua` (ou via `tools/publish.py --setup-monetization`, best effort).

## Developer Products (consommables)
| Clé (MonetizationIds) | Nom | Description | Prix |
|---|---|---|---|
| cash_s | Sac de billets | 5 000 $ immédiatement | 49 R$ |
| cash_m | Mallette | 30 000 $ immédiatement | 249 R$ |
| cash_l | Coffre-fort | 150 000 $ immédiatement | 999 R$ |

## Game Passes (permanents)
| Clé | Nom | Effet (implémenté) | Prix |
|---|---|---|---|
| VIP | VIP CITY RUSH | Gains x2 (argent), voiture Phantom Doré, badge VIP | 399 R$ |
| BOOST | Nitro Infini+ | Nitro qui s'épuise 2x moins vite, recharge 2x plus rapide | 149 R$ |

## Images
- Icône : `images/icon_512.png` (512x512)
- Vignettes : `images/thumbnail_*_1920x1080.png` (illustrations de présentation ; à remplacer idéalement par de vraies captures Studio)
