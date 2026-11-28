# Chipe-Œufs, idée 2 : évolution des pets (forme 2)

Préparé hors de la branche de jeu : copie de `roblox/` au commit **fa4e42b** (lot 14 intégré, exportée avec `git archive`). Aucune modification de la branche de jeu de la session Jeu 2. Aucune publication, aucune clé API.
Spécification : `obsidian-studio/Jeux/IDEES_CHIPE_OEUFS.md`, idée « Évolution des pets » (numérotée 1 dans le fichier, 2 dans la demande).

## Règle livrée

- Un pet passe en **forme 2** en sacrifiant **3 doublons de la même rareté** et **5 min du revenu actuel** du joueur (pièces, `300 s x revenu/s`, arrondi au supérieur).
- **Doublon** : pet dont l'espèce garde au moins un exemplaire dans la base après l'évolution (le pet visé compte). Le serveur choisit seul les 3 doublons : ceux qui rapportent le moins d'abord.
- **Forme 2** : même espèce (`slot.p` inchangé), `slot.f = 2`. Revenu x1,15 (`Config.petIncome`, donc `Rules.income`, étiquette, revente par lot). Pv et attaque x1,10 en combat (`Battle.unit`, échelle). Modèle agrandi x1,15 avec un anneau lumineux tournant (tag `EggHalo` existant, 1 Part de plus, aucun nouveau modèle).
- **Aucune forme payante** : aucun produit, pass ni Robux. Le client n'envoie que l'emplacement et le prix maximal qu'il accepte (`maxCost`). Tout le reste est calculé par le serveur.
- **Interdits**, pour le pet visé comme pour les sacrifiés :
  - pet suiveur (`equip`), pet de l'équipe de combat, pet dont la copie `(p, s, m)` est dans la défense PvP enregistrée ;
  - pet déjà en forme 2 ;
  - action refusée pendant un combat, le mode Château, une recherche PvP ou un départ.
- **Géant / Colossal / Arc-en-ciel (choix documenté)** : ces pets n'évoluent pas et ne sont jamais sacrifiés. Le même interdit couvre Alien et Céleste, plus forts qu'Arc-en-ciel.
  - Visuel : leurs effets (échelle 1,6 à 2,1, arc-en-ciel, aura Céleste) entreraient en conflit avec l'agrandissement et l'anneau.
  - Économie : un +15 % sur des multiplicateurs x2,5 à x20 serait très fort.
  - Protection : la sélection automatique ne doit jamais sacrifier un doublon précieux.
  - Réglable : `Config.EVOLUTION.blockedSizes` / `blockedMuts`.
- **Atomicité** (même schéma « sauvegarde puis octroi » que le calendrier et les cartes) :
  1. `Evolution.stage` construit une copie du profil après évolution ;
  2. `Data.save` sauvegarde cette copie ;
  3. seulement en cas de succès, `stillValid` puis `apply` modifient le profil vivant (pièces débitées par différence, pour garder le revenu gagné pendant la sauvegarde).

  Si la sauvegarde échoue, rien n'a changé. Pendant la sauvegarde, `s.evoBusy` gèle toutes les autres actions du joueur (sauf `sync`).
- **Profil v14** : `evo = { ["indice d'espèce"] = n }`. Le compteur survit à la renaissance et n'est jamais remis à zéro.
  - Migration v13 -> v14 (`Evolution.migrate`, idempotente) : pose `evo = {}` s'il manque, ne touche rien d'autre.
  - `merge` assainit `evo` et `slot.f` : `f = 2` est gardé, toute autre valeur est retirée (y compris sur un œuf).
  - Changement de version **voulu** : un serveur encore en v13 voit « version plus récente » et ne sauvegarde pas ce profil. Sans cela, il effacerait `evo` et compterait une forme 2 comme une forme 1.
- `Config.EVOLUTION.enabled = false` dans la source : à activer après le test Studio. Même désactivée, une forme 2 existante garde ses bonus.

## Contenu

