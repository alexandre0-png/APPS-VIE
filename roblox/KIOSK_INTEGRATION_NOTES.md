# Lot 8B-kiosque : notes d'intégration (NON INTÉGRÉ)

> **INTÉGRÉ (lot 8B, 2026-11-26)** : les lignes ci-dessous ont été appliquées (Config, build_place.py, check.py, Main, Builder, Client, tests). État réel et écarts : `LOT8B_ECARTS.md`. Ce document reste comme référence technique.

Livré : `src/ReplicatedStorage/KioskData.lua` (données pures), `src/ServerScriptService/Kiosk.lua` (construction, prompts, ambiance, validation serveur),
`tests/kiosk.luau` + `tests/run_kiosk.py`. Aucun fichier existant modifié (Main, Data, Config, Client*, Builder, build_place.py, run.luau, run_tests.py intacts).
Tout ce qui suit est à ajouter par la personne qui tient ces fichiers.

## 1. Coordonnées proposées

Centre du kiosque : **x = 14, z = 22** (sud-est du centre de la place ; `KioskData.CENTER`). Emprise : disque de rayon 7,7 (socle 15,4). Sol : y = 0,52 (dessus du dallage).
Le comptoir (PanneauBoutique) regarde la halle `Map2.hall` (-40, 0) : direction (-0,93, -0,38), le kiosque est tourné de `KioskData.yawFor` (calculé, pas figé).

