# À faire par toi (Chipe-Œufs, Roblox)

Seulement ce que je ne peux pas faire à ta place : il faut ton compte Roblox, Studio, un navigateur connecté, ou ton autorisation. Tout le reste est fait ou suivi dans `CHANGELOG.md`. Dernière mise à jour : 2026-11-12 (achats : tant que les ID valent 0, ils restent désactivés dans le jeu avec un message clair, rien à faire de plus côté code).

Les cases sont à cocher au fur et à mesure.

## 1. Autoriser les outils de vérification (optionnel, 2 minutes)

Quatre outils sont téléchargés mais l'exécution est refusée par l'autorisation de la session. Au choix :
- [ ] Ajouter une règle d'autorisation Bash pour `stylua`, `selene`, `rojo` et `lune` dans les paramètres de la session, puis me demander de les lancer ;
- [ ] ou les lancer toi-même depuis la racine du dépôt (commandes dans `roblox/tools/VERIFICATION.md`), et me coller les sorties.

## 2. Ouvrir la place dans Studio et publier

- [ ] Studio : **File > Open from File** → `roblox/build/ChipeOeufs.rbxlx`.
- [ ] Te connecter, puis **File > Publish to Roblox As…** → *Create new experience*. Titre : `Chipe-Œufs : Vole des Œufs ! 🥚`. Description, genre et appareils : copier depuis `roblox/publication/LISTING.md` §1.
- [ ] **Home > Game Settings > Security** : activer **Enable Studio Access to API Services**.
- [ ] **Game Settings** : **Max Players = 10** ; **Avatar = R15**.

## 3. Playtest dans Studio (indispensable avant de passer en public)

- [ ] **Test > Clients and Servers**, 2 joueurs. Parcourir la liste de `roblox/publication/LISTING.md` §5 (histoire, zones, vol entre joueurs, achats, sauvegarde, téléphone).
- [ ] Vérifier les animations en jeu (œufs, visages des pets, menus, barrière de zone, confettis) et me dire lesquelles gênent ou saccadent : chacune se coupe avec un drapeau de `Config.Animations`.
- [ ] Vérifier à l'œil le monument du Grand Nid (runes, panneau d'énigme lisible des deux côtés) et la résolution de l'énigme du jour.
- [ ] Me dire ce qui ne va pas (erreurs rouges de la fenêtre Output, comportements étranges, équilibrage trop dur ou trop facile) : je corrige.

## 4. Créer les achats sur le Creator Hub et me donner les ID

Creator Hub → ton expérience → **Monetization**. Les prix sont des suggestions (Roblox prélève 30 %). Une icône par achat est prête dans `roblox/publication/art/`.

| Type | Nom exact | Prix | Description | Icône |
|---|---|---|---|---|
| Game Pass | Revenus x2 | 199 R$ | Double tous tes revenus de pièces, pour toujours. | `pass_coins2x_512.png` |
| Game Pass | Chance +10% | 149 R$ | Augmente de 10 points tes chances d'obtenir un pet de rareté supérieure. | `pass_lucky_512.png` |
| Game Pass | Éclosion rapide | 149 R$ | Les œufs éclosent 25 % plus vite, pour toujours. | `pass_fast_512.png` |
| Developer Product | Éclosion instantanée | 49 R$ | Fait éclore tous tes œufs tout de suite. | `product_instanthatch_512.png` |
| Developer Product | Potion de chance | 99 R$ | +25 points de chances d'obtenir un pet supérieur pendant 15 minutes. | `product_luckpotion_512.png` |
| Developer Product | Sac de pièces | 99 R$ | Offre 20 minutes de tes revenus (minimum 5 000 pièces). | `product_coinpack_512.png` |

- [ ] Créer les 3 Game Passes et les 3 Developer Products.
- [ ] Copier chaque **ID** dans `roblox/src/ReplicatedStorage/Config.lua`, champ `id = 0` de la ligne correspondante : `Config.PASSES.Coins2x`, `.Lucky`, `.Fast` et `Config.PRODUCTS.InstantHatch`, `.LuckPotion`, `.CoinPack`. Ou me donner les 6 ID et je m'en charge, puis je régénère la place.
- [ ] Tester chaque achat avec le **test purchase** de Studio.
- [ ] **Décision à prendre** : lire la politique Roblox sur les « Paid Random Items » avant d'activer **Chance +10%**, **Potion de chance** et **Éclosion instantanée** (elles touchent à des tirages aléatoires payés). Les probabilités sont déjà affichées dans le jeu (menu Plus). Prudence : ne lancer d'abord que Revenus x2, Éclosion rapide et Sac de pièces (laisser les autres à `id = 0`).

## 5. Téléverser les images

Creator Hub → ton expérience → **Media** (ou *Basic Settings > Icon / Thumbnails*).

- [ ] Icône : `roblox/publication/art/icon_512.png`.
- [ ] Miniatures : `thumb_1_hero_1920x1080.png` (en premier), `thumb_2_vol_1920x1080.png`, `thumb_3_pets_1920x1080.png`, `thumb_4_histoire_1920x1080.png`.
- [ ] Après ton playtest, **prendre 2 à 3 vraies captures d'écran du jeu** et les ajouter (Roblox modère les images : elles doivent représenter le jeu).

## 6. Conformité et compte

- [ ] Répondre au **questionnaire de maturité** (Creator Hub → expérience → Settings) : seul le créateur peut le faire, et honnêtement (le jeu contient des poursuites de chiens en dessin animé, des vols entre joueurs, des achats Robux avec tirages).
- [ ] Si Roblox le demande : **vérification de l'email, de l'âge ou de l'identité** (nécessaire pour certaines fonctions de monétisation et pour retirer des gains via DevEx). C'est entre toi et Roblox, je ne peux rien y faire.
- [ ] Passer l'expérience en **Public** (Creator Hub → expérience → Access) seulement après les points 3 et 4.

## 7. Facultatif

- [ ] **Sons** : chercher des sons dans le Creator Store et coller leurs ID (`rbxassetid://…`) dans `Config.SOUNDS` (par défaut, sons intégrés Roblox non vérifiés).
- [ ] **Modèles 3D** des pets et des rivaux (Creator Store ou Blender) si tu veux un rendu plus distinctif.
- [ ] **Activer `StreamingEnabled`** (Workspace > Properties) pour les téléphones d'entrée de gamme.
