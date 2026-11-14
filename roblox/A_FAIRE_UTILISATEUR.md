# À faire par toi (Chipe-Œufs, Roblox)

Seulement ce que je ne peux pas faire à ta place : il faut ton compte Roblox, Studio, un navigateur connecté, ou ton autorisation. Tout le reste est fait ou suivi dans `CHANGELOG.md`. Dernière mise à jour : 2026-11-13 (modèles d'œufs à vérifier ; 2026-11-12 : achats : tant que les ID valent 0, ils restent désactivés dans le jeu avec un message clair, rien à faire de plus côté code).

Les cases sont à cocher au fur et à mesure.

## 1. Autoriser les outils de vérification (optionnel, 2 minutes)

Quatre outils sont téléchargés mais l'exécution est refusée par l'autorisation de la session. Au choix :
- [ ] Ajouter une règle d'autorisation Bash pour `stylua`, `selene`, `rojo` et `lune` dans les paramètres de la session, puis me demander de les lancer ;
- [ ] ou les lancer toi-même depuis la racine du dépôt (commandes dans `roblox/tools/VERIFICATION.md`), et me coller les sorties.

## 1bis. Réglages Studio vus dans ton premier lancement (v4)

- [ ] **Game Settings > Security > Enable Studio Access to API Services** : sans lui le jeu tourne en mode mémoire (rien n'est sauvegardé, pas de classement). C'est normal et signalé par un seul avertissement.
- [ ] **Modèles d'œufs refusés** (`Requester does not have permission for Asset`) : legendary 2937230482, orange 147144059, glitch 2937218888. Le jeu utilise alors les apparences construites par le code, aucun effet sur le gameplay. Pour les obtenir : ouvre chaque modèle dans la boutique Roblox (Toolbox / page du modèle) avec ton compte et utilise **Get** / l'ajouter à ton inventaire, ou remplace l'ID par un modèle que tu possèdes ; sinon laisse tel quel.
- [ ] Après le prochain playtest : dis-moi si le rythme te semble trop lent ou trop rapide (prix des œufs dans `Config.EGG_PRICE`, simulation dans `roblox/tools/sim_economy.py`).

## 1ter. Hub et parties (nouveau)

- [ ] **Creator Dashboard, lieu de JEU (115261336085924) : Max Players = 5** (le code refuse un 6e joueur et le renvoie au hub, mais le réglage évite des essais inutiles).
- [ ] Publier **deux fichiers** : `roblox/build/Hub.rbxlx` dans le lieu hub (106358102689021) et `roblox/build/ChipeOeufs.rbxlx` dans le lieu de jeu (115261336085924). Activer **Enable Studio Access to API Services** dans les deux, et **Allow Third Party Teleports** (Game Settings > Security) dans le lieu de jeu.
- [ ] **Décision importante** : le hub et le jeu sont dans deux expériences différentes (univers 10776613783 et 10776613087). Roblox limite la réservation de serveurs privés et MemoryStore à une seule expérience : les parties privées avec amis peuvent être refusées (le code bascule alors sur un serveur public, sans rejoindre entre amis). Pour que tout marche : Creator Hub > expérience « Jeu des oeufs » > Lieux > **ajouter le hub comme second lieu** de cette expérience, puis me donner son nouvel identifiant (ou changer `Config.Game.Places.hub`). Je n'ai pas pu le tester.
- [ ] Tester dans Studio (Test > Clients and Servers) : entrer dans un portail, compte à rebours, départ ; liste des amis ; interface bien aux bords sur téléphone (émulateur) et PC.
- [ ] Vérifier la grande carte : les trois domaines (ferme, bois, citadelle), les repères, les trois secrets (Config.SECRETS), l'ambiance qui change en entrant dans un domaine, les performances sur téléphone (la sortie affiche le nombre de Parts au démarrage).

## 2. Ouvrir la place dans Studio et publier

- [ ] Studio : **File > Open from File** → `roblox/build/ChipeOeufs.rbxlx`.
- [ ] Te connecter, puis **File > Publish to Roblox As…** → *Create new experience*. Titre : `Chipe-Œufs : Vole des Œufs ! 🥚`. Description, genre et appareils : copier depuis `roblox/publication/LISTING.md` §1.
- [ ] **Home > Game Settings > Security** : activer **Enable Studio Access to API Services**.
- [ ] **Game Settings** : **Max Players = 10** ; **Avatar = R15**.

## 3. Playtest dans Studio (indispensable avant de passer en public)

- [ ] **Test > Clients and Servers**, 2 joueurs. Parcourir la liste de `roblox/publication/LISTING.md` §5 (histoire, zones, vol entre joueurs, achats, sauvegarde, téléphone).
- [ ] Vérifier les cinématiques en jeu (intro puis tutoriel au premier lancement, skip, retour de la caméra, plan de la première zone et du premier pet rare) : lisibilité des légendes sur téléphone, durée ressentie, et me dire si une cinématique doit être raccourcie ou coupée (`Config.Cinematics`).
- [ ] Vérifier les animations en jeu (œufs, visages des pets, menus, barrière de zone, confettis) et me dire lesquelles gênent ou saccadent : chacune se coupe avec un drapeau de `Config.Animations`.
- [ ] Vérifier les modèles d'œufs en jeu : apparaissent-ils (sinon lire les lignes `[Assets]` de la fenêtre Output : ID refusé, modèle non autorisé pour ton compte, vide...) ? Taille, aspect et rareté associée te conviennent-ils ? Les IDs doivent être des modèles que ton compte a le droit d'utiliser (disponibles dans la boutique, utilisables dans Studio). Correspondance et IDs modifiables dans `Config.Assets` ; `Enabled = false` les coupe.
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
