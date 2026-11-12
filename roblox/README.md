# Chipe-Œufs : version Roblox

Jeu multijoueur Roblox complet (serveur + client + monde), écrit en Luau, sans aucun asset externe : tout le visuel est généré avec des Parts, matériaux, `PointLight`, `ParticleEmitter` et une UI construite par code.

## Boucle de jeu

1. Chaque joueur a une **base** (12 emplacements, 4 au départ) qui produit des pièces via ses pets.
2. Au **nord**, 3 rivaux PNJ (Gus ★, Mara ★★, Zed ★★★) gardent des nids d'œufs. Tu **maintiens le bouton de vol** (ProximityPrompt) pour prendre un œuf. Leur **gardien** te prend l'œuf et t'étourdit s'il t'attrape.
3. Tu **rapportes l'œuf** dans ta base : il éclot (timer basé sur `os.time()`, donc il éclot aussi hors-ligne). Tape dessus pour accélérer.
4. Un pet a une **rareté** (6 niveaux), une **taille** (Mini → Colossal) et peut **muter** (Doré, Néon, Arc-en-ciel, Alien). Revenus = base × taille × mutation × bonus.
5. Le **tapis roulant** (centre) donne de la vitesse tant que tu cours dessus, pour échapper aux gardiens.
6. **PvP** : les autres joueurs peuvent voler tes œufs en cours d'éclosion. Un œuf fraîchement posé est protégé 20 s (extensible avec l'amélioration Verrou). Si le voleur meurt ou se fait attraper par un gardien, l'œuf revient à son propriétaire.
7. Boutique d'œufs, 8 améliorations, **renaissance** (+50 % de revenus définitif), bonus quotidien, **événements serveur** (Biome Alien, Ruée vers l'or, Pluie de chance, Marathon), Game Passes (Revenus x2, Chance +10 %).
8. **Missions quotidiennes** (3 par jour, récompense proportionnelle à ton revenu), **classement global** (renaissances puis œufs éclos), **annonces sur tous les serveurs** quand quelqu'un obtient un pet Cosmique, Colossal ou Alien.
9. **Pets suiveurs** : jusqu'à 3 pets miniatures te suivent (bouton 🐾 dans Pets > Ma base), visibles par tous.
10. **Éclosion spectaculaire** : œuf qui tremble les 4 dernières secondes, explosion de particules et flash lumineux (plus gros pour les raretés élevées), flash d'écran et secousse de caméra pour Mythique/Cosmique, sons si tu colles des ID.
11. **Guidage** : un faisceau jaune indique le prochain objectif (nid à voler, tapis, ou ta base quand tu portes un œuf).
12. **Sauvegarde sûre** : DataStore avec **verrou de session** (un joueur ne peut pas être chargé sur 2 serveurs en même temps), 8 tentatives au chargement, autosave 60 s, verrou libéré au départ.

## Énigmes et succès (v4)

