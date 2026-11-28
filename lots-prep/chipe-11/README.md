# Chipe-Œufs, LOT 11 : bestiaire de 78 espèces (modules purs + patchs minimaux)

Préparé hors de la branche de jeu, sur une copie du commit 91f6907 (lot 15 intégré). Rien n'est publié, aucune clé API.
Spec : `obsidian-studio/Jeux/LOTS_9_PLUS.md` section C (C.1, C.2, C.3) et « Lot 11 » de K ; IDs : `obsidian-studio/Assets/Assets-crees.md` (lots 22 à 26).

## Contenu

| Fichier | Rôle |
|---|---|
| `roblox/src/ReplicatedStorage/Bestiary.lua` | NOUVEAU. 78 entrées (nom, rareté, revenu, emoji, couleur, oreilles, `extra`/`extra2`, `accent`, `glow`, `scale`, `event`, nom du modèle Blender), `SPECIES_TYPE`/`SPECIES_SKILL` finaux (9 types, vocabulaire du lot 12), `SPECIES_TYPE6`/`SPECIES_SKILL6` (vocabulaire actuel de Battle.lua), `ASSET_IDS` (60 IDs Blender, indice -> id), `ASSET_SPECIES` (nom du modèle -> indice), `fallback(idx)`, `speciesOfTier(t)` |
| `roblox/tests/lot11.luau` | NOUVEAU. 55 assertions (voir plus bas) |
| `roblox/tests/run_lot11.py` | NOUVEAU. Lanceur lupa de `lot11.luau` seul (même forme que lot10) : `python3 roblox/tests/run_lot11.py` |
| `patches/*.patch` | 6 patchs unifiés (`patch -p1` depuis la racine contenant `roblox/`, testés avec `--dry-run` puis appliqués sur le commit 91f6907) |

## Brancher (dans cet ordre)

1. Copier `Bestiary.lua`, `lot11.luau`, `run_lot11.py` à leur chemin. Rojo range `src/ReplicatedStorage` sous `ReplicatedStorage.Shared` : `Bestiary` y sera le frère de `Config` (vérifié : `rojo build game.project.json` OK, le module est dans le `.rbxlx`).
2. `patch -p1 < patches/<fichier>.patch` pour chacun :
   - **Config.lua** (`src_ReplicatedStorage_Config.lua.patch`)
     - juste après le `}` qui ferme `Config.PETS` (dernière ligne : `Wyrm astral`) : bloc `do ... end` qui exécute `require(script.Parent:WaitForChild("Bestiary", 10))` dans un `pcall` et remplace `Config.PETS` par `Bestiary.PETS` SEULEMENT si les 18 premières entrées (rareté, nom, revenu) sont identiques à la liste historique ; pose `Config.BESTIARY`. Sinon, ou sans module (tests qui chargent Config seul), la liste de 18 reste : rien ne casse.
     - après la fin de `Config.Assets` (après `blockedClasses = {...},` puis `}`) : `Config.Assets.petsNew[idx] = id` pour les 60 IDs de `Bestiary.ASSET_IDS` (la clé `petsNew = {}` et `petsMaxPartsNew = 40` existaient déjà, prévues au lot 9).
     - `Config.COLLECTION_BASE_COUNT = 18`, `COLLECTION_STEP2 = 6`, `COLLECTION_MAX = 0.8`, et `Config.collectionBonus` réécrite : +5 % par 3 espèces jusqu'à 18 (identique à l'ancienne formule), puis +5 % par 6 espèces de plus, plafond +80 % (78 espèces). Valeurs invalides = 1.
     - `Config.PRICING.EggDivine.timeToAffordCoin` recalibré (voir « Écarts »).
   - **Assets.lua** (`...Assets.lua.patch`) : `loadPets` charge aussi `cfg.petsNew` avec le plafond `petsMaxPartsNew` (40 Parts) ; `cfg.pets` garde la priorité et le plafond 120 pour les 18 anciens.
   - **Battle.lua** (`...Battle.lua.patch`) : les deux lignes `Battle.SPECIES_TYPE = {...}` et `Battle.SPECIES_SKILL = {...}` passent de 18 à 78 valeurs (copie testée de `Bestiary.SPECIES_TYPE6/SKILL6`). Les 18 premières sont inchangées. **Si le lot 12A (nouveau Battle.lua, 9 types) est déjà branché, NE PAS appliquer ce patch** : y coller à la place `Bestiary.SPECIES_TYPE` et `Bestiary.SPECIES_SKILL` (finaux, déjà au vocabulaire du lot 12) ; les tests de `lot11.luau` sur `Battle.SPECIES_*` (bloc « Battle.SPECIES_TYPE / SPECIES_SKILL : 78 valeurs ») devront alors comparer à `SPECIES_TYPE`/`SKILL` au lieu de `*6`.
   - **Builder.lua** (`...Builder.lua.patch`, `Builder.pet`) : rayon du repli multiplié par `def.scale` (borné 0,7 à 1,3 ; 1 par défaut) ; le bloc « extras » devient `applyExtra(def.extra)` puis `applyExtra(def.extra2)` ; accent (`def.accent`) et lumière (`def.glow`) pour `mane`, `horn`, `wings` ; 7 nouveaux extras : `shell`, `wings2`, `heads3`, `segments`, `crystals`, `chains`, `halo` (pièce nommée `PetHalo`, pour ne pas heurter le `Halo` des œufs). Les 18 espèces historiques sont identiques (voir « Exécuté »).
   - **Client.client.lua** (`...Client.client.lua.patch`, ligne 919) : texte du bonus de collection (nouveaux paliers).
   - **tests/run.luau** (`...run.luau.patch`) : branche `lot11.luau` après le bloc du lot 10 ; adapte 5 tests existants (liste dans « Tests existants adaptés »).
