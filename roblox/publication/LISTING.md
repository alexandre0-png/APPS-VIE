# Chipe-Œufs : kit de publication Roblox

Tout ce qu'il faut pour passer du fichier de place à un jeu public. Je n'ai pas accès à ton compte Roblox : les étapes marquées 🖱️ se font dans Studio ou le Creator Hub, en copiant-collant ce qui est ci-dessous.

Fichiers prêts :

| Quoi | Fichier |
|---|---|
| Place à ouvrir dans Studio | `roblox/build/ChipeOeufs.rbxlx` |
| Icône 512×512 | `roblox/publication/art/icon_512.png` |
| Miniatures 1920×1080 (4) | `art/thumb_1_hero_1920x1080.png`, `thumb_2_vol_1920x1080.png`, `thumb_3_pets_1920x1080.png`, `thumb_4_histoire_1920x1080.png` |
| Icônes d'achats 512×512 (6) | `art/pass_coins2x_512.png`, `pass_lucky_512.png`, `pass_fast_512.png`, `product_instanthatch_512.png`, `product_luckpotion_512.png`, `product_coinpack_512.png` |

Régénérer le fichier de place après une modification du code : `python3 roblox/tools/build_place.py`. Régénérer les visuels : `python3 roblox/tools/make_art.py`.

## 1. Fiche du jeu (à copier-coller)

**Titre** (50 caractères max) : `Chipe-Œufs : Vole des Œufs ! 🥚`

**Genre** : Adventure (alternative : Comedy). **Appareils** : coche Ordinateur, Téléphone, Tablette. Ajoute **Console** seulement après avoir testé la manette (menus et prompts non testés à la manette). Laisse VR décoché.

**Description FR** (1000 caractères max) :

```
🥚 Bienvenue dans Chipe-Œufs !

La Grande Couvée s'est brisée : reprends ses œufs, fais-les éclore et deviens Roi des Couvées !

🥚 Chipe des œufs gardés par des chiens... ou à d'autres joueurs
📜 11 chapitres d'histoire, 3 domaines à débloquer, des rangs à gagner
🐣 18 pets, 6 raretés, tailles et mutations (Doré, Néon, Arc-en-ciel, Alien)
📚 Chaque série de 3 espèces découvertes = bonus de revenus définitif
🎁 Pitié : une rareté supérieure garantie à intervalle régulier
💰 Tes pets rapportent des pièces, même quand tu es absent
🏃 Cours sur le tapis pour devenir plus rapide
♻️ Renais pour des bonus permanents
🎯 Missions quotidiennes, classement, événements (Biome Alien, Ruée vers l'or...)
🐾 Fais-toi suivre par tes pets préférés

Attention : un œuf posé dans ta base est protégé quelques secondes, puis les autres joueurs peuvent te le voler !

Probabilités affichées dans le jeu (menu Plus).
```

**Description EN** :

```
🥚 Welcome to Chipe-Œufs!

The Great Clutch is shattered: take back its eggs, hatch them and become King of Clutches!

🥚 Steal eggs guarded by dogs... or from other players
📜 11 story chapters, 3 domains to unlock, ranks to earn
🐣 18 pets, 6 rarities, sizes and mutations (Gold, Neon, Rainbow, Alien)
📚 Every 3 species discovered = permanent income bonus
🎁 Pity: a higher rarity is guaranteed at regular intervals
💰 Your pets earn coins, even while you're away
🏃 Run on the treadmill to get faster
♻️ Rebirth for permanent bonuses
🎯 Daily missions, leaderboard, events (Alien Biome, Gold Rush...)
🐾 Take your favorite pets along with you

Careful: an egg placed in your base is protected for a few seconds, then other players can steal it!

Drop rates are shown in-game (Plus menu).
```

**Serveurs** : Max Players = **10** (= `Config.PLOT_COUNT`). Avatar : R15. Serveurs privés : facultatifs, laisse désactivés au lancement.

## 2. Publier 🖱️

1. Studio → **File > Open from File** → `roblox/build/ChipeOeufs.rbxlx`.
2. Connecte-toi → **File > Publish to Roblox As…** → *Create new experience* → colle titre, description, genre, appareils → **Create**.
3. **Home > Game Settings > Security** : active **Enable Studio Access to API Services** (sauvegarde, classement, annonces multi-serveurs).
4. **Game Settings > Basic Info** : Max Players = 10. **Avatar** : R15.
5. **Playtest** (voir la liste en §5), puis **File > Publish to Roblox** à nouveau.
6. Creator Hub → ton expérience → **Settings** : réponds au questionnaire de maturité, puis **Access > Public**. Ne passe en public qu'après le §5.

## 3. Visuels 🖱️

Creator Hub → ton expérience → **Media** (ou *Basic Settings > Icon / Thumbnails*) :
- **Icône** : `icon_512.png`.
- **Miniatures** : les 4 fichiers `thumb_*`. L'ordre de la première compte le plus (`thumb_1`).
- Roblox modère les images : elles doivent représenter le jeu. Mes visuels sont des illustrations de marque ; après ton playtest, **remplace ou ajoute** 2 à 3 captures d'écran réelles du jeu (les jeux avec de vraies captures sont mieux reçus et évitent un refus).

