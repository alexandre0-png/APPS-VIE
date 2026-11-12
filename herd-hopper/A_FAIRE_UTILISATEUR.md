# À faire par toi (et seulement toi)

Tout le reste est fait dans le dépôt. Ce fichier ne liste que ce qui exige ton compte Roblox, Roblox Studio ou ton identité.
Détail pas à pas : `docs/PUBLICATION.md`. Rien n'a été publié.

## 1. Tester dans Roblox Studio (obligatoire avant de publier)
Le jeu n'a jamais tourné dans Roblox : il est vérifié par simulation, compilation Luau et tests, pas par le moteur.
- [ ] Ouvrir `build/SauteTroupeau.rbxlx` (Fichier > Ouvrir depuis le fichier).
- [ ] Paramètres du jeu > Sécurité : activer « Autoriser l'accès de Studio aux services API » (sauvegarde en test).
- [ ] Paramètres du jeu > Avatar : R15.
- [ ] Test > Clients et serveurs : 2 joueurs. Vérifier dans l'ordre :
  1. l'intro (survol du zoo, touche pour passer) ;
  2. ton zoo devant ta parcelle, la caisse, EXPÉDITION > PARTIR ;
  3. ton cavalier suit bien l'animal, la caméra reste derrière lui (point le plus risqué : soudure sur pièce ancrée) ;
  4. ESPACE saute, le lasso de saut accroche l'animal suivant, le sol est mortel ;
  5. un cœur rose apparaît sur certains animaux : monte-le jusqu'à la barre pleine puis RÉCUPÉRER ;
  6. Q lance le lasso de capture sur un animal à cœur ;
  7. un boss apparaît en fin de zone et te projette en arrière ;
  8. la mort affiche « Continuer » ; les résultats arrivent ; l'or et les animaux sont dans le zoo ;
  9. tactile (émulateur de téléphone) et, si possible, manette.
- [ ] Régler la sensation dans `ReplicatedStorage > Shared > Config` si besoin (portée, vitesses, prix, durées).

## 2. Créer le jeu et la page (Creator Dashboard)
- [ ] Fichier > Publier sur Roblox sous... > nouveau jeu « Saute-Zoo » (texte de la description dans `docs/PUBLICATION.md`).
- [ ] Téléverser l'icône `marketing/icone-experience-512.png` et les 3 vignettes `marketing/vignette-1…`, `-2…`, `-3…`.
- [ ] Remplir le questionnaire de classification (obligatoire avant le mode public).
- [ ] Joueurs max par serveur : 12 à 16.
- [ ] Vérification d'identité / paramètres de paiement Roblox si Roblox les demande pour vendre des objets.

## 3. Créer les achats Robux et copier leurs identifiants
Créer sur le Creator Dashboard (Monétisation), avec les icônes de `marketing/`. Les prix sont des suggestions.

**Game Passes** (identifiants à coller dans `Config.Monetization.GamePasses`, dans cet ordre)
| # | Nom exact | Prix suggéré | Icône | Description |
|---|---|---|---|---|
| 1 `zoo` | Zoo Premium | 399 R$ | `pass-zoo-premium-512.png` | +6 enclos, visiteurs x1,5 et cornes dorées VIP. |
| 2 `gold` | Or x2 | 249 R$ | `pass-or-x2-512.png` | Double l'or gagné à chaque expédition. |
| 3 `life` | Vie supplémentaire | 149 R$ | `pass-vie-supplementaire-512.png` | Une vie de plus à chaque expédition. |
| 4 `lasso` | Lasso doré | 199 R$ | `pass-lasso-dore-512.png` | +2 lassos de capture et une portée plus longue. |

**Produits développeur** (identifiants à coller dans `Config.Monetization.Products`, dans cet ordre)
| # | Clé | Nom exact | Prix suggéré | Icône |
|---|---|---|---|---|
| 1 | `gold_s` | Bourse d'or (2 000) | 49 R$ | `produit-or-2000-512.png` |
| 2 | `gold_m` | Coffre d'or (7 000) | 149 R$ | `produit-or-7000-512.png` |
| 3 | `gold_l` | Trésor d'or (25 000) | 449 R$ | `produit-or-25000-512.png` |
| 4 | `bones_s` | Sac d'os (40) | 59 R$ | `produit-os-40-512.png` |
| 5 | `bones_m` | Caisse d'os (150) | 199 R$ | `produit-os-150-512.png` |
| 6 | `boost` | Boost de zoo x2 (30 min) | 79 R$ | `produit-boost-zoo-512.png` |
| 7 | `revive` | Continuer (1 vie) | 25 R$ | `produit-continuer-512.png` |

- [ ] Ouvrir `Config` dans Studio et remplacer chaque `id = 0` par l'identifiant créé (les 4 passes, puis les 7 produits).
- [ ] Republier. Tant qu'un `id` vaut 0, l'objet affiche « Bientôt ».
- [ ] Faire un petit achat test avant d'ouvrir au public (pièces créditées, reçu rejoué sans doublon, pass actif, « Continuer » après une mort).

## 4. Audio (si tu veux de la musique)
- [ ] Aucune musique n'est fournie (droits d'auteur). Colle des identifiants `rbxassetid://...` de morceaux dont tu as les droits dans `Config.Audio.Music` (lobby, savane, marais, desert, volcan, boss, results). Vide = silence.
- [ ] Les effets utilisent les sons intégrés au client Roblox, non vérifiés : à écouter en test.

## 5. Mise en ligne
- [ ] Repasser le jeu en Public, surveiller la console développeur (F9) le premier jour.