- **Énigme des runes** : quatre runes entourent le Grand Nid (Nord = côté des rivaux). Chaque jour, le Gardien énonce un indice par direction (panneau près du Nid et onglet Missions > Énigme) ; il faut régler chaque rune sur le bon symbole (🔥 🌊 🌿 ⭐) puis toucher le Nid pour valider. Récompense : un œuf Épique et des pièces, une fois par jour. Une mauvaise combinaison impose une pause de 6 s (pas d'essai au hasard en boucle). L'énigme (24 ordres × 3 formulations par indice) est la même pour tous les joueurs un jour donné, générée de façon déterministe dans `Config.riddleFor`, donc testable. L'état des runes est propre à chaque joueur (symboles affichés localement).
- **Succès à paliers** (Collection > Succès) : Éleveur, Chipeur, Collectionneur, Renaissant, Déchiffreur, 4 paliers chacun, récompense en pièces (au moins un plancher fixe, ou des minutes de revenus). Pastille de notification quand un palier est prêt.
- **Histoire** : un 12e chapitre (« Le murmure des runes ») est inséré en position 8.
- **Données** : version 4 du schéma (migration depuis v1, v2, v3 : qui avait déjà réussi 8 chapitres ou plus est décalé d'un cran pour ne rien refaire).

## Univers et progression (v3)

- **Identité** : le Royaume des Couvées. La Grande Couvée s'est brisée ; tu es un apprenti Chipeur qui reconstruit le **Grand Nid** (monument doré au centre de l'arène). Texte dans `Config.LORE`, introduction affichée aux nouveaux joueurs.
- **Histoire** : 12 chapitres (`Config.STORY`), de « L'œuf d'argent » à « Le Grand Nid s'éveille ». Chaque chapitre a un objectif, un texte et une récompense (proportionnelle à ton revenu). Onglet Missions > Histoire.
- **Zones à débloquer** : le domaine de Mara s'ouvre au chapitre 3, la citadelle de Zed au chapitre 6 (`Config.ZONES`). Barrière rouge visible, traversable localement une fois la zone ouverte ; le **serveur refuse tout vol** dans une zone verrouillée, et leurs gardiens ignorent les joueurs qui n'y ont pas accès.
- **Rangs** : Apprenti, Chipeur, Maître Chipeur, Seigneur des Couvées, Roi des Couvées (affichés sur la base et dans le classement).
- **Collection** : +5 % de revenus définitifs tous les 3 espèces découvertes (max +30 %).
- **Pitié** : après 12 éclosions sans rareté supérieure, la suivante l'est garantie.
- **Sons** : sons intégrés au client Roblox par défaut (vol, éclosion, capture, récompense, clic), remplaçables dans `Config.SOUNDS`.
- **Achats Robux** : Game Passes Revenus x2, Chance +10 %, Éclosion rapide (-25 % de temps) ; produits Éclosion instantanée, Potion de chance, Sac de pièces. Aucun n'est nécessaire pour progresser (l'histoire, les zones et les rangs sont gratuits).
- **Données** : version 3 du schéma (devenue la version 4, voir plus haut).

## Passe graphique et robustesse (v2)

- **Ambiance** : soleil chaud, brume, bloom, rayons de soleil, étalonnage plus vif ; collines à l'horizon, murs invisibles, fleurs, rochers, arbres à trois feuillages.
- **Monde** : palissades et torches aux couleurs des rivaux, drapeaux, nids garnis de paille, tapis avec rails néon et **rayures animées**, bases de joueurs à couleur propre avec lampadaires, liseré néon et **pads encadrés**, panneau de nom en bois.
- **Pets** : reflets dans les yeux, joues, pieds, étincelles dorées de production.
- **Animations** : œuf qui tremble puis blanchit avant d'éclore, onde de choc + particules, pet qui apparaît en grossissant, œuf qui s'envole vers le joueur à la récolte, effets au dépôt.
- **HUD** : pastilles dégradées avec contour, « +X » flottant et pulsation lors d'un gros gain, toasts colorés par type, fenêtre d'éclosion avec rareté en étoiles, retour tactile des boutons.
- **Données** : champ de version `ver` avec migrations, valeurs assainies, niveaux bornés, sauvegarde sans chevauchement avec 3 tentatives, verrou libéré sur toutes les sorties.
- **Règles pures** (`Rules.lua`) : tirages, revenus, capacités, durées. Correctif : la part « rareté supérieure » est plafonnée à 70 % (avec Trèfle 10 + événement + Pass + Potion elle atteignait 87 % et rendait le poids « identique » négatif).
- **Serveur** : actions protégées par `pcall`, vitesse attendue calculée côté serveur, balayage des gardiens limité.

Voir `tools/VERIFICATION.md` pour ce qui est exécuté, relu ou à tester.

## Publication

