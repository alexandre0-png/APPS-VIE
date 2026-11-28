# Lot 16 : boutique pure, notes d'intégration (non intégré)

Fichiers nouveaux uniquement : `src/ReplicatedStorage/ShopInfo.lua`, `ShopData.lua`, `Shop.lua`, `tests/shop.luau`, `tests/run_shop.py`. Rien n'a été joué dans Studio ; tout est vérifié par lupa (`python3 roblox/tests/run_shop.py`, 115 assertions) et `check.py`.

Décision appliquée : PLUS DE PLAFOND D'ACHAT. Seuls les achats uniques (passes, Pack de départ, poses), le passe de saison (une fois par saison) et Double chance <= 70 points limitent.

## API

- `ShopData.ENTRIES[clé] = { kind = "product"|"pass", id, robux, cat, random?, once?, season?, eggTier? }` (46 achats, tous avec un id réel, dont StreakRestore 3736703610). `ShopData.merge(Config, ShopInfo)` pose ces champs dans `Config.PRODUCTS` / `Config.PASSES` (idempotent, garde name / emoji / desc existants).
- `ShopInfo[clé] = { cat, icon, title (<= 28), def (<= 90), detail, notDo, chance, limit, also }`.
- `Shop.CATEGORIES` (ordre imposé), `Shop.catalog(config)`, `Shop.visibleOffers(profil, config, restricted, info)` -> 8 catégories triées par prix, `Shop.canBuy(profil, config, clé, restricted)` -> `ok, motif, prix` (motifs : unknown, noId, policy, notLive, owned, needPremium, hasPremium, faisDeLaPlace) à appeler AVANT `PromptProductPurchase`, `Shop.priceFor(profil, offre)`, `Shop.canBuyEgg(profil, config, n)`, `Shop.overflowAdd`, `Shop.eggContentText(config, clé, upPoints)`, `Shop.card(config, info, profil, clé, restricted)` (même fiche pour kiosque et offres), `Shop.doubleLuckCap(points)` (x2 puis 70), `Shop.luckTotal`, `Shop.grant(profil, clé, receiptId, config)` -> `{ ok, dup, delta }`, `Shop.grantPass`.
- `restricted` : résultat de PolicyService (`false` seulement si autorisé ; `nil` ou `true` masque tout achat `random`).
- Forme du profil attendue : `coins, income (pièces/s), slots, cap, eggBag, overflow = { ["tier"] = n }, passes, once, season = { cur, premium, plus, bonusTiers }, receipts, timers = { luck, double }, tokens = { arena, raven, streak, catchup }`. Le serveur adapte (par exemple `season.cur` = numéro de saison, `s.premium == s.cur` = premium de la saison en cours).
- `delta` : ce que le serveur doit appliquer pour les effets que `grant` ne peut pas faire seul (minuteurs réels : `luck`, `doubleSeconds`, `server.beltSeconds`, `server.luckPoints`, `instantHatch`, `revive`, `creditReached` = le module de saison crédite UNE fois les paliers déjà atteints, `compensation.coins` déjà ajoutées au profil).

## Lignes à ajouter

- `Config.lua` (fin de fichier) : `local ShopData = require(script.Parent:WaitForChild("ShopData"))` n'est pas possible tel quel (Config est chargé sous lupa sans Roblox) : soit copier `ShopData.ENTRIES` dans `Config.SHOP`, soit appeler `ShopData.merge(Config, ShopInfo)` sous `pcall(require ...)` comme `Config.TYPE_FX`. Retirer l'entrée `StreakRestore` à id 0 (le merge la remplace par l'id réel) et retirer `buys` / plafonds éventuels.
- `tools/build_place.py` SHARED : `("ShopInfo", "ShopInfo.lua"), ("ShopData", "ShopData.lua"), ("Shop", "Shop.lua")`.
- `tools/check.py` : rien de spécial (modules purs, aucun service Roblox).
- `tests/run.luau` : `local shop = luau.load(fs.readFile("roblox/tests/shop.luau"), { debugName = "shop" })()` puis `shop({ check = check, suite = suite, luau = luau, fs = fs })` (même forme que lot10).
- `tools/run_tests.py` : rien (passe par run.luau). `tests/run_shop.py` lance la suite seule.
- `Main.server.lua` `ProcessReceipt` : `Shop.grant(profil, clé, tostring(info.PurchaseId), Config)`, `dup` = `PurchaseGranted` sans rien créditer ; refuser (`NotProcessedYet`) si `restricted ~= false` pour un produit `random`. Avant `PromptProductPurchase` : `Shop.canBuy`.

## Écarts et points à valider

1. `InstantHatch`, `RemoteSteal`, `RemoteStealPack` : `random` laissé à `false` (comme dans le code actuel : ils ne vendent pas d'objet aléatoire) alors que ACHATS_DEFINITIONS indique « oui, en partie ». Ils restent donc visibles pour les comptes restreints. À trancher.
2. Tapis doré : le texte ne donne pas d'intervalle (Config dit 3 s dans `PRODUCTS`, `BELT.golden.interval` dit 4 s) ; cumul « jusqu'à 30 min » (`maxSeconds`) à retirer du moteur si le cumul doit être sans limite (décision A de l'addendum).
3. Œuf Exclusif : la fiche annonce « espèce de l'événement » (ACHATS_DEFINITIONS) mais le moteur actuel tire une espèce au hasard dans la rareté 9 ; à implémenter au lot 11.
4. Les raretés 2, 8, 9, 10 n'ont pas d'espèce publiée aujourd'hui : EggR2, EggSecret, EggExclusive, EggDivine sont masqués et refusés (`notLive`) jusqu'au lot 11.
5. `Shop.canBuy` exige UNE place pour tout achat qui contient des œufs (le reste d'un coffre de 5 œufs va au débordement, testé). Le débordement est stocké `overflow["tier"] = n` : à brancher dans `Data.lua` (assainissement, sans limite) et à ajouter au sac / à la base via l'écran existant.
6. `StarterPack` et poses payés deux fois (course) ; premium, complément ou 799 déjà possédés : compensation en pièces (R$ x `PRICING_REF.secondsPerRobux` de revenu, plancher `COIN_PACK_MIN`) au lieu de rendre le produit sans effet.
7. Coffre royal sans passe payé sans premium (course impossible via l'interface) : œufs + premium offerts (`upgradedFromRace`).
8. Effets des produits (durées, jetons) dans `Shop.EFFECTS` : à comparer au moteur (LuckPotion 15 min, Potion express 5 min, DoubleLuck 30 min, ArenaTickets 5, etc.) ; le moteur reste maître des minuteurs.
