# Chipe-Œufs (Jeu 2) : suite de la refonte, lots 9 à 16

Destinataire : la session de développement du jeu (`roblox/`, lieu de partie 87012762353093, hub 115261336085924, univers 10776613087).
Complète `obsidian-studio/Jeux/REFONTE_CHIPE_OEUFS.md` (lots 1 à 8) sans le répéter. Prérequis : lots 1 à 8 livrés, profil **v10** (lot 5). Ce document crée le profil **v11**.
Sources lues : cahier lots 1-8, `Config.lua` (PETS, TIERS, EGG_PRICE, HATCH, SIZES, MUTS, BELT, TERR, RIVALS, TOWER, PVP, PASSES, PRODUCTS, REVEAL, AURA, Assets), `Battle.lua`, `Reveal.lua`, `Rules.lua`, `Data.lua` (v9 dans l'arbre lu), `BLENDER_REQUESTS.md`, 4 images de l'utilisateur (10 œufs, créatures et effets).

Conventions : rareté = indice 1..10 (`r`) ; « R5 » = Légendaire ; % = pourcentage affiché au joueur ; « revenus de N min » = `income(s) × 60 × N` ; jour = `os.time() // 86400` (00:00 UTC) ; semaine = `(jour + 3) // 7` (lundi) ; tous les tirages au serveur ; toute nouvelle table a son test « somme = 100 ± 0,01 ».

### 0. Constats qui conditionnent la suite

| Sujet | État actuel (code lu) | Décision |
|---|---|---|
| Raretés | 6 (`Config.TIERS` Commun..Cosmique), l'œuf annoncé fixe la rareté, +1 cran possible (5 % + bonus, plafond 70, `Rules.MAX_UP`) | 10 raretés. Le principe « l'œuf annoncé fixe la rareté » est **conservé** (honnête, déjà affiché). |
| Compteur « 1 sur N » | Existe déjà : `Reveal.oneIn` (probabilité *conditionnelle à l'œuf*) + `Config.fmtOdds` ; utilisé pour l'effet « secret » (`REVEAL.secret.oneInAtLeast = 20000`) | Ajout d'un compteur **de référence** stable (B.1), stocké par pet. `Reveal.oneIn` reste pour la ligne secondaire. |
| Espèces | 18, toutes avec modèle Blender (`Config.Assets.pets[1..18]`), types fixés par `Battle.SPECIES_TYPE` | Indices 1-18 **inchangés** (dex, défenses PvP, modèles). Nouvelles espèces 19 à 78. |
| Combat | `Battle.lua` pur : 6 types (2 triangles), compétence par espèce avec recharge `cd`, stats `60×1,45^(t-1)` | Charge de 5 coups, 9 types, matrice à 2 niveaux, stats par table (D). |
| PvP | Asynchrone (défense enregistrée, `ChipeOeufs_Pvp_v1`, trophées, saisons 7 j, 10 combats/j) | Conservé comme mode classé par défaut ; ajout duel local et file en ligne (E). |
| Serveurs | 5 joueurs max par partie, serveurs réservés déjà utilisés (hub → partie, mode Château) | Le PvP en ligne réutilise ce mécanisme (serveur réservé `serverMode = "arena"`). |
| Seuils codés en dur | `def.tier >= 4` etc. dans `Main.server.lua` (l. 874, 878, 897, 2085), `Belt.lua` (157, 172), `Animations.client.lua` (553), `Cinematics.client.lua` (508, 598), `Client.client.lua` (418, 427), `VfxKit.lua` (88-96), `CinematicKit.lua` (46, 51) | Tous remplacés par `Config.TIER_GATE` (A.7). Un test `grep` interdit `tier >= <chiffre>` hors Config. |
| Logo dans l'image des œufs | Les œufs de référence portent le logo carré Roblox | **Ne pas reproduire le logo Roblox** (marque déposée) : remplacé par l'emblème du jeu, une rune-œuf (A.5). |

---

## A. Œufs, raretés, pourcentages, contenus

### A.1 Les 10 raretés (`Config.TIERS`, 10 entrées)

| r | Nom | Couleur principale | Couleur 2 | Spécial affichage | Ancienne rareté migrée |
|---|---|---|---|---|---|
| 1 | Commun | `DCDCE6` gris-blanc | `8E93A0` | — | Commun (1) |
| 2 | Peu commun | `3CDC3C` vert | `1E8C28` | — | (nouvelle) |
| 3 | Rare | `2E8BFF` bleu | `1450B4` | — | Rare (2) |
| 4 | Épique | `9B4DFF` violet | `4A1A8C` | — | Épique (3) |
| 5 | Légendaire | `FFC21A` or | `B8860B` | couronne | Légendaire (4) |
| 6 | Mythique | `E0202E` rouge | `1A1014` noir | chaînes | Mythique (5) |
| 7 | Ultra Rare | `6FD6FF` cristal | `2A7FD4` | facettes | Cosmique (6), renommée |
| 8 | Secret | arc-en-ciel (`rainbow = true`) | `0A0A12` | étoiles | (nouvelle) |
| 9 | Exclusif | `F2F2F2` blanc | `141414` noir | couronne noire | (nouvelle, événements) |
| 10 | Divin | `FFF3B0` nacre | prisme | ailes + auréole | (nouvelle) |

`Config.TIER_MIGRATE = { 1, 3, 4, 5, 6, 7 }` (ancien indice → nouveau). Les noms des raretés migrées sont conservés (aucun joueur ne voit son « Rare » devenir « Peu commun »). Les pets Cosmiques deviennent « Ultra Rare » et reçoivent le titre permanent « 🌌 Ancien Cosmique » (`titles.oldCosmic = true`).

`Config.RARITY_BANNERS` est refait sur les couleurs ci-dessus (les bandeaux actuels jaune/vert/rouge contredisent l'image de l'utilisateur).

### A.2 Apparition des œufs par source (en %, ordre r1..r10)

| Source (clé) | C | PC | R | É | L | M | UR | S | Ex | D |
|---|---|---|---|---|---|---|---|---|---|---|
| Tapis standard `BELT.weights.normal` | 50 | 25 | 14 | 7 | 2,9 | 0,85 | 0,2 | 0,04 | 0 | 0,01 |
| Tapis doré `BELT.weights.golden` | 32 | 26 | 20 | 12 | 6,5 | 2,5 | 0,75 | 0,2 | 0 | 0,05 |
| Enclos sauvage `TERR.wild.weights` | 100 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Gus `TERR.gusNW/gusSW.weights`, `RIVALS[1]` | 45 | 35 | 17 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| Mara `TERR.mara.weights`, `RIVALS[2]` | 0 | 10 | 35 | 37 | 18 | 0 | 0 | 0 | 0 | 0 |
| Zed `TERR.zed.weights`, `RIVALS[3]` | 0 | 0 | 0 | 30 | 45 | 22 | 2,4 | 0,5 | 0 | 0,1 |

Justification : la colonne Zed garde l'ancienne part du sommet (3 % Cosmique → 2,4 + 0,5 + 0,1 = 3 %). Tapis : la rareté est visible avant achat et le prix (A.4) fait barrière ; fréquences serveur à 12 œufs/min : Ultra Rare toutes les 42 min, Secret toutes les 3,5 h, Divin toutes les 14 h (événement de serveur, annoncé). Exclusif n'apparaît jamais au tapis ni chez un rival.

**Amélioration d'un cran** (`Config.UPGRADE`) : inchangée (5 + Trèfle + pass 10 + événement 5 + potion 25, plafond 70), avec deux nouvelles bornes : `UPGRADE.maxEggTier = 6` (un œuf Ultra Rare, Secret, Exclusif ou Divin a une rareté fixe) et jamais vers Exclusif. Donc Mythique → Ultra Rare est la plus haute amélioration possible. `Rules.tierWeights` : `up = (tier <= Config.UPGRADE.maxEggTier) and min(upPoints, MAX_UP) or 0`.

### A.3 Contenu de chaque œuf (table affichée dans le menu 🎲 et sur la fiche de l'œuf)

Règle : un œuf de rareté r donne une espèce de rareté r (part `100 - up` %) ou r+1 (part `up` %), l'espèce étant tirée **à poids égaux** parmi les espèces *publiées* (`PETS[i].live = true`) de cette rareté. Exception : la « vedette de la semaine » (G.4) a un poids 2 dans les œufs, pas dans le compteur. Une rareté n'est mise en œuvre (œufs, tapis) que si elle compte ≥ 3 espèces publiées (R9 : ≥ 1, celle de l'événement en cours) ; sinon ses poids sont reportés sur la rareté inférieure et le test le signale.

| Œuf | Part sans bonus | Espèces possibles (indices du bestiaire C) | Chance par espèce (sans bonus) |
|---|---|---|---|
| Commun | 95 % Commun, 5 % Peu commun | 1-3, 19-25 ; 26-35 | 9,5 % chacune ; 0,5 % chacune |
| Peu commun | 95 % PC, 5 % Rare | 26-35 ; 4-6, 36-42 | 9,5 % ; 0,5 % |
| Rare | 95 % Rare, 5 % Épique | 4-6, 36-42 ; 7-9, 43-49 | 9,5 % ; 0,5 % |
| Épique | 95 % É, 5 % L | 7-9, 43-49 ; 10-12, 50-55 | 9,5 % ; 0,556 % |
| Légendaire | 95 % L, 5 % M | 10-12, 50-55 ; 13-15, 56-61 | 10,56 % ; 0,556 % |
| Mythique | 95 % M, 5 % UR | 13-15, 56-61 ; 16-18, 62-66 | 10,56 % ; 0,625 % |
| Ultra Rare | 100 % UR | 16-18, 62-66 | 12,5 % |
| Secret | 100 % S | 67-71 | 20 % |
| Exclusif | 100 % Ex | l'espèce de l'événement en cours (72, 73 ou 74) | 100 % (seules taille et mutation sont tirées) |
| Divin | 100 % D | 75-78 | 25 % |

Le texte affiché est généré par `Config.eggContentText(r, upPoints)` (les bonus actifs du joueur modifient la colonne « part » à l'écran : affichage exact de ce qui sera appliqué).

### A.4 Prix, durée d'éclosion, taille physique, poids de portage, score de maison

| r | `EGG_PRICE` (pièces) | Vendu en boutique (prix plein) | Tapis (×0,6) | `HATCH` (s) | Hauteur de l'œuf (studs) | `CARRY.weight` | `BASE_WEIGHTS` | Revenu/s des espèces |
|---|---|---|---|---|---|---|---|---|
| 1 | 25 | oui | oui | 8 | 1,80 | 1,00 | 1 | 1 – 2,8 |
| 2 | 300 | oui | oui | 12 | 1,90 | 1,00 | 2 | 3 – 5 |
| 3 | 900 | oui | oui | 20 | 2,00 | 1,00 | 4 | 6 – 15 |
| 4 | 20 000 | oui | oui | 45 | 2,10 | 0,95 | 15 | 32 – 70 |
| 5 | 350 000 | oui | oui | 90 | 2,25 | 0,90 | 50 | 170 – 420 |
| 6 | 6 000 000 | non | oui | 180 | 2,40 | 0,85 | 180 | 1 100 – 3 000 |
| 7 | 130 000 000 | non | oui | 300 | 2,55 | 0,80 | 700 | 9 000 – 26 000 |
| 8 | 1 500 000 000 | non | oui | 420 | 2,70 | 0,78 | 2 500 | 80 000 – 120 000 |
| 9 | 0 (jamais en pièces) | non | non | 420 | 2,70 | 0,78 | 2 500 | 50 000 – 70 000 |
| 10 | 30 000 000 000 | non | oui | 600 | 2,90 | 0,75 | 9 000 | 400 000 – 700 000 |

- `Config.Assets.targetHeights` : `eggMin = 1.8`, `eggMax = 2.9` ; `Config.eggHeight(r)` interpole sur `(r-1)/9` (remplace `/5`) ; `EGG_LIMITS` inchangé (l'œuf reste dans le pad).
- Hauteur des pets : `petMin = 1.7`, `petMax = 2.5`, `petHard = 3.4` ; `petTargetHeight(r, scale)` interpole sur `/9`.
- Rentabilité (prix / revenu moyen) : R6 ≈ 50 min, R7 ≈ 2 h, R8 ≈ 4 h (2,5 h au tapis), R10 ≈ 15 h (9 h au tapis). Le Divin est surtout un objet de prestige obtenu chez Zed (0,1 %).
- Exclusif (R9) volontairement **moins** rentable que Secret : un objet d'événement ne doit pas dominer l'économie.
- `BASE_WEIGHTS` : les valeurs migrées restent identiques à la refonte D.1 (Commun 1, Rare 4, Épique 15, Légendaire 50, Mythique 180, Cosmique 700) : aucun niveau de maison ne bouge à la migration.

### A.5 Les 10 œufs visuels (code d'abord, Blender ensuite)

Repli procédural obligatoire : `Config.EggFx.looks` passe à 10 entrées `r1..r10` ; `Config.Assets.eggByTier = { "r1", …, "r10" }`. Emblème commun : une **rune-œuf** (losange creux à pointe arrondie) sur la face avant, pièce `Embleme`, jamais le logo Roblox.

| Clé | Œuf | Coque (couleur, matériau) | Détails construits par le code (Parts, ≤ 24) | Effets client (VfxKit) |
|---|---|---|---|---|
| `r1` | Commun | `DCDCE6` SmoothPlastic, 3 taches `B4B8C4` | Emblème `3A3A42` | aucun |
| `r2` | Peu commun | `3CDC3C`, motif pixel `2EB82E` | Emblème `A8FF8C` | 6 petits cubes verts en orbite lente (0,3 tr/s) |
| `r3` | Rare | `2E8BFF`, motif `1450B4` | Emblème `8CC8FF`, 1 anneau `Anneau` incliné 20° | anneau qui tourne 0,5 tr/s, 4 cubes bleus |
| `r4` | Épique | `4A1A8C` à zébrures `9B4DFF` | Emblème `C89BFF`, 4 cristaux `Cristaux` au pied | éclats violets ascendants 4/s |
| `r5` | Légendaire | `FFC21A` Glass 0 / SmoothPlastic, facettes `E8A800` | Couronne `Couronne__FFD24A` (5 pointes), anneau au sol | anneau doré, étincelles 6/s, PointLight 1,5 |
| `r6` | Mythique | `1A1014` à fissures Neon `FF3020` | Chaîne en diagonale (`Chaine`, 6 maillons Metal `3A3A42`) | braises 8/s, pulsation rouge 1 Hz |
| `r7` | Ultra Rare | `6FD6FF` Glass transparence 0,2, facettes | 6 cristaux `Cristaux__BFEFFF` autour | givre (particules blanches), PointLight bleue |
| `r8` | Secret | `0A0A12` à emblème arc-en-ciel | 2 anneaux `Anneau` croisés, 3 étoiles `Etoiles` | anneaux qui changent de teinte (cycle 4 s), étoiles qui clignotent |
| `r9` | Exclusif | `F2F2F2` à éclats `141414` | Couronne noire `Couronne__141414`, chaîne `3A3A42`, 4 cubes noirs | fumée grise lente, désaturation locale |
| `r10` | Divin | `FFF3B0` Glass prismatique 0,15 | 2 ailes `Ailes__FFFFFF`, auréole `Aureole__FFE680` Neon, 4 cubes dorés | auréole qui flotte (±0,2 stud, 2 s), rayons, PointLight 2 |

Budget : 24 Parts par œuf procédural, 40 par modèle Blender (`eggsMaxParts = 40`). Sur téléphone (`REVEAL.forceReduced` ou tactile) : effets d'orbite coupés au-delà de 6 œufs visibles.

### A.6 Tailles et mutations

- `Config.SIZES` : inchangé (Mini 20 / Normal 62 / Grand 14 / Géant 3,5 / Colossal 0,5 ; mult 0,8 / 1 / 1,5 / 2,5 / 5).
- `Config.MUTS` : ajout d'une 6ᵉ mutation **Céleste** `{ name = "Céleste", mult = 20, weight = 0.1, color = FFF3B0, aura = true }` ; « aucune » passe de 82 à **81,9** (somme 100). Mêmes tables pour tous les œufs (le compteur reste lisible).
- Biome Alien : mutation Alien ×5 (inchangé). Week-end (G.5) : aucune modification des tailles/mutations (seulement la chance d'amélioration).
- `Battle` : `MUT_BONUS[6] = 1.12`. Index de mutation 6 accepté par `Data` (assainissement `m ∈ 1..6`).

### A.7 Migration du profil v10 → v11 (Data.lua) et constantes indexées par rareté

`VERSION = 11`, une étape `MIGRATIONS[10]` :

| Champ | Transformation |
|---|---|
| `slots[i] = { k = "e", t }` | `t = TIER_MIGRATE[t]` ; `ends` conservé |
| `slots[i] = { k = "p", p, s, m }` | espèce inchangée ; ajout `x = 0` (XP, D.6) et `o = Odds.ref(p, s, m)` (B.1) ; `ov = 1` (version de table du compteur) |
| `dex[k]` | ajout `ob` = meilleur `o` de l'espèce trouvé dans les emplacements (0 sinon) |
| `quests[j].re` | `TIER_MIGRATE[re]` si `re > 0` |
| `battle.best` (étage) | `oldTier = 1 + (f-1)//5`, `pos = (f-1)%5`, nouvel étage = `(index de TIER_MIGRATE[oldTier] dans TOWER.tiers - 1) × 5 + pos + 1` (D.7) |
| `titles.oldCosmic` | vrai si `dex` contient 16, 17 ou 18 |
| nouveaux champs (défauts) | `trainer = { xp = 0 }`, `battle.pve = { w = 0, l = 0 }`, `battle.duel = { w = 0, l = 0, day = 0, n = 0 }`, `battle.pvp.live = { w = 0, l = 0 }`, `cal = { month = 0, n = 0, last = 0 }`, `grace = { week = 0, used = false }`, `weekly = { week = 0, prog = {}, claimed = 0 }`, `npc = { day = 0, trades = 0, fights = 0, nextAt = 0, off = false }`, `season = { id = 0, xp = 0, premium = false, free = 0, prem = 0 }`, `boosts = {}` (clé → `until`), `event = { id = "", tok = 0, eggs = 0 }`, `buys = { day = 0, week = 0, month = 0, n = {} }`, `odds = { best = 0, p = 0 }` |

Constantes à étendre à 10 colonnes dans le même commit (test : `#t == 10` pour chacune) : `TIERS`, `EGG_PRICE`, `HATCH`, `BASE_WEIGHTS`, `CARRY.weight`, `RARITY_BANNERS`, `REVEAL.tiers` (10 styles, B.3), `EggFx.looks`, `Assets.eggByTier`, `Assets.eggsByRarity`, `Assets.eggGuardKeys`, `BELT.weights.*`, `TERR.*.weights`, `RIVALS[*].weights`. Valeurs d'indices à remapper : `STARTER_PACK.eggTier 2 → 3`, `EXCLUSIVE_EGG_TIER 5 → 6`, `PUZZLE_EGG_TIER 3 → 4`, `PVP.rewards[*].eggTier {2,3,4,5} → {3,4,5,6}`, `STORY` (`tier = 3 → 4`, `tier = 5 → 6`), `AURA.minTier 4 → 5`, `CARRY.beamTier 4 → 5`, `REMOTE_STEAL.maxTier 4 → 5`, `hatchSoundKey` (B.3).

`Config.TIER_GATE = { announce = 5, aura = 5, pillar = 6, beam = 5, serverBanner = 7, globalBanner = 8, rareCine = 5, belt2s = 5 }` : remplace tous les `tier >= N` listés en section 0.

---

## B. Compteur de rareté et animations

### B.1 Formule du compteur (module pur `ReplicatedStorage/Odds.lua`)

Le compteur affiché sur chaque création est la rareté **de référence** de la combinaison (espèce, taille, mutation), identique pour tous les joueurs, quel que soit l'œuf ou les bonus utilisés (un achat ne « gonfle » jamais le chiffre) :

```
p_ref(p, s, m) = REF[r] / 100  ×  1 / n_r  ×  SIZES[s].weight / ΣSIZES  ×  MUTS[m].weight / ΣMUTS
N = 1 / p_ref
```

- `r` = rareté de l'espèce ; `n_r` = nombre d'espèces publiées de rareté r au moment de l'éclosion.
- `Config.ODDS.REF = { 50, 25, 14, 7, 2.9, 0.85, 0.2, 0.04, 2, 0.01 }` = tapis standard, sauf r9 = **2** (part de l'Exclusif dans l'œuf d'événement, G.5 : 1 espèce, mais pondérée comme si 2 % des œufs d'événement étaient Exclusifs). Cette table ne sert qu'au compteur ; un test vérifie que REF[1..8, 10] = `BELT.weights.normal`.
- Arrondi : `N = math.floor(1 / p_ref + 0.5)` (entier), sauf N < 10 : une décimale.
- Affichage (`Config.fmtOdds`, étendu) : N < 10 → « 1 sur 7,3 » ; N < 10 000 000 → chiffres complets groupés par espace fine insécable : « 1 sur 38 494 » ; 10 M ≤ N < 1 Md → « 1 sur 12,5 M » ; N ≥ 1 Md → « 1 sur 8 Md » (une décimale si < 100 Md).
- Stockage : `slot.o` (entier, calculé par le **serveur** à l'éclosion, jamais recalculé ensuite, même si `n_r` change avec de nouvelles espèces) ; `slot.ov` = version de table (`Config.ODDS.version = 1`) ; `dex[k].ob = max(ob, o)` ; `odds.best/odds.p` = meilleur tirage du profil. Classement « Tirage le plus rare » : OrderedDataStore `ChipeOeufs_Rarest_v1`, clé `userId`, valeur `min(o, 2^53)`.
- Ligne secondaire (écran d'éclosion seulement, gris, petite) : « Dans cet œuf, avec tes bonus : 1 sur N' » = `Reveal.oneIn` existant (probabilité réelle conditionnelle).

Exemples à mettre dans les tests (78 espèces publiées : R3 = 10, R5 = 9, R6 = 9, R10 = 4) :

| Création | Calcul | Affichage |
|---|---|---|
| Chat, Normal, sans mutation | 0,14 × 1/10 × 0,62 × 0,819 = 7,109e-3 | « 1 sur 141 » |
| Requin éclair (R5), Grand, Doré | 0,029 × 1/9 × 0,14 × 0,09 = 4,06e-5 | « 1 sur 24 631 » |
| Loup de glace (R6), Géant, Néon | 0,0085 × 1/9 × 0,035 × 0,05 = 1,6528e-6 | « 1 sur 605 042 » |
| Dragon céleste (R10), Colossal, Céleste | 0,0001 × 1/4 × 0,005 × 0,001 = 1,25e-10 | « 1 sur 8 Md » |

Où l'afficher :
- Carte du pet (inventaire, bestiaire, fiche d'échange PNJ, intro de combat) : toujours, sous le nom, couleur de la rareté.
- Étiquette 3D au-dessus du pet qui suit le joueur ou posé en base : seulement si N ≥ `ODDS.billboardMin = 1000` (évite le bruit visuel), texte 14 px, distance max 60 studs.
- Révélation : le chiffre « compte » de 1 jusqu'à N en 0,8 s (ease out, 12 paliers) puis rebondit ; si N ≥ 100 000 : son `secret` + bandeau « Tirage exceptionnel ».
- `REVEAL.secret.oneInAtLeast` passe sur le compteur de référence : seuil **1 000 000**.

### B.2 Annonces sociales

| Condition | Annonce |
|---|---|
| N ≥ 10 000 ou r ≥ 7 | Message dans le serveur : « ✨ {nom} a fait éclore {Pet} ({1 sur N}) ! » |
| N ≥ 1 000 000 ou r ≥ 8 | Annonce **tous serveurs** via `MessagingService:PublishAsync("ChipeAnnonce", …)`, au plus 1 publication par serveur toutes les 10 s, file locale de 5 ; affichée en bandeau haut 4 s |
| r = 10 | En plus : pilier de lumière visible depuis tout le serveur pendant 30 s au-dessus de la base |

### B.3 Animations d'éclosion (10 variantes, module client `StarterPlayerScripts/HatchFx.lua`, plan pur dans `CinematicKit.hatchPlan(r, N)`)

Toutes : passables (bouton « Passer » après 1,5 s ; non passable la **première** fois qu'un joueur obtient une rareté ≥ 8), version réduite mobile (`REVEAL.reducedFactor`), ≤ 30 Parts et ≤ 40 particules/s, la caméra ne bouge pas si le joueur porte un œuf ou est poursuivi. `Config.hatchSoundKey(r)` : r1-2 `hatch`, r3 `rare`, r4 `epic`, r5-6 `legendary`, r7-10 `hatchSecret` (+ `fanfare` pour r ≥ 8).

| r | Durée | Séquence |
|---|---|---|
| 1 | 1,2 s | l'œuf tremble 0,4 s, pop blanc, 6 rayons, le pet saute |
| 2 | 1,5 s | tremble, 12 cubes verts éclatent en couronne, pet saute + pétales |
| 3 | 2,0 s | l'anneau bleu accélère et se resserre, flash bleu 0,15, 2 anneaux au sol |
| 4 | 2,8 s | cristaux violets jaillissent du sol, secousse 0,25, machine à sous (rareté, taille, mutation) |
| 5 | 4,0 s | une couronne dorée descend et se pose, l'œuf se fend en lumière, 12 rayons, zoom caméra ×1,15, bandeau doré |
| 6 | 5,0 s | fissures de lave, les chaînes se brisent (6 maillons projetés), teinte rouge `ColorCorrection` 0,6 s, secousse 0,6 |
| 7 | 6,0 s | des cristaux poussent autour, givre au sol, l'ensemble éclate en éclats bleus, cercle runique au sol (pattern des images) |
| 8 | 7,0 s | écran noir 0,5 s, « ??? » puis 2 anneaux arc-en-ciel, étoiles, révélation, annonce B.2 |
| 9 | 6,5 s | désaturation totale sauf le pet, couronne noire qui se brise, fumée, bandeau noir et blanc |
| 10 | 9,0 s | les ailes s'ouvrent, auréole qui monte, pilier de lumière jusqu'au ciel, rayons 16, chœur (son à fournir, `SOUNDS.divine`, id vide = silence), annonce mondiale |

Pour r ≥ 5 : cercle runique + aura (`Config.AURA`, `auraStyle` étendu à 10 niveaux : `runes = min(12, 4 + (r-4)×2)`, `pillar = r >= 6`).

### B.4 Début de combat avec ratio victoires/défaites (`StarterPlayerScripts/BattleIntro.lua`)

3,5 s, passable après 1 s :
1. Deux bandeaux glissent depuis les bords (0,4 s) : à gauche le joueur, à droite l'adversaire. Chaque bandeau : portrait (`Players:GetUserThumbnailAsync`, HeadShot 150), nom, ligue (E.4) avec icône, trophées, **« 124 V / 37 D (77 %) »**, 3 vignettes de pets avec icône de type et compteur de rareté.
2. « VS » qui frappe au centre (échelle 2 → 1, secousse 0,3), son `fanfare` à 0,5 de volume.
3. Indication de types : flèche verte « Avantage ×1,5 » ou rouge sous le pet actif quand une relation existe.
4. Décompte 3-2-1 (si le temps de tour réel n'a pas démarré).

Ratio : PvP classé = `battle.pvp.wins/losses` (+ `live.w/l`), duel local = `battle.duel`, PvE = `battle.pve` (ou étage atteint pour la tour). PNJ : ratio fictif fixe par PNJ (« Lina : 312 V / 140 D »). Pourcentage = `floor(100 × V / max(1, V + D) + 0.5)`.

### B.5 Présentation des lieux

- Arrivée sur le serveur (première fois par session) : survol de 5 s (place → tapis → château → arène, `CinematicKit`), bannière « Chipe-Œufs : {nombre} joueurs, événement : {nom} », passable dès 1 s.
- Première entrée dans une zone (`ZONE_BANNERS` existant, étendu) : caméra d'arrivée 2,5 s (plan large puis retour), bannière nom + étoiles + « Œufs ici : jusqu'à {rareté max} » + ratio de vols réussis du joueur dans la zone. Zones : place, tapis, Gus ×2, Mara, Zed, arène, lacs, château.
- Arène (serveur réservé E.3) : plan circulaire de 4 s sur les gradins, bannières des deux joueurs suspendues (couleur de leur ligue).

### B.6 Effets d'attaque par type (`StarterPlayerScripts/TypeFx.lua`, données `Config.TYPE_FX`)

| Type | Attaque de base (0,5 s) | Spécial (1,2 s, cercle runique sous l'attaquant + secousse 0,4) | Couleur |
|---|---|---|---|
| Feu | boule de feu + braises | cône de flammes, sol brûlé 2 s | `FF6A1A` |
| Eau | jet d'eau + éclaboussures | vague circulaire qui balaie | `3C96DC` |
| Plante | 3 feuilles tranchantes | lianes qui sortent du sol et enserrent | `5CB256` |
| Glace | éclats de glace | pics de cristal + givre au sol (image du loup) | `BFEFFF` |
| Foudre | éclair zigzag (`Beam`) | éclair en chaîne, flash 0,1 s | `FFE14A` |
| Terre | rochers qui jaillissent | séisme, poussière, fissures | `9C6B45` |
| Ciel | rafale de plumes | tornade qui soulève l'ennemi | `DDEBFF` |
| Ombre | fumée violette | chaînes violettes (image du démon) | `8A3CFF` |
| Lumière | rayon doré | pilier de lumière + runes en cercle (image du phénix) | `FFE680` |

Texte d'efficacité flottant : « Super efficace ! » (×1,5, vert), « Efficace » (×1,25, vert clair), « Peu efficace » (×0,8, orange), « Pas très efficace… » (×0,67, rouge).

### B.7 Suggestions d'animations supplémentaires (priorisées)

1. Pose de victoire du pet gagnant (saut + étincelles du type) et emote du joueur (cosmétique vendable, H).
2. Montée de niveau d'un pet : anneau ascendant + « Niv. 7 ! » (D.6).
3. Bestiaire : silhouette noire qui se colore à la découverte d'une espèce (0,6 s).
4. Musée des raretés à la maison niveau 6+ : socles qui exposent les 3 meilleurs compteurs du joueur (visible des visiteurs).
5. Réaction des pets proches à un tirage Divin d'un autre joueur (ils se tournent et sautent), cohésion sociale.
6. Coffre de série du jour 7 qui s'ouvre (couvercle `props.chest` existant).

---

## C. Bestiaire (78 espèces, 60 nouvelles)

Colonnes : # = indice dans `Config.PETS` (1-18 existants inchangés) ; type de combat (D.2) ; spécial (D.3) ; couleur dominante (suffixe Blender) ; style : **B** = blocs façon Roblox (arêtes vives, biseau 0,05), **L** = lisse façon Blender (biseau 0,15-0,2, formes arrondies, ombrage peint) ; pose de repos ; pièces ≤ 40 (pièces animées par le code : `Corps`, `Tete`, `Patte_AvG/AvD/ArG/ArD`, `Queue`, `AileG/AileD`, `Machoire`) ; rev/s = `PETS[i].inc` ; lot de production P1-P5 (12 modèles chacun).

Types des 18 existants : inchangés (compatibilité des défenses PvP et des tests existants), sauf indication.

### C.1 Existants (modèles déjà intégrés, à reprendre seulement si le style choisi en C.3 l'exige)

| # | Nom | Rareté | Type | Spécial | Rev/s |
|---|---|---|---|---|---|
| 1 | Poussin | Commun | Ciel | focus | 1 |
| 2 | Hamster | Commun | Ombre | heal | 1,5 |
| 3 | Lapin | Commun | Lumière | guard | 2 |
| 4 | Chat | Rare | Eau | stun | 6 |
| 5 | Chien | Rare | Plante | strike | 8 |
| 6 | Renard | Rare | Feu | drain | 11 |
| 7 | Panda | Épique | Lumière | heal | 32 |
| 8 | Hibou | Épique | Ombre | stun | 45 |
| 9 | Manchot | Épique | Ciel → **Glace** | freeze | 60 |
| 10 | Lion | Légendaire | Feu | drain | 170 |
| 11 | Tigre | Légendaire | Plante | strike | 230 |
| 12 | Licorne | Légendaire | Eau → **Lumière** | heal | 330 |
| 13 | Dragon | Mythique | Ciel → **Feu** | strike | 1 100 |
| 14 | T-Rex | Mythique | Ombre → **Terre** | bulwark | 1 600 |
| 15 | Kraken | Mythique | Lumière → **Eau** | stun | 2 300 |
| 16 | Alien | Ultra Rare | Plante → **Foudre** | chain | 9 000 |
| 17 | Calmar stellaire | Ultra Rare | Eau | heal | 13 000 |
| 18 | Wyrm astral | Ultra Rare | Feu → **Ciel** | focus | 20 000 |

Les 6 changements de type (en gras) rendent les types lisibles (un dragon crache du feu). Ils sont appliqués au lot 12 ; les défenses PvP enregistrées ne stockent que l'espèce, le serveur recalcule le type : aucune migration de données.

### C.2 Nouvelles espèces

| # | Nom | Rareté | Type | Spécial | Couleur | Style | Pose | Pièces | Rev/s | Lot |
|---|---|---|---|---|---|---|---|---|---|---|
| 19 | Souris | Commun | Terre | bulwark | `9E9E9E` | B | assise, oreilles rondes | 14 | 1,2 | P3 |
| 20 | Grenouille | Commun | Eau | heal | `5CB85C` | L | accroupie | 12 | 1,4 | P3 |
| 21 | Canard | Commun | Eau | stun | `F2F2F2` + bec `FFAA28` | B | debout | 12 | 1,6 | P3 |
| 22 | Escargot | Commun | Plante | guard | `C9A66B` coquille `8B5A2B` | L | rampant | 10 | 1,8 | P3 |
| 23 | Bébé phoque | Commun | Glace | freeze | `EDEFF5` | L | couché | 12 | 2,2 | P3 |
| 24 | Abeille | Commun | Foudre | chain | `FFD23F` rayures `1E1E1E` | B | vol stationnaire | 14 | 2,5 | P3 |
| 25 | Coccinelle | Commun | Feu | strike | `D63A3A` points `1E1E1E` | B | posée | 12 | 2,8 | P3 |
| 26 | Tortue | Peu commun | Eau | bulwark | `6F8F3A` carapace `5A3E28` | L | 4 pattes | 18 | 3 | P1 |
| 27 | Cochon | Peu commun | Terre | strike | `F5A0B4` | B | 4 pattes | 16 | 3,2 | P1 |
| 28 | Mouton | Peu commun | Lumière | heal | `FAFAFA` tête `3A3A42` | L | 4 pattes, laine en 5 boules | 18 | 3,4 | P1 |
| 29 | Hérisson | Peu commun | Plante | drain | `8B6A48` piquants `5A3C28` | B | roulé à moitié | 16 | 3,6 | P1 |
| 30 | Chauve-souris | Peu commun | Ombre | drain | `3A2E4A` | B | ailes ouvertes | 14 | 3,8 | P2 |
| 31 | Perroquet | Peu commun | Ciel | focus | `E83A3A` ailes `2E8BFF` `FFD23F` | B | perché | 16 | 4 | P2 |
| 32 | Salamandre | Peu commun | Feu | strike | `FF7A1A` taches `1E1E1E` | L | rampante | 14 | 4,3 | P2 |
| 33 | Lièvre arctique | Peu commun | Glace | freeze | `F5F8FF` | L | assis, longues oreilles | 14 | 4,5 | P3 |
| 34 | Écureuil-étincelle | Peu commun | Foudre | chain | `C8742A` queue `FFE14A` | B | debout sur 2 pattes | 16 | 4,8 | P3 |
| 35 | Castor | Peu commun | Terre | bulwark | `7A4E2A` queue `3A2A1E` | B | 4 pattes | 16 | 5 | P3 |
| 36 | Crocodile | Rare | Eau | drain | `4E7A3A` ventre `C9C08A` | B | couché, gueule entrouverte (`Machoire`) | 22 | 7 | P2 |
| 37 | Cheval | Rare | Terre | strike | `8B5A2B` crinière `2A1E14` | L | debout 4 pattes | 24 | 9 | P2 |
| 38 | Loup gris | Rare | Ombre | stun | `7A7F8C` ventre `D6D6DE` | B | debout | 22 | 10 | P4 |
| 39 | Koala | Rare | Plante | heal | `9E9EA8` | L | assis | 16 | 12 | P4 |
| 40 | Morse | Rare | Glace | bulwark | `8B5A44` défenses `F5EBD7` | L | couché | 18 | 13 | P4 |
| 41 | Aigle | Rare | Ciel | focus | `5A3C28` tête `FAFAFA` | B | ailes mi-ouvertes | 20 | 14 | P4 |
| 42 | Anguille électrique | Rare | Foudre | chain | `2E4A5A` lueurs `FFE14A` | L | ondulée (4 segments) | 12 | 15 | P4 |
| 43 | Ours brun | Épique | Terre | bulwark | `6B4A2E` museau `C9A27A` | B | debout 4 pattes, massif | 22 | 35 | P2 |
| 44 | Requin (d'eau) | Épique | Eau | strike | `5A7FA8` ventre `F2F2F2` | B | bipède comme l'image, vague autour | 24 | 40 | P2 |
| 45 | Caméléon | Épique | Plante | stun | `5CB256` crête `FFD23F` | L | sur une branche | 18 | 45 | P4 |
| 46 | Renne | Épique | Glace | freeze | `8B6A48` bois `E3D5B8` | L | debout | 24 | 50 | P4 |
| 47 | Bélier ardent | Épique | Feu | strike | `5A3E28` cornes `FF6A1A` | B | tête baissée | 22 | 55 | P4 |
| 48 | Lynx tonnerre | Épique | Foudre | chain | `C9A27A` pointes `FFE14A` | B | à l'affût | 22 | 62 | P4 |
| 49 | Flamant rose | Épique | Lumière | heal | `FF8CB4` bec `1E1E1E` | L | sur une patte | 14 | 70 | P4 |
| 50 | Léopard des neiges | Légendaire | Glace | freeze | `F2F2F2` taches `2A2A2A`, yeux `6FD6FF` | B | marche, cristaux sur le dos | 28 | 180 | P2 |
| 51 | Requin éclair | Légendaire | Foudre | chain | `B8C4CC` éclairs `6FD6FF` | B | bipède, sphère d'éclairs | 26 | 220 | P2 |
| 52 | Griffon | Légendaire | Ciel | focus | `C9A27A` ailes `FAFAFA` | L | assis, ailes repliées | 30 | 260 | P5 |
| 53 | Mammouth | Légendaire | Terre | bulwark | `7A4E2A` défenses `F5EBD7` | B | debout | 26 | 300 | P5 |
| 54 | Pégase | Légendaire | Lumière | heal | `FAFAFA` ailes `FFE680` | L | cabré | 30 | 360 | P5 |
| 55 | Panthère d'ombre | Légendaire | Ombre | drain | `1E1A28` yeux `B04DFF` | L | à l'affût | 24 | 420 | P5 |
| 56 | Phénix de feu | Mythique | Feu | drain | `FF6A1A` ailes `FFD24A` | B | ailes déployées (image) | 34 | 1 200 | P2 |
| 57 | Loup de glace | Mythique | Glace | freeze | `D6E4F0` yeux `6FD6FF` | B | debout, crête de cristaux (image) | 32 | 1 500 | P1 |
| 58 | Hydre des marais | Mythique | Plante | heal | `3E6E3A` 3 têtes | L | dressée | 30 | 1 800 | P5 |
| 59 | Golem de pierre | Mythique | Terre | bulwark | `8E93A0` runes `7FE8FF` | B | bipède massif | 26 | 2 100 | P5 |
| 60 | Tigre ailé à runes | Mythique | Lumière | focus | `FF8C2A` rayures `FFE680` Neon | L | debout, ailes + cercle runique (image) | 34 | 2 500 | P2 |
| 61 | Serpent foudre | Mythique | Foudre | chain | `2A2A5A` éclairs `FFE14A` | L | enroulé (5 segments) | 20 | 3 000 | P5 |
| 62 | Loup de cristaux | Ultra Rare | Glace | freeze | `BFEFFF` Glass + `FFFFFF` | B | debout, cristaux (image) | 36 | 10 000 | P1 |
| 63 | Renard à neuf queues | Ultra Rare | Lumière | heal | `FFE07A` queues `FFFFFF` | B | assis, 9 queues en éventail (image) | 38 | 14 000 | P2 |
| 64 | Dragon de lave | Ultra Rare | Feu | strike | `2A1A14` fissures `FF3020` Neon | B | ailes ouvertes (image) | 38 | 18 000 | P1 |
| 65 | Oiseau-tonnerre | Ultra Rare | Foudre | chain | `2A3A6A` ailes `FFE14A` | L | vol | 32 | 22 000 | P5 |
| 66 | Chimère d'ombre | Ultra Rare | Ombre | drain | `2A1A3A` flammes `8A3CFF` | L | 3 têtes (lion, chèvre, serpent) | 36 | 26 000 | P5 |
| 67 | Démon enchaîné | Secret | Ombre | stun | `1E1428` chaînes `3A3A42`, yeux `C86BFF` | B | bipède, chaînes (image) | 36 | 80 000 | P1 |
| 68 | Phénix solaire | Secret | Lumière | heal | `FFF3B0` ailes `FFD24A` Neon | B | ailes déployées, halo (image) | 38 | 90 000 | P1 |
| 69 | Léviathan | Secret | Eau | strike | `1A3A6A` nageoires `6FD6FF` | L | serpent marin (6 segments) | 28 | 100 000 | P4 |
| 70 | Dragon de cristal | Secret | Glace | freeze | `BFEFFF` Glass | L | assis, ailes de cristal | 38 | 110 000 | P1 |
| 71 | Titan de l'orage | Secret | Foudre | chain | `3A3A4A` éclairs `FFE14A` | B | bipède, nuage `Nuage` | 34 | 120 000 | P4 |
| 72 | Loup-garou citrouille | Exclusif (Halloween) | Feu | drain | `FF7A1A` `1E1E1E` | B | bipède, tête-citrouille | 30 | 50 000 | P5 |
| 73 | Renne étoilé | Exclusif (Noël) | Glace | heal | `FAFAFA` bois `FFD24A` | L | debout, guirlande | 30 | 60 000 | P5 |
| 74 | Corbeau couronné | Exclusif (Saison 1) | Ombre | focus | `141414` + `F2F2F2`, couronne noire | B | perché, couronne (assorti à l'œuf Exclusif) | 24 | 70 000 | P5 |
| 75 | Séraphin-lion | Divin | Lumière | heal | `FFF3B0` crinière `FFD24A`, ailes | L | assis, 2 paires d'ailes, auréole | 38 | 400 000 | P1 |
| 76 | Dragon céleste | Divin | Ciel | focus | `F2F6FF` nacre, cornes `FFE680` | L | en vol, corps en 6 segments | 40 | 500 000 | P1 |
| 77 | Qilin sacré | Divin | Foudre | chain | `FFE680` écailles `6FD6FF` | B | cabré | 36 | 600 000 | P3 |
| 78 | Baleine des étoiles | Divin | Eau | heal | `1A2A5A` points `FFFFFF` Neon | L | nage dans l'air | 26 | 700 000 | P3 |

Répartition : R1 10, R2 10, R3 10, R4 10, R5 9, R6 9, R7 8, R8 5, R9 3, R10 4. Types (total 78, après les 6 changements de C.1) : Feu 9, Eau 10, Plante 7, Glace 10, Foudre 10, Terre 8, Ciel 6, Ombre 8, Lumière 10. Bonus de collection (lot 11) : +5 % par 3 espèces jusqu'à 18 (existant, +30 %), puis +5 % par 6 espèces supplémentaires, maximum +80 % à 78.

Priorité de production (lots de 12) : **P1** = ce qui débloque les nouvelles raretés (≥ 3 espèces en R2 et R8, R10 publiables) + 3 créatures des images ; **P2** = espèces demandées (crocodile, cheval, ours) + créatures des images ; **P3** = petites raretés (beaucoup d'éclosions, grande visibilité) ; **P4-P5** = le reste. Tant qu'un modèle manque, l'espèce utilise le repli procédural (`ears`, `extra`, `color` à renseigner pour les 60 nouvelles ; nouveaux `extra` : `shell`, `wings2`, `heads3`, `segments`, `crystals`, `chains`, `halo`).

### C.3 Protocole de test fiable des modèles (blocs B contre lisse L)

1. **Prototype A/B** : le Loup de glace (#57) en B et en L, même nombre de pièces (32), même palette.
2. **Contrôle automatique dans Blender** (script `tools/blender_check.py` à exécuter dans Blender en ligne de commande, sortie JSON) : nombre d'objets ≤ 40 ; chaque nom respecte `^[A-Za-z_]+__[0-9A-Fa-f]{6}$` ou appartient à la liste des pièces sans couleur ; pièces animées présentes selon la pose (quadrupède : `Corps`, `Tete`, 4 `Patte_*`, `Queue`) ; origine au centre du socle (|z min| < 0,05) ; devant vers -Z (Blender -Y) ; hauteur entre 0,8 et 1,2 unité ; aucune pièce de moins de 0,15 d'arête (illisible) ; triangles totaux ≤ 4 000 ; aucun modificateur non appliqué.
3. **Contrôle dans Studio** (rapport existant `Config.Debug.AssetReport`) : le chargeur refuse > `petsMaxParts` ; mettre `petsMaxParts = 40` pour les nouveaux (`Assets.petsMaxPartsNew = 40`, les 18 anciens gardent 120).
4. **Rendu** : capture des 2 prototypes sur fond gris, lumière du jeu, à 3 distances (5, 20, 60 studs) et sur téléphone (émulateur iPhone SE et Android bas de gamme de Studio) ; critère : silhouette identifiable à 60 studs par 4 testeurs sur 5.
5. **Poids** : scène de test avec 15 pets suiveurs + 20 pets en base (pire cas de 5 joueurs × 3 suiveurs + 20 emplacements), FPS ≥ 30 sur l'émulateur mobile, mémoire client < 1,2 Go, `Stats.InstanceCount` noté.
6. **Animation sans bug** : chaque pièce animée par le code (`Animations.client.lua`) tourne autour de son pivot ; test de 120 s : aucune pièce ne dérive de plus de 0,05 stud de sa position de repos (mesure toutes les 10 s), aucune pièce séparée du corps (distance au `Corps` constante ± 0,1), pas de clignotement d'ombre ; à faire pour chaque pose (quadrupède, bipède, vol, nage, segments).
7. **Choix** : vote de 10 joueurs (5 enfants, 5 adultes si possible) + FPS ; le style gagnant devient la règle de P2 à P5 ; écrire le résultat dans `BLENDER_REQUESTS.md`. Recommandation de départ : **B** pour les quadrupèdes communs à épiques (cohérence avec les avatars Roblox, lisibilité mobile), **L** pour les créatures ailées et mythiques (images de référence).

---

## D. Combat PvE (modifications exactes de l'Arène des Pets)

### D.1 Ce qui change dans `Battle.lua`

| Élément | Actuel | Nouveau |
|---|---|---|
| Types | 6 : `Feu, Eau, Nature, Ciel, Ombre, Lumière` | 9 : `Feu, Eau, Nature, Glace, Foudre, Terre, Ciel, Ombre, Lumière` (clé `Nature` conservée, affichée « Plante » via `Battle.TYPE_LABEL`) |
| Matrice | `BEATS` simple, ×1,5 / ×0,67 | 2 niveaux : `BEATS` ×1,5/×0,67 et `BEATS2` ×1,25/×0,8 (D.2) |
| Compétence | recharge `cd` (3 à 5 tours) | **charge** : `u.charge` 0..5 ; le spécial se débloque à 5 |
| Stats | `hp = 60×1,45^(t-1)`, `atk = 10×1,4^(t-1)`, `spd = 10+2t` | tables par rareté (D.4) qui reproduisent exactement les anciennes valeurs des raretés migrées |
| Tours max | 30 | 40 (le spécial arrive plus tard) |
| Niveau de pet | aucun | XP et niveau 1-20, +1,5 % pv/attaque par niveau (D.6) |
| Récompense | fixe (`towerReward`) | tirage de 3 cartes, le joueur en choisit 1 (D.5) |
| Tour | 30 étages (6 raretés × 5) | 45 étages, `TOWER.tiers = { 1, 2, 3, 4, 5, 6, 7, 8, 10 }` × 5 étages ; boss tous les 5 |

### D.2 Matrice d'avantages (9 types)

Primaire (×1,5 si l'attaquant bat le défenseur, ×0,67 dans l'autre sens) = 3 triangles :
- Feu > Plante > Eau > Feu (existant)
- Lumière > Ombre > Ciel > Lumière (existant)
- Terre > Foudre > Glace > Terre (nouveau : la terre absorbe la foudre, la foudre brise la glace, la glace gèle la terre)

Secondaire (×1,25 / ×0,8), une relation sortante et une entrante par type, aucune ne contredit le primaire :
Feu > Glace, Glace > Ciel, Ciel > Terre, Terre > Feu, Foudre > Eau, Eau > Ombre, Ombre > Plante, Plante > Lumière, Lumière > Foudre.

Tableau (ligne = attaquant, colonne = défenseur) :

| Att \ Déf | Feu | Eau | Plante | Glace | Foudre | Terre | Ciel | Ombre | Lumière |
|---|---|---|---|---|---|---|---|---|---|
| Feu | 1 | 0,67 | **1,5** | 1,25 | 1 | 0,8 | 1 | 1 | 1 |
| Eau | **1,5** | 1 | 0,67 | 1 | 0,8 | 1 | 1 | 1,25 | 1 |
| Plante | 0,67 | **1,5** | 1 | 1 | 1 | 1 | 1 | 0,8 | 1,25 |
| Glace | 0,8 | 1 | 1 | 1 | 0,67 | **1,5** | 1,25 | 1 | 1 |
| Foudre | 1 | 1,25 | 1 | **1,5** | 1 | 0,67 | 1 | 1 | 0,8 |
| Terre | 1,25 | 1 | 1 | 0,67 | **1,5** | 1 | 0,8 | 1 | 1 |
| Ciel | 1 | 1 | 1 | 0,8 | 1 | 1,25 | 1 | 0,67 | **1,5** |
| Ombre | 1 | 0,8 | 1,25 | 1 | 1 | 1 | **1,5** | 1 | 0,67 |
| Lumière | 1 | 1 | 0,8 | 1 | 1,25 | 1 | 0,67 | **1,5** | 1 |

Test : chaque ligne a exactement un 1,5, un 1,25, un 0,8, un 0,67 ; la matrice est « antisymétrique » (`m[a][b] × m[b][a] ∈ {1 ; 1,005}` : 1,25 × 0,8 = 1 et 1,5 × 0,67 = 1,005).

### D.3 Attaques de base et spécial au 5ᵉ coup

- Action « Attaque » : dégâts `atk × 1 × typeMul × (0,9 + 0,2 r)` (formule existante de `strike`), puis `charge = min(5, charge + 1)` ; **+1 de charge en plus** si `typeMul ≥ 1,25` (récompense le bon choix de type). Un pet étourdi ne charge pas.
- Action « Spécial » : refusée si `charge < 5` (`Battle.validate` : « spécial pas prêt (x/5) ») ; consomme 5.
- Changer de pet : la charge reste attachée au pet (pas de perte).
- Interface : 5 pastilles sous la barre de vie, la 5ᵉ pulse ; bouton « Spécial » grisé avec « 3/5 ».
- IA (`Battle.aiAction`) : utilise le spécial dès 5, sauf `heal` si pv > 70 % (attend) et `guard` si l'ennemi n'a pas 4+ de charge.

`Battle.SKILLS` (le spécial porte un nom par type, `Config.TYPE_SPECIAL_NAME`, ex. Feu « Souffle ardent », Glace « Blizzard », Foudre « Arc électrique ») :

| Clé | Effet (nouveau, plus fort car 1 fois sur 6 actions au lieu de 1 sur 3-5) |
|---|---|
| `strike` | dégâts ×2,5 |
| `drain` | dégâts ×1,6, soigne 40 % des dégâts |
| `heal` | soigne 35 % des pv max, retire étourdissement |
| `guard` | les 2 prochains coups reçus ne font que 30 % |
| `stun` | dégâts ×1,2, l'ennemi passe 1 tour |
| `focus` | dégâts ×1,4 puis attaque +40 % pendant 3 tours |
| `freeze` (nouveau, Glace) | dégâts ×1,5, l'ennemi perd 2 de charge |
| `chain` (nouveau, Foudre) | dégâts ×1,6 sur l'actif + 35 % de ces dégâts sur le pet suivant en réserve |
| `bulwark` (nouveau, Terre) | dégâts ×1,3 et garde : le prochain coup reçu fait 50 % |

### D.4 Stats par rareté (`Battle.STATS[r]`)

| r | pv | attaque | vitesse |
|---|---|---|---|
| 1 | 60 | 10 | 12 |
| 2 | 73 | 12 | 13 |
| 3 | 87 | 14 | 14 |
| 4 | 126 | 20 | 16 |
| 5 | 183 | 27 | 18 |
| 6 | 265 | 38 | 20 |
| 7 | 385 | 54 | 22 |
| 8 | 470 | 64 | 23 |
| 9 | 470 | 64 | 23 |
| 10 | 560 | 75 | 24 |

`unit = STATS[r] × SIZE_BONUS[s] × MUT_BONUS[m] × (1 + 0,015 × (niveau - 1)) × scale`. Les valeurs r = 1, 3, 4, 5, 6, 7 sont celles de l'ancienne formule pour les raretés 1 à 6 : un pet migré garde exactement ses stats. Rien d'achetable ne modifie ces stats (règle existante, à tester).

### D.5 Récompense au choix après une victoire PvE (module pur `ReplicatedStorage/Rewards.lua`)

Le serveur tire **3 cartes de catégories différentes** (poids : Pièces 30, Expérience 25, Œuf 15, Vitesse 15, Effet 15), les envoie au client, le joueur en choisit une (15 s, sinon la première). Le tirage est enregistré (`pendingPick = { id, cards, expires }`) : se déconnecter ou relancer ne retire pas de nouvelles cartes.

| Carte | Valeur (étage f de la tour, rareté de l'étage `rt = towerTier(f)`) |
|---|---|
| 🪙 Pièces | `max(500, revenus de 1,5 min × (1 + f/10))` |
| ⭐ Expérience | `+ (30 + 10 f)` XP à chacun des 3 pets de l'équipe |
| 🥚 Œuf | 1 œuf de rareté `rt` (boss : `rt + 1`, règle existante) ; base pleine → son prix en pièces |
| 👟 Vitesse | `+ (2 + f // 5)` points de stat `speed` permanents (équivaut à 20-60 s de piste) |
| ✨ Effet (boost temporaire) | tiré parmi : Revenus ×2 5 min, Chance +10 points 5 min, XP ×2 10 min, Vitesse +15 % 5 min (`data.boosts[clé] = now + durée`, non cumulable avec lui-même : prolonge, plafond 30 min) |

Boss (étage multiple de 5) : une des 3 cartes est toujours l'Œuf. Première victoire d'un étage : valeurs ×2. Victoires répétées : comptent dans `TOWER.dailyRepeats` (10) et valeurs ×0,5. Combats PNJ (F) : valeurs ×0,6.

### D.6 Expérience et niveaux de pets

- XP par combat PvE gagné : 20 + 5 × étage à chacun des 3 pets ; perdu : 5. PvP : 15 / 5. Carte Expérience : D.5.
- Niveau : `xpTo(L) = floor(40 × L^1,6)` pour passer de L à L+1 ; niveau max 20 (≈ 9 600 XP cumulés).
- Stocké sur l'emplacement (`slot.x`) ; vendre ou se faire voler un pet fait perdre son XP (le pet volé garde son XP chez le voleur).
- **Jamais vendu contre des Robux** (aucun boost XP payant pour les pets ; l'effet « XP ×2 » ne s'obtient qu'en jouant).
- Niveau de Dresseur (`trainer.xp`, total des XP gagnés, niveau = `floor(sqrt(xp / 50)) + 1`, max 100) : sert au matchmaking (E) et aux titres cosmétiques ; peut être accéléré par la passe de saison (n'affecte pas la force).

### D.7 Tour à 45 étages

`TOWER.floors = 45`, `towerTier(f) = TOWER.tiers[1 + (f-1)//5]`, `bosses[35] = "Reine de Cristal"`, `[40] = "Démon enchaîné"`, `[45] = "Séraphin"`. `towerScale` inchangé. `Battle.towerTeam` pioche dans les espèces publiées de la rareté. Récompense « Œuf de boss » : `min(rt + 1, 8)` (jamais Exclusif ni Divin).

---

## E. PvP et matchmaking

### E.1 Trois modes, du plus robuste au plus ambitieux

| Mode | Où | Classé | Pourquoi |
|---|---|---|---|
| **Classé asynchrone** (existant) | n'importe quel serveur, panneau Arène | oui (trophées) | Toujours un adversaire, aucune latence, aucun téléport, 5 joueurs max par serveur ne suffisent pas pour du direct. Reste le mode classé par défaut. |
| **Duel local** (nouveau) | même serveur, sur le sable du colisée (-265, 165) | non (« amical ») | Social, immédiat, sans infrastructure. Non classé pour empêcher l'arrangement entre amis. |
| **Classé en direct** (nouveau, derrière `Config.PVP_LIVE.enabled = false`) | serveur réservé « arène » | oui | Combat en temps réel entre joueurs de niveau proche ; activé seulement quand l'audience le permet (E.3). |

### E.2 Duel local

`Config.DUEL = { range = 30, requestTimeout = 20, sameTargetCooldown = 120, rewardedPerDay = 10, samePairRewardedPerDay = 3, turnSeconds = 10, afkTurnsToForfeit = 2, coinsWinMins = 1, coinsLoseMins = 0.25 }`
1. Défier : prompt « ⚔️ Défier » sur un joueur à ≤ 30 studs, ou menu Arène > Joueurs du serveur. Refusé si l'un porte un œuf, est poursuivi, est en dialogue, en mode Château, ou sous protection débutant non désactivée.
2. Le défié reçoit « {nom} te défie en duel (équipe de 3) ! » [Accepter] [Refuser] (20 s). Option « Refuser automatiquement les duels » dans Réglages.
3. Les deux sont placés sur le sable (positions ±10 en X), caméra de duel, les autres joueurs peuvent regarder depuis les gradins (événements `RBattle` rejoués).
4. Tours en direct (10 s, action par défaut = Attaque si rien n'est choisi), le serveur résout avec `Battle.turn(st, actionA, actionB)`. 2 tours sans action = forfait.
5. Récompense : gagnant = revenus de 1 min, perdant = 15 s ; comptés seulement 10 duels/jour et 3 par paire de joueurs/jour. `battle.duel.w/l` mis à jour (ratio affiché en B.4). Aucun trophée.

### E.3 Classé en direct : file en ligne et serveur réservé (solution réaliste)

Architecture (tout côté serveur, MemoryStore + TeleportService, déjà utilisés par le hub) :

1. **Entrée en file** : bouton « Combat classé en direct ». Le serveur du joueur écrit dans `MemoryStoreService:GetSortedMap("PvpQueue_v1")` : clé `userId`, valeur `{ tr = trophées, pow = puissance d'équipe, lvl = niveau de Dresseur, job = game.JobId, t = os.time() }`, clé de tri = trophées, expiration 90 s, rafraîchie toutes les 10 s tant que le joueur attend. L'équipe est figée à l'entrée.
2. **Élection d'un apparieur** : chaque serveur de partie tente toutes les 3 s `UpdateAsync` sur `HashMap("PvpLock_v1")["leader"]` (expiration 10 s) ; seul le détenteur apparie.
3. **Appariement** (`ReplicatedStorage/Matchmaking.lua`, pur et testé) : lecture `GetRangeAsync` (200 entrées max) ; deux joueurs s'apparient si `|Δtrophées| ≤ 100 + 50 × floor(attente / 10 s)` (max 400) **et** rapport de puissance d'équipe dans [0,75 ; 1,33], élargi à [0,6 ; 1,67] après 30 s ; on privilégie le plus ancien en file. Jamais deux comptes ayant joué ensemble dans le même serveur dans les 10 dernières minutes (anti-arrangement).
4. **Ticket** : l'apparieur appelle `TeleportService:ReserveServer(Places.game)` → `code`, écrit `HashMap("PvpTicket_v1")["u"..uid] = { code, match = id, opp, exp = now + 30 }` pour les deux, retire les deux entrées de la file (`RemoveAsync`).
5. **Téléportation** : chaque serveur interroge toutes les 2 s les tickets de **ses** joueurs en file ; à réception : sauvegarde du profil (`Data.save`, libération du verrou de session), puis `TeleportAsync(Places.game, { player }, TeleportOptions { ReservedServerAccessCode = code, TeleportData = { mode = "arena", match, opp, back = { party = codeDePartieSiConnu } } })`. Échec (`TeleportInitFailed`) : 2 nouvelles tentatives à 3 s, sinon le joueur est remis en tête de file et l'autre reçoit « Adversaire indisponible ».
6. **Serveur d'arène** (`serverMode = "arena"`, comme `"castle"`) : pas de carte complète (colisée seul, 300 Parts), attend 25 s les deux joueurs. Si un seul arrive : il combat la **défense enregistrée** de l'absent (mode asynchrone), résultat classé normal pour le présent, l'absent ne perd rien. Combat en direct, 10 s par tour, déconnexion = 2 tours d'IA puis forfait. Intro B.4.
7. **Retour** : `TeleportAsync` vers la partie d'origine si `back.party` existe encore dans le registre `ChipeParties` et n'est pas pleine, sinon vers le hub. Les œufs en incubation continuent (temps absolu `ends`). Tant que `PVP_LIVE` n'est pas activé, le bouton propose directement le classé asynchrone.
8. **Bascule automatique** : si personne n'est trouvé en 45 s : « Aucun adversaire en ligne de ton niveau. Combattre une équipe enregistrée ? » → mode asynchrone (même gain de trophées).

Seuil d'activation recommandé : `PVP_LIVE.enabled = true` seulement si la moyenne de joueurs simultanés dépasse **60** (sinon la file est vide et frustre). Quotas MemoryStore : ~1 lecture/3 s par serveur leader + 1 écriture/10 s par joueur en file, très en dessous de la limite (1 000 + 100 × joueurs requêtes/min).

### E.4 Trophées, ligues, saisons

- Gains inchangés (`pvpGain` 10-40, défaite -15). Direct et asynchrone partagent les trophées ; asynchrone limité à 10/jour (existant), direct à 15/jour (`PVP_LIVE.dailyFights`).
- Ligues (`Config.LEAGUES`) : Bronze 0-299, Argent 300-599, Or 600-999, Diamant 1 000-1 499, Champion 1 500+. Badge au-dessus de la tête et dans l'intro.
- Fin de saison (7 jours, existant) : récompenses `PVP.rewards` étendues : 100 → 5 000 pièces + Œuf Rare ; 300 → Œuf Épique ; 600 → Œuf Légendaire + potion ; 1 000 → Œuf Mythique + potion ; 1 500 → Œuf Ultra Rare + titre « Champion de la saison n ».
- Remise partielle à chaque saison : `trophées = floor(trophées × 0,6)` au-delà de 300 (garde la file mélangée).

---

## F. PNJ qui interpellent le joueur (échanges et combats)

### F.1 Personnages (`Config.NPCS`)

| Clé | Nom | Rôle | Apparence (modèle J) |
|---|---|---|---|
| `pip` | Pip le Colporteur | échanges | petit marchand avec charrette d'œufs |
| `lina` | Lina la Dresseuse | combats (équipes Plante/Eau/Glace) | cape verte, pet Koala |
| `bruno` | Bruno le Costaud | combats (Terre/Feu) | tablier de forgeron, pet Ours brun |
| `kai` | Maître Kaï | combat hebdomadaire « Champion errant » | robe blanche, pet Renard à neuf queues |
| `nora` | Nora la Collectionneuse | échange « espèce manquante » | lunettes, carnet |

### F.2 Fréquence et conditions (`Config.NPC_ENCOUNTER`)

`{ firstAfterMinutes = 8, gapMinutes = { 6, 10 }, tradesPerDay = 4, fightsPerDay = 4, weeklyChampion = 1, snoozeMinutes = 10, offerSeconds = 60, approachRange = 25 }`
- Un PNJ apparaît à 25 studs du joueur, sur un chemin ou la place (jamais dans un territoire), marche vers lui, bulle « ❗ ».
- Jamais : pendant les 8 premières minutes, en portant un œuf, poursuivi par un gardien, dans les 60 s après une révélation de rareté ≥ 5, en duel, au château, pendant une cinématique, si `npc.off = true` (réglage « Ne plus être interpellé »).
- « Pas maintenant » = pas d'autre PNJ pendant 10 min. Le PNJ repart après 60 s sans réponse.
- Alternance : rencontre n paire = échange, impaire = combat (si le quota du type est atteint, l'autre type ; si les deux, plus de PNJ ce jour).

### F.3 Dialogues (exemples exacts)

- Pip, approche : « Psst ! Hé, toi, le Chipeur ! J'ai un œuf qui n'attend que toi… On fait affaire ? » [Voir l'offre] [Pas maintenant]
- Pip, offre 1 : « Cet œuf {rareté} contre 🪙 {prix} : c'est 20 % de moins qu'à la boutique ! »
- Pip, offre 2 : « Tu as des doublons ? Donne-m'en 3 de rareté {r} et je te donne un œuf {r+1}. Promis, pas d'arnaque. »
- Pip, refus : « Tant pis ! Je repasse plus tard, garde tes pièces au chaud. »
- Nora : « Oh ! Il te manque le {espèce} dans ton bestiaire ? J'en ai un. Je te l'échange contre ton {doublon} et 🪙 {complément}. »
- Lina, défi : « Ton équipe a l'air prometteuse… Un petit combat ? Je ne mords pas. Mon Koala, si. » [Combattre] [Pas maintenant]
- Lina, victoire du joueur : « Bien joué ! Choisis ta récompense, tu l'as méritée. »
- Lina, défaite du joueur : « Pas cette fois ! Entraîne-toi à la tour et reviens me voir. Astuce : la Glace craint la Foudre. » (astuce tirée de la matrice contre son équipe)
- Kaï (lundi, une fois par semaine) : « On m'a parlé de toi. Montre-moi ta meilleure équipe : si tu gagnes, la récompense est à la hauteur. »
- Bruno, si le joueur refuse 3 fois de suite : ne revient plus ce jour-là (« Bon, je vois que t'es occupé. À demain ! »).

### F.4 Échanges : règles anti-abus

1. Offre générée **par le serveur** (`ReplicatedStorage/Npc.lua`, pur), identifiant unique, valable 60 s, à usage unique, liée au `userId` ; le client ne renvoie que l'identifiant et « accepter ».
2. Valeurs : œuf contre pièces = `EGG_PRICE[r] × 0,8` (r ≤ 5) ; 3 doublons de rareté r (r ≤ 4) → 1 œuf r+1 ; espèce manquante (Nora, r ≤ 5) contre 1 doublon de même rareté + `EGG_PRICE[r] × 0,2`.
3. Le PNJ ne demande **jamais** : un pet de rareté ≥ 6, un pet équipé (suiveur) ou dans l'équipe de combat ou de défense PvP, un pet muté Arc-en-ciel ou mieux, un pet Géant ou Colossal, le dernier exemplaire d'une espèce (doublon = au moins 2 exemplaires).
4. Écran de confirmation : les deux objets côte à côte avec leur compteur « 1 sur N » et la valeur de revente ; 2ᵉ confirmation si un pet de rareté ≥ 4 est donné.
5. Aucun échange entre joueurs via PNJ (pas de transfert de valeur entre comptes) ; aucun achat Robux dans un dialogue PNJ.
6. Compteurs `npc.day/trades/fights` dans le profil : se reconnecter ou changer de serveur ne relance pas une rencontre ; `npc.nextAt` absolu.

### F.5 Combats PNJ

- Équipe adverse : 3 pets dont la puissance = puissance de l'équipe du joueur × U(0,9 ; 1,1), types choisis selon le PNJ ; niveau des pets = moyenne des niveaux du joueur.
- Victoire : 3 cartes D.5 à 60 % (Œuf = rareté moyenne de l'équipe du joueur, plafonnée à 5). Défaite : rien n'est perdu, +5 XP.
- Champion errant (Kaï) : puissance ×1,3, 1 fois/semaine, victoire = Œuf Mythique garanti + carte au choix à 100 %.
- Ratio `battle.pve` incrémenté.

---

## G. Récompenses journalières, quêtes, rotation, événements

### G.1 Série de 7 jours (remplace le bonus quotidien actuel, champs `daily`, `streak` réutilisés)

| Jour | Récompense |
|---|---|
| 1 | Œuf Peu commun + revenus de 5 min (min 500) |
| 2 | Œuf Rare |
| 3 | Potion de chance 10 min (+25 points) |
| 4 | Œuf Épique + revenus de 10 min |
| 5 | 2 Œufs Rares + effet XP ×2 30 min |
| 6 | 2 Œufs Épiques |
| 7 | Œuf Légendaire + revenus de 30 min + 1 Fragment du Grand Œuf ; toutes les 4 semaines complètes : Œuf **Mythique** à la place du Légendaire |

Pass VIP : pièces ×2 (règle `VIP_DAILY_MUL` conservée), pas les œufs. Réclamation par bouton (pas automatique), notification rouge sur l'icône. Œufs : base pleine → stockés dans `eggBag` (sac d'œufs, 10 places, à poser plus tard), jamais perdus.

### G.2 Rattrapage

- 1 **jour de grâce** gratuit par semaine (`grace.week/used`) consommé automatiquement si un seul jour est manqué : la série continue.
- Deuxième jour manqué dans la semaine : écran « Ta série de {n} jours va se perdre » avec deux moyens : (a) **gratuit** : terminer les 3 quêtes du jour aujourd'hui ; (b) produit `StreakRestore` 29 R$ (1 fois/semaine). Sinon retour au jour 1.
- 3 jours manqués ou plus : retour au jour 1 (pas de rachat).

### G.3 Calendrier de 30 connexions (`cal`, mois UTC, compte les jours de connexion, pas consécutifs)

| Connexion n° | Récompense | Connexion n° | Récompense |
|---|---|---|---|
| 1, 2, 4, 6, 8, 9, 11, 12 | revenus de 10 min | 3 | Œuf Peu commun |
| 5 | Œuf Rare | 7 | Œuf Épique |
| 10 | 2 Œufs Épiques | 13, 15, 16, 17, 19, 20 | revenus de 15 min |
| 14 | Œuf Légendaire | 18 | Potion de chance 30 min |
| 21 | 2 Œufs Légendaires | 22-24, 26, 27, 29 | revenus de 20 min |
| 25 | Œuf Mythique | 28 | effet Revenus ×2 1 h |
| 30 | Œuf **Ultra Rare** + aura cosmétique « du mois » (exclusive, ne revient pas) + titre | — | — |

### G.4 Quêtes du jour et de la semaine, rotation hebdomadaire

- **Quêtes du jour** (système existant `quests/qday`, types `QUEST_TYPES`) : 3 quêtes + 1 **quête bonus** débloquée quand les 3 sont faites : « Gagne 2 combats PvE » ou « Fais éclore 1 œuf Épique+ », récompense Œuf Épique (chapitre ≥ 6 : Légendaire). Nouveaux types : `pve`, `duel`, `npcTrade`, `typeWin` (gagner avec un type donné), `odds` (obtenir un pet ≥ 1 sur 1 000).
- **Quêtes de la semaine** (`weekly`) : 7 quêtes (une par thème : éclosion, vol, PvE, PvP, collection, énigme, PNJ). 5/7 → Œuf Légendaire ; 7/7 → Œuf Mythique + 300 XP de saison.
- **Rotation hebdomadaire** (`Config.WEEKLY_ROTATION`, déterminée par `semaine`, même pour tous) : (1) **espèce vedette** : poids ×2 dans son œuf, affichée sur le tapis et dans le 🎲 ; (2) **défi d'arène** : un type « en forme » (+20 % de dégâts en PvE seulement) ; (3) **boutique de la semaine** : 2 cosmétiques. Cycle de 9 semaines (un type par semaine).

### G.5 Événements

| Événement | Quand | Effet |
|---|---|---|
| Week-end chanceux | samedi 00:00 → lundi 00:00 UTC | +5 points d'amélioration pour tous, tapis toutes les 4 s au lieu de 5 |
| Heure dorée | tous les jours 18:00-19:00 UTC (≈ sortie d'école en Europe) | Ruée vers l'or (revenus ×2, clé `gold` existante) |
| Événement limité (10 jours, 1 par mois) | Halloween (#72), Noël (#73), printemps… | Monnaie « Plumes d'événement » : 10/quête du jour, 2/victoire PvE (max 20/j), 5 à la connexion ; **Œuf Exclusif = 150 plumes** (≈ 1 tous les 4 jours, 2 à 3 par événement) ; boss d'événement à la tour ; décor saisonnier (J) |
| Saison (28 jours) | continue | Passe de saison, 30 paliers, XP de saison : 100/quête du jour, 300/quêtes de la semaine, 20/victoire PvE ou PvP (max 200/j). Piste gratuite : pièces, œufs jusqu'à Épique, 1 Légendaire au palier 30. Piste premium (H) : œufs jusqu'à Mythique, Ultra Rare au palier 30, espèce **Exclusif fixe** (#74 en saison 1, pas de hasard sur l'espèce), cosmétiques. |
| Événements serveur (existants) | 120-200 s d'écart | inchangés |

Les dates d'événements sont des données (`Config.EVENTS_CAL = { { id, from = jour, to = jour, species } }`), modifiables sans republier la logique.

---

## H. Monétisation par paliers

### H.1 Règles (à tester)

1. Tout produit qui comporte du hasard (espèce, taille, mutation, rareté de tapis) porte `random = true`, affiche **avant l'achat** sa table exacte (`Config.eggContentText`, tables SIZES/MUTS) et est masqué + refusé côté serveur si `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` (et refusé si l'appel échoue : par défaut restreint).
2. **La rareté d'un œuf payant n'est jamais tirée au sort** : on achète « un Œuf Légendaire », pas « un œuf mystère ». Les raretés Secret, Exclusif (aléatoire) et Divin ne sont **jamais vendues**.
3. Rien de payant ne modifie la force d'un pet (stats, XP de pet, niveau) ni ne protège contre le vol (règles existantes).
4. Plafonds par jour/semaine/mois dans `buys` (contrôlés dans `ProcessReceipt` **avant** d'accorder ; si plafond atteint après paiement (course), créditer l'équivalent en pièces ou en jeton et le signaler, ne jamais perdre l'achat).
5. Les bonus de chance sont des points fixes affichés ; « Double chance » multiplie les points ×2, plafond 70 inchangé.
6. Fiche de maturité/questionnaire Roblox : déclarer « objets aléatoires payants » ; descriptions sans fausse urgence (pas de compte à rebours sur une offre permanente).

### H.2 Catalogue chiffré

Existants (prix suggérés du cahier E.2, à garder) : Revenus ×2 199, Chance +10 % 149, Éclosion rapide 149, Vitesse +20 % 149, Base VIP 399, +4 emplacements 249, Tapis privé 299, Potion de chance 99, Pluie de chance pour tous 129, Tapis doré 99, Corbeau 79, 3 Corbeaux 199. Prix à fixer pour les existants sans prix écrit : Pack de départ **49** (une fois, meilleure conversion premier achat), Éclosion instantanée **25**, Relance **15**, Sac de pièces **49**. `ExclusiveEgg` (« Œuf exclusif Mythique ») est renommé « Œuf Mythique » (`EXCLUSIVE_EGG_TIER = 6`) pour ne pas être confondu avec la rareté Exclusif.

**Palier 1 : petits achats (15-49 R$), peu d'avantage, but = premier achat**

| Nom | Clé | Type | Prix | Effet précis | Plafond | Aléatoire |
|---|---|---|---|---|---|---|
| Petit sac de pièces | `CoinPackS` | produit | 19 | revenus de 5 min (min 1 000) | aucun | non |
| Œuf Peu commun | `EggR2` | produit | 15 | 1 œuf Peu commun dans la base (ou le sac d'œufs) | 10/jour | espèce, taille, mutation (affichés) |
| Œuf Rare | `EggR3` | produit | 25 | 1 œuf Rare | 10/jour | idem |
| Potion express | `LuckPotionMini` | produit | 29 | +25 points d'amélioration 5 min | 6/jour | non (bonus fixe affiché) |
| Œuf Épique | `EggR4` | produit | 49 | 1 œuf Épique | 10/jour | idem |
| Ticket d'arène | `ArenaTickets` | produit | 19 | +5 combats de tour récompensés aujourd'hui | 2/jour | non |
| Sauvetage de série | `StreakRestore` | produit | 29 | rétablit la série (G.2) | 1/semaine | non |
| Pose de victoire | `EmoteVictory1..6` | produit | 39 | animation cosmétique de victoire | 1 chacune | non |
| Pack de départ | `StarterPack` | produit | 49 | 20 000 pièces, 3 œufs Rares, 1 potion (existant) | 1 à vie | espèces (affichées) |

**Palier 2 : achats moyens (79-199 R$), avantage modéré**

| Nom | Clé | Type | Prix | Effet | Plafond |
|---|---|---|---|---|---|
| Œuf Légendaire | `EggR5` | produit | 99 | 1 œuf Légendaire | 5/jour |
| Double chance | `DoubleLuck` | produit | 149 | 30 min : points d'amélioration d'un cran ×2 (plafond 70) ; ex. 5 → 10, avec pass 15 → 30 | 3/jour, cumul max 90 min |
| Œuf Mythique | `ExclusiveEgg` (renommé) | produit | 199 | 1 œuf Mythique | 3/jour |
| Tapis doré, Pluie de chance, Potion, Corbeaux | existants | produit | 99 / 129 / 99 / 79-199 | inchangés | inchangés |
| Sac d'œufs +10 | `EggBagPlus` | pass | 149 | sac d'œufs 10 → 20 places | — |

**Palier 3 : passes et saison (249-499 R$), confort durable**

| Nom | Clé | Type | Prix | Effet |
|---|---|---|---|---|
| Passe de saison premium | `SeasonPremium` | produit (par saison, `season.premium`) | 399 | piste premium G.5 ; achat possible à tout moment de la saison, paliers déjà atteints crédités |
| Passe de saison + 10 paliers | `SeasonPremiumPlus` | produit | 799 | idem + 10 paliers immédiats (max 1/saison) |
| Collectionneur | `Collector` | pass | 249 | +1 pet suiveur (`MAX_FOLLOWERS` 3 → 4), indices de silhouette dans le bestiaire, cadre doré sur les compteurs ≥ 1 sur 100 000 |
| Chance +10 % II | `Lucky2` | pass | 349 | +10 points d'amélioration supplémentaires (cumul avec `Lucky` : 5 → 25 de base) |
| Existants | `Coins2x`, `VipBase`, `PrivateBelt`, `ExtraSlots`… | pass | inchangés | inchangés |

**Palier 4 : gros achats (799-1 499 R$), meilleurs avantages, plafonnés**

| Nom | Clé | Prix | Effet | Plafond |
|---|---|---|---|---|
| Œuf Ultra Rare | `EggR7` | 799 | 1 œuf Ultra Rare (8 espèces, 12,5 % chacune, affiché) | 1/jour |
| Pack Légende | `BundleLegend` | 999 | 1 Œuf Ultra Rare + 3 Œufs Légendaires + Double chance 60 min | 1/semaine |
| Coffre royal | `BundleRoyal` | 1 499 | 2 Œufs Ultra Rares + 3 Œufs Mythiques + Passe de saison premium (si non possédée, sinon +10 paliers) | 1/mois |

Jamais en vente : œufs Secret, Exclusif aléatoire, Divin ; XP de pet ; stats ; protection anti-vol ; trophées.

### H.3 Placement des offres (sans harcèlement)

- Boutique en 4 onglets : Œufs, Chance, Passes, Saison ; la fiche de chaque œuf affiche la table A.3 complète et les tailles/mutations.
- Offres contextuelles (règle `Config.OFFERS` existante : 3 max par session, 300 s d'écart) : après une défaite PvE → aucune offre de force (il n'y en a pas) mais « Ticket d'arène » si quota épuisé ; base pleine → « +4 emplacements » ; première éclosion Légendaire → « Double chance ».
- Prix de premier achat : Pack de départ 49 mis en avant pendant les 3 premiers jours (une seule fois par session).

---

## I. Rétention et revenu

### I.1 Les 8 mécanismes les plus rentables (ordre de priorité)

| # | Mécanisme | Comment il fait revenir / payer | Lot |
|---|---|---|---|
| 1 | Série de 7 jours + calendrier de 30 connexions, œufs croissants, grâce et sauvetage | raison quotidienne de revenir (D1, D7), produit `StreakRestore` | 15 |
| 2 | Collection de 78 espèces + compteur « 1 sur N » + bestiaire + classement « tirage le plus rare » | objectif long terme, fierté partageable, achats d'œufs et de chance | 9, 10, 11 |
| 3 | Cycles courts : éclosions 8 s à 10 min, tapis toutes les 5 s, quêtes du jour, cartes de récompense au choix | session plus longue, « encore un » | 9, 12, 15 |
| 4 | Passe de saison 28 j (gratuit + premium 399) | revenu récurrent le plus stable des jeux Roblox de collection | 16 |
| 5 | Événements limités avec espèce Exclusif (monnaie d'événement gagnée en jouant) | pics de retour mensuels, réactivation des joueurs partis | 15 |
| 6 | Classements (trophées par ligue, tirage le plus rare, maison, étage de la tour) + fin de saison PvP hebdomadaire | compétition, retour hebdomadaire | 13, 14 |
| 7 | Boucles sociales : annonces serveur et mondiales des tirages rares, duels, Pluie de chance offerte au serveur, corbeau, gradins | envie, achats « pour tout le serveur », invitations d'amis | 10, 13 |
| 8 | Paliers de prix (15 R$ → 1 499 R$) avec premier achat à 49 et plafonds | conversion large + ARPPU des gros payeurs sans abus | 16 |

Notifications : Roblox « Experience Notifications » (opt-in du joueur, API Open Cloud `user-notifications`) pour 2 messages seulement : « Ta série de {n} jours t'attend » (après 20 h sans connexion) et « Ton œuf {rareté ≥ 5} a éclos ». Clé d'API dans les secrets d'environnement, jamais dans le code.

### I.2 Plan de mesure

Outils : `AnalyticsService` (Creator Dashboard) : `LogOnboardingFunnelStepEvent` (étapes 1-8 de l'onboarding), `LogFunnelStepEvent` (« achat » : vue boutique → fiche → clic → reçu), `LogEconomyEvent` (pièces et œufs gagnés/dépensés par source : `belt`, `terr`, `pve`, `daily`, `npc`, `robux`), `LogProgressionEvent` (niveau de maison, étage, ligue), `LogCustomEvent` (`hatch_r` par rareté, `odds_1e5`, `npc_accept`, `npc_snooze`, `streak_lost`, `streak_saved`). Une seule fonction serveur `Telemetry.log(kind, …)` avec pcall et débit ≤ 1 événement/s/joueur.

| Métrique | Cible au lancement | Alerte / décision |
|---|---|---|
| D1 (retour le lendemain) | ≥ 30 % | < 22 % : revoir onboarding (étape où l'entonnoir perd > 25 %) |
| D7 | ≥ 10 % | < 6 % : récompenses de série trop faibles ou J4-J7 trop tard |
| D30 | ≥ 4 % | — |
| Durée moyenne de session | ≥ 18 min | < 12 min : raccourcir HATCH r1-r4 de 20 % |
| Sessions par joueur et par jour | ≥ 1,6 | — |
| Conversion (payeurs / joueurs actifs du mois) | ≥ 2,5 % | < 1,5 % : mettre en avant Pack de départ 49 et palier 1 |
| ARPPU (mensuel, par payeur) | ≥ 350 R$ | < 200 R$ : passe de saison plus visible |
| ARPDAU | suivi | variation > 20 % semaine sur semaine = enquête |
| Taux de complétion des quêtes du jour | ≥ 45 % des actifs | — |
| Part des joueurs à 7 jours de série | ≥ 8 % des actifs | — |
| Refus de PNJ (« Pas maintenant » / rencontres) | ≤ 50 % | > 60 % : espacer à 10-15 min |
| Plaintes de vol (signalements) | — | relier au corbeau (lot 7) |

Revue chaque lundi : tableau des 12 métriques par version publiée (étiquette de version dans `LogCustomEvent("version", Config.BUILD)`), une seule modification d'équilibrage par semaine pour attribuer les effets.

---

## J. Modèles Blender à créer (en plus de la liste du cahier G et de `BLENDER_REQUESTS.md`)

Convention inchangée (`Nom__RRGGBB`, devant -Z, origine au centre du socle, pas de scripts, biseau 0,1-0,2). Pièces max ≤ 40 pour les créatures (demande de l'utilisateur).

### J.1 Décors manquants pour les lots 9+ (point 1 de la demande : seulement ce qui manque)

| Clé | Modèle | Taille (studs) | Pièces | Pièces nommées |
|---|---|---|---|---|
| `npc.pip` | Pip le Colporteur + charrette | 4 × 3 × 5 (charrette 6 × 3 × 4) | 40 | `Corps__8B5A2B`, `Tete__F2C8A0`, `Chapeau__6B4F35`, `Charrette__96622C`, `Roues__3A3A42`, `Oeufs__F5EBD7` |
| `npc.lina`, `npc.bruno`, `npc.kai`, `npc.nora` | Dresseurs (silhouette R15 simplifiée, bras séparés) | 5 de haut | 30 chacun | `Corps`, `Tete`, `Bras_G`, `Bras_D`, `Jambe_G`, `Jambe_D`, `Cape`/`Tablier`/`Robe`, `Accessoire` |
| `arena.podium` | Podium de duel (2 plots face à face) | 24 × 8 × 1,5 | 20 | `Socle__D2C1A0`, `PlotA__2E8BFF`, `PlotB__E0202E`, `Runes__FFE680` (Neon) |
| `arena.queuePortal` | Portail « Combat en ligne » | 10 × 2 × 12 | 20 | `Arche__3A3A42`, `Voile__8A3CFF`, `Epees__C8CCD6` |
| `arena.banner` | Bannière de ligue (recolorée par code) | 3 × 0,2 × 8 | 6 | `Mat__6B4F35`, `Toile__FFFFFF` |
| `arena.board` | Tableau des classements | 12 × 1 × 8 | 12 | `Cadre__6B4F35`, `Panneau__1E1E24`, `Toit__8B3A2A` |
| `hub.calendar` | Tableau du calendrier de série | 8 × 1 × 7 | 14 | `Cadre__96622C`, `Cases__F5EBD7`, `Coffre__E8B923` |
| `hub.hatchAltar` | Autel d'éclosion (socle des révélations ≥ 5) | 8 × 8 × 1,2 | 16 | `Socle__8E93A0`, `Cercle__FFE680` (Neon), `Piliers__D2C1A0` |
| `house.museum` | 3 socles d'exposition (maison ≥ 6) | 3 × 3 × 2,5 chacun | 10 | `Socle__ECE8E1`, `Vitre__A8D8F0`, `Plaque__FFCD46` |
| `event.pumpkin`, `event.xmasTree`, `event.springArch` | décors d'événements | 3 / 12 / 10 de haut | 12 / 30 / 20 | couleurs saisonnières |
| `shop.eggStand` | présentoir des 10 œufs (boutique) | 20 × 4 × 6 | 30 | `Etagere__96622C`, `Coussins__C8323C`, `Etiquettes__F5EBD7` |

### J.2 Les 10 œufs (`eggs.r1` à `eggs.r10`)

Hauteur 1 (mise à l'échelle par le code d'après A.4), 40 pièces max, pièces nommées et couleurs de A.5 (`Coque`, `Embleme`, `Motif`, `Anneau`, `Couronne`, `Chaine`, `Cristaux`, `Etoiles`, `Ailes`, `Aureole`). Les effets (orbites, particules, lumière) restent dans le code. Priorité : r2, r8, r9, r10 (nouvelles raretés), puis r7 (Ultra Rare remplace l'ancien œuf Secret), puis les autres. Budget : 24 pièces visées.

### J.3 Créatures

Les 60 de la table C.2 (colonnes taille de pose, pièces, couleurs), en 5 lots de 12 (P1 à P5). Hauteur 1 unité (le code met à l'échelle : `petMin 1,7` à `petMax 2,5` studs selon la rareté, × taille). Pièces animées nommées obligatoirement : quadrupède `Corps`, `Tete`, `Patte_AvG`, `Patte_AvD`, `Patte_ArG`, `Patte_ArD`, `Queue` ; bipède `Corps`, `Tete`, `Bras_G`, `Bras_D`, `Jambe_G`, `Jambe_D` ; volant + `AileG`, `AileD` ; serpentin `Seg1`..`Seg6`. Pièces émissives autorisées (Neon) : `Lueur`, `Runes`, `Eclairs`, `Flammes`, `Aureole`. Chaque lot de 12 passe le protocole C.3 (points 2, 3, 5, 6) avant intégration.

Charge totale : 60 créatures × ~28 pièces ≈ 1 700 pièces de modèles (jamais toutes affichées : au plus 35 pets à l'écran).

---

## K. Lots de travail 9 à 16

Chaque lot : commits dans `roblox/` seulement, tests verts (`lune run roblox/tests/run.luau`, `python3 roblox/tools/check.py`, `scripts/check-game.sh` sur le jeu 2), puis `roblox-qa-tester` et `roblox-security-reviewer` en parallèle (CLAUDE.md), rapport Exécuté / Analysé / À tester dans Studio.

### Lot 9 : 10 raretés, œufs, tables et migration v11 (modèle : **opus**, migration de profils réels)

- Fichiers : `Config.lua` (A.1, A.2, A.4, A.6, `TIER_MIGRATE`, `TIER_GATE`, `UPGRADE.maxEggTier`, tables étendues A.7, `eggContentText`, `EggFx.looks r1..r10`, `RARITY_BANNERS`), `Rules.lua` (`tierWeights`, pool d'espèces publiées), `Reveal.lua`, `Belt.lua` (seuils), `Data.lua` (v11, A.7), `Main.server.lua` + clients (remplacement des seuils codés en dur), `Builder.lua` (œufs procéduraux A.5), `tests/fixtures` (profils v9, v10).
- Tests : somme 100 de chaque table ; `#t == 10` pour toutes les constantes A.7 ; 1 000 000 tirages par source : écart ≤ 0,05 point sur r ≤ 5 et ≤ 20 % relatif sur r ≥ 6 ; aucun tirage d'amélioration depuis un œuf r ≥ 7 ; migration : profils v9 et v10 (dont un niveau 8, 20 emplacements pleins, 1 Cosmique, quête `re = 6`, `battle.best = 30`) → v11 sans perte, mêmes revenus/s, même niveau de maison, `battle.best = 35` pour 30 ; test `grep` : aucun `tier >= [0-9]` hors `Config.lua`.
- Acceptation : un joueur v10 se connecte, voit ses œufs avec la nouvelle apparence et la bonne rareté, revenus identiques à ±0,1 % ; `tests/Economy.lua` : cibles de rythme du lot 8 tenues sur 5 graines.

### Lot 10 : compteur de rareté et animations d'éclosion (modèle : **sonnet**)

- Fichiers : nouveau `ReplicatedStorage/Odds.lua`, `Config.fmtOdds` étendu, `Main.server.lua` (calcul et stockage `o`, `ob`, `odds`, annonces B.2, `MessagingService`), `Data.lua` (classement `ChipeOeufs_Rarest_v1`), `StarterPlayerScripts/HatchFx.lua`, `CinematicKit.hatchPlan` (10 variantes), `RevealFx.lua`, étiquettes 3D des pets.
- Tests : les 4 exemples de B.1 exacts ; `fmtOdds` (7,3 / 141 / 24 631 / 605 042 / 12,5 M / 8 Md) ; `o` jamais recalculé après éclosion ; annonce mondiale ≤ 1/10 s par serveur ; plan d'éclosion : durée = table B.3 ± 0,05 s, ≤ 30 Parts, version réduite ≤ 50 % des particules ; aucune erreur sur 200 éclosions simulées par rareté.
- Acceptation : dans Studio, éclosion de chaque rareté (commande de débogage `Config.Debug.forceHatch`) sans erreur dans la sortie ; mobile ≥ 30 FPS pendant l'animation Divin.

### Lot 11 : bestiaire (données, repli procédural, intégration Blender) (modèle : **sonnet**)

- Fichiers : `ReplicatedStorage/Bestiary.lua` (78 entrées, requis par `Config.PETS`), `Battle.SPECIES_TYPE/SPECIES_SKILL` (78), `Builder.lua` (nouveaux `extra` du repli), `Config.Assets.pets` (identifiants fournis au fil des lots P1-P5), `tools/blender_check.py`, `BLENDER_REQUESTS.md` (C.2 et J), bestiaire UI (filtres par rareté et type, silhouettes).
- Tests : 78 espèces, indices 1-18 inchangés (nom, revenu sauf types listés) ; chaque rareté ≥ 3 espèces publiées (R9 ≥ 1) ; revenus croissants à l'intérieur d'une rareté ; `COLLECTION_*` : +5 % par 3 espèces jusqu'à 18 puis +5 % par 6 (max +80 %), jamais en baisse pour un profil migré ; chaque modèle a un repli.
- Acceptation : protocole C.3 passé pour P1 ; choix de style B/L consigné.

### Lot 12 : combat PvE refait (modèle : **sonnet**)

- Fichiers : `Battle.lua` (9 types, `BEATS2`, charge, nouvelles compétences, `STATS`, niveau, 40 tours), `Config.TOWER` (45 étages), `Rewards.lua` (cartes D.5), `Main.server.lua` (`pendingPick`, XP, boosts), `BattleUi.lua` (pastilles de charge, bouton Spécial, textes d'efficacité), `TypeFx.lua` (B.6).
- Tests : matrice D.2 (propriétés) ; spécial refusé avant 5, disponible au 6ᵉ tour avec 5 attaques, au 5ᵉ avec un coup super efficace ; stats r = 1,3,4,5,6,7 identiques à l'ancienne formule ; combat déterministe (même graine = même journal) ; 10 000 combats IA contre IA à rareté égale : aucun type au-dessus de 56 % de victoires ; cartes : 3 catégories distinctes, une carte Œuf aux boss, relancer la connexion ne retire pas ; XP : niveau 20 max, aucun produit ne donne d'XP de pet.
- Acceptation : joueur-robot avec équipe de sa rareté : étages 1-15 franchis en < 30 min ; durée moyenne d'un combat 8-14 tours.

### Lot 13 : duel local, intro de combat, ligues (modèle : **sonnet**)

- Fichiers : `Main.server.lua` (défis, sable du colisée, tours en direct, forfaits, quotas), `Config.DUEL`, `Config.LEAGUES`, `BattleIntro.lua` (B.4), `Data.lua` (`battle.duel`, `battle.pve`), modèles `arena.podium`, `arena.banner`, `arena.board`.
- Tests : défi refusé dans chacun des 6 cas de E.2 ; 2 tours inactifs = forfait ; récompense comptée 10/jour, 3/paire ; ratio V/D exact (arrondi) ; aucun trophée en duel local ; deux défis simultanés vers la même cible : un seul accepté.
- Acceptation : playtest local 2 joueurs (Studio, Test > 2 clients) : duel complet sans erreur, spectateur voit le combat.

### Lot 14 : classé en direct (file MemoryStore, serveur réservé « arène ») (modèle : **opus**)

- Fichiers : nouveau `ReplicatedStorage/Matchmaking.lua` (pur), `ServerScriptService/PvpLive.lua` (file, leader, tickets, téléport, retour), mode `serverMode = "arena"` dans `Main.server.lua`/`Builder.lua` (colisée seul), `Config.PVP_LIVE = { enabled = false, queueTtl = 90, refresh = 10, leaderTtl = 10, pollTicket = 2, waitArena = 25, fallbackAfter = 45, dailyFights = 15, minCCU = 60 }`.
- Tests (purs + faux MemoryStore dans `tests/FakeRoblox.lua`) : appariement selon Δtrophées et puissance avec élargissement ; aucun joueur apparié deux fois ; ticket expiré ignoré ; un seul leader à la fois (2 serveurs simulés) ; absent → combat contre la défense, aucun trophée perdu pour l'absent ; échec de téléport → remise en file ; retour vers hub si la partie d'origine n'existe plus.
- Acceptation : test réel sur le lieu publié avec 2 comptes de test dans 2 serveurs différents : combat en direct et retour ; `PVP_LIVE.enabled` reste `false` en production tant que la moyenne de joueurs simultanés < 60.

### Lot 15 : PNJ, série, calendrier, quêtes, rotation, événements (modèle : **sonnet**)

- Fichiers : `ReplicatedStorage/Npc.lua` (offres pures), `Config.NPCS`, `Config.NPC_ENCOUNTER`, dialogues F.3, `Rewards.lua` (série G.1, grâce G.2, calendrier G.3), quêtes bonus et hebdomadaires, `Config.WEEKLY_ROTATION`, `Config.EVENTS_CAL`, monnaie d'événement, sac d'œufs (`eggBag`), `Data.lua` (`npc`, `cal`, `grace`, `weekly`, `event`), modèles `npc.*`, `hub.calendar`, décors d'événement.
- Tests : aucune rencontre avant 8 min ni pendant les états interdits F.2 ; quotas 4/4 par jour, persistants au changement de serveur ; offre expirée ou rejouée refusée ; le PNJ ne demande jamais un pet interdit (F.4 point 3, 10 000 offres générées) ; valeurs d'échange exactes ; série : jour manqué → grâce, deuxième → sauvetage (quêtes ou produit), troisième → jour 1 ; calendrier : 30 cases, une par jour UTC, nouveau mois = remise à 0 ; 4ᵉ semaine complète → Mythique ; Œuf Exclusif à 150 plumes, plafond de plumes par jour respecté ; rotation déterministe par semaine.
- Acceptation : joueur-robot sur 35 jours simulés (dont 4 jours manqués) : récompenses égales à la table attendue ; dans Studio, 3 rencontres PNJ en 30 min de jeu sans gêne pendant un vol.

### Lot 16 : monétisation par paliers, passe de saison, mesure (modèle : **sonnet**, revue sécurité obligatoire)

- Fichiers : `Config.PRODUCTS/PASSES` (H.2, `id = 0` tant que non créés, liste dans `PUBLICATION.md`), `Main.server.lua` (`ProcessReceipt` : plafonds `buys`, PolicyService, crédit des œufs, saison), `Shop.lua` (pur : plafonds, éligibilité, texte des tables), UI boutique 4 onglets, `Config.SEASON` et passe (G.5), `Telemetry.lua` (I.2), `Config.BUILD`.
- Tests : chaque produit `random = true` masqué et refusé si `ArePaidRandomItemsRestricted` ou si l'appel PolicyService échoue ; aucun produit ne vend r = 8, 9 (aléatoire) ou 10 ; reçu rejoué = 1 seul crédit ; plafond atteint → compensation, jamais perte ; Double chance plafonnée à 70 ; aucun produit ne touche `Battle.STATS`, `slot.x`, protections ; passe premium achetée en cours de saison crédite les paliers déjà atteints une seule fois ; télémétrie ≤ 1 événement/s/joueur.
- Acceptation : 0 défaut critique/élevé au `roblox-security-reviewer` ; chaque fiche de produit montre sa table avant l'achat (capture dans le rapport) ; tableau de bord Analytics reçoit les 6 types d'événements en test publié.

---

## L. Les 5 risques principaux et leurs tests

1. **Migration v10 → v11 qui casse des profils (raretés décalées, revenus faux, étages)**. Test : fixtures v1 à v10 (dont Cosmique, 20 emplacements, quêtes en cours, `battle.best = 30`, défense PvP enregistrée) → v11 ; égalité des revenus/s à ±0,1 %, du niveau de maison, du nombre de pets ; relecture d'un profil v11 par le code v11 (idempotence) ; essai sur un compte de test dans un lieu privé avant publication ; garde « version plus récente = pas de sauvegarde » conservée.
2. **Inflation économique (60 espèces plus rentables, Divin à 700 000/s, récompenses quotidiennes en œufs)**. Test : `tools/sim_economy.py 30 <graine>` sur 5 graines avant/après, avec série quotidienne et cartes PvE ; bornes : premier Mythique sans achat ≥ 2 h, premier Ultra Rare ≥ 8 h, niveau de maison 8 ≥ 5 h ; un joueur payant le palier 4 une fois ne dépasse pas ×2 la progression d'un non-payeur sur 7 jours.
3. **Non-conformité sur les objets aléatoires payants**. Test automatique sur tout `PRODUCTS`/`PASSES` : `random = true` ⇒ table affichée, masquage PolicyService, refus serveur ; test « politique indisponible » (pcall en erreur) ⇒ restreint ; revue manuelle de chaque fiche avant `id ≠ 0` ; aucune offre ne contient « mystère » sans rareté fixée.
4. **PvP en ligne fragile (file vide, téléports ratés, profil écrasé au retour)**. Test : `PVP_LIVE.enabled = false` par défaut ; faux MemoryStore avec pannes injectées (latence 2 s, `UpdateAsync` en échec 20 %) : aucun joueur perdu ni dupliqué ; verrou de session : sauvegarde terminée avant `TeleportAsync` ; test réel à 2 comptes ; repli automatique vers l'asynchrone à 45 s mesuré.
5. **Performance mobile (animations Divin, 35 pets à 40 pièces, effets de types)**. Test : émulateur téléphone de Studio, 5 joueurs, 15 suiveurs + 20 pets en base + éclosion Divin + combat : FPS ≥ 30, mémoire < 1,2 Go, Parts créées par une animation ≤ 30 (compteur dans le test du plan), aucune instance qui fuit après 50 éclosions (comptage avant/après).