Tout est prêt dans **`publication/LISTING.md`** : fiche du jeu FR/EN à copier-coller, étapes Studio / Creator Hub, tableau des achats intégrés, liste de playtest. Visuels dans `publication/art/` (icône, 3 miniatures, 4 icônes d'achats). Le fichier de place à ouvrir dans Studio est `build/ChipeOeufs.rbxlx`.

Outils : `python3 tools/check.py` (contrôle automatique à lancer après chaque modification), `python3 tools/build_place.py` (régénère la place), `python3 tools/make_art.py` (régénère les visuels).

## Structure

```
roblox/
├─ default.project.json                      ← projet Rojo
└─ src/
   ├─ ReplicatedStorage/Config.lua           → ReplicatedStorage > Shared > Config   (ModuleScript)
   ├─ ServerScriptService/Main.server.lua    → ServerScriptService > Main            (Script)
   ├─ ServerScriptService/Data.lua           → ServerScriptService > Data            (ModuleScript)
   ├─ ServerScriptService/Builder.lua        → ServerScriptService > Builder         (ModuleScript)
   ├─ ServerScriptService/Rules.lua          → ServerScriptService > Rules           (ModuleScript, règles pures testées avec Lune)
   └─ StarterPlayerScripts/Client.client.lua → StarterPlayer > StarterPlayerScripts > Client (LocalScript)
```

## Installation

### Option A : Rojo (recommandé)
1. Installe [Rojo](https://rojo.space) (CLI + plugin Studio).
2. Dans `roblox/` : `rojo serve`, puis dans Studio (place vide, template **Baseplate**) clique **Connect** dans le plugin Rojo.
3. Lance **Play**.

### Option B : copier-coller dans Studio (sans outil)
Crée les 5 scripts ci-dessus **avec exactement ces noms et types**, puis colle le contenu de chaque fichier. Dans `ReplicatedStorage`, crée d'abord un `Folder` nommé `Shared` et mets-y le ModuleScript `Config`.

## Publier

1. Studio → **File > Publish to Roblox**.
2. **Game Settings > Security** : active **Enable Studio Access to API Services** (pour tester la sauvegarde) et laisse **Allow HTTP Requests** désactivé (inutile).
3. **Game Settings > Basic Info > Max Players** : mets `10` (= `Config.PLOT_COUNT`). Pour plus de joueurs, augmente `PLOT_COUNT` ; les bases sont placées en cercle (rayon 170) et le terrain fait 620 studs, au-delà de ~14 bases il faut agrandir `radius` et le sol dans `Builder.lua`.
4. **Game Settings > Avatar** : laisse R15. **Basic Info** : remplis l'âge via le questionnaire de maturité (obligatoire pour publier en public).
5. Crée une **icône** (512×512) et 3 captures d'écran : c'est ce qui fait cliquer, bien plus que le code.
6. Passe le jeu en **Public**.

## Game Passes (monétisation)

1. create.roblox.com → ton expérience → **Monetization > Passes** → crée « Revenus x2 » et « Chance +10 % ».
2. Copie chaque ID dans `Config.PASSES` (`id = 123456789`) dans `Config.lua`. Tant que l'ID vaut `0`, le pass est affiché « Bientôt » et inactif.
3. Test : un pass acheté s'active tout de suite (`PromptGamePassPurchaseFinished`) et à chaque reconnexion.

## Produits Robux ponctuels et sons

- **Developer Products** : crée « Éclosion instantanée » et « Potion de chance » (Monetization > Developer Products), colle les ID dans `Config.PRODUCTS`. Les achats sont idempotents (les reçus sont mémorisés 30 jours) et la sauvegarde est forcée avant de valider l'achat.
- **Sons** : cherche des sons dans le Creator Store, copie leur ID (`rbxassetid://…`) dans `Config.SOUNDS` (`hatch`, `rare`). Vide = silencieux.
- Pour tester le classement et les annonces multi-serveurs en Studio : Game Settings > Security > **Enable Studio Access to API Services**.

## Réglages d'équilibrage (tout dans `Config.lua`)

| Quoi | Où |
|---|---|
| Prix et temps d'éclosion des œufs | `EGG_PRICE`, `HATCH` |
| Pets, revenus, apparence | `PETS` (couleur, oreilles, extra : `beak`, `tail`, `mane`, `horn`, `wings`, `tentacles`, `antenna`) |
| Probabilités de taille et de mutation | `SIZES`, `MUTS` |
| Difficulté des gardiens (studs/s ; le joueur démarre à 16) | `RIVALS[i].guardSpeed`, `patrolSpeed` |
| Événements (durée, fréquence) | `EVENTS`, `EVENT_DURATION`, `EVENT_GAP` |
| Protection anti-vol d'un œuf posé | `SHIELD_BASE`, `SHIELD_PER_LEVEL` |
| Coût des améliorations et de la renaissance | `UPGRADES`, `rebirthCost` |

## Ce qui est vérifié, et ce qui ne l'est pas

Vérifié ici : la syntaxe Luau des 5 fichiers (compilateur Luau) et l'existence de **tous** les noms de classes, propriétés, événements et enums Roblox utilisés (comparés au dump officiel de l'API). Un bug de rendu de l'UI a été trouvé et corrigé à la relecture.

**Non vérifié : aucun lancement dans Roblox Studio.** Je n'en ai pas dans cet environnement. Il faut donc un premier playtest (Studio → **Test > Clients and Servers**, 2 joueurs) pour confirmer notamment : placement des modèles sur les pads, sensation du tapis roulant, vol entre joueurs, pets suiveurs, équilibrage. Ne publie pas en public avant ce test.

Points les plus susceptibles de demander un ajustement au premier test :
- `PromptButtonHoldBegan` côté serveur (anti-triche du vol) : si un vol légitime est refusé, mets `s.holdSeen = false` en permanence dans `Main.server.lua` pour désactiver ce contrôle et préviens-moi.
- Le contrôle de vitesse (`fastTick`) remet un joueur en place s'il dépasse nettement sa vitesse autorisée. Si des joueurs sont « téléportés » à tort (lag, vitesses très élevées), augmente la marge `(hum.WalkSpeed + 16) * dt * 1.4 + 3`.

## Ce qui est fait et ce qui reste

Fait dans le code : playtest guidé (bandeau + faisceau), sauvegarde avec verrou de session, éclosion spectaculaire, pets suiveurs, monétisation douce (2 Game Passes + 2 produits), missions, classement global, annonces multi-serveurs, anti-triche (durée de vol mesurée par le serveur, contrôle de vitesse, validation de toutes les actions).

**Reste à faire, et je ne peux pas le faire à ta place** (il faut Studio, le Creator Hub ou des ressources visuelles) :
1. **Playtest + équilibrage** : mesure le temps pour acheter le 1er emplacement (cible < 90 s), la part de joueurs qui volent un œuf dans les 3 premières minutes, la fréquence des captures par les gardiens. Ajuste `guardSpeed` et les prix.
2. **Vrais modèles 3D** : remplace `Builder.pet` par des `MeshPart` du Creator Store ou de Blender (les pets en Parts sont lisibles mais peu distinctifs sur une vignette).
3. **Sons, icône, miniatures, description** : à créer / choisir sur le Creator Hub. L'icône et les 3 premières secondes de la vignette font cliquer, pas le code.
4. **`StreamingEnabled`** : active-le dans Workspace > Properties (une propriété de Studio, pas modifiable par script) pour les téléphones d'entrée de gamme.
5. **Échanges entre joueurs** : volontairement absents (source d'arnaques). À ajouter seulement avec double confirmation, historique et limite de valeur.
6. **Publicité et mises à jour** : une mise à jour par semaine au début ; teste les Roblox Ads une fois la rétention du jour 1 > 25 %.

## À propos de l'objectif « +1 million d'utilisateurs par jour »

Ce chiffre dépend de la rétention, de l'icône, des recommandations de la plateforme et de la publicité, pas du code. Le code fournit une boucle de jeu éprouvée ; la traction se mesure après publication (tableau de bord Creator Hub > Analytics) et s'améliore par itérations.

## Propriété intellectuelle

Le jeu est original : nom, personnages, modèles et interface sont les miens et n'utilisent aucun asset d'un autre jeu. Il reprend seulement le principe général (voler des œufs, les faire éclore, gagner de l'argent). Ne reprends ni le nom, ni l'icône, ni les modèles du jeu qui t'a inspiré : Roblox retire les copies.
