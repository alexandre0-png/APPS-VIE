# Chipe-Œufs : fiche de publication et vérifications avant le passage en public

Ce fichier résume ce qu'il faut renseigner et contrôler avant de rendre le jeu public. Rien n'a été publié par l'agent : tout se fait par toi dans Studio et le Creator Hub (kit détaillé : `publication/LISTING.md`, tâches : `A_FAIRE_UTILISATEUR.md`). Aucun playtest Studio n'a été fait à ce jour : la qualité décrite plus bas est celle de l'analyse statique et des simulations.

## 1. Fiche du jeu

**Nom** (50 caractères max) : `Chipe-Œufs : Vole des Œufs ! 🥚`

**Description courte** (réseaux, partages, ~120 caractères) : `Chipe des œufs, fais-les éclore, collectionne 18 pets et défie le Château avec tes amis !`

**Description longue** (1000 caractères max, à coller dans le Creator Hub) :

```
🥚 Bienvenue dans Chipe-Œufs !

La Grande Couvée s'est brisée : reprends ses œufs, fais-les éclore et deviens Roi des Couvées !

🥚 Chipe des œufs gardés par un chien, un loup et un ours... ou à d'autres joueurs
🏰 Le Château : 5 salles à pièges, chevaliers et coffre final, en solo ou jusqu'à 5 amis, avec classement des temps
👥 Lance une partie depuis le hub, tes amis te rejoignent quand ils veulent
🐣 18 pets, 6 raretés, tailles et mutations (Doré, Néon, Arc-en-ciel, Alien)
📖 Un index de collection : chaque série d'espèces découvertes donne un bonus définitif
💰 Tes pets rapportent des pièces tant que tu joues, et un peu de revenu continue quand tu pars (30 minutes au plus)
⭐ Échange tes doublons, améliore ta base, 🌅 renais pour des bonus permanents
🎯 Missions du jour avec œufs en récompense, énigme quotidienne, événements

Un œuf posé dans ta base est protégé quelques secondes, puis les autres joueurs peuvent te le voler. Les probabilités d'éclosion sont affichées dans le jeu.
```

**Genres** : principal Adventure ; secondaires Fantasy, Comedy (choisir ceux proposés par le Creator Hub). **Appareils** : Ordinateur, Téléphone, Tablette ; Console seulement après un test à la manette (non testé). **Joueurs max** : 5 pour le lieu de jeu (87012762353093) ; le hub (115261336085924) est le lieu de départ.

**Âge et questionnaire de classification** : à remplir honnêtement (violence très légère de dessin animé : coups non mortels des gardiens et des pièges ; vol d'objets virtuels entre joueurs ; achats Robux à probabilité non payante : aucun œuf n'est vendu avec une probabilité modifiée, les passes de chance sont des bonus fixes affichés).

## 2. Cinq phrases d'accroche

1. Chipe l'œuf, évite le loup, deviens Roi des Couvées !
2. 18 pets à faire éclore : lequel sera ton premier Cosmique ?
3. Affronte le Château avec jusqu'à 4 amis : pics, lames, boulets et chevaliers.
4. Ton armée de pets travaille pour toi tant que tu joues, et garde un petit gain pour ton retour.
5. Un œuf mal gardé ne reste pas longtemps dans ta base… sauras-tu le défendre ?

## 3. Achats à créer (IDs à renseigner dans `Config.PASSES` / `Config.PRODUCTS`)

Voir le tableau complet (noms, prix, descriptions) dans `A_FAIRE_UTILISATEUR.md` §4. Tant qu'un ID vaut 0, l'achat reste désactivé avec un message clair et aucune offre d'achat n'apparaît dans le jeu.

## 3bis. Catalogue de la boutique (à créer par le propriétaire)

Chaque ligne donne l'ID attendu et l'endroit exact où le coller. Tant qu'un ID vaut 0 : aucune offre n'apparaît, l'achat renvoie « 🛒 Cet achat n'est pas encore disponible » et rien ne plante (testé). Les prix sont des suggestions (Roblox prélève 30 %). Les passes ci-dessous sont celles du code ; « Chance x2 » n'existe pas : la chance est vendue en bonus fixes affichés (+10 % passe, +25 % potion) pour rester conforme aux règles Roblox sur les objets aléatoires payants.