| Fichier | Rôle |
|---|---|
| `roblox/src/ReplicatedStorage/Evolution.lua` (nouveau, pur) | `form`, `sanitizeForm`, `sanitizeCounts`, `migrate`, `protected`, `targetCheck`, `pickSacrifices`, `cost`, `plan`, `view`, `stage`, `stillValid`, `apply`, `powerScale`, `incomeMulOf`, `visualScale`, messages `REFUSE`. Aucun yield, aucune API Roblox. |
| `roblox/tests/evolution.luau`, `roblox/tests/run_evolution.py` | 77 assertions (voir Résultats). |
| `patches/Config.lua.patch` | `Config.EVOLUTION` ; `Config.petIncome(p, s, m, f)` (4e argument facultatif) ; `dupesToSell` compte la forme 2 et ne la revend jamais. |
| `patches/Data.lua.patch` | `VERSION = 14`, `MIGRATIONS[13]`, `evo` dans `default()` et `merge()`, `Evolution.sanitizeForm` sur chaque emplacement. |
| `patches/Main.server.lua.patch` | Module et remote `Evo` rangés dans `Lot7` (aucune nouvelle variable locale : le bloc principal est à 169/200). Actions `evoPreview` / `evolve`, gel des actions pendant `evoBusy`, `battleUnits` avec `Evolution.powerScale`, `Builder.pet` / `follower` avec la forme, étiquette « ★2 » avec le revenu de forme 2, `snapshot` (`f`, `evo`), `fresh.evo` à la renaissance. |
| `patches/Builder.lua.patch` | `evolveLook` : `ScaleTo(x1,15)` et anneau `addHalo` (pet procédural ou modèle Blender), `Builder.pet(..., form)` et `Builder.follower(..., form)`. |
| `patches/Rules.lua.patch` | Hors liste demandée, mais indispensable : `Rules.income` passe `sl.f` (c'est là que se calcule le revenu). |
| `patches/build_place.py.patch` | Ajoute `Evolution` à la liste des modules partagés du constructeur de lieu. |
| `patches/Economy.lua.patch` | Joueur-robot : option `opts.evolve` (absente = comportement identique au bit près) ; `weakest()` lit la forme. |
| `patches/run.luau.patch` | Ajoute la suite `evolution` ; assertions `ver == 13` -> `ver == 14`. |
| `patches/lot12b.luau.patch`, `patches/lot15_e2e.luau.patch`, `patches/lot16_e2e.luau.patch` | Assertions de version `13` -> `14`. La fixture « version plus récente » du lot 15 passe de v14 à v15. |

## Brancher

Depuis la racine du dépôt de jeu (le dossier qui contient `roblox/`) :

1. Copier `roblox/src/ReplicatedStorage/Evolution.lua`, `roblox/tests/evolution.luau` et `roblox/tests/run_evolution.py` aux mêmes chemins.
2. Appliquer les patchs : `for p in <chemin>/lots-prep/idee-evolution/patches/*.patch; do patch -p1 < "$p"; done`
   - Testé : `patch -p1 --dry-run` OK pour les 11 patchs sur une copie neuve de fa4e42b.
   - Application réelle + copie des 3 fichiers = arbre identique à l'arbre testé (`diff -r` vide sur les fichiers du lot).
   - Si un lot postérieur a touché les mêmes zones (`Data.VERSION`, `merge` des emplacements, `actions.rebirth`, dispatcher `RAction`, `battleUnits`, `snapshot`, `Builder.pet`), appliquer les blocs à la main : ils sont courts et commentés « idée 2 ».
   - **Si un autre lot passe aussi la version à 14**, prendre la suivante et ajuster les assertions `ver ==`.
3. Client (non fourni, petit) :
   - bouton « ✨ Évoluer » sur la fiche d'un pet → action `evoPreview` avec l'indice ; le serveur répond sur le remote `Evo` : `{ k = "preview", view = { ok, sac, cost, code, found, need } }` ;
   - confirmation → action `evolve` avec `{ i = indice, maxCost = view.cost }` ; réponse `{ k = "done", i, p, n }` et un message ;
   - `snapshot.slots[i].f == 2` permet d'afficher « ★2 » et le revenu x1,15 dans la collection (aujourd'hui, `Client.client.lua` affiche encore le revenu de forme 1) ;
   - `snapshot.evo` donne le compteur par espèce.
4. Activer : `Config.EVOLUTION.enabled = true` après le test Studio ci-dessous.

## Résultats (exécutés dans cet environnement, arbre patché)

| Commande | Résultat |
|---|---|
| `python3 roblox/tests/run_evolution.py` (lupa) | **77 assertions réussies, 0 échec** |
| `python3 roblox/tools/run_tests.py` (suite complète, avec démarrage réel du vrai `Main.server.lua` dans le runtime factice) | **4290 réussies, 0 échec**, code 0 |
| `lune run roblox/tests/run.luau` (Lune) | **4290 réussies, 0 échec** |
| Référence fa4e42b sans patch (`run_tests.py`) | 4213 réussies, 0 échec. L'écart est exactement les 77 assertions de l'idée 2, aucune régression. |
| Tests de rythme et de tapis du lot 9 / lot 16 | Verts (robot sans évolution). Trajectoires identiques au bit près avec et sans le patch (test dédié). |
| Mutations (5 règles cassées une à une : force x1,30, dernier exemplaire sacrifiable, suiveur non protégé, sauvegarde ignorée, Arc-en-ciel autorisé) | **Toutes détectées** : 5, 1, erreur d'exécution, 2 et 3 échecs. |
| `stylua --check` sur `Evolution.lua` et `evolution.luau` | OK. `Config` / `Data` / `Main` / `Builder` n'étaient déjà pas conformes stylua à fa4e42b ; les patchs ne les reformatent pas. |
| `selene` | La std `roblox` n'est pas téléchargeable ici. Lancé avec une std `luau` + globales Roblox : `Evolution.lua` 0 erreur, 0 avertissement ; Config/Data/Main/Builder/Rules : même nombre d'alertes qu'à fa4e42b. |
| `rojo build game.project.json` | OK |

