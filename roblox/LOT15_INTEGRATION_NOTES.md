# Lot 15 : notes d'intégration (modules purs)

**État au 2026-11-27 : INTÉGRÉ** (voir CHANGELOG « LOT 15 intégré », LOT15_ECARTS.md, LOT15_SECURITE.md). Les données de `Lot15Data.lua` vivent désormais dans le bloc « LOT 15 » de `Config.lua` (`EVENTS` renommé `TIMED_EVENTS`) ; le fichier a été supprimé. Le reste de ce document décrit l'état d'origine des modules (historique).

État d'origine : 3 modules purs + tests, rien n'est branché. Fichiers touchés par ce travail : uniquement les nouveaux fichiers ci-dessous. Non testé dans Studio.

| Fichier | Rôle |
|---|---|
| `src/ReplicatedStorage/Lot15Data.lua` | Données : `NPCS`, `NPC_ENCOUNTER`, `NPC_RULES`, `DIALOGUES`, `TYPE_WEAK`, `STREAK`, `EGG_BAG`, `QUESTS`, `PLUMES`, `EVENTS`, `EVENTS_CAL`, `WEEKLY_ROTATION*`, `FORBIDDEN_GIFT_TIERS` |
| `src/ReplicatedStorage/Npc.lua` | Rencontres, offres, carnet, accepter / refuser / résoudre, contrôleur de violations |
| `src/ReplicatedStorage/Rewards.lua` | Série 7 jours, grâce / sauvetage, enveloppe du calendrier, quêtes bonus / hebdo, sac d'œufs, rotation, événements, plumes |
| `tests/lot15.luau`, `tests/run_lot15.py` | 204 assertions (`python3 roblox/tests/run_lot15.py`) |

Convention : tout module reçoit `Config` en paramètre (jamais de `require` interne). Toute rareté est un NOM résolu par `Config.TIERS` ; `Secret`, `Exclusif`, `Divin` ne sont jamais donnés par PNJ, série, quêtes ni sac (`FORBIDDEN_GIFT_TIERS`). Le serveur fournit le jour UTC (`os.time() // 86400`) et décide de tout.

## 1. Lignes à ajouter

### Config.lua (fin du fichier, avant `return Config`)
Fusionner les données (le plus simple, et les modules lisent ces clés dans `Config`) :
```lua
local Lot15Data = require(script.Parent.Lot15Data) -- ou copier les tables en clair, comme le reste de Config
for k, v in pairs(Lot15Data) do Config[k] = v end
```
Si l'intégrateur préfère copier à la main : `Config.NPCS`, `Config.NPC_ENCOUNTER`, `Config.NPC_RULES`, `Config.DIALOGUES`, `Config.TYPE_WEAK`, `Config.STREAK`, `Config.EGG_BAG`, `Config.QUESTS`, `Config.PLUMES`, `Config.EVENTS`, `Config.EVENTS_CAL`, `Config.WEEKLY_ROTATION`, `Config.WEEKLY_ROTATION_EPOCH`, `Config.WEEKLY_ROTATION_MULT`, `Config.WEEKLY_ROTATION_DAMAGE`, `Config.FORBIDDEN_GIFT_TIERS`. Les tests chargent le vrai `Config.lua` puis fusionnent `Lot15Data` de cette façon (`loadConfig` dans `tests/lot15.luau`).

### tools/build_place.py (liste `SHARED`)
```python
("Lot15Data", "Lot15Data.lua"), ("Npc", "Npc.lua"), ("Rewards", "Rewards.lua"),
```
(`Calendar` y est déjà.) `check.py` parcourt tous les `.lua`, donc les nouveaux fichiers sont contrôlés sans autre modification.