3. **Main.server.lua, Data.lua, Rules.lua : aucune ligne à changer** (vérifié par `grep` : aucun `18`, aucun `#Config.PETS` codé en dur ; `dex`, `pets`, défenses PvP stockent l'INDICE d'espèce, stable ; la collection est recalculée par `Config.collectionBonus(s.species)` à chaque fois, donc aucun profil migré ne perd de bonus). Pas de migration de profil : version de données inchangée.
4. Lancer : `python3 roblox/tools/run_tests.py` et `lune run roblox/tests/run.luau` (racine contenant `roblox/`).

## Les 78 espèces (C.2) et leurs revenus (inc)

R1 10 (1, 1,1, 1,25, 1,4, 1,5, 1,6, 1,7, 1,8, 1,9, 2), R2 10 (3,6 à 4,1), R3 10 (7,5 à 15), R4 10 (32 à 70), R5 9 (170 à 420), R6 9 (1 100 à 3 000), R7 8 (9 000 à 26 000), R8 5 (80 000 à 120 000), R9 3 (220 000, 260 000, 300 000), R10 4 (550 000, 650 000, 750 000, 900 000). Tous distincts à l'intérieur d'une rareté, croissants dans l'ordre de la table C.2 pour les nouvelles, dans la fourchette `Config.INCOME_RANGE`, avec le rapport minimal 1,8 entre raretés consécutives (testé sur les espèces réelles).

## Résultat des tests dans la copie de travail (Exécuté)

| Commande | Résultat |
|---|---|
| état de départ (commit 91f6907) : `python3 roblox/tools/run_tests.py` et `lune run roblox/tests/run.luau` | 3239 réussis, 0 échoué (les deux) |
| avec le lot 11 : `python3 roblox/tools/run_tests.py` | **3294 réussis, 0 échoué**, code 0 |
| avec le lot 11 : `lune run roblox/tests/run.luau` | **3294 réussis, 0 échoué** (3239 + 55) |
| `python3 roblox/tests/run_lot11.py` (lot11 seul) | 55 assertions réussies, 0 échec |
| `rojo build game.project.json` | OK (Bestiary présent) |
| `stylua --check` | `Bestiary.lua` et `lot11.luau` propres ; Config, Battle, Assets, Builder, Client, run.luau échouaient DÉJÀ avant (non enforcé dans le projet) |
| Comparaison ponctuelle ancien / nouveau Builder (script jetable, runtime factice) : 18 espèces x 5 tailles x 6 mutations = 540 pets, nom, classe et toutes les propriétés de chaque Part | 0 différence |
| `selene` | non lancé (std roblox indisponible hors ligne) |