| Type | Nom exact | Prix suggéré | Description | ID à renseigner (Config.lua) |
|---|---|---|---|---|
| Game Pass | Revenus x2 | 199 R$ | Double tous tes revenus de pièces, pour toujours. | `Config.PASSES.Coins2x.id` (ligne 119) : `____` |
| Game Pass | Chance +10% | 149 R$ | Augmente de 10 points tes chances d'obtenir un pet de rareté supérieure. | `Config.PASSES.Lucky.id` (ligne 120) : `____` |
| Game Pass | Éclosion rapide | 149 R$ | Les œufs éclosent 25 % plus vite, pour toujours. | `Config.PASSES.Fast.id` (ligne 121) : `____` |
| Game Pass | Vitesse +20 % | 149 R$ | Cours 20 % plus vite, pour toujours. | `Config.PASSES.Speed.id` (ligne 122) : `____` |
| Game Pass | Base VIP | 399 R$ | Boucliers d'œufs x2 et bonus quotidien x2, pour toujours. | `Config.PASSES.VipBase.id` (ligne 123) : `____` |
| Developer Product | Pack de départ | 99 R$ | Achat unique : 20 000 pièces, 3 œufs Rares et une potion de chance. | `Config.PRODUCTS.StarterPack.id` (ligne 345) : `____` |
| Developer Product | Œuf Mythique | 249 R$ | Un œuf Mythique (rareté fixe) placé dans ta base (place libre requise, sinon livré plus tard). Lot 9 : ex-« Œuf exclusif Mythique », à renommer. | `Config.PRODUCTS.ExclusiveEgg.id` (ligne 346) : `____` |
| Developer Product | Relance immédiate | 49 R$ | Au Château : repars aussitôt là où tu es tombé, pv rétablis. | `Config.PRODUCTS.Revive.id` (ligne 347) : `____` |
| Developer Product | Éclosion instantanée | 49 R$ | Fait éclore tous tes œufs tout de suite. | `Config.PRODUCTS.InstantHatch.id` (ligne 343) : `____` |
| Developer Product | Potion de chance | 99 R$ | +25 points de chances d'obtenir un pet supérieur pendant 15 minutes. | `Config.PRODUCTS.LuckPotion.id` (ligne 344) : `____` |
| Developer Product | Sac de pièces | 99 R$ | Offre 20 minutes de revenus (minimum 5 000 pièces). | `Config.PRODUCTS.CoinPack.id` (ligne 348) : `____` |
| Game Pass | +4 emplacements | 249 R$ | 4 emplacements d'œufs en plus dans ta base, pour toujours (jusqu'à 20). | `Config.PASSES.ExtraSlots.id` (ligne 125) : renseigné |
| Game Pass | Tapis privé | 299 R$ | Un petit tapis au milieu de ta base : un œuf gratuit toutes les 3 min tant que tu joues. | `Config.PASSES.PrivateBelt.id` (ligne 126) : renseigné |
| Developer Product | Pluie de chance pour tous | 129 R$ | 10 min de +5 points de chance d'amélioration pour tout le serveur. | `Config.PRODUCTS.ServerLuck.id` (ligne 351) : renseigné |
| Developer Product | Tapis doré | 99 R$ | 10 min : le tapis du marché livre un œuf toutes les 4 s (table dorée affichée, x2 à x2,5 sur les raretés >= Rare), cumulable jusqu'à 30 min. | `Config.PRODUCTS.GoldenBelt.id` (ligne 352) : renseigné |
| Developer Product | Corbeau chipeur | 79 R$ | 1 jeton de vol à distance (rendu si la victime chasse le corbeau). | `Config.PRODUCTS.RemoteSteal.id` (ligne 353) : renseigné |
| Developer Product | 3 Corbeaux chipeurs | 199 R$ | 3 jetons de vol à distance. | `Config.PRODUCTS.RemoteStealPack.id` (ligne 354) : renseigné |