### tests/run.luau
Brancher le fichier de test (forme `return function(env)` avec `env = { check, suite, luau, fs }`) :
```lua
luau.load(fs.readFile("roblox/tests/lot15.luau"), { debugName = "lot15" })()({ check = check, suite = suite, luau = luau, fs = fs })
```
`tools/run_tests.py` : même appel (le runner lupa n'a pas besoin de `newRuntime` pour ce lot).

### Data.lua (nouvelle version de profil, migration idempotente depuis v11)
Champs à ajouter à `Data.default()` et à la relecture (toujours via les `sanitize` des modules, qui bornent tout) :
| Champ | Défaut | Assainissement | Contenu |
|---|---|---|---|
| `npc` | `Npc.newState()` | `Npc.sanitize(saved.npc)` | `day, trades, fights, enc, nextAt, off, champ, refuse, gone` |
| `grace` | `Rewards.sanitizeGrace(nil)` | `Rewards.sanitizeGrace(saved.grace)` | `week, used, weeks, rweek` |
| `weekly` | `Rewards.sanitizeWeekly(Config, nil)` | `Rewards.sanitizeWeekly(Config, saved.weekly)` | `w, prog[7], c5, c7, bq = { d, prog, claimed }` (la quête bonus du jour vit dans `weekly.bq`) |
| `event` | `Rewards.sanitizeEvent(Config, nil)` | `Rewards.sanitizeEvent(Config, saved.event)` | `k, d, q, v, l, p, x` (`p` = plumes d'événement) |
| `eggBag` | `{}` | `Rewards.sanitizeBag(Config, saved.eggBag)` | liste de raretés (entiers), 10 au plus |
| `cal` | déjà présent (lot 9b) | `Calendar.sanitize` (inchangé) | inchangé |
| `daily`, `streak` | déjà présents | inchangés | `daily` = dernier jour UTC réclamé, `streak` = jours de suite (non plus plafonné à 7 : le jour de série = `streak % 7 + 1`) |

Migration : un profil v11 sans ces champs reçoit les valeurs par défaut ; relire un profil déjà migré ne change rien (les `sanitize` sont idempotents : tests `Npc.sanitize`, `sanitizeGrace`, `sanitizeWeekly`, `sanitizeEvent`, `sanitizeBag`). Ajouter un test de relecture (profil v12 -> `Data.load` -> égal) dans les tests de Data. Garde « version plus récente = pas de sauvegarde » à conserver.

Note : `d.grace` (série de 7 jours) est distinct de `d.cal.grace` (jours de grâce du calendrier) : ne pas confondre. `d.event.p` (plumes d'événement) est distinct de `d.plumes` (plumes du calendrier, lot 9b) : décision à valider (fusionner les deux monnaies reviendrait à lire/écrire `d.plumes` dans `Rewards.plume*`).

### Main.server.lua (limite de 200 variables locales atteinte : loger dans la table `Lot7`, comme `Lot7.Calendar`)
```lua
Lot7.Npc, Lot7.Rewards, Lot7.NpcBook = require(Shared.Npc), require(Shared.Rewards), {} -- NpcBook[player] = Npc.newBook()
```
Branchements à faire (le serveur décide, le client affiche) :
1. **Boucle de rencontres** (toutes les 5 s par joueur) : `Npc.encounter(Config, d.npc, book, userId, os.time(), os.time() // 86400, ctx, inv, math.random)` avec `ctx = { sessionStart, carrying, chased, inDuel, inCastle, inCinematic, flying, inTerritory, pending, lastRevealAt, lastRevealTier }` (états déjà connus du serveur) et `inv` construit à partir de `d.slots` (voir ci-dessous). Si une offre est retournée : créer le PNJ (modèle `npc.*` ou repli procédural) à `NPC_ENCOUNTER.approachRange` (25 studs), sur un chemin ou la place, jamais dans un territoire ; envoyer au client `NpcOffer`. Appeler `Npc.sweep(book, os.time())` toutes les 5 s (le PNJ repart sans pénalité) et à la sortie du joueur (libérer le carnet : pas de fuite mémoire).
2. **Inventaire `inv`** : `{ coins = d.coins, pets = { { slot = i, p = sl.p, s = sl.s, m = sl.m, follower = d.equip contient i, team = i dans d.battle.team, defense = i dans d.battle.pvp.defense } ... }, seen = { [p] = true pour p dans d.dex }, typeOf = fonction (Battle.SPECIES_TYPE ou matrice du lot 12), avgLevel, teamTiers = { rareté de chaque pet de l'équipe } }`.
3. **Accepter** : `Npc.accept(Config, book, id, userId, now, inv, { confirm2 = c })` ; pour un échange, appliquer l'effet retourné en une seule fois APRÈS `Data.save` réussi (comme pour le calendrier : verrou de réclamation pendant la sauvegarde) : `coins`, retirer `take` (emplacements), donner `egg` via `Rewards.storeEggs(Config, d.slots, cap, d.eggBag, { egg }, mkEgg)` (refus `bagFull` = refuser l'échange avant de retirer quoi que ce soit : vérifier `Rewards.canStore` d'abord), ou créer le pet `species` (`{ p, s, m }`) ; incrémenter la quête `npcTrade` et le thème hebdo `npc` ; `Npc.noteAccepted(d.npc, effet.npc)`. Pour un combat : lancer le combat PvE avec `offer.team`, `offer.powerMul`, résultat déclaré par le SERVEUR via `Npc.resolve(...)` (jamais par le client), puis cartes D.5 (`cardPct`, `rewardMul`, `cardEgg`) ou `egg` garanti (Kaï) ; défaite : `xp` (+5) et rien d'autre.
4. **Refuser** : `Npc.decline(Config, d.npc, book, id, userId, now)` ; « Ne plus être interpellé » = `d.npc.off = true/false` (remote réglage, booléen validé).
5. **Série quotidienne** (remplace `actions.daily` et le texte du `playerState` : `dailyReady` / `dailyReward`) : `Rewards.streakPlan(Config, g, today, { questsDone })` pour l'affichage (état `ready / grace / rescue / reset / done`, jour, série en jeu), `Rewards.streakClaim(Config, g, today, how, ctx)` pour réclamer, avec `g = { daily = d.daily, streak = d.streak, grace = d.grace }` (mêmes tables : la fonction modifie `d.grace` en place ; recopier `daily` et `streak` dans `d`). Octroyer ensuite `grant` : `coins`, `luck` (`d.luckUntil`), `boost` (`d.boosts`), `fragments` (`d.puzzle.fragments`), `eggs` déjà rangés par `streakClaim` si `ctx.slots` est fourni (base puis sac, atomique ; en cas d'échec `bagFull`, rien n'est modifié). `how = "product"` uniquement après vérification du reçu `StreakRestore` (29 R$, 1 fois par semaine : `grace.rweek`).
6. **Calendrier** : remplacer l'octroi de l'œuf (« refusé si base pleine ») par `Rewards.calendarClaim(Config, Calendar, cal, today, day, how, eligible, rnd, income, { slots, cap, bag })` ; il utilise `Calendar.check / plan / apply` du lot 9b sans les modifier. Le tirage du jour 30 peut donner un Secret : règle propre au calendrier (décision utilisateur), hors des interdits.
7. **Quêtes** : `Rewards.bonusEvent` (victoire PvE : `{ kind = "pve" }` ; éclosion : `{ kind = "hatch", tier }`, `unlocked` = 3 quêtes du jour faites), `Rewards.bonusClaim`, `Rewards.weeklySync` (chaque jour), `Rewards.weeklyAdd(Config, wk, "hatch" | "steal" | "pve" | "pvp" | "collect" | "riddle" | "npc", n)`, `Rewards.weeklyClaim(Config, wk, 5 | 7, store)` ; `seasonXp` du retour -> passe de saison (lot 16). Nouveaux types de quêtes du jour : `Config.QUESTS.newTypes` (forme libre à adapter à `Config.QUEST_TYPES` : `pve`, `duel`, `npcTrade`, `typeWin`, `odds`).
8. **Sac d'œufs** : action serveur « poser un œuf du sac » -> `Rewards.bagTake(d.slots, cap, d.eggBag, mkEgg)` (`mkEgg(tier)` = emplacement avec `ends` / `shield` comme les autres œufs) ; envoyer `#d.eggBag` dans `playerState`.
9. **Rotation et événements** : `Rewards.rotation(Config, Npc.weekOf(today))` (même résultat sur tous les serveurs) ; `Rewards.featuredWeight` dans le tirage des œufs et l'affichage du 🎲 ; `Rewards.typeDamage(Config, rot, type, true)` en PvE ; `Rewards.activeEvents(Config, os.time())` : `weekend` (+5 points d'amélioration, tapis 4 s) et `golden` (clé `gold` de la ruée vers l'or existante) ; `Rewards.limitedEvent(Config, today)` -> décor et boss d'événement ; plumes : `Rewards.plumeSync(Config, d.event, today, key)` puis `Rewards.plumeAdd(Config, d.event, "quest" | "pve" | "login", active)` et `Rewards.plumeBuyExclusive(Config, d.event, active, store)` (refusé tant que la rareté Exclusif n'a aucune espèce publiée : `notLive`).
10. **Reçu / sécurité** : toutes ces actions sont des remotes qui ne portent que des identifiants ou des booléens ; le serveur revérifie chaque condition (le client n'envoie jamais un prix, une rareté ou un jour). Un verrou par joueur pendant la sauvegarde (comme `s.calBusy`) empêche une double réclamation.

## 2. Remotes à créer (+ déclaration dans `check.py` si nécessaire)
| Remote | Sens | Charge utile | Remarque |
|---|---|---|---|
| `NpcOffer` | serveur -> client | vue (`Npc.view`) + dialogue (`Npc.say`) | seulement hors vol, cinématique, œuf porté, poursuite |
| `NpcAnswer` | client -> serveur | `{ id, action = "accept" or "decline", confirm2 = bool }` | validation de type stricte, antispam |
| `NpcSetting` | client -> serveur | `{ off = bool }` | règle `npc.off` |
| `NpcResult` | serveur -> client | issue d'un échange ou d'un combat | dialogues de victoire / défaite (`Npc.say`, `Npc.tip`) |
| `StreakView` / `StreakClaim` | serveur -> client / client -> serveur | vue de `streakPlan` ; `{ how = nil or "quest" or "product" or "reset" }` | `product` n'est jamais accepté du client : seul le reçu le déclenche |
| `BagPlace` | client -> serveur | aucune donnée (le serveur choisit l'œuf le plus ancien) | |
| `WeeklyClaim` / `BonusClaim` | client -> serveur | `{ which = 5 or 7 }` / aucune | |
| `PlumeBuy` | client -> serveur | aucune | Exclusif à 150 plumes |

Client : bulle « ❗ » au-dessus du PNJ, panneau série + calendrier (kiosque), notification rouge (`ui_pastille_rouge`), réglage « Ne plus être interpellé » dans le menu ; sons `npc_ping`, `calendar_*`, `jackpot_rare` seulement (aucun son de harcèlement).

## 3. Décisions et écarts à connaître
1. **Calendrier 30 jours** : réutilisé tel quel (`Calendar.lua`) ; la table des récompenses lue est celle de `Config.CALENDAR` au moment de l'intégration. Dans le commit de départ (`ca484b2`), `Config.CALENDAR.rewards` donne encore J7 = Rare (egg 3) et J14 = Épique (egg 4), pas la table finale annoncée par le brief (J3 Légendaire, J7 Épique, J10 Légendaire, J20 Mythique) : c'est un autre agent qui modifie `Config.lua`, les tests de ce lot n'assertent donc pas ces valeurs (ils vérifient que chaque jour donne exactement ce que dit `Config.CALENDAR.rewards[jour]`).
2. **Espèces de PNJ (Koala, Ours brun, Renard à neuf queues)** : absentes de `Config.PETS` (lot 11) ; elles ne sont que des `signature` (affichage / modèle). Les équipes PNJ n'utilisent que des espèces existantes (filtrées par `inv.typeOf` si fourni). Le test vérifie que la signature n'est pas utilisée tant qu'absente.
3. **Rareté sans espèce publiée** (Peu commun, Secret, Exclusif, Divin avant le lot 11) : un œuf donné prend la rareté publiée inférieure (`Config.tierLive`, convention du lot 9). Conséquence visible avec le `Config` actuel : le jour 1 de la série donne un Œuf Commun tant que « Peu commun » n'a pas d'espèce. Le test « Config full » (10 raretés publiées par des espèces factices) prouve que la rareté suit bien le nom. Les offres de Pip qui n'apporteraient aucun gain (3 Communs contre 1 Commun) sont écartées.
4. **Plumes d'événement** : monnaie distincte de `d.plumes` ; solde et achats remis à zéro au début d'un nouvel événement (pas de report) ; plafond 3 Œufs Exclusifs par événement ; plafonds par jour : quêtes 40, victoires PvE 20, connexion 5 (65 au plus). À valider par l'utilisateur.
5. **Série de 7 jours** : le champ `streak` compte les jours de suite sans plafond ; jour affiché = `streak % 7 + 1` ; un jour manqué est pardonné (grâce gratuite, 1 par semaine UTC, lundi = début) ; 2 jours manqués ou un jour manqué sans grâce = écran de sauvetage (3 quêtes du jour faites, ou produit une fois par semaine) ; 3 jours manqués ou plus = jour 1. Choix à confirmer : « deuxième jour manqué » interprété comme « grâce déjà consommée cette semaine » ou « 2 jours d'affilée ».
6. **Quota PNJ** : un échange ou un combat compte dès l'apparition (même sans réponse), ce qui empêche de forcer de nouvelles rencontres en se reconnectant. Kaï (lundi UTC, 1 fois par semaine) est hors quota et hors alternance. 8 premières minutes comptées depuis `ctx.sessionStart` (une reconnexion les relance, `npc.nextAt` absolu empêche en plus toute rencontre trop proche).
7. **Rotation** : types de `TypeFx.TYPES` (9) ; espèces vedettes et cosmétiques de boutique (`shop`) sont des ids provisoires à relier au catalogue (lot 16) ; `WEEKLY_ROTATION_EPOCH = 0` (la semaine 0 UTC du 1970 = cycle 1).
8. **Limites** : logique pure testée sous lupa (Lua 5.x, pas Luau) ; aucun test Studio ; client, remotes et sauvegarde non écrits.