Les 55 assertions de `lot11.luau` couvrent : 78 espèces, indices 1 à 18 identiques (nom, rareté, revenu, emoji, couleur, repli) ; garde-fou si les 18 premières entrées dérivent ou si le module est trop court (retour aux 18) ; répartition 10-10-10-10-9-9-8-5-3-4 ; chaque rareté >= 3 espèces publiées (Exclusif >= 1), 10 raretés publiées ; revenus dans `INCOME_RANGE`, croissance 1,8 entre raretés, aucun doublon, croissance intra-rareté ; >= 3 types par rareté ; types finaux (Feu 9, Eau 10, Plante 7, Glace 10, Foudre 10, Terre 8, Ciel 6, Ombre 8, Lumière 10) et 6 changements de C.1 ; `Battle.SPECIES_*` à 78 valeurs avec les 18 premières inchangées, `Battle.unit` valide pour les 78, puissance de combat croissante par rareté, 300 combats aléatoires mixtes sans erreur ; 60 IDs Blender uniques (indices 19 à 78), correspondance asset -> espèce, `Config.Assets.petsNew`, `Assets.loadPets` (plafond 40 Parts pour les nouveaux, 120 pour les anciens, repli si permission refusée) ; collection (identique à l'ancienne jusqu'à 18, 24 -> +35 %, 78 -> +80 %, plafond, jamais en baisse de 0 à 120, valeurs invalides) ; `Rules.rollPet` : chaque espèce de chaque rareté sort ; chaque espèce a un repli valide ; vrai `Builder.pet` (runtime factice) : 78 espèces x 3 tailles x 3 mutations sans erreur, corps et extras présents, <= 60 Parts, les 18 historiques sans nouvel extra.

## Tests existants adaptés (conséquence normale des 78 espèces)