Bandeaux et icônes : `publication/art/` (icône 512 px des 6 premiers achats ; les autres sont à créer).

| Developer Product | Œuf Secret | 1 499 R$ | Un œuf Secret (rareté FIXE) placé dans ta base. Espèce, taille et mutation tirées au sort : probabilités affichées avant l'achat. Aucun bonus de combat. Masqué et refusé si PolicyService restreint, et tant qu'aucune espèce Secret n'existe (lot 11). | `Config.PRODUCTS.EggSecret.id` : 3736452048 (créé) |
| Developer Product | Œuf Exclusif | 3 499 R$ | Un œuf Exclusif (rareté FIXE) placé dans ta base. Probabilités affichées avant l'achat. Aucun bonus de combat. Mêmes protections. | `Config.PRODUCTS.EggExclusive.id` : 3736452061 (créé) |
| Developer Product | Œuf Divin | 6 999 R$ | Un œuf Divin (rareté FIXE) placé dans ta base. Probabilités affichées avant l'achat. Aucun bonus de combat. Mêmes protections. | `Config.PRODUCTS.EggDivine.id` : 3736452072 (créé) |
| Developer Product | Rattrapage du calendrier | 29 R$ | Rattrape UN jour manqué du calendrier de 30 jours (au choix du joueur) ; livre un jeton de rattrapage, aucun tirage payant. | `Config.PRODUCTS.CalendarCatchup.id` : 3736695392 (créé, en vente) |
| Developer Product | Sauver ma série | 29 R$ | Sauve la série de 7 jours après 2 jours manqués (une fois par semaine UTC) ; aucun hasard. Livré seulement si la série est réellement à sauver (sinon rejoué plus tard, rien n'est perdu). | `Config.PRODUCTS.StreakRestore.id` : 0 (à créer, lot 15) |

**Lot 9, œufs Secret / Exclusif / Divin (décision de l'utilisateur)** : vendus en Robux à très haut prix, en rareté FIXE affichée avant l'achat, contenu (espèces, tailles, mutations) affiché, `random = true` : masqués côté client et refusés côté serveur (`NotProcessedYet`, rien n'est livré) si `ArePaidRandomItemsRestricted` ou si PolicyService ne répond pas. Reçu idempotent, œuf placé dans une place libre de la base (sinon `NotProcessedYet` : livré à la prochaine occasion). Tant que la rareté n'a aucune espèce publiée (lot 11), l'offre est masquée et le reçu refusé. Aucun avantage de combat acheté directement (les stats dépendent de la rareté, pas du moyen d'obtention). Le prix en pièces de ces raretés au tapis respecte la règle (3) ci-dessous.

### Règles de design (lot 9, contraignantes, vérifiées par tests)

1. **Revenu** : plus un pet est rare, plus il rapporte : fourchettes `Config.INCOME_RANGE`, min(r+1) >= 1,8 x max(r) ; taille et mutation multiplient ensuite.
2. **Combat** : plus un pet est rare, plus il est fort : `Battle.STATS[r]`, puissance (pv + 3 x attaque + 2 x vitesse) croissante d'au moins x1,25 ; au sein d'une rareté, profils tank / attaquant / rapide / équilibré (écart 8 à 15 %).
3. **Pièces contre Robux** : tout ce qui s'achète aux deux est plus cher et plus long en pièces : temps de gain en pièces du débutant entre 4 et 12 fois le « temps Robux » (prix en R$ x 12,1 s, taux du Sac de pièces : 20 min de revenu pour 99 R$). Œuf Mythique (boutique, 370 M pièces), Œuf Secret (tapis, 48 Md), Œuf Divin (tapis, 1 080 Md) : mesuré de x4,5 à x8,9 (`Config.PRICING`). L'Exclusif ne s'achète jamais en pièces.

## 3ter. Offres à hasard, vol à distance et fiche de classification (lot 7)

**Probabilités à afficher sur la fiche de chaque offre à hasard** (valeurs lues dans `Config`, jamais copiées à la main : `Config.beltOddsText`, `Config.oddsText`) :

| Offre | Ce qui est tiré au sort | Probabilités |
|---|---|---|
| Œuf exclusif Mythique | Taille et mutation du pet (la rareté Mythique est fixe et annoncée) | Tables « taille » et « mutation » du menu Plus (`Config.oddsText()`) |
| Tapis privé (pass) | Rareté de l'œuf gratuit (toutes les 2 min d'activité, 3 en attente au plus) | Table STANDARD du tapis : Commun 62 %, Rare 26 %, Épique 9 %, Légendaire 2,6 %, Mythique 0,37 %, Secret 0,03 % |
| Tapis doré (produit) | Rareté des œufs du tapis pendant 10 min (3 s au lieu de 5) | Table DORÉE : 40 / 34 / 18 / 6,5 / 1,35 / 0,15 % (affichée sur le panneau du tapis, en surbrillance quand elle est active) |
| Potion de chance, Chance +10 %, Pluie de chance pour tous | Amélioration d'UN cran de rareté à l'éclosion | Valeurs fixes affichées : base 5 %, +25 points (potion), +10 points (passe), +5 points (pluie), plafond 70 % ; jamais de rétrogradation |

Aucune offre ne vend un œuf dont la rareté est tirée au sort sans que la table soit visible avant l'achat (panneau du tapis, menu Plus, description de l'offre « 🎲 Probabilités affichées »).