Marges libres mesurées (studs, bord du disque au bord de l'obstacle, `Config.Map2` de la branche) :

| Obstacle | Marge libre |
|---|---|
| Bord de la place (r = 60) | 26,2 |
| Halle (-40, 0, r = 18) | 32,6 (centre à centre : 58,3) |
| Fontaine (10, -38, r = 7) | 45,4 |
| Tapis central (x -22 à 38, z ±4) | 10,3 |
| Bac du tapis (42, 0) | 21,9 |
| Étals (-35, 38) / (5, 42) / (40, 36) | 37,3 / 8,4 / 15,0 |
| Portails (z = -50) | 58,3 |
| Arrivée des tapis (28, -34) | 46,0 |
| Routes pavées B1 / B2 / B3 / B4 / B5 (demi-largeur 5 déjà retirée) | 13,4 / 13,4 / 5,2 / 5,0 / 5,7 |

Le test `kiosk.luau` revérifie cela avec `KioskData.overlap(Config.Map2, 14, 22, 7.7, 2)` : si `Map2` change, le test échoue.
Les routes B3 et B4 passent à 5 studs du bord : le kiosque ne les coupe pas ; ne pas rapprocher le centre de plus de ~2 studs vers l'ouest ou le nord.

## 2. Lignes à ajouter

### Config.lua
```lua
-- dans Config.Assets.models (après `scenery = {...},`) :
hub = { kiosk = 90238570290603 }, -- lot 8B : kiosque central (hub_kiosk, clé J.1 hub.kiosk)
-- dans Config.Assets.modelsMaxParts :
["hub.kiosk"] = 220,
-- dans Config.SOUNDS (à côté de ambMeadow) :
kiosk_ambience = { id = "rbxassetid://82723287691994", speed = 1.0, vol = 0.25, loop = true }, -- ambiance du kiosque (Kiosk.lua plafonne à 0,5)
```
`Config.SOUNDS_ENABLED = false` supprime le Sound du kiosque (aucune instance créée). Aucune autre clé n'est nécessaire (IDs, libellés, portées : `KioskData`).

### tools/build_place.py (SHARED et scripts serveur)
```python
# SHARED : ajouter à la fin de la liste
("KioskData", "KioskData.lua"),
# scripts serveur (bloc ServerScriptService, après Scenery) :
item("ModuleScript", "Kiosk", read("ServerScriptService/Kiosk.lua")),
```
Puis `python3 roblox/tools/build_place.py` (sans cela `check.py` signale « absent ou périmé dans ChipeOeufs.rbxlx » pour ces 2 fichiers). Les `*.project.json` (Rojo, chemins par dossier) n'ont rien à changer.
`tools/check.py` ligne `RUNTIME_CREATED` : ajouter `"Kiosk"` (nouveau Remote créé à l'exécution).

### Main.server.lua
En tête (avec les autres `require`) :
```lua
local Kiosk = require(ServerScriptService:WaitForChild("Kiosk"))
local KioskData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KioskData"))
```
Remote (après `local RTop = newRemote("Top")`) :
```lua
local RKiosk = newRemote("Kiosk") -- serveur -> client seulement : { panel = "shop" | "calendar" | "odds" | "ranking", ... } (voir Kiosk.handle)
```
Construction, **à deux endroits** (idempotent : le second appel remplace le premier, sans doublon) :
1. juste après `local world = Builder.build()` : `kiosk = { Kiosk.build(world, nil, { Config = Config, quiet = true, loadAsset = function() return nil end }) }` (kiosque procédural immédiat, sans avertissement) ;
2. dans le thread des Assets, **après** `assets.loadGroup("props")` (ou juste avant `assets.loadGroup("vfx")`) : `assets.loadGroup("hub")` puis
   `kioskModel, kioskPrompts, kioskInfo = Kiosk.build(world, nil, { Config = Config, assets = assets })` : le modèle Blender remplace le repli, ou le repli est reconstruit avec un avertissement `[Kiosk] modèle Blender indisponible`.
   Garder `kioskInfo` dans une variable locale du fichier (`local kioskInfo`) : elle sert à la portée et à la pastille.

Validation et traitement (à côté des autres branches de `ProximityPromptService.PromptTriggered`, avant `if CollectionService:HasTag(prompt, "CastleEntry")`) :
```lua
if CollectionService:HasTag(prompt, "KioskPrompt") then
	local res = Kiosk.handle(player, prompt:GetAttribute("KioskAction"), {
		Config = Config,
		inRange = function(p)
			local r = getRoot(p)
			if not (r and alive(p) and kioskInfo) then return false end
			local c = kioskInfo.center
			return math.sqrt((r.Position.X - c.X) ^ 2 + (r.Position.Z - c.Z) ^ 2) <= KioskData.SERVER_RANGE
		end,
		calView = function(p)
			local ss = sessions[p]
			return ss and Lot7.Cal.snapshot and Lot7.Cal.snapshot(ss) or nil
		end,
		top = function(season, n)
			return kioskTopCached(season, n) -- voir ci-dessous : Data.pvpTop lit un DataStore (yield, quota)
		end,
		mine = function(p)
			local ss = sessions[p]
			local pv = ss and ss.data.battle.pvp
			return pv and { trophies = pv.trophies, wins = pv.wins, losses = pv.losses } or nil
		end,
	})
	if res.ok then
		RKiosk:FireClient(player, res.payload)
	end -- un refus ne répond rien : aucune information donnée à un client hors de portée
	return
end
```
Cache du classement (30 s, 1 appel DataStore au plus par fenêtre, quel que soit le nombre de joueurs) :
```lua
local kioskTop = { at = -1e9, season = nil, list = {} }
local function kioskTopCached(season, n)
	if kioskTop.season ~= season or os.clock() - kioskTop.at > 30 then
		kioskTop.at, kioskTop.season = os.clock(), season
		local ok, list = pcall(Data.pvpTop, season, n)
		kioskTop.list = ok and list or {}
	end
	return kioskTop.list
end
```
(Le yield de `Data.pvpTop` se produit dans le thread du `PromptTriggered`, comme les autres actions du fichier.)

Pastille rouge du calendrier : boucle de 5 s (ou dans la boucle serveur existante) :
```lua
task.spawn(function()
	while true do
		task.wait(5)
		if kioskInfo then
			local any = false
			for _, ss in pairs(sessions) do
				local view = Lot7.Cal.snapshot and Lot7.Cal.snapshot(ss) or nil
				if Kiosk.badgeNeeded(view) then any = true break end
			end
			Kiosk.setBadge(kioskInfo, any) -- idempotent : ne touche l'instance que si l'état change
		end
	end
end)
```
(La pastille est commune à tous : elle s'allume dès qu'un joueur présent a une récompense ; le détail par joueur est dans la réponse du prompt, `payload.ready`.)
Nettoyage : dans `Players.PlayerRemoving`, `Kiosk.forget(player)` (facultatif, la table est à clés faibles).

### Builder.lua
Rien d'obligatoire : le kiosque est construit par `Main` (le modèle dépend du chargement des Assets, qui se fait après `Builder.build`).
Si l'on préfère tout dans `Builder.build()` : après `deco("plaza", ...)`, `Kiosk.build(world, nil, { Config = Config, assets = eggAssets, quiet = true })`, mais le modèle Blender ne sera alors pas encore préchargé (repli), donc l'appel de `Main` reste nécessaire.

### Client (Client.client.lua)
Remote : `local RKiosk = Remotes:WaitForChild("Kiosk")`. Réception (payload tel que renvoyé par `Kiosk.handle`) :
```lua
RKiosk.OnClientEvent:Connect(function(p)
	if type(p) ~= "table" then return end
	if p.panel == "shop" then
		if not (panel and panel.name == "shop") then openPanel("shop") end
	elseif p.panel == "calendar" then
		if not (panel and panel.name == "bonus") then openPanel("bonus") end
		panel.tab = "cal"; showPanel() -- la réclamation passe par l'action existante calClaim (RAction), déjà validée par le serveur
	elseif p.panel == "odds" then
		showInfoCard("🎲 Probabilités et prix", p.lines) -- à écrire : carte de texte (titre + lignes), voir ci-dessous
	elseif p.panel == "ranking" then
		showInfoCard("🏆 Classement de la saison", rankingLines(p)) -- p.entries = { {name, trophies} }, p.secondsLeft, p.mine
	end
end)
```
`p.lines` (odds) est déjà en texte lisible : `Commun : 50,0 % (tapis doré 29,3 %)`, `Exclusif : hors tapis`, puis les prix (`Secret : 1499 R$ ou 🪙 48 Md`...). `p.rows` et `p.prices` donnent les nombres pour une vraie table.
Le calendrier et la boutique réutilisent les panneaux existants (aucune nouvelle interface) ; seuls les deux écrans `odds` et `ranking` demandent une carte de texte côté client.
Ambiance : le Sound est dans le monde (Parent = Lueur), il suit donc le réglage de volume général seulement si `Ambience.client.lua` met à l'échelle les Sound du monde ; à vérifier au playtest (sinon `Config.volumeLabel` ne s'applique pas à lui).

## 3. Remotes
Un seul : `Remotes.Kiosk` (RemoteEvent, serveur vers client). Aucun remote client vers serveur : les interactions sont des ProximityPrompt (déclenchées côté serveur par `PromptTriggered`).
Les actions qui modifient l'état (réclamer le calendrier, acheter) restent sur les chemins existants (`RAction` : `calClaim`, achats Robux), déjà validés ; le kiosque ne fait qu'ouvrir.

## 4. Validation serveur de `Kiosk.handle` (ordre)
contexte (Config + `inRange` requis) puis joueur non nil, action = chaîne de 24 caractères au plus appartenant à la liste blanche {shop, calendar, odds, ranking}, **distance mesurée par le serveur** (`inRange`, 20 studs du centre ; prompts à 11), pause de 0,6 s par joueur (table à clés faibles), puis calcul des données dans un `pcall` (une panne de DataStore ou de profil donne un refus `erreur` sans plantage et sans pause consommée). Un refus ne renvoie rien au client.

## 5. Ce qui n'est PAS fait / testé
- Pas de test Roblox Studio : rendu du modèle Blender, orientation réelle des panneaux (le yaw est déduit de la position de `PanneauBoutique` par rapport au pivot ; à confirmer), taille de la lanterne, volume et portée de `kiosk_ambience`, lisibilité des SurfaceGui du repli.
- Tests exécutés avec lupa et `FakeRuntime` (proxy permissif) : logique, repli, idempotence, validation ; pas la physique ni le réseau.
- `check.py` : syntaxe, classes et enums des 2 nouveaux modules OK ; le contrôle « place à jour » restera rouge pour ces fichiers tant que `build_place.py` n'a pas reçu les lignes du §2.
