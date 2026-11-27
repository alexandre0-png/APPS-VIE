# Lot 16 : offres contextuelles et vendeurs PNJ (parties pures, NON intégrées)

Fichiers ajoutés (aucun fichier existant modifié) :
`src/ReplicatedStorage/Offers.lua`, `OffersData.lua`, `SellersData.lua`, `src/ServerScriptService/Sellers.lua`, `tests/offers.luau`, `tests/sellers.luau`, `tests/run_offers.py`, `tests/run_sellers.py`.
Exécution : `python3 roblox/tests/run_offers.py` (59 assertions) et `python3 roblox/tests/run_sellers.py` (71 assertions). Non testé dans Studio.

## 1. Offres contextuelles (`Offers` / `OffersData`, partagés client + serveur)

Logique pure : aucun service Roblox, aucune instance, aucun hasard.

```
local state = Offers.newState(os.time())            -- un par joueur et par session (jamais enregistré)
local offer = Offers.pick(state, profil, now, ctx)  -- offre | nil, PURE
Offers.onShown(state, offer, now)  Offers.onClosed(state, now)  Offers.onBought(state, keyOrOffer, now)
Offers.shouldHide(state, ctx)  Offers.expired(state, now, ctx)
```

- `profil = { owned = {[clé]=true}, passes = {[clé]=true}, dayNumber = jours de jeu (1 = premier), bestTier = plus haute rareté obtenue, hatchedTotal }` (`owned`, `passes` et `purchased` sont tous lus ; Pack de départ acheté = `owned.StarterPack`).
- `ctx = { Config (requis), restricted (résultat PolicyService, doit valoir false pour les achats `random`), calm, baseFull, bagFull, firstLegend, streakAtRisk, towerQuotaExhausted, flying, cinematic, inCombat, carrying, chased, hatching, castleTimer, menuOpen }`. Les drapeaux d'événement (`baseFull`, `firstLegend`, `streakAtRisk`, `towerQuotaExhausted`) sont posés par Main/Client au moment de l'événement ; `calm = true` quand le joueur est au repos au hub.
- `offer = { id, key, kind ("product"|"pass"), title, text, robux, random, tier }` : le client ouvre la MEME fiche que le kiosque pour `key` (`Config.PRODUCTS[key]` / `Config.PASSES[key]`), avec bouton Fermer toujours visible (52 px), jamais de minuteur affiché. `Offers.expired` (45 s) range la carte sans l'annoncer.
- Règles tenues : une offre à la fois ; 3 par session et 300 s d'écart (lus dans `Config.OFFERS` : max, gap, graceSeconds = 90) ; aucune offre pendant vol, cinématique, combat, œuf porté, poursuite, éclosion, chrono de château, menu ouvert ; aucune offre pendant 600 s après TOUT achat (`onBought`, y compris achat au kiosque) ; une offre fermée ne revient pas dans la session ; jamais un achat possédé, à id 0/absent/non entier, ou masqué (`random` sans PolicyService = false, rareté sans espèce publiée `Config.tierLive`) ; jamais d'œuf Secret/Exclusif/Divin (palier borné 2 à 4, noms de `Config.FORBIDDEN_GIFT_TIERS` exclus).
- Déclencheurs : base pleine -> `ExtraSlots` ; première éclosion Légendaire -> `DoubleLuck` ; série en danger -> `StreakRestore` ; quota de tour épuisé -> `ArenaTickets` ; jours 1 à 3 + `calm` -> `StarterPack` ; `calm` + 5 éclosions + base/sac non pleins -> œuf du palier (`EggR<t>`, sinon l'achat le moins cher avec `eggTier == t`).
- Décisions « proposé » : offre d'œuf seulement après 5 éclosions (pas pour un tout nouveau joueur) et seulement si l'achat ne serait pas refusé pour place ; Pack de départ seulement en moment calme ; délai post-achat 600 s ; carte rangée après 45 s.

### Branchement à faire
- **Config.lua** : rien d'obligatoire (`Config.OFFERS` existe). Les achats du lot 16 (`EggR2..EggR5` avec `eggTier`, `DoubleLuck`, `StreakRestore`, `ArenaTickets`) doivent exister dans `Config.PRODUCTS` avec leur id ; sans eux, l'offre correspondante reste silencieusement absente.
- **Main.server.lua** : créer `Offers.newState` à l'arrivée du joueur ; appeler `Offers.pick` aux événements (éclosion, base pleine, défaite PvE avec quota épuisé, ouverture de session pour la série) et au calme (toutes les ~30 s si `calm`) ; envoyer au client `offer` ; `onShown` à l'envoi, `onClosed` sur demande de fermeture, `onBought` dans `ProcessReceipt` (après crédit) ; le serveur revalide l'achat comme toujours (aucune confiance au client).
- **Client.client.lua** : carte petite sur bord sûr (zone centrale libre), bouton Fermer, `Offers.shouldHide` à chaque changement d'état (vol, combat, cinématique).
- **build_place.py** : ajouter `Offers.lua`, `OffersData.lua`, `SellersData.lua` à SHARED, et `Sellers.lua` aux scripts serveur (comme `Kiosk.lua`).
- **check.py** : aucun RemoteEvent nouveau obligatoire ; si un remote `Offer` ou `Seller` est ajouté, l'inscrire dans `RUNTIME_CREATED` (ligne 331).
- **run.luau / run_tests.py** : ajouter `offers.luau` et `sellers.luau` comme `kiosk.luau` (`luau.load(fs.readFile("roblox/tests/offers.luau"))()(env)`).

## 2. Vendeurs PNJ (`SellersData` partagé, `Sellers` serveur)

```
local folder, prompts, info = Sellers.build(parent, { Config = Config, assets = assets, decor = DecorData })   -- idempotent
local r = Sellers.handle(player, action, { Config = Config, inRange = function(player, id) ... end, clock = os.clock })
Sellers.inRange(info, id, px, pz)   -- distance serveur à la position construite (SERVER_RANGE 16)
Sellers.forget(player)
```

- 8 vendeurs `Vendor_<eggs|luck|coins|base|combat|pass|packs|cosmetics>` dans un dossier `Sellers`. Un vendeur par catégorie ; l'onglet à ouvrir = l'id de la catégorie. `handle` retourne `{ ok = true, id, tab, payload = { panel = "shop", tab, vendor } }` : Main envoie `payload` au client (comme `Kiosk.handle`), qui ouvre la boutique du kiosque sur `tab` (action locale). Refus : contexte, joueur, action, distance, pause (0,8 s par joueur, table à clés faibles).
- Modèles Blender (ids dans `SellersData.VENDORS[i].asset`), clés `Config.Assets.models.hub.vendor_<id>` à ajouter (8 lignes, comme `hub.kiosk` : id numérique, groupe `hub`). Sans `assets`, chargement par `InsertService:LoadAsset`. Repli procédural par vendeur (étal, silhouette, auvent, planche `Etiquette`, `Lueur`) : jamais plus de 14 Parts chacun. Orientation : la planche `Etiquette` du modèle est tournée vers le centre du kiosque.
- Étiquette (`SurfaceGui` sur `Etiquette`, face choisie par la normale) + `BillboardGui` 280 x 132 px, `MaxDistance = 60` : icône et nom, ligne de prix calculée sur les achats RÉELLEMENT disponibles (« Œufs : de 15 à 6 999 R$ » ; « bientôt disponible » si rien n'est ouvert), 2 lignes d'exemples. Aucun ❗, aucun son, aucun mouvement.
- `ProximityPrompt` « Parler » (attribut `SellerAction`, tag `SellerPrompt`, 9 studs).

### Écart de spec : rayon 14 à 22 studs
Le kiosque (14, 22) est cerné par le tapis, les routes B1/B3/B4/B5 et les étals : mesuré avec les vrais obstacles, **2 vendeurs seulement** tiennent entre 14 et 22 studs (au mieux 4 en glouton à marge 0). Les 6 autres sont placés au rayon libre le plus proche (`SellersData.RING_FAR`, 24 à 42 studs), toujours face au centre, hors obstacles, décor et tapis. Position actuelle : voir `SellersData.layout(Config.Map2, KioskData, { decor = DecorData })`.

### Branchement à faire
- **Config.lua** : `Config.Map2.kiosk.r` (rayon d'exclusion du décor, 12) ne couvre pas les vendeurs. Soit y ajouter les emprises `SellersData.footprints(layout)` dans les exclusions de `Decor.lua` (plan : `Config.Map2.vendors = { {x,z,r}... }` lu comme `kiosk`), soit poser le décor APRÈS les vendeurs. Ajouter `Config.Assets.models.hub.vendor_eggs`... `vendor_cosmetics` (8 ids de `SellersData`).
- **Main.server.lua** : `Sellers.build(K8.world, { Config = Config, assets = assets, decor = DecorData })` après `Kiosk.build` (même `pcall`) ; `PromptTriggered` sur les prompts de tag `SellerPrompt` : `Sellers.handle(player, prompt:GetAttribute("SellerAction"), { Config = Config, inRange = function(p, id) return Sellers.inRange(info, id, x, z) end })` avec `x, z` lus sur `HumanoidRootPart` ; réponse via le remote `Kiosk` (payload `panel = "shop"`, `tab`). `Sellers.forget` dans `PlayerRemoving`.
- **Client.client.lua** : le panneau `shop` accepte `payload.tab` (sélection de l'onglet ; catégories de `SellersData.VENDORS`).
- **build_place.py / check.py / run.luau / run_tests.py** : comme pour les offres ci-dessus ; remote `Kiosk` déjà dans `RUNTIME_CREATED`.

## Écarts et limites
- Rayon 14 à 22 studs non tenable pour 8 vendeurs (voir plus haut).
- Orientation et faces du modèle Blender réel (devant vers -Y Blender) à vérifier dans Studio : l'orientation se déduit de la position de `Etiquette` par rapport au pivot, la face du `SurfaceGui` de la normale ; non testé sur les vrais modèles.
- Les prix de passes viennent de `SellersData.PRICES` (le code n'en porte pas) ; les achats absents de `Config.PRODUCTS/PASSES` ne comptent pas dans la ligne de prix.
- `Offers` suppose les ids/clés du lot 16 dans Config ; aucun modèle ni image n'a été téléversé.
