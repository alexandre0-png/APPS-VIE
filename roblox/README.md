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
8. Sauvegarde DataStore (avec 3 tentatives, autosave 60 s, sauvegarde à la fermeture du serveur).

## Structure

```
roblox/
├─ default.project.json                      ← projet Rojo
└─ src/
   ├─ ReplicatedStorage/Config.lua           → ReplicatedStorage > Shared > Config   (ModuleScript)
   ├─ ServerScriptService/Main.server.lua    → ServerScriptService > Main            (Script)
   ├─ ServerScriptService/Data.lua           → ServerScriptService > Data            (ModuleScript)
   ├─ ServerScriptService/Builder.lua        → ServerScriptService > Builder         (ModuleScript)
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

**Non vérifié : aucun lancement dans Roblox Studio.** Je n'en ai pas dans cet environnement. Il faut donc un premier playtest (Studio → **Test > Clients and Servers**, 2 joueurs) pour confirmer notamment : placement des modèles sur les pads, sensation du tapis roulant, vol entre joueurs, équilibrage. Ne publie pas en public avant ce test.

## Améliorations à faire, par ordre de rentabilité

1. **Playtest + équilibrage** (avant tout). Mesure : temps pour acheter le 1er emplacement (cible < 90 s), part de joueurs qui volent un œuf dans les 3 premières minutes, et fréquence des captures par les gardiens. Ajuste `guardSpeed` et les prix en conséquence.
2. **Sauvegarde sûre** : remplace `Data.lua` par **ProfileStore** (verrou de session). `SetAsync` sans verrou peut perdre ou dupliquer des données si un joueur change de serveur très vite.
3. **Éclosion spectaculaire** : le moment « œuf → pet » fait la rétention. Ajoute un son (assets du Creator Store : ID à coller), un tremblement de l'œuf, un flash et un `ParticleEmitter` plus gros pour les raretés ≥ Légendaire. Le code actuel n'a qu'une fenêtre UI.
4. **Pets qui te suivent** : équiper 1 à 3 pets qui marchent derrière le joueur (très demandé sur Roblox, et c'est ce que les autres voient en premier).
5. **Vrais modèles 3D** : remplace `Builder.pet` par des `MeshPart` du Creator Store ou de Blender. Les pets en Parts sont lisibles mais ne sont pas distinctifs sur une vignette.
6. **Monétisation (sans agressivité)** : produits développeur « Éclosion instantanée », « Potion de chance 15 min », « Auto-éclosion », VIP, serveurs privés. Garde le jeu jouable gratuitement : les jeux qui bloquent la progression perdent leurs joueurs.
7. **Rétention** : missions quotidiennes, classement global (`OrderedDataStore`), annonce serveur quand quelqu'un obtient un pet Cosmique (`MessagingService`), événements planifiés à heure fixe (week-end) pour créer un rendez-vous.
8. **Échanges entre joueurs** : très rétentif mais source d'arnaques. À ajouter seulement avec confirmation à double validation, historique et limite de valeur.
9. **Anti-triche** : le serveur valide déjà distances, capacité du sac, cadence des actions et propriété des œufs. À ajouter : vérifier la vitesse réelle (`WalkSpeed` et déplacement) et mesurer la durée réelle du maintien du bouton de vol (aujourd'hui le temps de maintien est géré côté client, un tricheur peut le raccourcir).
10. **Performance mobile** : active `StreamingEnabled`, limite les `BillboardGui` (déjà `MaxDistance = 70`), réduis les particules sur appareils faibles.
11. **Onboarding** : flèches `Beam` qui guident vers l'œuf, le rival 1 puis le tapis. Aujourd'hui le tutoriel est un bandeau de texte.
12. **Découvrabilité** : titre, icône, miniature et 1ʳᵉ minute de jeu comptent plus que tout. Prévois des mises à jour régulières (une par semaine au début) et teste les Roblox Ads une fois le jeu rétentif (rétention J1 > 25 % avant d'investir).

## À propos de l'objectif « +1 million d'utilisateurs par jour »

Ce chiffre dépend de la rétention, de l'icône, des recommandations de la plateforme et de la publicité, pas du code. Le code fournit une boucle de jeu éprouvée ; la traction se mesure après publication (tableau de bord Creator Hub > Analytics) et s'améliore par itérations.

## Propriété intellectuelle

Le jeu est original : nom, personnages, modèles et interface sont les miens et n'utilisent aucun asset d'un autre jeu. Il reprend seulement le principe général (voler des œufs, les faire éclore, gagner de l'argent). Ne reprends ni le nom, ni l'icône, ni les modèles du jeu qui t'a inspiré : Roblox retire les copies.