Ce que couvrent les 77 assertions :

- **Configuration** : valeurs de la spécification, `enabled = false`, interdits.
- **Aucune forme payante** : le code d'`Evolution.lua` et de `actions.evolve` (commentaires exclus) ne contient ni Robux, ni produit, ni pass, ni invite d'achat ; aucun produit « evo » ; `ProcessReceipt` ne touche ni `f`, ni `evo`.
- **Règle de force sur les 10 raretés** : 9 x 3 tailles x 3 mutations x 20 niveaux = 1 620 comparaisons. La forme 2 de la rareté r reste strictement sous la forme 1 de r + 1. Plus petit écart : x1,143 (raretés 8 -> 9 et 9 -> 10).
  - Le test a des dents : avec x1,30, la règle est violée.
  - Marge : même un Géant ou Colossal Céleste niveau 20 en forme 2 resterait sous la rareté suivante, à conditions égales.
  - Sur les 78 espèces du bestiaire, par le vrai chemin `Battle.unit` + `Evolution.powerScale` : plus de 1 000 comparaisons contre toutes les espèces de rareté supérieure.
- **Revenu** : la forme 2 de la meilleure espèce d'une rareté reste sous la plus faible espèce de la rareté suivante (règle x1,8 de `INCOME_RANGE`).
- **Assainissement et migration** : idempotence, jamais de remise à zéro.
- **Plan** :
  - choix des doublons, jamais le dernier exemplaire, ordre par revenu ;
  - chacun des interdits ;
  - emplacement invalide ou hors capacité, combat en cours ;
  - pièces insuffisantes ;
  - prix maximal du client (dépassé, non numérique, NaN) ;
  - coût arrondi, revenu invalide = 0.
- **Atomicité** :
  - `stage` ne touche pas le profil vivant ;
  - `apply` débite par différence ;
  - `apply` rejoué, doublon remplacé ou pièces insuffisantes : refusé sans rien modifier.
- **Économie** :
  - `Rules.income` avec la forme 2 ;
  - la revente par lot ne revend jamais une forme 2 ;
  - robot du lot 9 identique ;
  - robot qui fait évoluer ses pets : 20 graines, 12 h.
- **Bout en bout** (vrai Main + Data) :
  - migration v13 -> v14 et relecture idempotente ;
  - profil v15 jamais écrasé ;
  - action refusée tant que l'option est désactivée ;
  - aperçu, puis refus au-dessus du prix maximal ;
  - évolution réussie, enregistrée dans le DataStore **avant** l'octroi ;
  - **DataStore en panne : aucune perte** (pets, forme, compteur, pièces, DataStore inchangés), `evoBusy` libéré, puis nouvel essai réussi ;
  - interdits vérifiés côté serveur ;
  - arguments invalides sans effet ;
  - actions gelées pendant `evoBusy` ;
  - combat de la tour : le pet en forme 2 entre avec pv x1,10 ;
  - le compteur survit à la renaissance.

### Mesure économique (joueur-robot, `tests/Economy.lua`)

| Profil de joueur | Évolutions | Jalons d'accès (premier Légendaire, premier Mythique, maisons 4 à 6, moyenne géométrique) |
|---|---|---|
| Normal : évolue si le coût vaut au plus 10 % de ses pièces | 2,1 par partie de 12 h, la première vers 7 h | **x0,999** (aucun effet mesurable). Tous les jalons du lot 9 atteints avant la première évolution sont identiques au bit près. |
| Acharné : évolue dès que le coût vaut au plus 50 % de ses pièces | 5,3 par partie, la première vers 58 min | **x0,894**, soit environ 11 % plus tôt. Mesuré seulement, voir Écarts. |

## Écarts et choix (assumés)

1. **Fichiers patchés en plus de Config/Data/Main/Builder** :
   - `Rules.lua` : 1 ligne, c'est la fonction de revenu ;
   - `build_place.py` : liste des modules ;
   - `tests/Economy.lua` : option du robot ;
   - les tests qui vérifient `ver == 13`, à cause du passage en v14.
