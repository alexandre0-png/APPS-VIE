# Chipe-Œufs, lot 12 partie B : récompenses par cartes (D.5), XP de pet (D.6), UI de combat

Préparé hors de la branche de jeu (copie de `wt/o2/roblox`, commit 91f6907). Rien ici ne touche `Battle.lua`, `Rewards.lua` (lot 15), `Main.server.lua`, `Config.lua`.
Aucun jeu publié, aucune clé API.

## Contenu

| Fichier (arbre `roblox/`) | Rôle |
|---|---|
| `src/ReplicatedStorage/BattleRewards.lua` (nouveau) | Pur. Tirage de 3 cartes de 3 catégories distinctes (poids 30/25/15/15/15), carte Œuf d'office aux boss, `pendingPick`, `claim`, `grant`, boosts temporaires, assainissement. Park-Miller 48271 mod 2^31-1, graine injectable. |
| `src/ReplicatedStorage/PetXp.lua` (nouveau) | Pur. XP cumulée (`slot.x`), niveaux 1-20, `statMul` (+1,5 %/niveau), sources d'XP en liste blanche (jamais de produit), XP de Dresseur. |
| `src/StarterPlayerScripts/BattleUi.lua` (remplace l'existant) | Pastilles de charge, bouton Spécial « 3/5 », texte d'efficacité (journal + flottant), écran de choix des 3 cartes. Patch : `patches/BattleUi.lua.patch`. |
| `patches/Data.lua.patch` | Champs `battle.pendingPick`, `boosts`, `trainer`, `slot.x` borné. Testé : `patch -p1` s'applique sur 91f6907. |
| `tests/lot12b.luau`, `tests/run_lot12b.py` | 92 assertions (voir Résultats). |

## Brancher (ordre conseillé)

1. Copier `BattleRewards.lua` et `PetXp.lua` dans `src/ReplicatedStorage/`, `BattleUi.lua` dans `src/StarterPlayerScripts/`, `lot12b.luau` + `run_lot12b.py` dans `tests/`.
2. `cd roblox && patch -p1 < ../patches/Data.lua.patch` (depuis la racine du dépôt de jeu : `patch -p1 < <chemin>/patches/Data.lua.patch`). Il ajoute : deux `require` (après `local Rewards = ...`), `boosts = {}` et `trainer = { xp = 0 }` dans `Data.default()`, `d.boosts`/`d.trainer` dans `merge()` (après `d.xp2Until`), `d.battle.pendingPick = BattleRewards.sanitizePending(...)` **après** la reconstruction de `d.battle` (avant `if type(saved.receipts)`), et `sl.x = PetXp.sanitize(sl.x)`.
3. `tests/run.luau`, ligne `for _, name in ipairs({ "lot15", "lot15_e2e" }) do` : remplacer par `{ "lot15", "lot15_e2e", "lot12b" }`.
4. `Main.server.lua` (intégrateur, non testé ici car `Battle.lua` du lot 12 arrive d'ailleurs) :

```lua
-- en tête, avec les autres require
local BattleRewards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BattleRewards"))
local PetXp = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetXp"))
```

Dans `battleFinish`, bloc `if first or b.repeats < TW.dailyRepeats then ... end` (actuellement `Config.towerReward` + `giveEgg`), remplacer le corps par :

```lua
if not first then
	b.repeats += 1
end
rewards.first = first
rewards.pick = true -- le client attend { k = "pick" } et masque « Continuer »
local pick, isNew = BattleRewards.offer(Config, b.pendingPick, { floor = bt.floor, income = income(s), mode = first and "first" or "repeat" },
	rng:NextInteger(1, 2147483000), os.time(), HttpService:GenerateGUID(false))
b.pendingPick = pick -- enregistré AVANT l'envoi : déconnexion ou relance ne retire pas la récompense
```

et, **après** le `RBattle:FireClient(..., { k = "end", ... })` de la fin de `battleFinish` : `if s.data.battle.pendingPick then sendPick(s) end`. Pour les combats PNJ (`L15.fightEnd`), même appel avec `mode = "npc"`, `floor = 0`.

Fonctions serveur à ajouter près de `giveEgg` :

```lua
local function pickHooks(s)
	return { giveEgg = function(t) -- base pleine : NE PAS appeler giveEgg (il paie déjà la moitié du prix) ; grant paie le prix plein
		if not freeSlot(s) then return false end
		return giveEgg(s, t)
	end }
end
local claimPick
local function sendPick(s)
	local pk = s.data.battle.pendingPick
	if not pk then return end
	if BattleRewards.expired(pk, os.time()) then return claimPick(s, nil, nil) end
	local v = BattleRewards.view(Config, pk, os.time())
	RBattle:FireClient(s.player, { k = "pick", id = v.id, cards = v.cards, seconds = v.seconds, floor = v.floor })
	task.delay(v.seconds + 1, function() -- délai de 15 s tenu par le SERVEUR : première carte d'office
		local cur = s.data.battle.pendingPick
		if s.player.Parent and cur and cur.id == v.id then claimPick(s, nil, nil) end
	end)
end
function claimPick(s, id, index)
	local b = s.data.battle
	local card, auto = BattleRewards.claim(b.pendingPick, id, index, os.time())
	if not card then return end -- index invalide : rien n'est consommé
	b.pendingPick = nil -- vidé AVANT d'attribuer : aucun double gain
	local out = BattleRewards.grant(Config, s.data, card, pickHooks(s), os.time(), PetXp)
	-- texte : out.coins / out.xp / out.speed / out.egg (+ out.converted) / out.effect -> chaîne pour { k = "picked", text, auto }
	local _, _, desc = BattleRewards.cardText(Config, card)
	RBattle:FireClient(s.player, { k = "picked", text = desc .. (out and out.converted and " (base pleine : converti en pièces)" or ""), auto = auto })
	RState:FireClient(s.player, snapshot(s))
end
function actions.battlePick(s, arg) -- arg = { id, i } ; le dispatcher d'actions fournit déjà la limitation de fréquence
	if type(arg) == "table" then claimPick(s, arg.id, arg.i) end
end
```

À la connexion (fin d'`onJoin`, une fois `s.data` chargé) : `sendPick(s)` (reconnexion : même tirage, temps restant ; échu = première carte d'office). Dans `snapshot`, ne PAS exposer `pendingPick` (cartes seulement via `k = "pick"`).

XP de pet, dans `battleFinish` après le résultat (PvE tour, PvP, PNJ) :

```lua
local mul = PetXp.boostMul(s.data, os.time())
local kind = bt.pvp and "pvp" or (bt.npc and "npc" or "pve")
local xp = PetXp.award(kind, PetXp.combat(kind, win, bt.floor), mul)
PetXp.addToTeam(s.data.slots, s.data.battle.team, xp)
s.data.trainer = PetXp.trainerAdd(s.data.trainer, xp)
```

Boosts de cartes (`data.boosts`, fin en `os.time()`), à lire aux endroits existants : `income2` dans `gmult`/revenus (x2), `luck10` dans le calcul de chance d'amélioration (+10 points, comme `luckUntil`), `speed15` dans la vitesse de marche (+15 %), `xp2` déjà lu par `PetXp.boostMul`. Utiliser `BattleRewards.boostActive(d.boosts, "income2", os.time())`.

Vol / vente : `PetXp.carry(slot)` donne l'XP à reporter sur l'emplacement du voleur ; la victime la perd avec le pet (slot remplacé). `Battle.unit` (autre agent) : multiplier pv et attaque par `PetXp.statMul(PetXp.level(slot.x))`.

Client (`Client.client.lua`) : aucune modification requise ; `BattleUi.start` garde la même signature. Le client envoie `fire("battlePick", { id, i })`.

## Migration du profil v12 (documentée)

Version **inchangée** (12). Nouveaux champs facultatifs, tous assainis par `merge()` (comme le lot 15) :

| Champ | Absent / corrompu | Assainissement |
|---|---|---|
| `battle.pendingPick` | `nil` (aucun tirage) | `BattleRewards.sanitizePending` : 3 cartes de catégories distinctes, montants bornés, sinon `nil` |
| `boosts` | `{}` | `BattleRewards.sanitizeBoosts` : clés `income2 luck10 xp2 speed15` seulement, entiers 1..4e9 |
| `trainer` | `{ xp = 0 }` | `PetXp.sanitizeTrainer` |
| `slot.x` (existant, 0 depuis v11) | 0 | `PetXp.sanitize` : 0..`PetXp.MAX_XP` (9 734) |

Idempotent (testé : `migrate(migrate(x)) == migrate(x)`, et relecture réelle avec le vrai `Data.lua`). Un serveur du lot 15 qui relit un profil écrit par le lot 12 B ignore ces champs (le `merge` du lot 15 reconstruit `d.battle` sans `pendingPick` : **le tirage en attente serait perdu si un ancien serveur sauvegardait ensuite** ; déployer le lot 12 B sur tous les serveurs d'un coup, ou ne pas avoir de serveurs mixtes).

## Écarts avec la spec

1. **D.6 : formule retenue par la gestion** : `xpTo(L) = floor(40 x L^1,1)` (et non 1,6 : la spec écrite donnait 34 742 cumulés, alors que l'intention est ~9 600). `PetXp.MAX_XP = 9734` (niveau 20). Une seule constante dans `PetXp.xpTo`.
2. Combat de PNJ : XP = formule PvE étage 0 x 0,6 (12 gagné / 3 perdu) : la spec donne x0,6 pour les valeurs de cartes, pas pour l'XP de combat ; hypothèse.
3. Carte Effet « XP x2 » : stockée dans `boosts.xp2` ; l'effet de série du lot 15 (`xp2Until`) reste séparé ; `PetXp.boostMul` lit les deux (jamais cumulés : x2 au maximum).
4. Carte Expérience : non multipliée par l'effet XP x2 (valeur fixe D.5).
5. Boss : la règle « œuf d'un cran au-dessus » reprend `Config.towerReward` (`min(8, nextLiveTier)`) ; boss = étage multiple de 5 **et** non PNJ. La potion de chance « tous les 5 étages (3, 8...) » de `towerReward` n'est pas dans D.5 : non reprise ici (à garder à côté des cartes si on la veut).
6. Aucun nom de spécial par type (`Config.TYPE_SPECIAL_NAME`) n'existe encore : `BattleUi.specialState` l'utilise s'il est présent, sinon le nom de la compétence. Il lit `u.charge` (moteur lot 12) et retombe sur `u.cd` avec l'ancien `Battle.lua` (écran correct avant et après l'intégration).
7. Les pastilles de l'adversaire sont aussi affichées (D.3 ne parle que des pastilles « sous la barre de vie »).

## Résultats (dans ma copie, Data.lua patché et lot12b branché dans run.luau)

- `python3 roblox/tools/run_tests.py` (lupa) : **3330 assertions réussies, 0 échec** (dont les 91 du lot 12 B ; 3239 avant).
- `lune run roblox/tests/run.luau` (Lune, PATH=/tmp/claude-0/cargo-out/bin) : **3330 réussis, 0 échoué**.
- `python3 roblox/tests/run_lot12b.py` seul : **91 assertions, 0 échec** (Park-Miller dont la valeur de contrôle 399268537, tirage sur 45 étages x 3 modes, boss = œuf, reconnexion, claim/expiration, grant, PetXp, BattleUi avec Roblox factice, vrai `Data.lua` + vrai `Main.server.lua` dans le runtime factice : profils v12 sans champs, avec champs, corrompus, sauvegarde et relecture).
- `stylua --check` : `BattleRewards.lua`, `PetXp.lua`, `lot12b.luau` propres. `BattleUi.lua` et `Data.lua` ne le sont pas (les versions d'origine non plus : fichiers à longues lignes, hors convention stylua du dépôt).
- `selene` : inutilisable ici (échec de collecte de la bibliothèque standard Roblox hors ligne). `luau-analyze` absent. Le contrôle de syntaxe vient des deux exécuteurs de tests qui chargent chaque fichier.
- Analysé seulement : `BattleUi.lua` en vrai Roblox (API Instance, TweenService, mise en page), snippets `Main.server.lua` ci-dessus.

## À tester dans Studio

1. Tour étage 1 : gagner. Attendu : écran de résultat sans « Continuer », puis 3 cartes de catégories différentes, compte à rebours 15 s ; cliquer une carte : message « Récompense reçue », puis « Continuer ».
2. Étage 5 (boss) : une des 3 cartes est un Œuf doré, de rareté un cran au-dessus ; le choisir avec base pleine : pièces (prix de l'œuf), pas d'œuf perdu.
3. Gagner, ne rien choisir, quitter le jeu à 5 s, revenir : mêmes 3 cartes avec le temps restant ; revenir après > 15 s : la première carte a été donnée automatiquement (vérifier pièces / XP).
4. Choisir « Expérience » : les 3 pets de l'équipe gagnent l'XP ; au 20e niveau l'XP ne monte plus. Vérifier la stat dans un combat suivant (avec `Battle.unit` modifié).
5. Combat : 5 pastilles sous chaque barre de vie, la 5e pulse à 5/5, bouton « Spécial 3/5 » grisé puis actif avec son nom ; clic avant 5 sans effet. Effet super efficace : texte vert flottant + journal.
6. Mobile (écran 360 px) : les 3 cartes tiennent dans le panneau de 360 x 330, texte lisible.
7. Cliquer très vite plusieurs cartes : une seule récompense (serveur : `pendingPick = nil` avant attribution).