Dans `tests/run.luau`, les tests qui passent par le serveur factice voient maintenant 78 espèces (le module est dans l'arborescence) et 10 raretés publiées. 6 échecs apparus au premier essai, corrigés ainsi :
1. « Base : des éclosions successives... » et « Base : le score atteint est sauvegardé... » : supposaient 3 Communs (doublons revendus, emplacements libérés) ; le scénario tourne maintenant avec un roster restreint aux 18 historiques (`cfg.PETS` temporaire).
2. « Inventaire : onglet Index » : compare à `#cfg.PETS` du serveur factice (78) et non au Config nu (18).
3. « Panneau du tapis (e2e) » : compare à `beltOddsText` de la config du serveur factice (raretés publiées : plus de report de poids).
4. « Œuf Secret (Robux) : aucune espèce Secret publiée » : roster restreint aux 18 pendant ce scénario (le bestiaire publie 5 Secrets).
5. « Types : 18 espèces, 3 par type... » : `Battle.SPECIES_TYPE` compte 78 valeurs ; la règle « 3 par type, triangle par rareté » ne porte plus que sur les 18 premières.
6. « Règle (3) EggDivine » : le nouveau plafond de collection ralentit la projection à 30 jours ; `Config.PRICING.EggDivine.timeToAffordCoin` recalibré avec `python3 roblox/tools/sim_economy.py prix` : beginner 705120 -> 687360 (-2,5 %), mid 669420 -> 651900, advanced 395520 -> 406560. Les rapports restent dans 4 à 12 x le temps Robux.

## Écarts avec la spec

- **Revenus** : la spec A.4 donne R1 1 à 2,8 et R9 50 à 70 k < R8. Le code (lot 9) impose `Config.INCOME_RANGE` testé (R1 1 à 2, R2 3,6 à 4,1, R9 220 à 300 k, R10 550 à 900 k) : les revenus de la table C.2 ont été ramenés dans ces fourchettes en gardant leur ordre. Conséquence assumée : l'Exclusif (R9) rapporte plus que le Secret (R8), contrairement au texte de A.4 (« moins rentable ») ; à trancher côté design (changer `INCOME_RANGE` + `PRICING`). Chat reste à 7,5 (valeur existante, la spec dit 6). Caméléon 47 (spec 45 : doublon avec Hibou).
- **Types / compétences** : `Battle.lua` actuel ne connaît que 6 types et 6 compétences (Nature, pas Plante ; ni Terre, Glace, Foudre ; ni freeze, bulwark, chain). Le patch Battle utilise donc une projection (Plante et Terre -> Nature, Glace -> Eau, Foudre -> Ciel ; freeze -> stun, bulwark -> guard, chain -> strike) ; les 18 premières valeurs sont inchangées (les 6 changements de type de C.1 ne sont appliqués qu'au lot 12 via `Bestiary.SPECIES_TYPE`). Sans cette projection, `BattleUi` plante (emoji de type nil).
- **Taille** : « taille » = `scale` du repli procédural (0,8 à 1,3, absent = 1) ; les modèles Blender sont mis à l'échelle par `Assets.fitHeight`.
- **Emoji** : choisis au plus proche (pas d'emoji morse : 🦦 ; anguille 🐟) ; sans séquences ZWJ. Cosmétique, modifiables sans risque.
- **Espèces R9 (événement)** : `event` = halloween / noel / saison1 (documentaire). `Rules.rollPet` tire aujourd'hui uniformément parmi les 3 ; le filtrage par événement relève du lot 15 / des offres.
- **Plafond de Parts** : les modèles Blender ont un plafond de 40 Parts (`petsMaxPartsNew`) ; un modèle plus lourd est refusé et le pet reste procédural (repli automatique, aucun crash). Le nombre réel de Parts des 60 modèles n'est pas connu ici (Assets-crees.md ne le donne pas pour tous).

## Non fait (hors périmètre de cette préparation)

Interface du bestiaire (filtres par rareté et type, silhouettes), `tools/blender_check.py`, `BLENDER_REQUESTS.md`, protocole C.3 (rendu, FPS mobile, vote B/L : exige Blender et Studio), tests de l'Index client avec 78 espèces en grille.

## À tester dans Studio

1. Démarrer le jeu : Sortie sans erreur ; `#Config.PETS` = 78 (serveur ET client, via la console : `require(game.ReplicatedStorage.Shared.Config).BESTIARY ~= nil`). Si le client affichait 18, c'est que `WaitForChild("Bestiary")` a expiré : à signaler.
2. Acheter un œuf Peu commun (rareté 2, 300 pièces) : une des 10 espèces R2 sort, son modèle Blender s'affiche ; mettre `Config.Assets.Enabled = false` : le repli procédural s'affiche (carapace pour la tortue, 3 têtes pour l'hydre, halo pour le Séraphin-lion...). Contrôler à l'œil : pas de pièce qui traverse le corps, étiquette bien placée au-dessus du pet, tailles `scale` cohérentes (Titan, Baleine, Escargot).
3. Hatch Secret / Divin via `Config.Debug.forceHatch` (si présent) : les 5 Secrets et les 4 Divins apparaissent, animation d'éclosion sans erreur.
4. Profil ancien (18 espèces découvertes) : onglet Index `x/78`, bonus de collection inchangé à +30 %, puis +35 % dès la 24ᵉ espèce ; un profil v12 complet se connecte sans perte de pets ni de revenus.
5. Arène des pets : une équipe contenant un Hérisson, une Souris ou un Léopard des neiges lance ses attaques (types projetés) sans erreur ; les anciens pets gardent leurs types.
6. Modèles Blender de plus de 40 Parts : Sortie affiche l'entrée refusée (`Config.Debug.AssetReport`), le pet reste procédural.
7. Mobile : 15 pets suiveurs de la nouvelle série + 20 en base, FPS >= 30 (protocole C.3 point 5).