2. **Version 14** au lieu d'un champ facultatif sans version (comme au lot 14). Seule une nouvelle version garantit qu'un serveur ancien ne remet pas `evo` à zéro pendant un déploiement.
3. **« 5 min de revenus »** = revenu total actuel du joueur, événements et boosts compris. Le prix change donc pendant une Ruée vers l'or ; d'où `maxCost`, qui garantit au joueur de ne jamais payer plus que ce qu'il a vu.
4. **Force +10 %** = pv et attaque x1,10, vitesse inchangée, comme les bonus de taille et de niveau. La puissance (`pv + 3 x atq + 2 x vit`) monte donc d'un peu moins de 10 %.
5. **PvP enregistré et classé en direct** : les copies d'équipe `(p, s, m)` restent des **stats brutes**, sans forme, comme l'XP de niveau aujourd'hui. Une forme 2 y compte donc comme une forme 1 : elle est plus faible, jamais plus forte. Elle s'applique là où l'équipe vient des emplacements : tour, duels locaux, rencontres PNJ, camp attaquant du PvP asynchrone.
6. **Défense PvP** : correspondance par valeur `(p, s, m)`, car la défense est une copie. Prudent : si deux pets identiques existent, les deux sont protégés tant que la défense n'est pas réenregistrée.
7. **Rythme, joueur acharné** : environ 11 % d'avance, au-delà des 10 % visés. L'accélération ne vient **pas** du revenu x1,15 (un essai à revenu x1,00 donne le même x0,87). Elle vient des **3 places libérées** par les doublons, que le robot remplit aussitôt d'œufs : plus d'éclosions, donc des maisons plus rapides. Le joueur normal n'est pas affecté. Si la télémétrie montre un effet réel :
   - passer `costSeconds` à 900 (mesuré x0,96) ;
   - ou ne pas compter les éclosions qui suivent une évolution.

   Les valeurs de la spécification sont gardées.
8. **Revente à l'unité** d'une forme 2 : autorisée, au prix d'une forme 1 (`sellValue` inchangé). La revente **par lot** ne la prend jamais.
9. **Télémétrie** (critère de succès « 40 % évoluent en 7 jours ») : non branchée. Ajouter la métrique `pet_evolve` impose de modifier le test qui compte exactement 16 métriques ; à faire avec le client.
10. **Interface client** : non fournie (voir Brancher, point 3).

## Limites connues

- Pendant la sauvegarde d'une évolution (jusqu'à environ 10 s en cas de nouvelles tentatives), les autres actions du joueur sont ignorées. Le revenu et les éclosions continuent.
- Si le joueur quitte pendant cette sauvegarde, sa sauvegarde de départ attend la fin, puis écrit l'état vivant, déjà évolué si la sauvegarde a réussi.
- Un serveur encore en v13 pendant le déploiement charge un profil v14 en lecture seule : le joueur joue, mais ce serveur ne sauvegarde pas. Comportement voulu, le même que pour chaque montée de version.

## À tester dans Studio

1. **Démarrage** (Play, `enabled = false`) : aucune erreur dans la sortie. Un profil existant passe en v14 sans perte : comparer pièces, pets et niveau de maison avant et après.
2. **Activer** (`Config.EVOLUTION.enabled = true`, copie de test). Base avec 4 Poussins et un Hamster ; action `evoPreview` sur le premier Poussin. Attendu : `ok`, 3 sacrifiés, coût = 300 x revenu/s.
   Puis `evolve { i = 1, maxCost = coût }`. Attendu :
   - les 3 doublons disparaissent ;
   - le Poussin restant est plus grand, entouré d'un anneau doré qui tourne ;
   - l'étiquette affiche « ★2 » et un revenu x1,15 ;
   - pièces débitées, message « évolue en forme 2 ».
3. **Suiveur / équipe** : équiper le pet évolué comme suiveur. Il doit rester plus grand avec son anneau (réduit à 0,45 comme les autres suiveurs), sans décalage de position ni anneau détaché. Le mettre dans l'équipe, lancer la tour : ses pv affichés sont x1,10.
4. **Interdits** : essayer d'évoluer un suiveur, un membre de l'équipe, un Géant, un Arc-en-ciel. Attendu : message de refus, rien ne change.
5. **Sauvegarde** (Studio avec accès API, ou lieu publié de test) : évoluer, quitter, revenir. Attendu : forme 2, compteur (`snapshot.evo`) et pièces conservés.
6. **Modèle Blender** : si un pet utilise un modèle `clonePet`, vérifier l'agrandissement et l'anneau sur ce modèle (`ScaleTo` sur un modèle ancré).
7. **Mobile** : l'anneau (1 Part Neon) ne doit pas gêner les invites de proximité des emplacements voisins.
