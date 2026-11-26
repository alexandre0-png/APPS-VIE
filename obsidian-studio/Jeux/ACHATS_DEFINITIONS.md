---
type: jeux
---
# Chipe-Œufs : définitions de tous les achats (kiosque et offres à l'écran)

Fiche destinée à être affichée dans le jeu quand le joueur clique sur un achat (kiosque boutique + offres à l'écran). Elle suit le code actuel (`roblox/src/ReplicatedStorage/Config.lua`, `PRODUCTS`, `PASSES`, `OFFERS`, `eggContentText`), `PUBLICATION.md`, `LOTS_9_PLUS.md` (H, G.5), `Assets/Assets-crees.md` (ids, créés le 2026-11-26 pour le lot 16).

Légende : « titre » 28 caractères au plus ; « définition » 90 caractères au plus. Colonne « source » des conditions d'affichage : `code` (déjà dans Config.lua), `spec` (LOTS_9_PLUS.md), `proposé` (à valider). Palier : 1 = 15 à 49 R$, 2 = 79 à 199 R$, 3 = 249 à 499 R$, 4 = 799 R$ et plus.

## Règles communes à toutes les fiches

1. **Aucune fausse urgence.** Pas de compte à rebours sur une offre permanente, pas de « dernière chance », pas de stock fictif. Une durée n'est affichée que si elle fait partie de l'achat (« 10 min de bonus », fenêtre réelle de 20 s de l'écran de défaite).
2. **Aucune promesse de gain.** On écrit ce qu'on reçoit, jamais « tu vas obtenir ». Aucun achat ne donne de force en combat, de niveau ou d'XP de pet, ni de protection contre le vol.
3. **Hasard : probabilités avant l'achat.** Tout achat « aléatoire » affiche, avant le bouton d'achat : la rareté fixe, la table de contenu (`Config.eggContentText`, ex. « Rare : 95 % Rare, 5 % Épique »), les tailles (Mini 20 %, Normal 62 %, Grand 14 %, Géant 3,5 %, Colossal 0,5 %) et les mutations (aucune 81,9 %, Doré 9 %, Néon 5 %, Arc-en-ciel 2,6 %, Alien 1,4 %, Céleste 0,1 %), tirées de `Config`. Ces achats sont masqués et refusés côté serveur pour les comptes à objets aléatoires payants restreints (PolicyService).
4. **La rareté d'un œuf payant est FIXE** et écrite sur la fiche. Seuls l'espèce (dans la rareté), la taille et la mutation sont tirées au sort.
5. **On ne paie jamais deux fois la même chose.** Un passe ou un achat unique déjà possédé est grisé (« Déjà à toi ») et ne peut pas être payé. Compléments : **SeasonUpgradePlus** (3736704000) n'est proposé qu'à qui a déjà le passe de combat premium ; **BundleRoyalNoPass** (3736704205) n'est proposé qu'à qui a déjà le passe premium. Sinon, ce sont « Passe de combat + 10 paliers » et « Coffre royal » qui s'affichent.
6. **Pas de limite d'achat, sauf « achat unique »** (passes permanents, Pack de départ, poses de victoire, passe de combat une fois par saison). Seule limite de puissance affichée : Double chance, 70 points de chance au total. Un achat d'œuf est refusé AVANT paiement si la base ou le sac est plein (« fais de la place ») ; si une course survient après paiement, l'œuf va dans le coffre de débordement : rien n'est perdu. Sans limite d'achat, l'écran d'un œuf aléatoire affiche toujours la table de probabilités et le prix clairement, et aucune offre n'apparaît juste après un achat répété.
7. Un achat dont l'id n'est pas renseigné reste caché (rien ne s'affiche à l'écran).

## Tableau récapitulatif (catégories dans l'ordre d'affichage, prix croissant dans chacune)

| Catégorie | Ordre | Clé | Type | Id | Prix R$ | Titre | Aléatoire ? | Limite d'achat | Palier |
|---|---|---|---|---|---|---|---|---|---|
| Œufs | 1 | `EggR2` | produit | 3736703563 | 15 | Œuf Peu commun | oui | aucune limite | 1 |
| Œufs | 2 | `EggR3` | produit | 3736703571 | 25 | Œuf Rare | oui | aucune limite | 1 |
| Œufs | 3 | `EggR4` | produit | 3736703588 | 49 | Œuf Épique | oui | aucune limite | 1 |
| Œufs | 4 | `EggR5` | produit | 3736703667 | 99 | Œuf Légendaire | oui | aucune limite | 2 |
| Œufs | 5 | `ExclusiveEgg` | produit | 3734229320 | 249 | Œuf Mythique | oui | aucune limite | 3 |
| Œufs | 6 | `EggR7` | produit | 3736703695 | 799 | Œuf Ultra Rare | oui | aucune limite | 4 |
| Œufs | 7 | `EggSecret` | produit | 3736452048 | 1499 | Œuf Secret | oui | aucune limite | 4 |
| Œufs | 8 | `EggExclusive` | produit | 3736452061 | 3499 | Œuf Exclusif | oui | aucune limite | 4 |
| Œufs | 9 | `EggDivine` | produit | 3736452072 | 6999 | Œuf Divin | oui | aucune limite | 4 |
| Chance & boosts | 1 | `LuckPotionMini` | produit | 3736703579 | 29 | Potion express | oui | aucune limite | 1 |
| Chance & boosts | 2 | `LuckPotion` | produit | 3734229337 | 99 | Potion de chance | oui | aucune limite | 2 |
| Chance & boosts | 3 | `GoldenBelt` | produit | 3736121227 | 99 | Tapis doré | oui | aucune limite | 2 |
| Chance & boosts | 4 | `ServerLuck` | produit | 3736121217 | 129 | Pluie de chance pour tous | oui | aucune limite | 2 |
| Chance & boosts | 5 | `DoubleLuck` | produit | 3736703673 | 149 | Double chance | oui | plafond de 70 points (puissance) | 2 |
| Chance & boosts | 6 | `Lucky` | passe | 2093447290 | 149 | Chance +10 % | oui | achat unique | 2 |
| Chance & boosts | 7 | `Fast` | passe | 2097173053 | 149 | Éclosion rapide | non | achat unique | 2 |
| Chance & boosts | 8 | `Speed` | passe | 2092253306 | 149 | Vitesse +20 % | non | achat unique | 2 |
| Chance & boosts | 9 | `PrivateBelt` | passe | 2098265697 | 299 | Tapis privé | oui | achat unique | 3 |
| Chance & boosts | 10 | `Lucky2` | passe | 2102045961 | 349 | Chance +10 % II | oui | achat unique | 3 |
| Pièces | 1 | `CoinPackS` | produit | 3736703557 | 19 | Petit sac de pièces | non | aucune limite | 1 |
| Pièces | 2 | `CoinPack` | produit | 3734229339 | 99 | Sac de pièces | non | aucune limite | 2 |
| Pièces | 3 | `Coins2x` | passe | 2093291260 | 199 | Revenus x2 | non | achat unique | 2 |
| Base & confort | 1 | `StreakRestore` | produit | 3736703610 | 29 | Sauvetage de série | non | aucune limite | 1 |
| Base & confort | 2 | `CalendarCatchup` | produit | 3736695392 | 29 | Rattrapage du calendrier | non | aucune limite | 1 |
| Base & confort | 3 | `InstantHatch` | produit | 3734229329 | 49 | Éclosion instantanée | oui | aucune limite | 1 |
| Base & confort | 4 | `EggBagPlus` | passe | 2099454839 | 149 | Sac d'œufs +10 | non | achat unique | 2 |
| Base & confort | 5 | `ExtraSlots` | passe | 2098181699 | 249 | +4 emplacements | non | achat unique (20 emplacements au maximum) | 3 |
| Base & confort | 6 | `Collector` | passe | 2099556764 | 249 | Collectionneur | non | achat unique | 3 |
| Base & confort | 7 | `VipBase` | passe | 2094209172 | 399 | Base VIP | non | achat unique | 3 |
| Combat & vol | 1 | `ArenaTickets` | produit | 3736703606 | 19 | Ticket d'arène | non | aucune limite | 1 |
| Combat & vol | 2 | `Revive` | produit | 3734229323 | 49 | Relance immédiate | non | aucune limite | 1 |
| Combat & vol | 3 | `RemoteSteal` | produit | 3736121232 | 79 | Corbeau chipeur | oui | aucune limite | 2 |
| Combat & vol | 4 | `RemoteStealPack` | produit | 3736121238 | 199 | 3 Corbeaux chipeurs | oui | aucune limite | 2 |
| Passe de combat | 1 | `SeasonPremium` | produit | 3736703683 | 399 | Passe de combat premium | non | achat unique par saison | 3 |
| Passe de combat | 2 | `SeasonUpgradePlus` | produit | 3736704000 | 400 | Passe de combat + (suite) | non | achat unique par saison | 3 |
| Passe de combat | 3 | `SeasonPremiumPlus` | produit | 3736703689 | 799 | Passe de combat + 10 paliers | non | achat unique par saison | 4 |
| Packs | 1 | `StarterPack` | produit | 3734229313 | 99 | Pack de départ | oui | achat unique | 2 |
| Packs | 2 | `BundleLegend` | produit | 3736703706 | 999 | Pack Légende | oui | aucune limite | 4 |
| Packs | 3 | `BundleRoyalNoPass` | produit | 3736704205 | 1100 | Coffre royal sans passe | oui | aucune limite | 4 |
| Packs | 4 | `BundleRoyal` | produit | 3736703714 | 1499 | Coffre royal | oui | aucune limite | 4 |
| Cosmétiques (poses de victoire) | 1 | `EmoteVictory1` | produit | 3736703619 | 39 | Pose de victoire 1 | non | achat unique | 1 |
| Cosmétiques (poses de victoire) | 2 | `EmoteVictory2` | produit | 3736703629 | 39 | Pose de victoire 2 | non | achat unique | 1 |
| Cosmétiques (poses de victoire) | 3 | `EmoteVictory3` | produit | 3736703634 | 39 | Pose de victoire 3 | non | achat unique | 1 |
| Cosmétiques (poses de victoire) | 4 | `EmoteVictory4` | produit | 3736703641 | 39 | Pose de victoire 4 | non | achat unique | 1 |
| Cosmétiques (poses de victoire) | 5 | `EmoteVictory5` | produit | 3736703649 | 39 | Pose de victoire 5 | non | achat unique | 1 |
| Cosmétiques (poses de victoire) | 6 | `EmoteVictory6` | produit | 3736703657 | 39 | Pose de victoire 6 | non | achat unique | 1 |

Écarts connus entre sources : Pack de départ 99 dans le code (49 en spec H.2) ; Œuf Mythique 249 dans le code (199 en spec) ; Tapis doré 3 s dans le code (4 s dans une note) ; Tapis privé 2 min dans le code (3 min dans une note). Les prix des 7 passes anciens sont les prix suggérés de `PUBLICATION.md` (le code ne porte pas de prix de passe).

## 1. Œufs

### 1.1 Œuf Peu commun (`EggR2`)
- **Clé / type / id / prix** : `EggR2` / produit / 3736703563 / 15 R$ (palier 1)
- **Titre court** : Œuf Peu commun
- **Définition** : Un œuf Peu commun posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.
- **Détail** : Contenu sans bonus : 95 % Peu commun, 5 % Rare (les bonus de chance actifs changent cette part, l'écran affiche la part exacte). Tailles et mutations tirées au sort avec les tables du menu Plus. Il faut une place libre dans ta base ou ton sac : sinon l'achat est refusé AVANT paiement (« fais de la place »). Si une course survient après paiement, l'œuf va dans le coffre de débordement, jamais perdu.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol ; un pet vaut pareil, acheté ou trouvé
- **Accès direct à l'écran** : Kiosque seulement (source : proposé)

### 1.2 Œuf Rare (`EggR3`)
- **Clé / type / id / prix** : `EggR3` / produit / 3736703571 / 25 R$ (palier 1)
- **Titre court** : Œuf Rare
- **Définition** : Un œuf Rare posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.
- **Détail** : Contenu sans bonus : 95 % Rare, 5 % Épique (les bonus de chance actifs changent cette part, l'écran affiche la part exacte). Tailles et mutations tirées au sort avec les tables du menu Plus. Il faut une place libre dans ta base ou ton sac : sinon l'achat est refusé AVANT paiement (« fais de la place »). Si une course survient après paiement, l'œuf va dans le coffre de débordement, jamais perdu.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol ; un pet vaut pareil, acheté ou trouvé
- **Accès direct à l'écran** : Kiosque seulement (source : proposé)

### 1.3 Œuf Épique (`EggR4`)
- **Clé / type / id / prix** : `EggR4` / produit / 3736703588 / 49 R$ (palier 1)
- **Titre court** : Œuf Épique
- **Définition** : Un œuf Épique posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.
- **Détail** : Contenu sans bonus : 95 % Épique, 5 % Légendaire (les bonus de chance actifs changent cette part, l'écran affiche la part exacte). Tailles et mutations tirées au sort avec les tables du menu Plus. Il faut une place libre dans ta base ou ton sac : sinon l'achat est refusé AVANT paiement (« fais de la place »). Si une course survient après paiement, l'œuf va dans le coffre de débordement, jamais perdu.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol ; un pet vaut pareil, acheté ou trouvé
- **Accès direct à l'écran** : Kiosque seulement (source : proposé)

### 1.4 Œuf Légendaire (`EggR5`)
- **Clé / type / id / prix** : `EggR5` / produit / 3736703667 / 99 R$ (palier 2)
- **Titre court** : Œuf Légendaire
- **Définition** : Un œuf Légendaire posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.
- **Détail** : Contenu sans bonus : 95 % Légendaire, 5 % Mythique (les bonus de chance actifs changent cette part, l'écran affiche la part exacte). Tailles et mutations tirées au sort avec les tables du menu Plus. Il faut une place libre dans ta base ou ton sac : sinon l'achat est refusé AVANT paiement (« fais de la place »). Si une course survient après paiement, l'œuf va dans le coffre de débordement, jamais perdu.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol ; un pet vaut pareil, acheté ou trouvé
- **Accès direct à l'écran** : Kiosque seulement (source : proposé)

### 1.5 Œuf Mythique (`ExclusiveEgg`)
- **Clé / type / id / prix** : `ExclusiveEgg` / produit / 3734229320 / 249 R$ (palier 3)
- **Titre court** : Œuf Mythique
- **Définition** : Un œuf Mythique posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.
- **Détail** : Contenu sans bonus : 95 % Mythique, 5 % Ultra Rare (les bonus de chance actifs changent cette part, l'écran affiche la part exacte). Tailles et mutations tirées au sort avec les tables du menu Plus. Il faut une place libre dans ta base ou ton sac : sinon l'achat est refusé AVANT paiement (« fais de la place »). Si une course survient après paiement, l'œuf va dans le coffre de débordement, jamais perdu. Ex-« Œuf exclusif Mythique », à ne pas confondre avec la rareté Exclusif.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol ; un pet vaut pareil, acheté ou trouvé
- **Accès direct à l'écran** : Kiosque seulement (jamais en offre à l'écran) (source : code)

### 1.6 Œuf Ultra Rare (`EggR7`)
- **Clé / type / id / prix** : `EggR7` / produit / 3736703695 / 799 R$ (palier 4)
- **Titre court** : Œuf Ultra Rare
- **Définition** : Un œuf Ultra Rare posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.
- **Détail** : Contenu : 100 % Ultra Rare (rareté fixe, pas d'amélioration possible). Tailles et mutations tirées au sort avec les tables du menu Plus. Il faut une place libre dans ta base ou ton sac : sinon l'achat est refusé AVANT paiement (« fais de la place »). Si une course survient après paiement, l'œuf va dans le coffre de débordement, jamais perdu.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol ; un pet vaut pareil, acheté ou trouvé
- **Accès direct à l'écran** : Kiosque seulement (jamais en offre à l'écran) (source : proposé)

### 1.7 Œuf Secret (`EggSecret`)
- **Clé / type / id / prix** : `EggSecret` / produit / 3736452048 / 1499 R$ (palier 4)
- **Titre court** : Œuf Secret
- **Définition** : Un œuf Secret posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.
- **Détail** : Contenu : 100 % Secret (5 espèces possibles, chacune 20 %). Taille et mutation tirées au sort (tables du menu Plus). Il faut une place libre : sinon l'achat est refusé avant paiement ; un débordement après paiement va dans le coffre de débordement, rien n'est perdu. Masqué tant qu'aucune espèce Secret n'est publiée.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Kiosque seulement (jamais en offre à l'écran) (source : code)

### 1.8 Œuf Exclusif (`EggExclusive`)
- **Clé / type / id / prix** : `EggExclusive` / produit / 3736452061 / 3499 R$ (palier 4)
- **Titre court** : Œuf Exclusif
- **Définition** : Un œuf Exclusif posé dans ta base : l'espèce est celle de l'événement en cours.
- **Détail** : Contenu : 100 % Exclusif ; l'espèce est celle de l'événement du moment (affichée), donc seules la taille et la mutation sont tirées au sort. Il faut une place libre : sinon l'achat est refusé avant paiement ; un débordement après paiement va dans le coffre de débordement, rien n'est perdu.
- **Aléatoire ?** : oui, en partie : la taille et la mutation (tables affichées) ; la rareté ET l'espèce de l'événement sont fixes et affichées
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol ; il rapporte moins qu'un Secret
- **Accès direct à l'écran** : Kiosque seulement (jamais en offre à l'écran) (source : code)

### 1.9 Œuf Divin (`EggDivine`)
- **Clé / type / id / prix** : `EggDivine` / produit / 3736452072 / 6999 R$ (palier 4)
- **Titre court** : Œuf Divin
- **Définition** : Un œuf Divin posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.
- **Détail** : Contenu : 100 % Divin (4 espèces possibles, chacune 25 %). Taille et mutation tirées au sort. Il faut une place libre : sinon l'achat est refusé avant paiement ; un débordement après paiement va dans le coffre de débordement, rien n'est perdu. Masqué tant qu'aucune espèce Divin n'est publiée.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Kiosque seulement (jamais en offre à l'écran) (source : code)

## 2. Chance & boosts

### 2.1 Potion express (`LuckPotionMini`)
- **Clé / type / id / prix** : `LuckPotionMini` / produit / 3736703579 / 29 R$ (palier 1)
- **Titre court** : Potion express
- **Définition** : +25 points de chance d'avoir un pet de rareté au-dessus, pendant 5 minutes.
- **Détail** : Comme la Potion de chance mais seulement 5 minutes, pour un petit prix. La chance d'amélioration passe de 5 % à 30 % pendant ce temps (70 % au maximum). Chiffres affichés avant l'achat.
- **Aléatoire ?** : oui, en partie : le bonus est fixe et affiché ; ce qui sort de chaque éclosion reste aléatoire
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne garantit aucun pet rare et ne donne aucune force
- **Accès direct à l'écran** : Kiosque seulement (source : spec H.2)

### 2.2 Potion de chance (`LuckPotion`)
- **Clé / type / id / prix** : `LuckPotion` / produit / 3734229337 / 99 R$ (palier 2)
- **Titre court** : Potion de chance
- **Définition** : +25 points de chance d'avoir un pet de rareté au-dessus, pendant 15 minutes.
- **Détail** : Pendant 15 min, la chance d'amélioration d'un cran passe de 5 % à 30 % (si tu n'as pas d'autre bonus). Jamais de rétrogradation. Les chiffres exacts sont affichés avant l'achat.
- **Aléatoire ?** : oui, en partie : le bonus est fixe et affiché ; ce qui sort de chaque éclosion reste aléatoire (table affichée)
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne garantit aucun pet rare et ne donne aucune force
- **Accès direct à l'écran** : Kiosque seulement (source : code)

### 2.3 Tapis doré (`GoldenBelt`)
- **Clé / type / id / prix** : `GoldenBelt` / produit / 3736121227 / 99 R$ (palier 2)
- **Titre court** : Tapis doré
- **Définition** : 10 min : le tapis du marché donne des œufs plus vite et de meilleure rareté, pour tous.
- **Détail** : Pendant 10 min, un œuf toutes les 3 s au lieu de 5, avec la table « dorée » (affichée sur le tapis). Profite à tout le serveur. Durées cumulables. Certaines notes de publication parlent de 4 s : la valeur du code est 3 s.
- **Aléatoire ?** : oui : la rareté de chaque œuf du tapis est tirée au sort avec la table dorée, affichée avant l'achat et sur le tapis
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Kiosque seulement (source : code)

### 2.4 Pluie de chance pour tous (`ServerLuck`)
- **Clé / type / id / prix** : `ServerLuck` / produit / 3736121217 / 129 R$ (palier 2)
- **Titre court** : Pluie de chance pour tous
- **Définition** : Pendant 10 min, tout le serveur gagne +5 points de chance d'amélioration.
- **Détail** : Le bonus profite à tous les joueurs du serveur, pas seulement à toi (ton nom est remercié). Il ne dure que 10 minutes, le temps réel affiché est la durée du bonus, pas une pression pour acheter.
- **Aléatoire ?** : oui, en partie : le bonus est fixe et affiché ; ce qui sort de chaque éclosion reste aléatoire
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne garantit aucun pet rare et ne donne aucune force
- **Accès direct à l'écran** : Kiosque seulement (source : code)

### 2.5 Double chance (`DoubleLuck`)
- **Clé / type / id / prix** : `DoubleLuck` / produit / 3736703673 / 149 R$ (palier 2)
- **Titre court** : Double chance
- **Définition** : Pendant 30 minutes, tes points de chance d'amélioration comptent double.
- **Détail** : Les points de chance (base, Trèfle, passes, potion) sont multipliés par 2 pendant 30 min, plafond de 70 points. Exemple : 5 points deviennent 10, et 15 deviennent 30. Les durées s'ajoutent ; seule limite : 70 points de chance au total.
- **Aléatoire ?** : oui, en partie : le bonus est fixe et affiché ; ce qui sort de chaque éclosion reste aléatoire
- **Limite d'achat** : plafond de 70 points (puissance)
- **Ne fait PAS** : ne garantit aucun pet rare et ne donne aucune force
- **Accès direct à l'écran** : Juste après ta première éclosion Légendaire (source : spec H.3)

### 2.6 Chance +10 % (`Lucky`)
- **Clé / type / id / prix** : `Lucky` / passe / 2093447290 / 149 R$ (palier 2)
- **Titre court** : Chance +10 %
- **Définition** : +10 points de chance d'avoir un pet de rareté au-dessus, pour toujours.
- **Détail** : La chance d'amélioration d'un cran passe de 5 % à 15 % (70 % au maximum avec tous les bonus). Les chiffres sont affichés avant l'achat. Jamais de rétrogradation.
- **Aléatoire ?** : oui, en partie : le bonus est fixe et affiché ; ce qui sort de chaque éclosion reste aléatoire
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne garantit aucun pet rare et ne donne aucune force
- **Accès direct à l'écran** : Juste après ta première éclosion d'un pet Rare ou mieux (source : code)
- **Voir aussi** : Chance +10 % II (même catégorie)

### 2.7 Éclosion rapide (`Fast`)
- **Clé / type / id / prix** : `Fast` / passe / 2097173053 / 149 R$ (palier 2)
- **Titre court** : Éclosion rapide
- **Définition** : Tes œufs éclosent 25 % plus vite, pour toujours.
- **Détail** : Réduit le temps d'éclosion de 25 %, à vie. Ne change ni la rareté ni le contenu des œufs.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force en combat et ne change pas ce qui sort des œufs
- **Accès direct à l'écran** : Quand 3 œufs ou plus incubent en même temps (source : code)

### 2.8 Vitesse +20 % (`Speed`)
- **Clé / type / id / prix** : `Speed` / passe / 2092253306 / 149 R$ (palier 2)
- **Titre court** : Vitesse +20 %
- **Définition** : Tu cours 20 % plus vite, pour toujours.
- **Détail** : Ta vitesse de course est multipliée par 1,2, à vie. Elle ne rend pas le vol automatique : les gardiens et les autres joueurs restent là.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne pas de force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Après un vol raté (rattrapé par un gardien) (source : code)

### 2.9 Tapis privé (`PrivateBelt`)
- **Clé / type / id / prix** : `PrivateBelt` / passe / 2098265697 / 299 R$ (palier 3)
- **Titre court** : Tapis privé
- **Définition** : Un petit tapis dans ta base : un œuf gratuit toutes les 2 min quand tu joues.
- **Détail** : Un œuf gratuit toutes les 2 min tant que tu joues, 3 en attente au plus. La rareté de chaque œuf est tirée au sort avec la table standard du tapis, affichée avant l'achat (la liste exacte est sur le tapis). Une ancienne fiche dit 3 min : le code dit 2.
- **Aléatoire ?** : oui : la rareté de chaque œuf gratuit est tirée au sort (table affichée) ; aucune garantie
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Après 10 œufs pris au tapis du marché (source : code)
- **Voir aussi** : Œufs (le tapis donne des œufs)

### 2.10 Chance +10 % II (`Lucky2`)
- **Clé / type / id / prix** : `Lucky2` / passe / 2102045961 / 349 R$ (palier 3)
- **Titre court** : Chance +10 % II
- **Définition** : +10 points de chance d'avoir un pet de rareté au-dessus, en plus de Chance +10 %.
- **Détail** : S'ajoute à Chance +10 % : la chance d'amélioration de base passe de 5 % à 25 % avec les deux (70 % au maximum avec tous les bonus). Chiffres affichés avant l'achat.
- **Aléatoire ?** : oui, en partie : le bonus est fixe et affiché ; ce qui sort de chaque éclosion reste aléatoire
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne garantit aucun pet rare et ne donne aucune force
- **Accès direct à l'écran** : Kiosque seulement (source : spec H.3)
- **Voir aussi** : Chance +10 %

## 3. Pièces

### 3.1 Petit sac de pièces (`CoinPackS`)
- **Clé / type / id / prix** : `CoinPackS` / produit / 3736703557 / 19 R$ (palier 1)
- **Titre court** : Petit sac de pièces
- **Définition** : Reçois les revenus de 5 minutes de jeu (au moins 1 000 pièces).
- **Détail** : Une somme de pièces égale à 5 min de tes revenus, minimum 1 000. Ce sont des pièces, pas des pets.
- **Aléatoire ?** : non
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucun pet et aucune force
- **Accès direct à l'écran** : Quand il te manque des pièces pour un œuf du marché (source : spec H.2)

### 3.2 Sac de pièces (`CoinPack`)
- **Clé / type / id / prix** : `CoinPack` / produit / 3734229339 / 99 R$ (palier 2)
- **Titre court** : Sac de pièces
- **Définition** : Reçois les revenus de 20 minutes de jeu (au moins 5 000 pièces).
- **Détail** : Une somme égale à 20 min de tes revenus, minimum 5 000 pièces. Ce n'est pas une pièce de pet, et les pièces ne s'achètent pas à l'infini : rien n'est promis de plus.
- **Aléatoire ?** : non
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucun pet et aucune force
- **Accès direct à l'écran** : Kiosque seulement (source : code)

### 3.3 Revenus x2 (`Coins2x`)
- **Clé / type / id / prix** : `Coins2x` / passe / 2093291260 / 199 R$ (palier 2)
- **Titre court** : Revenus x2
- **Définition** : Tes pets rapportent deux fois plus de pièces, pour toujours.
- **Détail** : Double tous tes revenus de pièces, à vie, une seule fois pour tout le compte. Le prix est celui suggéré dans PUBLICATION.md.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force en combat, ne donne pas de pets et ne protège pas du vol
- **Accès direct à l'écran** : Quand tu atteins un palier de pièces (palier de jeu), une fois par session (source : code)

## 4. Base & confort

### 4.1 Sauvetage de série (`StreakRestore`)
- **Clé / type / id / prix** : `StreakRestore` / produit / 3736703610 / 29 R$ (palier 1)
- **Titre court** : Sauvetage de série
- **Définition** : Rétablit ta série de connexion quand elle va se perdre.
- **Détail** : Quand un deuxième jour manqué dans la semaine va casser ta série, tu peux la sauver. Il y a un moyen gratuit : finir les 3 quêtes du jour. Pas de rachat après 3 jours manqués.
- **Aléatoire ?** : non
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucun œuf supplémentaire et n'avance pas le calendrier
- **Accès direct à l'écran** : Écran « Ta série va se perdre », seulement quand la série est en danger (source : spec G.2/H.2)

### 4.2 Rattrapage du calendrier (`CalendarCatchup`)
- **Clé / type / id / prix** : `CalendarCatchup` / produit / 3736695392 / 29 R$ (palier 1)
- **Titre court** : Rattrapage du calendrier
- **Définition** : Rattrape UN jour manqué du calendrier de 30 jours, au jour de ton choix.
- **Détail** : Tu choisis le jour manqué ; la récompense est celle affichée sur la carte. Deux rattrapages gratuits existent (jour de grâce, 3 missions). Aucun tirage payant.
- **Aléatoire ?** : non : la récompense du jour est affichée
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne rien d'autre que la récompense du jour choisi
- **Accès direct à l'écran** : Quand tu as manqué un jour du calendrier et que les rattrapages gratuits sont utilisés (source : code)

### 4.3 Éclosion instantanée (`InstantHatch`)
- **Clé / type / id / prix** : `InstantHatch` / produit / 3734229329 / 49 R$ (palier 1)
- **Titre court** : Éclosion instantanée
- **Définition** : Fait éclore tous tes œufs tout de suite, sans attendre.
- **Détail** : Tous les œufs qui incubent éclosent maintenant. Ce qui sort est toujours tiré au sort comme d'habitude : ça ne change ni la rareté ni les chances.
- **Aléatoire ?** : oui, en partie : ce qui sort des œufs reste aléatoire (tables affichées) ; l'achat ne change pas les chances
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne change pas les chances et ne donne aucune force
- **Accès direct à l'écran** : Quand 3 œufs ou plus incubent et qu'un temps d'attente long reste affiché (source : code)

### 4.4 Sac d'œufs +10 (`EggBagPlus`)
- **Clé / type / id / prix** : `EggBagPlus` / passe / 2099454839 / 149 R$ (palier 2)
- **Titre court** : Sac d'œufs +10
- **Définition** : Ton sac d'œufs passe de 10 à 20 places, pour toujours.
- **Détail** : Le sac range les œufs gagnés quand ta base est pleine. Avec ce passe il garde 20 œufs au lieu de 10.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucun œuf et ne protège pas du vol
- **Accès direct à l'écran** : Quand ton sac d'œufs est plein (10 sur 10) (source : spec H.2)

### 4.5 +4 emplacements (`ExtraSlots`)
- **Clé / type / id / prix** : `ExtraSlots` / passe / 2098181699 / 249 R$ (palier 3)
- **Titre court** : +4 emplacements
- **Définition** : 4 places d'œufs en plus dans ta base, pour toujours (jusqu'à 20).
- **Détail** : Ajoute 4 emplacements à ta base, à vie, jusqu'à un maximum de 20. Utile quand la base est pleine d'œufs ou de pets.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique (20 emplacements au maximum)
- **Ne fait PAS** : ne donne aucun pet, aucune force et ne protège pas du vol
- **Accès direct à l'écran** : Quand ta base est pleine (source : code + spec H.3)

### 4.6 Collectionneur (`Collector`)
- **Clé / type / id / prix** : `Collector` / passe / 2099556764 / 249 R$ (palier 3)
- **Titre court** : Collectionneur
- **Définition** : Un pet suiveur de plus (4 au lieu de 3), plus des aides pour ta collection.
- **Détail** : Ajoute un pet suiveur (3 passent à 4), des indices de silhouette dans le bestiaire et un cadre doré sur les compteurs de rareté. Rien de tout cela ne change les œufs ni la force.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force en combat et ne donne aucun pet
- **Accès direct à l'écran** : Quand tu équipes ton 3ᵉ pet suiveur (maximum actuel) (source : spec H.3)

### 4.7 Base VIP (`VipBase`)
- **Clé / type / id / prix** : `VipBase` / passe / 2094209172 / 399 R$ (palier 3)
- **Titre court** : Base VIP
- **Définition** : Boucliers d'œufs x2 et bonus quotidien x2, pour toujours.
- **Détail** : Les boucliers de tes œufs durent deux fois plus longtemps, et le bonus de pièces de la série quotidienne est doublé. Les boucliers retardent le vol mais ne l'empêchent pas pour toujours.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne protège pas totalement du vol, ne donne pas de force en combat
- **Accès direct à l'écran** : Kiosque seulement (source : code)

## 5. Combat & vol

### 5.1 Ticket d'arène (`ArenaTickets`)
- **Clé / type / id / prix** : `ArenaTickets` / produit / 3736703606 / 19 R$ (palier 1)
- **Titre court** : Ticket d'arène
- **Définition** : 5 combats de tour de plus aujourd'hui, avec récompenses.
- **Détail** : Ajoute 5 combats de tour récompensés pour la journée en cours. Les combats restent équitables : aucune force n'est vendue.
- **Aléatoire ?** : non
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne change pas les adversaires
- **Accès direct à l'écran** : Après une défaite PvE, seulement si ton quota du jour est épuisé (source : spec H.3)

### 5.2 Relance immédiate (`Revive`)
- **Clé / type / id / prix** : `Revive` / produit / 3734229323 / 49 R$ (palier 1)
- **Titre court** : Relance immédiate
- **Définition** : Au Château : repars tout de suite où tu es tombé, avec tes points de vie.
- **Détail** : Pv rétablis, 4 s d'invulnérabilité, la défaite n'est pas comptée. Le retour gratuit au début de la salle reste toujours possible. La fenêtre de 20 s est la durée réelle de l'écran de défaite.
- **Aléatoire ?** : non
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force permanente et ne change pas le Château
- **Accès direct à l'écran** : Offre de relance de 20 s après une défaite au Château (non bloquante) (source : code)

### 5.3 Corbeau chipeur (`RemoteSteal`)
- **Clé / type / id / prix** : `RemoteSteal` / produit / 3736121232 / 79 R$ (palier 2)
- **Titre court** : Corbeau chipeur
- **Définition** : 1 jeton : un corbeau tente de rapporter un œuf d'un joueur du serveur.
- **Détail** : Le corbeau vise un œuf en incubation. La victime peut le chasser ; si ça échoue, ton jeton t'est rendu. Limites : 3 vols réussis par jour, protection débutant, bouclier de 5 min après un vol, 20 min de délai par victime, indemnité de 50 % pour la victime. Ton nom de voleur est affiché.
- **Aléatoire ?** : oui : réussite du vol et œuf volé dépendent du jeu ; rien n'est garanti
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne protège de rien (aucun produit de protection n'est vendu) et ne donne aucune force
- **Accès direct à l'écran** : Kiosque seulement (source : code)

### 5.4 3 Corbeaux chipeurs (`RemoteStealPack`)
- **Clé / type / id / prix** : `RemoteStealPack` / produit / 3736121238 / 199 R$ (palier 2)
- **Titre court** : 3 Corbeaux chipeurs
- **Définition** : 3 jetons de vol à distance.
- **Détail** : Trois jetons identiques au Corbeau chipeur, mêmes limites (3 vols réussis par jour, bouclier de 5 min, 20 min de délai par victime, indemnité de 50 %). Un jeton est rendu si la victime chasse le corbeau.
- **Aléatoire ?** : oui : réussite du vol et œuf volé dépendent du jeu ; rien n'est garanti
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne protège de rien (aucun produit de protection n'est vendu) et ne donne aucune force
- **Accès direct à l'écran** : Kiosque seulement (source : code)

## 6. Passe de combat

### 6.1 Passe de combat premium (`SeasonPremium`)
- **Clé / type / id / prix** : `SeasonPremium` / produit / 3736703683 / 399 R$ (palier 3)
- **Titre court** : Passe de combat premium
- **Définition** : Débloque la piste premium de la saison en cours : œufs, cosmétiques, un pet exclusif.
- **Détail** : Valable pour la saison en cours de 60 jours (renouvelée tous les 2 mois, thème tournant Feu, Glace, Foudre, Ombre, Nature, Ciel). Paliers déjà atteints crédités une seule fois ; réclamation possible 7 jours après la fin. 30 paliers, XP gagnée en combat et en quêtes. Piste premium : œufs jusqu'à Mythique, une espèce Exclusif FIXE de la saison au palier 30 (annoncée, pas de hasard sur l'espèce), cosmétiques « Saison N » qui ne reviennent pas. La piste gratuite reste gratuite.
- **Aléatoire ?** : non : tout le contenu de chaque palier est affiché ; seuls les pets sortant des œufs gagnés restent tirés au sort
- **Limite d'achat** : achat unique par saison
- **Ne fait PAS** : ne donne aucune force en combat ; ne vend pas de niveaux de pets
- **Accès direct à l'écran** : À l'ouverture de la catégorie Passe de combat, ou quand tu atteins le palier 3 de la piste gratuite (source : spec G.5/H.2 + ADDENDUM B)
- **Voir aussi** : Packs (Coffre royal)

### 6.2 Passe de combat + (suite) (`SeasonUpgradePlus`)
- **Clé / type / id / prix** : `SeasonUpgradePlus` / produit / 3736704000 / 400 R$ (palier 3)
- **Titre court** : Passe de combat + (suite)
- **Définition** : Pour qui a déjà le premium : ajoute les 10 paliers immédiats (799 - 399 = 400).
- **Détail** : Seulement si tu as DÉJÀ acheté le passe de combat premium cette saison : il ajoute les 10 paliers immédiats sans repayer le premium. Sans le premium, il est caché et refusé.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique par saison
- **Ne fait PAS** : ne donne aucune force en combat
- **Accès direct à l'écran** : Catégorie Passe de combat seulement, uniquement si le premium est possédé (source : Assets-crees)

### 6.3 Passe de combat + 10 paliers (`SeasonPremiumPlus`)
- **Clé / type / id / prix** : `SeasonPremiumPlus` / produit / 3736703689 / 799 R$ (palier 4)
- **Titre court** : Passe de combat + 10 paliers
- **Définition** : Le passe premium plus 10 paliers de saison tout de suite.
- **Détail** : Comme le passe premium, avec en plus 10 paliers immédiats (leurs récompenses sont créditées). Pour qui possède déjà le premium, voir « Passe de combat + (suite) ».
- **Aléatoire ?** : non : récompenses de paliers affichées
- **Limite d'achat** : achat unique par saison
- **Ne fait PAS** : ne donne aucune force en combat
- **Accès direct à l'écran** : Kiosque seulement (catégorie Passe de combat) ; masqué si le premium est déjà possédé (source : spec H.2)
- **Voir aussi** : Packs (Coffre royal)

## 7. Packs

### 7.1 Pack de départ (`StarterPack`)
- **Clé / type / id / prix** : `StarterPack` / produit / 3734229313 / 99 R$ (palier 2)
- **Titre court** : Pack de départ
- **Définition** : Une seule fois : 20 000 pièces, 3 œufs Rares et une potion de chance.
- **Détail** : Contient 20 000 pièces, 3 œufs Rares (espèce, taille, mutation tirées au sort, rareté fixe) et une Potion de chance (+25 points, 15 min). Achat unique, à vie. Le prix de 99 R$ est celui du code ; la spec H.2 proposait 49.
- **Aléatoire ?** : oui : espèces, tailles et mutations des 3 œufs Rares (rareté fixe, affichée)
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Les 3 premiers jours de jeu, une seule fois par session, tant qu'il n'est pas acheté (source : code)
- **Voir aussi** : Œufs

### 7.2 Pack Légende (`BundleLegend`)
- **Clé / type / id / prix** : `BundleLegend` / produit / 3736703706 / 999 R$ (palier 4)
- **Titre court** : Pack Légende
- **Définition** : 1 œuf Ultra Rare, 3 œufs Légendaires et Double chance 60 minutes.
- **Détail** : Contient 1 Œuf Ultra Rare, 3 Œufs Légendaires et 60 min de Double chance (points d'amélioration x2, limite de 70 points). Raretés fixes et affichées ; espèces, tailles et mutations tirées au sort. Moins cher que les parties achetées séparément.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée (pour chaque œuf)
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Kiosque seulement (jamais en offre à l'écran) (source : spec H.2)
- **Voir aussi** : Œufs, Chance & boosts

### 7.3 Coffre royal sans passe (`BundleRoyalNoPass`)
- **Clé / type / id / prix** : `BundleRoyalNoPass` / produit / 3736704205 / 1100 R$ (palier 4)
- **Titre court** : Coffre royal sans passe
- **Définition** : Le Coffre royal pour qui a déjà le passe premium : 2 Ultra Rares, 3 Mythiques.
- **Détail** : Complément pour qui possède déjà le passe de combat premium : mêmes œufs que le Coffre royal (2 Œufs Ultra Rares, 3 Œufs Mythiques), sans repayer le passe (1 499 - 399 = 1 100). Impossible à acheter sans le passe premium.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée (pour chaque œuf)
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Kiosque seulement ; affiché seulement si le passe premium est possédé (source : spec H.2 + Assets-crees)
- **Voir aussi** : Œufs, Passe de combat

### 7.4 Coffre royal (`BundleRoyal`)
- **Clé / type / id / prix** : `BundleRoyal` / produit / 3736703714 / 1499 R$ (palier 4)
- **Titre court** : Coffre royal
- **Définition** : 2 œufs Ultra Rares, 3 œufs Mythiques et le passe de combat premium.
- **Détail** : Contient 2 Œufs Ultra Rares, 3 Œufs Mythiques et le Passe de combat premium (paliers déjà atteints crédités). Pour qui a déjà le passe premium, ce coffre est remplacé par « Coffre royal sans passe ». Raretés fixes et affichées.
- **Aléatoire ?** : oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée (pour chaque œuf)
- **Limite d'achat** : aucune limite
- **Ne fait PAS** : ne donne aucune force en combat et ne protège pas du vol
- **Accès direct à l'écran** : Kiosque seulement (jamais en offre à l'écran) ; masqué si le passe premium est déjà possédé (source : spec H.2)
- **Voir aussi** : Œufs, Passe de combat

## 8. Cosmétiques (poses de victoire)

### 8.1 Pose de victoire 1 (`EmoteVictory1`)
- **Clé / type / id / prix** : `EmoteVictory1` / produit / 3736703619 / 39 R$ (palier 1)
- **Titre court** : Pose de victoire 1
- **Définition** : Une animation de victoire pour ton personnage, juste pour le style.
- **Détail** : Un geste cosmétique que tu peux jouer après une victoire. Aucun effet sur le jeu. Une fois achetée, elle est à toi pour toujours.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force, aucun œuf, aucun bonus
- **Accès direct à l'écran** : Après ta première victoire PvE (une seule pose proposée à la fois) (source : spec H.2)

### 8.2 Pose de victoire 2 (`EmoteVictory2`)
- **Clé / type / id / prix** : `EmoteVictory2` / produit / 3736703629 / 39 R$ (palier 1)
- **Titre court** : Pose de victoire 2
- **Définition** : Une animation de victoire pour ton personnage, juste pour le style.
- **Détail** : Un geste cosmétique que tu peux jouer après une victoire. Aucun effet sur le jeu. Une fois achetée, elle est à toi pour toujours.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force, aucun œuf, aucun bonus
- **Accès direct à l'écran** : Après ta première victoire PvE (une seule pose proposée à la fois) (source : spec H.2)

### 8.3 Pose de victoire 3 (`EmoteVictory3`)
- **Clé / type / id / prix** : `EmoteVictory3` / produit / 3736703634 / 39 R$ (palier 1)
- **Titre court** : Pose de victoire 3
- **Définition** : Une animation de victoire pour ton personnage, juste pour le style.
- **Détail** : Un geste cosmétique que tu peux jouer après une victoire. Aucun effet sur le jeu. Une fois achetée, elle est à toi pour toujours.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force, aucun œuf, aucun bonus
- **Accès direct à l'écran** : Après ta première victoire PvE (une seule pose proposée à la fois) (source : spec H.2)

### 8.4 Pose de victoire 4 (`EmoteVictory4`)
- **Clé / type / id / prix** : `EmoteVictory4` / produit / 3736703641 / 39 R$ (palier 1)
- **Titre court** : Pose de victoire 4
- **Définition** : Une animation de victoire pour ton personnage, juste pour le style.
- **Détail** : Un geste cosmétique que tu peux jouer après une victoire. Aucun effet sur le jeu. Une fois achetée, elle est à toi pour toujours.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force, aucun œuf, aucun bonus
- **Accès direct à l'écran** : Après ta première victoire PvE (une seule pose proposée à la fois) (source : spec H.2)

### 8.5 Pose de victoire 5 (`EmoteVictory5`)
- **Clé / type / id / prix** : `EmoteVictory5` / produit / 3736703649 / 39 R$ (palier 1)
- **Titre court** : Pose de victoire 5
- **Définition** : Une animation de victoire pour ton personnage, juste pour le style.
- **Détail** : Un geste cosmétique que tu peux jouer après une victoire. Aucun effet sur le jeu. Une fois achetée, elle est à toi pour toujours.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force, aucun œuf, aucun bonus
- **Accès direct à l'écran** : Après ta première victoire PvE (une seule pose proposée à la fois) (source : spec H.2)

### 8.6 Pose de victoire 6 (`EmoteVictory6`)
- **Clé / type / id / prix** : `EmoteVictory6` / produit / 3736703657 / 39 R$ (palier 1)
- **Titre court** : Pose de victoire 6
- **Définition** : Une animation de victoire pour ton personnage, juste pour le style.
- **Détail** : Un geste cosmétique que tu peux jouer après une victoire. Aucun effet sur le jeu. Une fois achetée, elle est à toi pour toujours.
- **Aléatoire ?** : non
- **Limite d'achat** : achat unique
- **Ne fait PAS** : ne donne aucune force, aucun œuf, aucun bonus
- **Accès direct à l'écran** : Après ta première victoire PvE (une seule pose proposée à la fois) (source : spec H.2)

## Règles d'affichage à l'écran

Elles reprennent `Config.OFFERS = { max = 3, gap = 300, graceSeconds = 90 }` et la section H.3.

1. **Une seule offre à l'écran à la fois.** Si une offre est ouverte, aucune autre n'apparaît.
2. **3 offres par session au maximum**, et **300 secondes d'écart** entre deux offres. Pas d'offre dans les 90 premières secondes de la session.
3. **Ordre de priorité** (une seule est choisie quand plusieurs conditions sont vraies) : (1) sécurité du joueur et fonctions de confort qui évitent une perte : Sauvetage de série, Rattrapage du calendrier ; (2) +4 emplacements et Sac d'œufs +10 quand la base ou le sac est plein ; (3) Ticket d'arène après une défaite PvE (quota épuisé) ; (4) Double chance après la première éclosion Légendaire, Chance +10 % après une éclosion Rare ou mieux ; (5) Pack de départ les 3 premiers jours ; (6) Revenus x2 aux paliers ; (7) Passe de combat, seulement à l'ouverture de sa catégorie (saison de 60 jours, aucun compte à rebours) ; (8) le reste. Un achat jamais proposé à l'écran (palier 4, œufs Secret, Exclusif, Divin, Coffres) reste au kiosque.
4. **Le bouton « Fermer » est toujours visible**, même taille minimale 52 px, et la carte se ferme d'un geste. Un refus n'est jamais pénalisé et ne ramène pas la même offre dans la même session.
5. **Ne jamais masquer l'action de jeu.** Carte petite sur un bord sûr, zone centrale libre, jamais pendant un vol, un combat, une éclosion en cours ou un chrono de Château. Après une défaite, l'offre apparaît après l'écran de défaite.
6. **Pas d'offre juste après un achat répété (aucune relance incitative), pas d'offre pour un achat possédé, indisponible (id manquant) ou masqué par PolicyService.** Pas de compte à rebours sur une offre permanente.
7. **Chaque offre ouvre la même fiche que le kiosque** : titre, définition, détail, probabilités si l'achat est aléatoire, prix en R$, ce que l'achat ne fait pas.