## 4. Achats intégrés 🖱️

Creator Hub → ton expérience → **Monetization**. Prix = suggestions, à ajuster ; Roblox prélève 30 %.

| Type | Nom | Prix conseillé | Description à coller | Icône |
|---|---|---|---|---|
| Game Pass | Revenus x2 | 199 R$ | Double tous tes revenus de pièces, pour toujours. | `pass_coins2x_512.png` |
| Game Pass | Chance +10% | 149 R$ | Augmente de 10 points tes chances d'obtenir un pet de rareté supérieure. | `pass_lucky_512.png` |
| Game Pass | Éclosion rapide | 149 R$ | Les œufs éclosent 25 % plus vite, pour toujours. | `pass_fast_512.png` |
| Developer Product | Éclosion instantanée | 49 R$ | Fait éclore tous tes œufs tout de suite. | `product_instanthatch_512.png` |
| Developer Product | Potion de chance | 99 R$ | +25 points de chances d'obtenir un pet supérieur pendant 15 minutes. | `product_luckpotion_512.png` |
| Developer Product | Sac de pièces | 99 R$ | Offre 20 minutes de tes revenus (minimum 5 000 pièces). | `product_coinpack_512.png` |

Après chaque création, copie l'**ID** dans `roblox/src/ReplicatedStorage/Config.lua` (`Config.PASSES` et `Config.PRODUCTS`, champ `id`), puis relance `python3 roblox/tools/build_place.py` (ou colle la valeur directement dans le script Config dans Studio) et republie. Tant qu'un ID vaut `0`, l'achat s'affiche « Bientôt » dans le jeu.

**Conformité (important)** : le Pass Chance, la Potion de chance et l'Éclosion instantanée touchent à des tirages aléatoires payés en Robux. Roblox encadre les « Paid Random Items » : il faut afficher les probabilités (c'est fait : menu **Plus** du jeu, texte calculé depuis `Config.lua`) et certaines régions les restreignent. Avant d'activer ces trois achats, lis la politique Roblox sur les objets aléatoires payants. Les passes « Revenus x2 » et « Éclosion rapide » et le « Sac de pièces » ne touchent pas au hasard et ne sont pas concernés. Si tu as un doute, publie d'abord uniquement « Revenus x2 » (laisse les autres ID à 0).

## 5. Liste de playtest avant passage en public

Studio → **Test > Clients and Servers** (2 joueurs). Coche chaque ligne :

- [ ] Au spawn : ta base apparaît, l'œuf de départ éclot en ~6 s ; taper dessus accélère.
- [ ] Vol à Gus : maintenir le bouton prend l'œuf ; la barre de maintien correspond à `stealTime`.
- [ ] Le gardien te poursuit, t'étourdit et te fait lâcher l'œuf (retour au nid).
- [ ] Déposer l'œuf dans ta base le place sur un pad libre et il éclot.
- [ ] Joueur A vole l'œuf de B après la fin de la protection ; B reçoit la notification ; si A meurt, l'œuf revient à B.
- [ ] Le tapis roulant augmente la vitesse seulement quand on court dessus.
- [ ] Achat d'un œuf et d'une amélioration ; l'emplacement supplémentaire se débloque.
- [ ] Vente d'un pet, bouton 🐾 : le pet miniature suit le joueur (et chez l'autre joueur aussi).
- [ ] Missions : progression puis récompense.
- [ ] Histoire : éclosion du 1er œuf, chapitre « terminé » signalé, récompense réclamée dans Missions > Histoire, chapitre suivant affiché.
- [ ] Zones : la barrière rouge de Mara bloque avant le chapitre 3 et devient traversable ensuite ; aucun vol possible avant (même en forçant le passage) ; idem pour Zed au chapitre 6.
- [ ] Introduction : visible pour un nouveau joueur seulement, fermée par le bouton.
- [ ] Bonus de collection et pitié : valeurs cohérentes dans Pets, Boutique et Plus.
- [ ] Sons : sons intégrés audibles (hatch, vol, capture) ; sinon coller des ID dans `Config.SOUNDS`.
- [ ] Monument du Grand Nid et décor : rendu correct, aucun obstacle gênant le tapis roulant.
- [ ] Arrêter la partie puis relancer (API activée) : pièces, pets et améliorations sont restaurés.
- [ ] Achats Robux : **test purchase** de Studio pour chaque produit après avoir collé les ID.
- [ ] Téléphone : émulateur Studio (Test > Device) ; l'UI tient à l'écran, le bouton de vol se touche.
- [ ] Sortie console Studio (View > Output) : aucune erreur rouge pendant 10 minutes.

## 6. Mises à jour ensuite

Modifie le code, lance `python3 roblox/tools/check.py`, régénère le fichier de place, ouvre-le dans Studio, **File > Publish to Roblox**. Les serveurs en cours basculent à la prochaine ouverture ; tu peux forcer l'arrêt des anciens serveurs dans le Creator Hub (*Shut down servers*) pour les mises à jour importantes.