**PolicyService** : si `ArePaidRandomItemsRestricted` est vrai (ou inconnu, ou si l'appel échoue), les 6 offres marquées `random = true` (ExclusiveEgg, PrivateBelt, GoldenBelt, LuckPotion, Lucky, ServerLuck) sont masquées dans la boutique et les cartes d'offre, et REFUSÉES côté serveur (reçu `NotProcessedYet`, pass non livré). À tester dans Studio avec un compte restreint.

**Texte pour la fiche de classification (questionnaire de maturité)** : vol d'objets virtuels entre joueurs (œufs, y compris à distance via un « corbeau » payant en jetons), déjà déclaré. Le vol à distance : jeton par achat (1 ou 3), 3 vols réussis par jour au plus, protection débutant, bouclier de 5 min après tout vol, délai de 20 min par victime, indemnité de 50 % du prix de l'œuf, option « Refuser les corbeaux de mes amis », nom du voleur toujours affiché, aucun produit de protection vendu, journal « Qui m'a volé ? » et journal serveur `RavenLog` (30 jours) pour le support.

## 4. État de la qualité (constaté par lecture et tests, pas en Studio)

| Domaine | Constat | Source |
|---|---|---|
| Remotes | Tous les clients passent par `Action` (hub : `HubRemote`) : nom d'action string, arguments typés et bornés (emplacement entier 1..12, rareté entière, clés connues), limite 12 appels/s et par joueur (0,4 s au hub), aucune action ne crédite de monnaie sur la foi du client (achats : serveur seul). Rien n'est lu dans un `RemoteFunction` | `Main.server.lua`, `Hub.server.lua`, tests e2e |
| Achats | `ProcessReceipt` : `PurchaseGranted` seulement après sauvegarde réussie, relivraison impossible, reçu dédoublonné, achat unique contrôlé, base pleine gérée | lot H, tests |
| DataStore | `UpdateAsync` avec verrou de session (120 s), 3 tentatives, version 7 avec migrations, sauvegarde automatique 60 s, `BindToClose` (25 s max), valeurs JSON invalides assainies, mode dégradé sans API | `Data.lua`, `Main.server.lua` |
| Fuites | Tables par joueur nettoyées à la sortie (`sessions`, `holds`, `lastReq`, `friendCache`, `launching`, verrou de sauvegarde) ; reçus anciens purgés (30 jours) ; clones Blender détruits ou ancrés une seule fois | relecture, tests de 30 minutes simulées |
| Mobile | Budget carte 7 000 Parts (procédural), accessoires 2 600, château 1 700, arène 500, sol 600 (mesuré) : ce sont des pires cas ; effets de révélation et aura réduits sur tactile ; lumières et émetteurs plafonnés | `Config.Map`, `Config.Assets`, tests de budget |
| Accessibilité | Texte fixe de 11 minimum (test), contrastes vérifiés par `Config.contrast`, bords sûrs et zone centrale libre sur 10 tailles d'écran (test de mise en page), boutons de 52 px minimum | tests |

Limites connues : rien n'a été mesuré sur un vrai téléphone ; la taille et l'orientation des modèles Blender n'ont pas été vues (devant supposé = -Z) ; pas de test manette ; pas de test à 5 joueurs réels ; les chronos de sauvegarde et de téléportation sont simulés.

## 5. Liste de vérifications avant le passage en public

À cocher dans Studio, dans cet ordre. Chaque point dit comment savoir que ça marche.

**A. Configuration**
- [ ] Les deux lieux sont dans la même expérience et publiés : `Hub.rbxlx` dans 115261336085924 (lieu de départ), `ChipeOeufs.rbxlx` dans 87012762353093. *Preuve : un clic sur un portail du hub arrive dans la partie.*
- [ ] **Enable Studio Access to API Services** activé. *Preuve : aucun avertissement « mode mémoire » dans la sortie.*
- [ ] **Max Players = 5** sur le lieu de jeu.
- [ ] IDs des passes et produits collés dans `Config.lua`, build régénéré (`python3 roblox/tools/build_place.py`).
- [ ] Les modèles Blender se chargent : sortie `[Assets]` sans « refusé » ; sinon ouvrir chaque modèle avec ton compte et l'ajouter à l'inventaire.

**B. Playtest Studio (Test > Clients and Servers, 2 puis 5 joueurs)**
- [ ] Sortie sans erreur rouge pendant 15 minutes. *Preuve : fenêtre Output.*
- [ ] Hub, portails, amis, retour au hub, mode Château (entrée, chrono, coffre, classement).
- [ ] Un gardien ne tue jamais d'un coup (barre de vie), les pièges et chevaliers non plus.
- [ ] Orientation et taille des modèles (gardiens, pièges, herses, pales du moulin, bancs) : sinon dis-moi lesquels, je corrige l'échelle et la rotation.
- [ ] Achats : tester avec un compte de test que chaque passe et produit livre une fois, qu'un échec de sauvegarde (couper l'accès API) ne livre pas deux fois.
- [ ] Sauvegarde : quitter puis revenir, tout est retrouvé (pièces, œufs, pets, quêtes, pack de départ).

**C. Appareils**
- [ ] Émulateur téléphone 360x640 et 844x390 : rien ne se chevauche, texte lisible, zone centrale libre.
- [ ] Vrai téléphone si possible : fluidité (>= 30 images/s) dans le domaine de Zed et le château. Si lent : `Config.REVEAL.forceReduced = true`, réduire `Config.Assets.*BudgetParts`, couper `Config.Animations.*`.
- [ ] Manette (si Console cochée) : X boutique, Y missions, B fermer.

**D. Fiche et conformité**
- [ ] Nom, descriptions, genres, icône 512x512, miniatures 1920x1080 (dans `publication/art/` et la scène de miniature faite par ailleurs).
- [ ] Questionnaire de classification rempli ; vérification d'identité si exigée pour la monétisation.
- [ ] Probabilités visibles dans le jeu (menu Plus) : obligatoire pour les mécaniques d'œufs.
- [ ] Aucun nom, modèle ou asset copié d'un autre jeu.

**E. Lancement**
- [ ] Publier d'abord en **privé** puis en **amis uniquement** : 24 h de retours, regarder les erreurs serveur dans le Creator Hub (Analytics > Performance).
- [ ] Passer en public, surveiller la première heure : taux d'erreur, durée des sessions, fuites mémoire (courbe de mémoire serveur).
