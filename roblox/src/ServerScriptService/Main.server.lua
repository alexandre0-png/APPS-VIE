-- Script : ServerScriptService/Main
-- Logique serveur complète de Chipe-Œufs (le serveur décide de tout, le client ne fait qu'afficher).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.Game.roleFor(game.PlaceId) == "hub" then
	return -- le hub a son propre script (Hub.server) ; ce code est celui de la partie
end
local TeleportService = game:GetService("TeleportService")
local Party = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Party"))
local Reveal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reveal"))
local Guard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Guard"))
local Castle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Castle"))
local Belt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Belt"))
local Traps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traps")) -- pièges des territoires (lot 4)
local Riddle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Riddle")) -- énigme de la Mère Poule : règles pures (lot 6)
local Raven = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Raven")) -- vol à distance « Corbeau chipeur » : règles pures (lot 7)
local Data = require(script.Parent:WaitForChild("Data"))
local Builder = require(script.Parent:WaitForChild("Builder"))
local HenQuest = require(script.Parent:WaitForChild("HenQuest")) -- énigme de la Mère Poule : état, prompts, récompense (lot 6)
local Rules = require(script.Parent:WaitForChild("Rules")).new(Config) -- règles pures (tirages, revenus), testées avec Lune
local tele = (function() -- lot 9 : 12 métriques AnalyticsService (pcall, 1 événement / s / joueur) ; une seule variable locale (limite de 200)
	local svc = nil
	pcall(function()
		svc = game:GetService("AnalyticsService")
	end)
	return require(script.Parent:WaitForChild("Telemetry")).new(svc)
end)()

Players.CharacterAutoLoads = false

---------------------------------------------------------------- Remotes
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage
local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local RState, RNotify, RHatch, RAction = newRemote("State"), newRemote("Notify"), newRemote("Hatch"), newRemote("Action")
local RTop = newRemote("Top")
local RBattle = newRemote("Battle") -- serveur -> client : début, tours (événements à rejouer) et fin des combats de l'Arène des pets
local RRaven = newRemote("Raven") -- Corbeau chipeur (lot 7) : serveur -> client seulement (alerte de la victime, liste des cibles) ; les demandes passent par Action
local RHen = newRemote("Hen") -- serveur -> client : répliques de la Mère Poule (identifiant + paramètres), berceuse à jouer, retour des touches, plume ramassée

-- Lot 8B : kiosque central, décor de carte, meubles des maisons. UNE seule variable locale (limite de 200) : modules, remote, état et fonctions dans K8.
local K8 = {
	Kiosk = require(script.Parent:WaitForChild("Kiosk")), KioskData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KioskData")),
	HouseDecor = require(script.Parent:WaitForChild("HouseDecor")), HouseDecorData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HouseDecorData")),
	remote = newRemote("Kiosk"), -- serveur -> client seulement : { panel = "shop" | "calendar" | "odds" | "ranking", ... } (Kiosk.handle) ; aucune demande client par ce remote
	world = nil, info = nil, -- dossier World (Builder.build) ; info du kiosque construit (centre, prompts, pastille)
	top = { at = -1e9, season = nil, list = {} }, -- cache du classement du kiosque (30 s : au plus 1 lecture DataStore par fenêtre)
	Sellers = require(script.Parent:WaitForChild("Sellers")), DecorData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DecorData")), sellers = nil, -- lot 16 : 8 vendeurs PNJ autour du kiosque
}
-- Lot 15 : PNJ, série de 7 jours, quêtes bonus et hebdomadaires, sac d'œufs, rotation, événements. UNE seule variable locale (limite de 200) : modules,
-- remote serveur -> client « Npc » (les demandes du client passent par Action : npcAnswer, npcOff, daily, bagPlace, bonusClaim, weeklyClaim, plumeBuy),
-- carnets d'offres par joueur (mémoire, vidés au départ) et fonctions (bloc « Lot 15 » plus bas).
-- LOT 12 B : L15.BR (cartes de récompense D.5), L15.PetXp (source UNIQUE de l'XP et des niveaux de pets, D.6) et les fonctions de choix de carte sont rangés dans cette table : Luau limite une fonction à 200 variables locales.
local L15 = {
	BR = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BattleRewards")),
	PetXp = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetXp")),
	Npc = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Npc")), Rewards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rewards")),
	Duel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Duel")), -- lot 13 : duel local, ligues, remise de saison (module pur) ; état des duels dans L15.duel (bloc « Duel local »)
	remote = newRemote("Npc"), books = {}, assets = nil, decorKey = nil,
}
-- Construit (ou reconstruit : idempotent) le kiosque dans World. assets = nil : repli procédural immédiat, sans avertissement.
function K8.build(assets)
	if not K8.world then
		return
	end
	local ok, _, _, info = pcall(K8.Kiosk.build, K8.world, Config.Map2.kiosk, assets and { Config = Config, assets = assets, noAmbience = true }
		or { Config = Config, quiet = true, noAmbience = true, loadAsset = function()
			return nil
		end })
	if ok and type(info) == "table" then
		local wasReady = K8.info and K8.info.ready
		K8.info = info
		if wasReady then
			K8.Kiosk.setBadge(info, true) -- la pastille allumée reste allumée après la reconstruction
		end
	end
	-- lot 16 : 8 vendeurs PNJ (un par catégorie de la boutique), reconstruits avec les modèles Blender arrivés ; repli procédural sinon
	task.wait() -- le placement (SellersData.layout, mémorisé) est un calcul assez long : on rend la main avant
	local okS, serr, _, sinfo = pcall(K8.Sellers.build, K8.world, assets and { Config = Config, assets = assets, decor = K8.DecorData }
		or { Config = Config, decor = K8.DecorData, loadAsset = function()
			return nil
		end })
	if okS and type(sinfo) == "table" then
		K8.sellers = sinfo
	elseif not okS then
		warn("[Sellers] construction impossible : " .. tostring(serr))
	end
end

---------------------------------------------------------------- Monde
local onAssetsLoaded = nil -- défini après applyBase et refreshAllPads (voir plus bas), appelé par la tâche de chargement des modèles
-- Apparence des œufs : modèles Roblox chargés en arrière-plan (jamais bloquant ; échec = apparence par défaut, voir Config.Assets).
task.spawn(function()
	local InsertService = game:GetService("InsertService")
	local assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets")).new(Config, {
		loadAsset = function(id)
			return InsertService:LoadAsset(id)
		end,
		spawn = task.spawn,
		wait = task.wait,
		clock = os.clock,
		warn = warn,
		store = function(key, model)
			model.Name = "EggAsset_" .. key
			model.Parent = game:GetService("ServerStorage")
		end,
	})
	Builder.setAssets(assets)
	-- Ordre de chargement : d'abord ce qui se voit dans les premières secondes (œufs, base du joueur, chemins, arbres, accessoires, village), par lots parallèles
	assets.loadAll()
	assets.loadGroup("base")
	assets.loadGroup("house") -- maisons évolutives (niveaux 2 à 7) : avant tous les groupes non essentiels, onAssetsLoaded les applique
	assets.loadGroup("paths")
	assets.loadGroup("trees")
	assets.loadProps()
	assets.loadGroup("scenery")
	assets.loadGroup("eggguard") -- protections d'œuf (dôme, cage, cristaux, nid) posées à chaque rafraîchissement de pad
	assets.loadPets()
	if onAssetsLoaded then
		pcall(onAssetsLoaded) -- base et pads déjà affichés : reconstruits avec les modèles arrivés
	end
	local propParts, propCount = Builder.dressWorld(assets)
	print("[Assets] accessoires Blender : " .. propCount .. " posés (" .. propParts .. " Parts)")
	assets.loadGroup("guards")
	print("[Assets] gardiens Blender : " .. Builder.dressGuards(assets) .. " remplacé(s)")
	assets.loadGroup("traps")
	assets.loadGroup("guards", { knight = true })
	print("[Assets] pièges Blender : " .. Builder.dressTraps(assets) .. " habillé(s)")
	print("[Assets] chevaliers Blender : " .. Builder.dressKnights(assets) .. " habillé(s)")
	assets.loadGroup("castle")
	assets.loadGroup("props") -- coffre, torche, drapeau, château en fond, moulin, enclos, lampadaire, banc, panneau
	assets.loadGroup("ground")
	print("[Assets] arène Blender : " .. Builder.dressArena(assets) .. " modèle(s) posé(s)")
	assets.loadTextures()
	print("[Assets] textures : " .. Builder.dressTextures(assets) .. " posée(s)")
	assets.loadGroup("deco")
	assets.loadGroup("terrain")
	local pt, pu = Builder.dressPaths(assets)
	print("[Assets] chemins sinueux : " .. pt .. " tuile(s), " .. pu .. " Parts (budget " .. Config.Assets.pathBudgetParts .. ")")
	local sn, su = Builder.dressScenery(assets)
	print("[Assets] décor de village : " .. sn .. " objet(s), " .. su .. " Parts (budget " .. Config.Assets.sceneryBudgetParts .. ")")
	local dp, du, df = Builder.dressDeco(assets)
	print("[Assets] décor fin : " .. dp .. " objet(s), " .. du .. " Parts Blender (budget " .. Config.Assets.decoBudgetParts .. "), " .. df .. " Parts de repli")
	local rn, ru = Builder.dressRelief(assets)
	print("[Assets] relief : " .. rn .. " pièce(s), " .. ru .. " Parts (budget " .. Config.Assets.reliefBudgetParts .. ")")
	print("[Assets] panneaux d'étoiles : " .. Builder.dressSigns(assets))
	assets.loadGroup("vfx")
	print("[Assets] effets 3D : " .. Builder.exportVfx(assets) .. " modèle(s) publiés pour les clients")
	local gt, gp = Builder.dressGround(assets)
	print("[Assets] sol Blender : " .. gt .. " tuile(s), " .. gp .. " Parts (budget " .. Config.Assets.groundBudgetParts .. ")")
	print("[Assets] château Blender : " .. Builder.dressCastle(assets) .. " modèle(s) posé(s)")
	assets.loadGroup("hub") -- lot 8B : kiosque central (hub.kiosk) ; le modèle remplace le repli procédural posé au démarrage
	K8.build(assets)
	assets.loadGroup("npc") -- lot 15 : PNJ (publiés aux clients, repli procédural côté client) ; décors d'événement ; calendrier mural près du kiosque
	assets.loadGroup("event")
	L15.assets = assets
	if L15.publishNpc then -- (fonctions du bloc « Lot 15 », définies au chargement du script)
		print("[Assets] PNJ publiés aux clients : " .. L15.publishNpc(assets) .. "/5 ; calendrier mural : " .. (L15.placeCalendar(assets) and "modèle Blender" or "absent (le kiosque garde son prompt)"))
		pcall(L15.placeEventDecor, true)
	end
	print("[Assets] kiosque central : " .. ((K8.info and K8.info.usedAsset) and "modèle Blender" or ("repli procédural (" .. tostring(K8.info and K8.info.reason) .. ")")))
	local dn, du, dfb = Builder.dressDecor(assets)
	print("[Assets] décor de carte (lots 15 à 17) : " .. dn .. " exemplaire(s), " .. du .. " Parts Blender (budget " .. Config.Assets.decorBudgetParts .. "), " .. dfb .. " Parts de repli")
	if onAssetsLoaded then
		pcall(onAssetsLoaded)
	end
	-- Rapport de chargement : par catégorie (chargés / demandés / en repli) et, pour chaque échec, nom, ID et message ; publié aux clients (touche F3, « Blender N/M »)
	local lines, loaded, requested = assets.reportLines()
	for _, l in ipairs(lines) do
		if l:find("ÉCHEC", 1, true) then
			warn(l)
		else
			print(l)
		end
	end
	print(("[Assets] TOTAL Blender %d/%d (repli procédural : %d)"):format(loaded, requested, requested - loaded))
	local rv = Instance.new("StringValue")
	rv.Name = "AssetReport"
	rv:SetAttribute("Loaded", loaded)
	rv:SetAttribute("Requested", requested)
	rv.Value = table.concat(lines, "\n"):sub(1, 15000)
	rv.Parent = ReplicatedStorage
end)

local world = Builder.build()
K8.world = world.folder -- dossier World (Builder.build retourne une table de résultats)
K8.build(nil) -- lot 8B : kiosque procédural immédiat (le modèle Blender le remplace dans la tâche des Assets)
local rng = Random.new()
local sessions = {} -- [Player] = session
local leavingSave = {} -- userId -> true tant que la sauvegarde de départ de ce joueur est en cours (une reconnexion attend)
local pendingSaves, saveLater = {}, nil -- profils à sauvegarder en arrière-plan (voir saveLater)
local beltBuy -- définie avec le tapis roulant central (section dédiée) ; déclarée ici car le gestionnaire de prompts l'utilise
-- lot 9b : Calendar (règles pures du calendrier de 30 jours) et Cal (fonctions du bloc « Lot 9b » plus bas) logent dans Lot7 : AUCUNE variable locale de plus (limite de 200 atteinte)
local Lot7 = { Calendar = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Calendar")), Odds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Odds")), Cal = {}, luckUntil = 0, luckBy = nil, compPaid = 0, L16 = {} } -- lot 7 : Corbeau, tapis privé, bonus serveur, PolicyService (fonctions ajoutées dans le bloc « Lot 7 » plus bas)
-- Lot 10 : 42 icônes d'interface (Config.ICONS = IDs de DÉCAL). Chargées une fois en arrière-plan (InsertService:LoadAsset sous pcall, une seule tentative par
-- icône), URL d'image (Decal.Texture) publiée en attribut du dossier ReplicatedStorage.Icons ; échec = attribut absent, le client garde l'emoji de repli.
task.spawn(function()
	local folder = Instance.new("Folder")
	folder.Name = "Icons"
	folder.Parent = ReplicatedStorage
	if not (Config.Assets and Config.Assets.Enabled == true) then
		return
	end
	local keys = {}
	for key in pairs(Config.ICONS) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local loaded = 0
	for _, key in ipairs(keys) do
		local ok, model = pcall(function()
			return game:GetService("InsertService"):LoadAsset(Config.ICONS[key])
		end)
		if ok and model then
			pcall(function()
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("Decal") and type(d.Texture) == "string" and d.Texture ~= "" then
						folder:SetAttribute(key, d.Texture)
						loaded += 1
						break
					end
				end
				model:Destroy()
			end)
		end
	end
	print("[Assets] icônes d'interface : " .. loaded .. "/" .. #keys)
end)
local Hen = nil -- énigme de la Mère Poule (HenQuest) : construite après les événements serveur, utilisée par les prompts et la synchronisation
local castleEnter, castleFinish -- définies avec le mode Château (plus bas) ; déclarées ici car le gestionnaire de prompts les utilise
local serverPartyId = nil -- identifiant de la partie de ce serveur (celui du premier joueur envoyé par le hub)

local function rnd()
	return rng:NextNumber()
end
local function wpick(ws)
	return Rules.wpick(ws, rnd)
end

local function getRoot(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum(player)
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function alive(player)
	local h = getHum(player)
	return h ~= nil and h.Health > 0
end
local function validSlot(i)
	return type(i) == "number" and i % 1 == 0 and i >= 1 and i <= Config.SLOTS_MAX
end
-- sfx (optionnel) : clé de Config.SOUNDS jouée par le client avec le message
local function notify(player, msg, sfx)
	if player and player.Parent then
		RNotify:FireClient(player, msg, sfx)
	end
end

---------------------------------------------------------------- Règles
local currentEvent = nil -- { cfg, ends }
local function evKey()
	return currentEvent and currentEvent.cfg.key or nil
end

-- Capacité de la base : 4 + améliorations + bonus de niveau de maison + pass ExtraSlots (jamais plus de Config.SLOTS_MAX = 20).
local function cap(s)
	return Rules.capacity(s.data.up, s.baseLevel or 1, s.passes.ExtraSlots == true)
end
local function carryCap(d)
	return Rules.carryCapacity(d.up)
end
local function hatchTime(s, tier)
	return Rules.hatchTime(tier, s.data.up.inc, s.passes.Fast == true)
end
local function shieldTime(s)
	local lv = Config.BASE_LEVELS[s.baseLevel or 1]
	return Rules.shieldTime(s.data.up.lock) * (s.passes.VipBase == true and Config.VIP_SHIELD_MUL or 1) + (lv and lv.shieldBonus or 0) -- château doré : +10 s
end
-- Multiplicateur de vitesse de marche (pass « Vitesse+ »), appliqué aussi à la tolérance anti-triche.
local function speedMul(s)
	return (s.passes.Speed == true and Config.SPEED_PASS_MUL or 1) * (L15.BR.boostActive(s.data.boosts, "speed15", os.time()) and 1.15 or 1) -- lot 12 B : carte Effet « vitesse +15 % »
end
local function freeSlot(s)
	for i = 1, cap(s) do
		if not s.data.slots[i] then
			return i
		end
	end
	return nil
end

-- Une passe est-elle ACTIVE ? Les passes à hasard (Lucky, Tapis privé) exigent que PolicyService ait confirmé « non restreint » (restricted == false) : restreint ou inconnu = inactive,
-- même si le joueur la possède (lot 7b : sinon une reconnexion la réactivait). Toute lecture d'une passe à hasard passe par ici.
local function passOn(s, name)
	if s.passes[name] ~= true then
		return false
	end
	local def = Config.PASSES[name]
	return not (def and def.random == true and s.restricted ~= false)
end

-- Multiplicateur de revenu : renaissances, Festin, événement, passe, collection, puis bonus de la maison évolutive (1 + 5 % à 50 %, REFONTE lot 5).
local function gmult(s)
	return Rules.multiplier(s.data.rb, s.data.up.food, evKey() == "gold" or L15.Rewards.isGoldenHour(Config, os.time()), s.passes.Coins2x == true, Config.collectionBonus(s.species or 0)) * Rules.levelMul(s.baseLevel or 1) * (L15.BR.boostActive(s.data.boosts, "income2", os.time()) and 2 or 1) -- lot 12 B : carte Effet « revenus x2 »
end

local function income(s)
	return Rules.income(s.data.slots, cap(s), gmult(s))
end

local function luckPoints(s)
	local pts = Rules.upPoints(s.data.up.luck, evKey() == "luck", passOn(s, "Lucky"), os.time() < s.data.luckUntil or L15.BR.boostActive(s.data.boosts, "luck10", os.time()), os.time() < Lot7.luckUntil, passOn(s, "Lucky2")) + L15.Rewards.activeEvents(Config, os.time()).upgradeBonus -- lot 15 : week-end chanceux (+5, gratuit, pour tous) ; lot 16 : Chance +10 % II
	return Lot7.L16.luckTotal(pts, os.time() < s.data.doubleUntil and s.restricted == false) -- lot 16 : Double chance (x2, 70 points au plus ; produit à hasard : seulement si PolicyService a confirmé)
end

local function rollPet(s, eggTier, guaranteed)
	local up = Config.effectiveUp(eggTier, luckPoints(s), Config.dexTopTier(s.data.dex)) -- lot 9 : pas d'amélioration vers une rareté jamais découverte
	local alien = evKey() == "alien"
	local open = Config.debugForceTier(RunService:IsStudio()) and Config.allEventTags() or Lot7.L16.openEv(os.time()) -- A5 : espèces d'événement / de saison seulement dans leur fenêtre (A9 : toutes, Studio seulement)
	local pet = Rules.rollPet(eggTier, up, alien, rnd, guaranteed, open)
	pet.p = L15.Rewards.featuredPick(Config, L15.Rewards.rotation(Config, L15.Rewards.weekOf(os.time() // 86400)), pet.p, rnd) -- lot 15 : espèce vedette de la semaine (poids x2)
	return pet, up, alien, open
end

---------------------------------------------------------------- Missions quotidiennes
local QUEST_TYPES = { "steal", "hatch", "earn", "train", "pvp", "discover", "sell", "castle", "rare", "secret", "duel", "typeWin", "odds", "pve", "npcTrade" } -- A11 : 5 types des lots 12 à 14

local function newQuests(s)
	local inc = math.max(income(s), 1)
	local pool = table.clone(QUEST_TYPES)
	local out = {}
	for _ = 1, 3 do
		local t = table.remove(pool, rng:NextInteger(1, #pool))
		local goal
		if t == "steal" then
			goal = rng:NextInteger(3, 7)
		elseif t == "hatch" then
			goal = rng:NextInteger(4, 9)
		elseif t == "earn" then
			goal = math.floor(math.max(1000, inc * 240))
		elseif t == "train" then
			goal = rng:NextInteger(3, 6) * 20
		elseif t == "sell" then
			goal = rng:NextInteger(2, 4)
		elseif t == "castle" or t == "rare" or t == "secret" then
			goal = 1
		elseif L15.Rewards.newQuestGoal(Config, t, 0) then -- A11 : duel, typeWin, odds, pve, npcTrade (objectifs de Config.QUESTS.newTypes)
			goal = L15.Rewards.newQuestGoal(Config, t, rng:NextNumber())
		else -- pvp, discover
			goal = rng:NextInteger(1, 2)
		end
		local bonus = Config.questBonus(t, #out + 1, s.data.story.ch)
		out[#out + 1] = { t = t, goal = goal, prog = 0, rew = math.floor(math.max(250, inc * 150)), re = bonus.egg or 0, rb = bonus.boost or 0, claimed = false }
	end
	return out
end

local function qp(s, t, n)
	for _, q in ipairs(s.data.quests) do
		if q.t == t and q.prog < q.goal then
			q.prog = math.min(q.goal, q.prog + n)
		end
	end
	if L15.QP_WEEKLY[t] and L15.weekly then
		L15.weekly(s, L15.QP_WEEKLY[t], n) -- lot 15 : quêtes de la semaine (éclosion, vol, collection)
	end
end

-- A11 : applique la progression décidée par Rewards.questKinds (événements serveur seulement). Dans L15 : limite de 200 variables locales.
function L15.qk(s, kind, info)
	for _, e in ipairs(L15.Rewards.questKinds(Config, kind, info)) do
		qp(s, e[1], e[2])
	end
end

local function ensureQuests(s)
	local today = os.time() // 86400
	if s.data.qday ~= today or #s.data.quests == 0 then
		s.data.quests = newQuests(s)
		s.data.qday = today
	end
end

---------------------------------------------------------------- Histoire (chapitres), collection et rang
local function speciesCount(d)
	local n = 0
	for _ in pairs(d.dex) do
		n += 1
	end
	return n
end

local function chapter(s)
	return Config.STORY[s.data.story.ch + 1]
end

local function storyReached(s, c)
	notify(s.player, "📜 Chapitre « " .. c.title .. " » terminé ! Réclame ta récompense (Missions > Histoire).", "claim")
end

-- Fait avancer le chapitre en cours si son type correspond. info = { rival = n, tier = n } selon l'événement.
local function sp(s, kind, n, info)
	local c = chapter(s)
	local st = s.data.story
	if not c or c.type ~= kind or st.prog >= c.goal then
		return
	end
	if c.rival and (not info or info.rival ~= c.rival) then
		return
	end
	if c.tier and (not info or (info.tier or 0) < c.tier) then
		return
	end
	st.prog = math.min(c.goal, st.prog + n)
	if st.prog >= c.goal then
		storyReached(s, c)
	end
end

-- Chapitres fondés sur un état (espèces découvertes, renaissances).
local function storyRefresh(s)
	local c = chapter(s)
	local st = s.data.story
	if not c or st.prog >= c.goal then
		return
	end
	local value
	if c.type == "species" then
		value = s.species
	elseif c.type == "rebirth" then
		value = s.data.rb
	end
	if value and value > st.prog then
		st.prog = math.min(c.goal, value)
		if st.prog >= c.goal then
			storyReached(s, c)
		end
	end
end

local function updateSign(s)
	local r = Config.rankFor(s.data.story.ch)
	s.plot.nameLabel.Text = "🏠 Base de " .. s.player.DisplayName .. " · " .. r.emoji .. " " .. r.name
end

---------------------------------------------------------------- Statistiques de succès (l'énigme du jour est dans HenQuest)
local function statValues(s)
	local d = s.data
	return { hatched = d.hatched, stolen = d.stolen, species = s.species, rb = d.rb, puzzles = d.puzzle.solved, tower = d.battle.best, fragments = d.puzzle.fragments }
end

---------------------------------------------------------------- Synchronisation client
local function snapshot(s)
	local d = s.data
	local slots = {}
	for i = 1, Config.SLOTS_MAX do
		local sl = d.slots[i]
		if sl and sl.k == "e" then
			slots[i] = { k = "e", t = sl.t, ends = sl.ends }
		elseif sl then
			slots[i] = { k = "p", p = sl.p, s = sl.s, m = sl.m, o = sl.o } -- lot 10 : o absent (pet ancien) = « — » côté client
		else
			slots[i] = false
		end
	end
	local today = os.time() // 86400
	local l15 = L15.view and L15.view(s) or nil -- lot 15 : série, sac, quêtes bonus et de la semaine, événements, réglage PNJ
	return {
		up = d.up,
		slots = slots,
		rb = d.rb,
		dex = d.dex,
		mult = gmult(s),
		cap = cap(s),
		baseLevelFloor = d.baseLevelFloor,
		carry = #s.carry,
		carryCap = carryCap(d),
		passes = s.passes,
		starter = s.data.starter == true,
		dailyReady = l15 ~= nil and l15.streak.state ~= "done" or d.daily ~= today, -- lot 15 : série de 7 jours (pastille rouge du menu Bonus)
		streak = l15 ~= nil and l15.streak.day or 1,
		l15 = l15,
		stolen = d.stolen,
		hatched = d.hatched,
		cine = d.cine,
		quests = d.quests,
		equip = d.equip,
		luckLeft = math.max(0, d.luckUntil - os.time()),
		story = { ch = d.story.ch, prog = d.story.prog },
		pity = d.pity,
		species = s.species,
		collection = Config.collectionBonus(s.species),
		runes = s.runes,
		hen = Hen and Hen.snapshot(s) or nil, -- énigme de la Mère Poule : étape, plumes, indices (lot 6) ; aucun indice n'est envoyé avant le ramassage de la plume
		puzzleDone = d.puzzle.day == today,
		puzzleSolved = d.puzzle.solved,
		ach = d.ach,
		stats = statValues(s),
		baseScore = d.baseScore,
		away = math.floor(d.pendingAway),
		battle = { pvp = { trophies = d.battle.pvp.trophies, season = d.battle.pvp.season, wins = d.battle.pvp.wins, losses = d.battle.pvp.losses, hasDefense = #d.battle.pvp.defense > 0, fightsLeft = math.max(0, Config.PVP.dailyFights - (d.battle.pvp.day == os.time() // 86400 and d.battle.pvp.fights or 0)) }, team = d.battle.team, best = d.battle.best, fightsLeft = math.max(0, Config.TOWER.dailyFights + Lot7.L16.arenaExtra(s) - (d.battle.day == os.time() // 86400 and d.battle.fights or 0)), repeatsLeft = math.max(0, Config.TOWER.dailyRepeats + Lot7.L16.arenaExtra(s) - (d.battle.day == os.time() // 86400 and d.battle.repeats or 0)),
			duel = { w = d.battle.duel and d.battle.duel.w or 0, l = d.battle.duel and d.battle.duel.l or 0 }, pve = { w = d.battle.pve and d.battle.pve.w or 0, l = d.battle.pve and d.battle.pve.l or 0 }, league = L15.Duel.leagueText(Config.LEAGUES, d.battle.pvp.trophies) }, -- lot 13 : ratios duel / PvE, ligue
		baseLevel = s.baseLevel,
		welcome = s.welcome, -- œuf de bienvenue du tapis : wait / offered / taken / gone / none (onboarding)
		newbie = s.newbie == true, -- protection débutant active (lot 4)
		tokens = d.tokens.remoteSteal, -- lot 7 : jetons du Corbeau, réglage, journal « Qui m'a volé ? », offres masquées (PolicyService), bonus serveur, œufs du tapis privé
		ravenLeft = Lot7.ravenLeft and Lot7.ravenLeft(s) or 0,
		settings = { blockFriendRavens = d.settings.blockFriendRavens == true, duelOff = d.settings.duelOff == true },
		stealLog = d.stealLog,
		restricted = s.restricted ~= false, -- vrai tant que PolicyService n'a pas confirmé « non restreint » (repli prudent : offres à hasard masquées)
		srv = Lot7.serverBuffs and Lot7.serverBuffs() or { golden = 0, luck = 0 },
		pbCount = #d.pb,
		cal = Lot7.Cal.snapshot and Lot7.Cal.snapshot(s) or nil, -- lot 9b : vue du calendrier (le jour est décidé ICI, jamais par le client)
		l16 = Lot7.L16.view and Lot7.L16.view(s) or nil, -- lot 16 : achats uniques, saison (résumé), débordement, Double chance, pose, tickets d'arène
	}
end

local function pushStats(s)
	local d = s.data
	local p = s.player
	p:SetAttribute("Coins", d.coins)
	p:SetAttribute("Speed", d.speed)
	p:SetAttribute("Income", income(s))
	s.lsCoins.Value = math.floor(math.min(d.coins, 9e15))
	s.lsSpeed.Value = math.floor(d.speed)
	s.lsRb.Value = d.rb
	s.lsRank.Value = Config.rankFor(d.story.ch).name
end

local function sync(s)
	pushStats(s)
	RState:FireClient(s.player, snapshot(s))
end

---------------------------------------------------------------- Vigilance des territoires et protection débutant (lot 4)
-- Vols réussis par territoire (horodatages os.clock) : Guard.vigilance en tire le bonus de vue et d'ouïe des gardiens de CE territoire.
local vigilSteals = {}
local function recordSteal(terr)
	local now = os.clock()
	local list = Guard.vigilancePrune(vigilSteals[terr] or {}, now, Config.VIGILANCE)
	list[#list + 1] = now
	vigilSteals[terr] = list
end
local function vigilanceOf(terr)
	return Guard.vigilance(vigilSteals[terr] or {}, os.clock(), Config.VIGILANCE)
end
-- Protection débutant : moins de Config.NEWBIE.minutes de jeu cumulées ET maison sous le niveau Config.NEWBIE.untilLevel (sauf fin anticipée).
local function isNewbie(s)
	return Config.isNewbie(s.data.played, s.baseLevel, s.data.newbieOff)
end

---------------------------------------------------------------- Vitesse / étourdissement
-- Rarétés des œufs portés (liste d'indices) : le poids du portage dépend de la rareté (Config.CARRY.weight, produit, plancher 0,70).
local function carryTiers(s)
	local out = {}
	for i, e in ipairs(s.carry) do
		out[i] = e.t
	end
	return out
end
-- Boue (Mara) : vitesse x Config.TRAPS.mudMul tant que le joueur est encore « embourbé » dans l'un des territoires (états de Traps par territoire).
local function mudMulOf(s)
	local m = 1
	local now = os.clock()
	for _, ps in pairs(s.traps or {}) do
		m = math.min(m, Traps.mudMul(ps, now, Config.TRAPS))
	end
	return m
end
local function applySpeed(s)
	local hum = getHum(s.player)
	if hum and s.stun <= 0 then
		local ws = Config.walkSpeed(s.data.speed) * speedMul(s) * Config.carryMul(carryTiers(s)) * mudMulOf(s) * ((s.slowUntil or 0) > os.clock() and Config.INTRUDER.dogMul or 1)
		if math.abs(hum.WalkSpeed - ws) > 0.05 then
			hum.WalkSpeed = ws
		end
	end
end

---------------------------------------------------------------- Badge débutant, porte de base (lot 4)
-- Met à jour la protection débutant d'un joueur : attribut `Newbie` (le client l'affiche), badge 🐣 au-dessus de la tête (recréé après chaque réapparition).
local function refreshNewbie(s)
	local nb = isNewbie(s)
	if nb ~= s.newbie then
		local was = s.newbie
		s.newbie = nb
		s.player:SetAttribute("Newbie", nb)
		if was == true and not nb then
			notify(s.player, "⚔️ Protection débutant terminée : tu peux voler les autres joueurs, et ils peuvent te voler.")
		end
	end
	local char = s.player.Character
	local adornee = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if nb and adornee and not (s.badge and s.badge.Parent and s.badge.Adornee == adornee) then -- recréé après chaque réapparition (nouveau personnage)
		if s.badge then
			s.badge:Destroy()
			s.badge = nil
		end
		do
			local gui = Instance.new("BillboardGui")
			gui.Name = "NewbieBadge"
			gui.Adornee = adornee
			gui.Size = UDim2.fromOffset(44, 44)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
			gui.MaxDistance = 80
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.GothamBold
			t.TextSize = 30
			t.Text = "🐣"
			t.Parent = gui
			gui.Parent = adornee
			s.badge = gui
		end
	elseif not nb and s.badge then
		s.badge:Destroy()
		s.badge = nil
	end
end

-- Barrière lumineuse de la porte de base : un mur de lumière sur le bord de la base qui regarde la place (aucune collision : le serveur refuse le vol).
local function setDoorBarrier(s, on)
	if on and not s.doorPart and s.plot then
		local half = math.max(s.plot.platform.Size.X / 2, (Config.baseExtent(s.baseLevel or 1)))
		local p = Instance.new("Part")
		p.Name = "DoorBarrier"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 120, 90)
		p.Transparency = 0.6
		p.Size = Vector3.new(half * 2, 7, 0.4)
		p.CFrame = s.plot.cf * CFrame.new(0, 4.5, -(half + 0.2))
		p.Parent = s.plot.model
		s.doorPart = p
	elseif not on and s.doorPart then
		s.doorPart:Destroy()
		s.doorPart = nil
	end
end

---------------------------------------------------------------- Œufs portés
local function rebuildCarry(s)
	s.player:SetAttribute("Carry", #s.carry) -- le client évite les plans de caméra quand un œuf est porté
	for _, p in ipairs(s.carryParts) do
		p:Destroy()
	end
	s.carryParts = {}
	local char = s.player.Character
	local root = getRoot(s.player)
	if not (char and root) then
		return
	end
	for i, e in ipairs(s.carry) do
		local egg = Builder.egg(e.t, false)
		egg.Massless = true
		local off = CFrame.new(0, 3.4 + (i - 1) * 1.8, 0)
		egg.CFrame = root.CFrame * off
		local w = Instance.new("Weld")
		w.Part0 = root
		w.Part1 = egg
		w.C0 = off
		w.Parent = egg
		egg.Parent = char
		CollectionService:AddTag(egg, "CarryEgg") -- balancement pendant la course (client)
		s.carryParts[i] = egg
	end
	-- colonne de lumière : le porteur d'un œuf Légendaire ou plus est visible de loin (BillboardGui, portée Config.CARRY.beamRange, détruit avec les œufs)
	local top = 0
	for _, e in ipairs(s.carry) do
		top = math.max(top, e.t)
	end
	if top >= Config.CARRY.beamTier then
		local gui = Instance.new("BillboardGui")
		gui.Name = "CarryBeam"
		gui.Adornee = root
		gui.Size = UDim2.fromOffset(22, 640)
		gui.ExtentsOffset = Vector3.new(0, 0.5, 0)
		gui.MaxDistance = Config.CARRY.beamRange
		gui.AlwaysOnTop = true
		local col = Instance.new("Frame")
		col.Name = "Column"
		col.Size = UDim2.fromScale(1, 1)
		col.BorderSizePixel = 0
		col.BackgroundColor3 = Config.TIERS[top].color
		col.BackgroundTransparency = 0.25
		col.Parent = gui
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		fade.Parent = col
		gui.Parent = root
		s.carryParts[#s.carryParts + 1] = gui
	end
end

---------------------------------------------------------------- Nids des rivaux
local function setNestEgg(n, tier)
	n.egg = tier
	if n.eggPart then
		n.eggPart:Destroy()
		n.eggPart = nil
	end
	if not tier then
		return
	end
	local egg = Builder.egg(tier, true)
	egg.CFrame = CFrame.new(n.pos)
	egg.Parent = n.folder
	n.eggPart = egg
	CollectionService:AddTag(egg, "EggShake") -- animé côté client (rebond ; pas d'attribut Ends = pas de tremblement)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Voler l'œuf"
	pr.ObjectText = "Œuf " .. Config.TIERS[tier].name
	pr.HoldDuration = Config.stealTime(0, n.terr) -- temps de vol propre au territoire (sauvage 0,8 / Gus 1,3 / Mara 2,2 / Zed 3,5)
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Terr", n.terr)
	pr:SetAttribute("Kind", "Nest")
	pr:SetAttribute("Nest", n.index)
	pr:SetAttribute("Rival", n.rival) -- le client masque le prompt tant que la zone est verrouillée
	pr.Parent = egg
	CollectionService:AddTag(pr, "StealPrompt")
	Builder.sign(egg, Config.TIERS[tier].name, Config.TIERS[tier].color, 3, 160)
end

for i, n in ipairs(world.nests) do
	n.index = i
	setNestEgg(n, wpick(Config.foldWeights(n.weights or Config.RIVALS[n.rival].weights))) -- enclos sauvage : poids propres (Config.TERR.wild)
end

---------------------------------------------------------------- Pads d'une base
local hatch, speedUpEgg -- déclarations anticipées

local function clearPad(s, i)
	local pad = s.plot.pads[i]
	if pad.content then
		local gp = pad.content:GetAttribute("GuardParts")
		if s.guardBudget and gp then
			s.guardBudget.used = math.max(0, s.guardBudget.used - gp)
		end
		pad.content:Destroy()
		pad.content = nil
	end
	s.labels[i] = nil
end

local function refreshPad(s, i, animate)
	clearPad(s, i)
	local d = s.data
	local pad = s.plot.pads[i]
	local locked = i > cap(s)
	pad.locked = locked
	pad.lock.Enabled = locked
	if locked then
		local lbl = pad.lock:FindFirstChild("Text")
		if lbl then
			lbl.Text = Config.slotHint(i, cap(s), s.data.up.slots, s.baseLevel or 1, s.passes.ExtraSlots == true) -- cadenas + coût du prochain emplacement
		end
	end
	pad.part.Transparency = locked and 0.25 or 0.7
	pad.part.Color = locked and Color3.fromRGB(40, 40, 45) or Color3.new(1, 1, 1)
	pad.frame.Color = locked and Color3.fromRGB(50, 52, 58) or s.plot.color
	pad.frame.Material = locked and Enum.Material.SmoothPlastic or Enum.Material.Neon
	local sl = d.slots[i]
	if locked or not sl then
		return
	end
	local content = Instance.new("Model")
	content.Name = "Content"
	content.Parent = pad.part
	pad.content = content

	if sl.k == "e" then
		local egg = Builder.egg(sl.t, true)
		egg.CFrame = pad.part.CFrame * CFrame.new(0, 1.9, 0)
		egg:SetAttribute("Ends", sl.ends)
		CollectionService:AddTag(egg, "EggShake")
		egg.Parent = content
		s.guardBudget = s.guardBudget or { used = 0 }
		Builder.nest(pad.part.Position + Vector3.new(0, 0.3, 0), content, sl.t, s.guardBudget) -- l'œuf repose sur une protection selon sa rareté
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Voler l'œuf"
		pr.ObjectText = "Œuf de " .. s.player.DisplayName
		pr.HoldDuration = Config.stealTime(0)
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr:SetAttribute("Kind", "Pad")
		pr:SetAttribute("Owner", s.player.UserId)
		pr:SetAttribute("Slot", i)
		pr.Parent = egg
		CollectionService:AddTag(pr, "StealPrompt")
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 40
		cd.Parent = egg
		cd.MouseClick:Connect(function(who)
			speedUpEgg(s, i, who)
		end)
		s.labels[i] = Builder.sign(egg, "", Config.TIERS[sl.t].color, 3, 200)
	else
		local model, lift, labelY = Builder.pet(sl.p, sl.s, sl.m)
		model.Parent = content
		model:PivotTo(pad.part.CFrame * CFrame.new(0, 0.2 + lift, 0))
		CollectionService:AddTag(model, "Bob")
		model:SetAttribute("Seed", i * 17 + sl.p) -- désynchronise les clignements et les regards entre pets
		if animate then
			model:SetAttribute("Born", workspace:GetServerTimeNow())
			CollectionService:AddTag(model, "PopIn")
		end
		s.labels[i] = Builder.sign(model.PrimaryPart, "", Config.TIERS[Config.PETS[sl.p].tier].color, labelY, 220)
	end
end

local function refreshAllPads(s)
	for i = 1, Config.SLOTS_MAX do
		refreshPad(s, i)
	end
end

-- Capacité modifiée (niveau de maison, pass) : seuls les emplacements dont l'état verrouillé change, ou qui affichent un coût, sont rafraîchis ;
-- les emplacements occupés ne sont JAMAIS recréés.
local function refreshLocks(s)
	local c = cap(s)
	for i = 1, Config.SLOTS_MAX do
		local pad = s.plot.pads[i]
		if pad and (pad.locked ~= (i > c) or i == c + 1 or pad.hintShown) then
			refreshPad(s, i)
			pad.hintShown = (i > c) and i == c + 1 or nil
		end
	end
end

---------------------------------------------------------------- Retour / chute des œufs portés
local function returnEgg(e)
	if e.rival then
		local home = e.nest and world.nests[e.nest]
		if home then -- l'œuf regagne SON nid (même si un autre œuf y est réapparu entre-temps : le nid est remis tel qu'il était)
			setNestEgg(home, e.t)
			return
		end
		for pass = 1, 2 do -- d'abord un nid libre de SON territoire (clé `terr`), à défaut n'importe quel nid libre du même rival
			for _, n in ipairs(world.nests) do
				if n.rival == e.rival and not n.egg and (pass == 2 or n.terr == e.terr) then
					setNestEgg(n, e.t)
					return
				end
			end
		end
	elseif e.from then
		local vp = Players:GetPlayerByUserId(e.from)
		local vs = vp and sessions[vp]
		if vs then
			local i = freeSlot(vs)
			if i then
				vs.data.slots[i] = { k = "e", t = e.t, ends = os.time() + e.rem, shield = os.time() + shieldTime(vs), rv = e.rv, rvAt = e.rvAt }
				refreshPad(vs, i)
				notify(vs.player, "🥚 Ton œuf t'a été rendu !")
				sync(vs)
			end
		end
	end
end

local function dropCarry(s)
	if #s.carry == 0 then
		return
	end
	for _, e in ipairs(s.carry) do
		if e.belt and (e.paid or 0) > 0 then
			s.data.coins += e.paid -- œuf du tapis perdu en route : les pièces sont rendues (il n'a pas de nid d'origine)
			notify(s.player, "🪙 Œuf du tapis perdu : " .. Config.fmt(e.paid) .. " 🪙 rendues.")
		end
		returnEgg(e)
	end
	s.carry = {}
	rebuildCarry(s)
	applySpeed(s)
	if s.player.Parent then
		sync(s)
	end
end

local function afterTake(s, msg, sfx)
	rebuildCarry(s)
	applySpeed(s)
	sync(s)
	notify(s.player, msg or "🥚 Œuf volé ! Rapporte-le vite à ta base.", sfx or "steal")
end

---------------------------------------------------------------- Pets suiveurs (le déplacement est calculé côté client, le serveur ne fait que créer les modèles)
local followersFolder = Instance.new("Folder")
followersFolder.Name = "Followers"
followersFolder.Parent = workspace

local function clearFollowers(s)
	for _, m in ipairs(s.followers) do
		m:Destroy()
	end
	s.followers = {}
end

local function rebuildFollowers(s)
	clearFollowers(s)
	local d = s.data
	local clean = {}
	for _, i in ipairs(d.equip) do
		local sl = validSlot(i) and d.slots[i]
		if sl and sl.k == "p" then
			clean[#clean + 1] = i
		end
	end
	d.equip = clean
	local root = getRoot(s.player)
	if not root or not alive(s.player) then
		return
	end
	for n, i in ipairs(d.equip) do
		local sl = d.slots[i]
		local m = Builder.follower(sl.p, sl.s, sl.m)
		m.Name = "Follower"
		m:SetAttribute("OwnerId", s.player.UserId)
		m:SetAttribute("Idx", n)
		m:PivotTo(root.CFrame * CFrame.new((n - 2) * 3, -2, 4))
		m.Parent = followersFolder
		CollectionService:AddTag(m, "Follower")
		s.followers[#s.followers + 1] = m
	end
end

---------------------------------------------------------------- Annonces (ce serveur + tous les serveurs)
local function announce(text)
	for _, pl in ipairs(Players:GetPlayers()) do
		notify(pl, text)
	end
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync("ChipeAnnounce", { sid = Data.SERVER_ID, text = text })
		end)
	end)
end
task.spawn(function() -- SubscribeAsync attend le réseau : ne pas bloquer le démarrage du serveur
	pcall(function()
		MessagingService:SubscribeAsync("ChipeAnnounce", function(msg)
			local m = msg.Data
			if type(m) == "table" and m.sid ~= Data.SERVER_ID and type(m.text) == "string" then
				for _, pl in ipairs(Players:GetPlayers()) do
					notify(pl, m.text)
				end
			end
		end)
	end)
end)

---------------------------------------------------------------- Progression de la base (niveau d'après le score pondéré par la rareté)
-- Niveau de maison d'après le score pondéré par la rareté, la rareté découverte (niveaux 7 et 8) et le plancher sauvegardé (jamais de recul).
local function levelOf(s)
	return Config.baseLevel(s.data.baseScore, s.data.dex, s.data.baseLevelFloor)
end
-- Reconstruit l'apparence de la base au niveau courant et publie le niveau (attributs lus par le client : animation de montée de niveau, interface).
-- Une vraie montée (célébration demandée, niveau supérieur à celui déjà construit) lance l'animation : l'ancienne maison reste le temps de l'effet (Config.UPGRADE_FX),
-- les pads ne sont pas recréés (refreshLocks). `force` reconstruit sans animation (modèles Blender arrivés, renaissance).
-- Lot 8B-meubles : meubles des lots 18 et 19 dans la maison BaseUpgrade que Builder.baseUpgrade vient de créer. Repère : attributs DecorY / DecorZ
-- posés par Builder (centre du bâtiment au plancher, repère de plot.cf). Idempotent (HouseDecor), part avec la maison quand elle est démolie.
function K8.houseDecor(plot, level)
	local house = plot and plot.model and plot.model:FindFirstChild("BaseUpgrade")
	if not house then
		return
	end
	local y, z = house:GetAttribute("DecorY"), house:GetAttribute("DecorZ")
	task.spawn(function()
		local ok, err = pcall(K8.HouseDecor.apply, house, level, {
			offset = { 0, type(y) == "number" and y or 1.6, type(z) == "number" and z or 0 }, data = K8.HouseDecorData, useAssets = Config.Assets.Enabled == true,
		})
		if not ok then
			warn("[HouseDecor] " .. tostring(err))
		end
	end)
end
local function applyBase(s, celebrate, force)
	local level = levelOf(s)
	local before = s.baseLevel
	s.baseLevel = level
	local built = s.baseBuilt
	local rose = celebrate and built ~= nil and level > built
	if s.plot and (built ~= level or force) then
		Builder.baseUpgrade(s.plot, level, rose and { animate = true } or nil)
		s.baseBuilt = level
		K8.houseDecor(s.plot, level) -- lot 8B-meubles : décor intérieur cumulé du niveau, posé sur la nouvelle maison (hors du thread courant : LoadAsset cède la main)
		if rose then
			local plot = s.plot
			task.delay(Config.UPGRADE_FX.seconds, function()
				if plot.upgrading then
					Builder.finishUpgrade(plot)
				end
			end)
		end
	end
	if before ~= nil and level > before then
		tele.log(s.player, "house_level_reached", s.data.played, "_l" .. level)
	end
	if s.plot and before ~= level then
		refreshLocks(s) -- la capacité dépend du niveau : cadenas et coûts à jour, pets déjà posés intacts
	end
	s.player:SetAttribute("BaseLevel", level)
	s.player:SetAttribute("BaseScore", s.data.baseScore)
	if rose or (celebrate and before and level > before) then
		local lv = Config.BASE_LEVELS[level]
		local text = Config.upgradeBanner(level)
		local player = s.player
		-- la bannière, la fanfare et les confettis arrivent au début de la fête (après échafaudage, poussière et échange des maisons : 2,7 s)
		task.delay(Config.UPGRADE_FX.scaffold + Config.UPGRADE_FX.dust + Config.UPGRADE_FX.swap, function()
			notify(player, text, "levelup")
		end)
		if level >= Config.UPGRADE_FX.announceFrom then
			announce("🏠 " .. player.DisplayName .. " passe au niveau " .. level .. " : " .. lv.emoji .. " " .. lv.name .. " !")
		end
		sync(s)
	end
end

-- Les modèles Blender arrivent APRÈS l'entrée des premiers joueurs : une fois un groupe chargé, on reconstruit la base et les pads déjà affichés
-- (sinon le repli procédural resterait visible jusqu'au prochain changement de niveau).
onAssetsLoaded = function()
	for _, s in pairs(sessions) do
		pcall(function()
			applyBase(s, false, true)
			refreshAllPads(s)
		end)
	end
end

---------------------------------------------------------------- Éclosion
-- Lot 10 : annonces d'un tirage d'après Odds.fx. Monde (N >= 1 000 000 ou rareté >= Secret) et ancienne règle (bandeau serveur, mutation >= Alien, Colossal) :
-- tous les serveurs ; serveur seul : N >= 10 000 ou Ultra Rare ; panneau « 1 sur N » au-dessus du pad pendant quelques secondes dès N >= 1 000 (visible de tous).
function Lot7.oddsAnnounce(s, i, def, p, odds, fx)
	local text = "🌟 " .. s.player.DisplayName .. " vient d'obtenir " .. def.emoji .. " " .. Config.petName(p.p, p.s, p.m) .. " !" .. (odds and (" (" .. Lot7.Odds.label(odds) .. ")") or "")
	if Config.tierAtLeast(def.tier, "serverBanner") or p.m >= 5 or p.s == 5 or fx.announceWorld then
		announce(text)
	elseif fx.announceServer then
		for _, pl in ipairs(Players:GetPlayers()) do
			notify(pl, text)
		end
	end
	local pad = s.plot and s.plot.pads[i]
	if fx.billboard and Config.HATCH_FX.Enabled and pad and pad.part then
		pcall(function()
			local bb = Instance.new("BillboardGui")
			bb.Name = "OddsBillboard"
			bb.Size = UDim2.fromOffset(220, 44)
			bb.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
			bb.AlwaysOnTop = true
			bb.MaxDistance = 160
			local lab = Instance.new("TextLabel")
			lab.Size = UDim2.fromScale(1, 1)
			lab.BackgroundTransparency = 1
			lab.Font = Enum.Font.GothamBold
			lab.TextScaled = true
			lab.Text = "✦ " .. Lot7.Odds.label(odds) .. " ✦"
			lab.TextColor3 = Config.TIERS[def.tier].color
			lab.TextStrokeTransparency = 0
			lab.Parent = bb
			bb.Parent = pad.part
			game:GetService("Debris"):AddItem(bb, Config.HATCH_FX.billboardSeconds)
		end)
	end
end

function hatch(s, i)
	local d = s.data
	local sl = d.slots[i]
	if not sl or sl.k ~= "e" then
		return
	end
	local eggT = Config.debugForceTier(RunService:IsStudio()) or sl.t -- A9 : Config.Debug.forceHatch, Studio seulement (nil en production)
	local guaranteed = Config.PITY_ENABLED and eggT <= Config.UPGRADE.maxEggTier and d.pity >= Config.PITY_EVERY - 1
	local p, upPoints, alienBoost, open = rollPet(s, eggT, guaranteed)
	local oneIn = Reveal.oneIn(Config, Rules, eggT, upPoints, alienBoost, p.p, p.s, p.m, guaranteed, open)
	if p.tier > eggT then
		d.pity = 0
	elseif eggT <= Config.UPGRADE.maxEggTier then
		d.pity += 1
	end
	local firstOfTier = true -- lot 9 (mesure) : première fois que cette rareté est obtenue ?
	for k, e in pairs(d.dex) do
		local dd = Config.PETS[tonumber(k) or 0]
		if dd and dd.tier == p.tier and type(e) == "table" and type(e.n) == "number" and e.n > 0 then
			firstOfTier = false
		end
	end
	-- lot 10 : compteur « 1 sur N » de référence calculé UNE fois ici et figé dans le slot (jamais recalculé ; aucun bonus n'entre dans le calcul)
	local odds = Lot7.Odds.forPet(Config, p.p, p.s, p.m)
	d.slots[i] = { k = "p", p = p.p, s = p.s, m = p.m, o = odds, ov = odds and Config.ODDS.version or nil }
	L15.qk(s, "hatch", { odds = odds }) -- A11 : quête « 1 sur 1 000 ou plus rare » (compteur de référence, sans bonus)
	d.hatched += 1
	if d.hatched == 1 then
		tele.log(s.player, "first_hatch_seconds", d.played)
		tele.event(s.player, "onboarding", "first_hatch") -- lot 16 (I.2)
	end
	if Lot7.L16.hatchQualifies(p.tier) then
		Lot7.L16.addXp(s, "hatch") -- lot 16 : éclosion Épique ou mieux
	end
	if firstOfTier then
		tele.log(s.player, "tier_first_reached", d.played, "_r" .. p.tier)
		if Config.TIERS[p.tier] and Config.TIERS[p.tier].name == "Légendaire" then
			s.l16Legend = os.time() -- lot 16 : première éclosion Légendaire (déclencheur d'offre « Double chance », valable 10 min)
			Lot7.L16.event(s, "firstLegend")
		end
	end
	tele.log(s.player, "hatch_tier", 1, "_r" .. p.tier)
	d.baseScore += Config.baseGain(p.tier) -- la base grandit avec chaque pet éclos, d'autant plus que le pet est rare
	local key = tostring(p.p)
	local dx = d.dex[key]
	if not dx then
		dx = { n = 0, b = 0 }
		d.dex[key] = dx
		s.species += 1
		qp(s, "discover", 1)
	end
	dx.n += 1
	dx.b = math.max(dx.b, Config.SIZES[p.s].mult * Config.MUTS[p.m].mult)
	refreshPad(s, i, true)
	qp(s, "hatch", 1)
	local def = Config.PETS[p.p]
	L15.onHatch(s, def.tier) -- lot 15 : quête bonus « éclosion Épique+ », calme des PNJ après une grande révélation
	sp(s, "hatch", 1)
	applyBase(s, true)
	sp(s, "tier", 1, { tier = def.tier })
	if p.m > 1 then
		sp(s, "mut", 1)
	end
	if Config.tierAtLeast(def.tier, "shine") then
		qp(s, "rare", 1)
	end
	storyRefresh(s)
	local big = Config.tierAtLeast(def.tier, "announce") or p.m > 1 or p.s >= 4
	local col = Config.MUTS[p.m].color or Config.TIERS[def.tier].color
	Builder.burst(s.plot.pads[i].part.Position + Vector3.new(0, 3, 0), col, big and 90 or 25, big)
	-- Rareté élevée ou tirage secret : cercle runique au sol, particules, pilier de lumière et contour lumineux du pet (Config.AURA)
	local oddsFx = Lot7.Odds.fx(odds, def.tier, Config) -- lot 10 : annonces sociales (serveur, monde, pilier, panneau au-dessus du pad)
	local secretHit = oneIn >= Config.REVEAL.secret.oneInAtLeast or oddsFx.pillar
	if Config.AURA.Enabled and (def.tier >= Config.AURA.minTier or secretHit) then
		Builder.aura(s.plot.pads[i].part.Position, col, def.tier, secretHit)
		local holder = s.plot.pads[i].content
		local petModel = holder and holder:FindFirstChild("Pet")
		if Config.AURA.highlight and petModel then
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 1
			hl.OutlineColor = col
			hl.OutlineTransparency = 0.1
			hl.Parent = petModel
			game:GetService("Debris"):AddItem(hl, Config.AURA.seconds)
		end
	end
	RHatch:FireClient(s.player, { p = p.p, s = p.s, m = p.m, slot = i, inc = Config.petIncome(p.p, p.s, p.m) * gmult(s), oneIn = oneIn < math.huge and oneIn or 0, egg = eggT, upgraded = p.tier > eggT, o = odds, first = firstOfTier })
	Lot7.oddsAnnounce(s, i, def, p, odds, oddsFx)
	sync(s)
end

function speedUpEgg(s, i, who)
	if who ~= s.player then
		return
	end
	local sl = s.data.slots[i]
	if not sl or sl.k ~= "e" then
		return
	end
	Lot7.chase(s, i) -- un corbeau vise cet œuf : le toucher (dans sa base) le chasse
	local now = os.clock()
	if now - s.lastTap < 0.12 then
		return
	end
	s.lastTap = now
	sl.ends -= 1
	local content = s.plot.pads[i].content
	local eggPart = content and content:FindFirstChild("Egg")
	if eggPart then
		eggPart:SetAttribute("Ends", sl.ends)
	end
	if os.time() >= sl.ends then
		hatch(s, i)
	end
end

---------------------------------------------------------------- Vol (nids PNJ et bases des joueurs)
-- Le serveur mesure lui-même la durée de maintien du bouton (le client ne fait qu'afficher la barre).
local holds = {}
local pendingCharges = {} -- lot 8A : alarmes de nid en attente { player, terr, at } (Mara et Zed ; traitées par guardsStep)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
	holds[player] = { prompt = prompt, t = os.clock() }
	local s = sessions[player]
	if s then
		s.holdSeen = true
	end
end)

-- Secrets de la carte : une récompense par jour et par secret, distance et existence vérifiées côté serveur.
local function claimSecret(s, root, prompt)
	local id = prompt:GetAttribute("SecretId")
	local sct = type(id) == "string" and Config.secret(id)
	local holder = prompt.Parent
	if not sct or not holder or not holder:IsA("BasePart") or (root.Position - holder.Position).Magnitude > 18 then
		return
	end
	local today = os.time() // 86400
	if s.data.secrets[sct.id] == today then
		notify(s.player, "💤 Tu as déjà fouillé ici aujourd'hui. Reviens demain !")
		return
	end
	local reward = Config.secretReward(sct, income(s))
	s.data.secrets[sct.id] = today
	s.data.coins += reward
	Builder.burst(holder.Position, Color3.fromRGB(255, 214, 90), 24, true)
	qp(s, "secret", 1)
	notify(s.player, sct.emoji .. " " .. sct.name .. " : +" .. Config.fmt(reward) .. " 🪙", "secret_decouvert") -- secret de la carte (lot 8A)
	sync(s)
end

-- Voyage rapide (Config.TRAVEL2) : le serveur valide TOUT (destination, portail débloqué, joueur vivant, hors combat, hors château, à moins de
-- maxDistance du portail, délai, AUCUN œuf porté : on ne téléporte jamais un œuf) ; la destination vient d'un attribut du prompt, jamais du client.
-- dest > 0 : portail k de la rose ; 0 : retour à la place ; -i : arche de la base i (réservée à son propriétaire).
local function fastTravel(s, dest, prompt)
	local root = getRoot(s.player)
	local T = Config.TRAVEL2
	if not root or not alive(s.player) or s.stun > 0 or s.castle then
		return false
	end
	if type(dest) ~= "number" or dest % 1 ~= 0 or dest < -Config.PLOT_COUNT or dest > #T.portals then
		return false
	end
	if not (prompt and prompt.Parent and prompt.Parent:IsA("BasePart")) or (root.Position - prompt.Parent.CFrame.Position).Magnitude > T.maxDistance + 1 then
		return false
	end
	local now = os.clock()
	if now - (s.travelAt or -99) < T.cooldown then
		return false
	end
	if s.sinceHit < T.combatLock or (s.battle and s.battle.duel) then -- lot 13 : pas de voyage pendant un duel (personnage figé sur le sable)
		notify(s.player, "⚔️ Pas de voyage rapide en plein combat.")
		return false
	end
	if T.blockWhileCarrying and #s.carry > 0 then
		notify(s.player, "🥚 Pas de portail avec un œuf : rapporte-le à pied !", "refuse")
		return false
	end
	local x, z
	if dest < 0 then
		local plot = s.plot
		if not plot or plot.index ~= -dest then
			notify(s.player, "🏠 Cette arche mène à la base d'un autre joueur.", "refuse")
			return false
		end
		local sp = plot.spawn.CFrame.Position
		x, z = sp.X, sp.Z
	else
		if dest > 0 and not Config.portalUnlocked(s.data.story.ch, dest) then
			notify(s.player, "🔒 Portail verrouillé : termine l'histoire jusqu'au chapitre " .. T.portals[dest].chapter .. ".", "refuse")
			return false
		end
		x, z = Config.travelDest(dest)
	end
	s.travelAt = now
	root.CFrame = CFrame.new(x, 4, z)
	root.AssemblyLinearVelocity = Vector3.zero
	s.noCheckUntil = now + 2
	s.lastPos = nil
	s.lastActive = now
	notify(s.player, "", "portal") -- son de portail
	return true
end

-- Lot 8B : kiosque central. Classement mis en cache 30 s (Data.pvpTop lit un DataStore : quota), quel que soit le nombre de joueurs.
function K8.topCached(season, n)
	local c = K8.top
	if c.season ~= season or os.clock() - c.at > 30 then
		c.at, c.season = os.clock(), season
		local ok, list = pcall(Data.pvpTop, season, n)
		c.list = (ok and type(list) == "table") and list or {}
	end
	return c.list
end
-- Un prompt du kiosque : TOUT est revalidé par Kiosk.handle (liste blanche d'actions, distance mesurée ici, pause par joueur). Un refus ne répond rien.
-- Le kiosque ne fait qu'ouvrir : réclamer le calendrier ou acheter passe par les chemins existants (RAction calClaim, achats Robux), déjà validés.
function K8.prompt(player, prompt)
	local res = K8.Kiosk.handle(player, prompt:GetAttribute("KioskAction"), {
		Config = Config,
		inRange = function(p)
			local r = getRoot(p)
			local info = K8.info
			if not (r and alive(p) and info and sessions[p]) then
				return false
			end
			local c = info.center
			return math.sqrt((r.Position.X - c.X) ^ 2 + (r.Position.Z - c.Z) ^ 2) <= K8.KioskData.SERVER_RANGE
		end,
		calView = function(p)
			local ss = sessions[p]
			return ss and Lot7.Cal.snapshot and Lot7.Cal.snapshot(ss) or nil
		end,
		top = K8.topCached,
		mine = function(p)
			local ss = sessions[p]
			local pv = ss and ss.data.battle and ss.data.battle.pvp
			return type(pv) == "table" and { trophies = pv.trophies, wins = pv.wins, losses = pv.losses } or nil
		end,
	})
	if res.ok then
		K8.remote:FireClient(player, res.payload)
	end
end
-- Pastille rouge du calendrier sur le kiosque : allumée dès qu'un joueur présent a une récompense réclamable (Calendar, via Lot7.Cal.snapshot). Toutes les 5 s.
task.spawn(function()
	while true do
		task.wait(5)
		if K8.info then
			local any = false
			for _, ss in pairs(sessions) do
				local okV, view = pcall(function()
					return Lot7.Cal.snapshot and Lot7.Cal.snapshot(ss) or nil
				end)
				if okV and K8.Kiosk.badgeNeeded(view) then
					any = true
					break
				end
			end
			K8.Kiosk.setBadge(K8.info, any)
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if CollectionService:HasTag(prompt, "BeltEgg") then
		beltBuy(player, prompt)
		return
	end
	if CollectionService:HasTag(prompt, "FastTravel") then
		local ss = sessions[player]
		if ss then
			fastTravel(ss, prompt:GetAttribute("Dest"), prompt)
		end
		return
	end
	if CollectionService:HasTag(prompt, "KioskPrompt") then
		K8.prompt(player, prompt)
		return
	end
	if CollectionService:HasTag(prompt, "SellerPrompt") then
		-- lot 16 : vendeur PNJ -> ouvre la boutique sur SON onglet. Tout est revalidé par Sellers.handle (liste blanche, distance mesurée ici, pause par joueur).
		local res = K8.Sellers.handle(player, prompt:GetAttribute("SellerAction"), {
			Config = Config,
			inRange = function(p, id)
				local r = getRoot(p)
				return r ~= nil and alive(p) and sessions[p] ~= nil and K8.Sellers.inRange(K8.sellers, id, r.Position.X, r.Position.Z)
			end,
		})
		if res.ok then
			K8.remote:FireClient(player, res.payload)
		end
		return
	end
	if CollectionService:HasTag(prompt, "CastleEntry") then
		local ss, rr = sessions[player], getRoot(player)
		if ss and rr and alive(player) and ss.stun <= 0 and (rr.Position - prompt.Parent.Position).Magnitude <= 20 then
			castleEnter(ss)
		end
		return
	elseif CollectionService:HasTag(prompt, "CastleChest") then
		local ss, rr = sessions[player], getRoot(player)
		if ss and rr and alive(player) then
			castleFinish(ss, rr, prompt)
		end
		return
	end
	if CollectionService:HasTag(prompt, "SecretPrompt") then
		local ss, rr = sessions[player], getRoot(player)
		if ss and rr and alive(player) and ss.stun <= 0 then
			claimSecret(ss, rr, prompt)
		end
		return
	end
	local kind = prompt:GetAttribute("Kind")
	if kind ~= "Nest" and kind ~= "Pad" and kind ~= "Rune" and kind ~= "RuneConfirm" and kind ~= "HenTalk" and kind ~= "Feather" and kind ~= "PrivBelt" then
		return
	end
	local s = sessions[player]
	local root = getRoot(player)
	if not s or not root or not alive(player) or s.stun > 0 then
		return
	end
	if kind == "PrivBelt" then
		Lot7.privTake(s, root, prompt) -- tapis privé : seul le propriétaire prend l'œuf (validé dans privTake)
		return
	end
	if kind == "Rune" or kind == "RuneConfirm" or kind == "HenTalk" or kind == "Feather" then
		if Hen then -- énigme de la Mère Poule (toutes les validations sont dans HenQuest)
			if kind == "Rune" then
				Hen.stoneTap(s, root, prompt)
			elseif kind == "RuneConfirm" then
				Hen.confirmRunes(s, root)
			elseif kind == "HenTalk" then
				Hen.talk(s, root)
			else
				Hen.pickFeather(s, root, prompt)
			end
		end
		return
	end
	local now = os.clock()
	if now - s.lastSteal < 0.3 then
		return
	end
	s.lastSteal = now
	if s.holdSeen then
		local h = holds[player]
		holds[player] = nil
		if not h or h.prompt ~= prompt or os.clock() - h.t < Config.stealTime(s.data.up.fing, prompt:GetAttribute("Terr")) * 0.7 then
			return
		end
	end
	if #s.carry >= carryCap(s.data) then
		notify(player, "Sac plein ! Rapporte tes œufs à ta base.")
		return
	end

	if kind == "Nest" then
		local n = world.nests[prompt:GetAttribute("Nest")]
		if not n or not n.egg or (root.Position - n.pos).Magnitude > 18 then
			return
		end
		local zone = Config.ZONES[n.rival]
		if not Config.zoneUnlocked(s.data.story.ch, n.rival) then
			notify(player, "🔒 " .. zone.name .. " : termine d'abord le chapitre " .. zone.chapter .. " de l'histoire.", "caught")
			return
		end
		local t = n.egg
		setNestEgg(n, nil)
		Builder.flyEgg(t, n.pos, player.UserId)
		Builder.burst(n.pos, Config.TIERS[t].color, 14, false)
		n.rt = rng:NextNumber(9, 16) * (1 + (n.rival - 1) * 0.3)
		s.carry[#s.carry + 1] = { t = t, rem = hatchTime(s, t), rival = n.rival, terr = n.terr, nest = n.index, fresh = Traps.freshDeadline(Config, t, n.terr, os.clock()) }
		recordSteal(n.terr) -- vigilance : les gardiens de ce territoire voient et entendent plus loin pendant un moment
		s.data.stolen += 1
		qp(s, "steal", 1)
		sp(s, "steal", 1, { rival = n.rival })
		local alarm = Config.TERR[n.terr] and Config.TERR[n.terr].nestAlarm
		if alarm then -- alarme du nid (Mara, Zed) : le gardien le plus proche chargera le voleur dans alarm.delay s (voir guardsStep)
			if #pendingCharges < 64 then -- borne de sécurité (une entrée par vol, purgée en alarm.delay s)
				pendingCharges[#pendingCharges + 1] = { player = player, terr = n.terr, at = os.clock() + alarm.delay }
			end
			afterTake(s, "🥚 Œuf chipé ! " .. (n.rival == 3 and "🐻 L'ours" or "🐺 Le loup") .. " a senti le nid se vider : file vers la sortie !")
		else
			afterTake(s)
		end
	else
		local vp = Players:GetPlayerByUserId(prompt:GetAttribute("Owner") or 0)
		local vs = vp and sessions[vp]
		local i = prompt:GetAttribute("Slot")
		if not vs or vs == s or type(i) ~= "number" then
			return
		end
		local sl = vs.data.slots[i]
		if not sl or sl.k ~= "e" then
			return
		end
		if isNewbie(s) then
			notify(player, "🐣 Protection débutant : tu ne peux pas encore voler d'autres joueurs (menu : « Je suis prêt pour le PvP »).")
			return
		end
		if isNewbie(vs) then
			notify(player, "🐣 Ce joueur est sous protection débutant : ses œufs ne peuvent pas être volés.")
			return
		end
		if (vs.lockUntil or 0) > os.clock() then
			notify(player, "🔒 La porte de cette base est fermée !")
			return
		end
		if (sl.shield or 0) > os.time() or (vs.graceUntil or 0) > os.time() then
			notify(player, "🛡 Cet œuf est encore protégé !")
			return
		end
		local pad = vs.plot.pads[i].part
		if (root.Position - pad.Position).Magnitude > 20 then
			return
		end
		vs.data.slots[i] = false
		refreshPad(vs, i)
		Builder.flyEgg(sl.t, pad.Position + Vector3.new(0, 2, 0), player.UserId)
		s.carry[#s.carry + 1] = { t = sl.t, rem = math.max(0, sl.ends - os.time()), from = vp.UserId, rv = sl.rv, rvAt = sl.rvAt } -- rv/rvAt suivent l'œuf (lot 7b)
		s.data.stolen += 1
		qp(s, "steal", 1)
		qp(s, "pvp", 1)
		sp(s, "steal", 1, {})
		notify(vp, "😡 " .. player.DisplayName .. " a volé ton œuf ! Rattrape-le !", "caught")
		Lot7.onPhysicalSteal(vs, player.DisplayName, sl.t) -- journal « Qui m'a volé ? » + bouclier post-vol de 5 min contre les corbeaux
		sync(vs)
		afterTake(s)
	end
end)

---------------------------------------------------------------- Gardiens PNJ : perception, états, dégâts non mortels (voir Guard.lua)
local GC = Config.GUARD

-- Réglages de perception propres à chaque gardien (délai de réaction : Gus 1,6 s, Mara 0,9 s, Zed 0,5 s).
local gcCache = {}
local function gcFor(rival)
	local c = gcCache[rival]
	if not c then
		c = setmetatable({ alertDelay = Config.RIVALS[rival].alertDelay or GC.alertDelay }, { __index = GC })
		gcCache[rival] = c
	end
	return c
end

local function setHp(s, hp)
	s.hp = hp
	s.player:SetAttribute("Hp", math.floor(hp + 0.5))
	s.player:SetAttribute("MaxHp", GC.maxHp)
end

-- Défaite (0 pv) : œufs portés rendus à leur nid, retour à la base avec tous les pv et une courte invulnérabilité. Jamais en un seul coup.
local function defeatAtBase(s)
	dropCarry(s)
	local root = getRoot(s.player)
	if root and s.plot then
		root.CFrame = s.plot.spawn.CFrame + Vector3.new(0, 4, 0)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	s.noCheckUntil = os.clock() + 2
	s.iframes, s.sinceHit = GC.respawnIframes, 0
	setHp(s, GC.maxHp)
	notify(s.player, "🏠 Tu as été vaincu : retour à ta base, œufs rendus, pv rétablis.", "caught")
end

local function hitPlayer(s, g)
	local r = g.stats
	if r.gentle then
		-- gardien clément (Gus) : jamais de dégâts ; la première prise renvoie à la base (la cargaison est gardée), puis 6 s de répit
		if os.clock() < (s.gentleUntil or 0) then
			return false
		end
		s.gentleUntil = os.clock() + GC.gentleRecover
		s.stun = GC.stun
		s.noCheckUntil = os.clock() + 2
		local root0 = getRoot(s.player)
		if root0 and s.plot then
			root0.CFrame = s.plot.spawn.CFrame + Vector3.new(0, 4, 0)
			root0.AssemblyLinearVelocity = Vector3.zero
		end
		notify(s.player, "🐕 " .. r.name .. " t'a attrapé, réessaie ! (aucun œuf ni pet perdu)", "hurt")
		return true
	end
	local hp, hit, inv = Guard.applyDamage(s.hp, r.damage, s.iframes, GC)
	if not hit then
		return false
	end
	s.iframes, s.sinceHit = inv, 0
	setHp(s, hp)
	s.stun = GC.stun
	s.noCheckUntil = os.clock() + 1.2
	local root, hum = getRoot(s.player), getHum(s.player)
	if hum then
		hum.PlatformStand = true
	end
	if root then
		local away = (root.Position - g.pos) * Vector3.new(1, 0, 1)
		away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
		root.AssemblyLinearVelocity = away * GC.knockback + Vector3.new(0, 18, 0) -- recul
	end
	notify(s.player, "🐕 " .. r.name .. " t'a mordu : -" .. r.damage .. " ❤️ (" .. math.floor(hp + 0.5) .. "/" .. GC.maxHp .. ")", "hurt")
	if hp <= 0 then
		defeatAtBase(s)
		return true
	end
	-- lot 8A (B.4 « prise par un gardien ») : le gardien qui CHARGE après l'alarme du nid reprend les œufs de SON territoire (ils regagnent leur nid)
	local back = false
	if g.charge == s.player then
		g.charge = nil
		for i = #s.carry, 1, -1 do
			local e = s.carry[i]
			if e.rival and e.terr == g.terr then
				table.remove(s.carry, i)
				returnEgg(e)
				back = true
			end
		end
	end
	if back then
		rebuildCarry(s)
		applySpeed(s)
		sync(s)
		notify(s.player, "↩️ " .. r.name .. " a repris l'œuf : il retourne à son nid.", "caught")
	end
	return true
end

-- Cible la plus proche dans la zone de perception maximale du gardien (seuls les joueurs dont le domaine est ouvert sont ciblables).
local function inPlot(s, root)
	local rel = s.plot.cf:PointToObjectSpace(root.Position)
	return Config.inBase(s.baseLevel or 1, rel.X, rel.Z, rel.Y) -- la plateforme grandit avec le niveau de la maison
end

-- Intrusion dans la base de `host` par `visitor` (D.2) : alarme (niveau 3, notification à l'hôte) et chien de garde (niveau 5, intrus ralenti x0,7 pendant 3 s).
-- Chaque effet a un délai de récupération ; aucun des deux ne bloque le vol (la porte de base et la protection débutant restent les règles de protection).
local function onIntrusion(host, visitor)
	local lv = Config.BASE_LEVELS[host.baseLevel or 1]
	if not lv then
		return
	end
	local now = os.clock()
	if lv.alarm and now - (host.lastAlarm or -99) >= Config.INTRUDER.alarmCooldown then
		host.lastAlarm = now
		notify(host.player, "🔔 Alarme : " .. visitor.player.DisplayName .. " est entré dans ta base !")
	end
	if lv.guardDog and now - (visitor.lastDog or -99) >= Config.INTRUDER.dogCooldown then
		visitor.lastDog = now
		visitor.slowUntil = now + Config.INTRUDER.dogSeconds
		applySpeed(visitor)
		notify(visitor.player, "🐕 Le chien de garde de " .. host.player.DisplayName .. " te ralentit !")
		task.delay(Config.INTRUDER.dogSeconds + 0.1, function()
			if visitor.player.Parent then
				applySpeed(visitor)
			end
		end)
	end
end

-- Zone de sécurité (A.5) : la base du joueur, toute la place du marché et les safeRadius studs autour de l'entrée du territoire du gardien ne sont
-- jamais ciblés.
local PLAZA = Config.Map2.plaza
local function safeSpot(s, root, g)
	if s.plot and inPlot(s, root) then
		return true
	end
	local p = root.Position
	if math.sqrt((p.X - PLAZA.x) ^ 2 + (p.Z - PLAZA.z) ^ 2) < PLAZA.r then
		return true
	end
	local ex, ez = Config.territoryEntry(g.terr)
	return math.sqrt((p.X - ex) ^ 2 + (p.Z - ez) ^ 2) < GC.safeRadius
end

local function candidate(g, r)
	local best, bd = nil, math.max(r.viewDist, r.hearRadius) + 2
	for player, s in pairs(sessions) do
		if Config.zoneUnlocked(s.data.story.ch, g.rival) and alive(player) then
			local root = getRoot(player)
			if root and not safeSpot(s, root, g) then
				local dd = math.sqrt((root.Position.X - g.pos.X) ^ 2 + (root.Position.Z - g.pos.Z) ^ 2)
				if dd < bd then
					best, bd = player, dd
				end
			end
		end
	end
	return best
end

-- Chemin : PathfindingService en tâche de fond (ComputeAsync cède) ; sans résultat, ligne droite (repli). Retourne le point visé.
local PathfindingService = game:GetService("PathfindingService")
local function aimPoint(g, goal, dt)
	g.pathT = (g.pathT or 0) - dt
	if g.pathT <= 0 and not g.pathBusy then
		g.pathT, g.pathBusy = GC.pathInterval, true
		local from = g.pos
		task.spawn(function()
			local ok, wps = pcall(function()
				local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
				path:ComputeAsync(from, goal)
				if path.Status ~= Enum.PathStatus.Success then
					return nil
				end
				local out = {}
				for _, w in ipairs(path:GetWaypoints()) do
					out[#out + 1] = w.Position
				end
				return out
			end)
			g.wps = ok and wps or nil
			g.pathBusy = false
		end)
	end
	if g.wps then
		while #g.wps > 0 and ((g.wps[1].X - g.pos.X) ^ 2 + (g.wps[1].Z - g.pos.Z) ^ 2) < 4 do
			table.remove(g.wps, 1)
		end
		if g.wps[1] then
			return Vector3.new(g.wps[1].X, g.pos.Y, g.wps[1].Z)
		end
	end
	return goal
end

local MARKS = { patrol = "", alert = "❓", chase = "❗", lostChase = "❓", ["return"] = "" }

for _, g in ipairs(world.guards) do -- marque d'état au-dessus de chaque gardien (❓ alerte, ❗ poursuite)
	local ok, label = pcall(Builder.sign, g.model.PrimaryPart, "", Color3.fromRGB(255, 230, 90), 7, 80)
	if ok then
		label.TextSize = 34
		g.mark = label
	end
end

-- Réglages de chaque gardien d'après SON territoire (Config.guardStats : vitesses, vue, ouïe, coup de Config.TERR ; Gus = son rival, clément).
for _, g in ipairs(world.guards) do
	g.stats = Config.guardStats(g.terr)
end

local function guardsStep(dt)
	for _, s in pairs(sessions) do -- invulnérabilité et temps depuis le dernier coup
		s.iframes = math.max(0, (s.iframes or 0) - dt)
		s.sinceHit = (s.sinceHit or 99) + dt
	end
	local nowc = os.clock()
	for i = #pendingCharges, 1, -1 do -- alarmes de nid échues (lot 8A) : le gardien du territoire le plus proche du voleur le charge
		local pc = pendingCharges[i]
		if nowc >= pc.at then
			table.remove(pendingCharges, i)
			local ps = sessions[pc.player]
			local proot = ps and alive(pc.player) and getRoot(pc.player)
			if proot then
				local best, bd = nil, math.huge
				for _, g in ipairs(world.guards) do
					if g.terr == pc.terr then
						local d = (Vector3.new(g.pos.X, 0, g.pos.Z) - Vector3.new(proot.Position.X, 0, proot.Position.Z)).Magnitude
						if d < bd then
							best, bd = g, d
						end
					end
				end
				if best and not safeSpot(ps, proot, best) then -- déjà à l'abri (entrée, place, base) : aucune charge
					best.st = Guard.charge(best.st)
					best.target, best.charge, best.wps = pc.player, pc.player, nil
					best.last = Vector3.new(proot.Position.X, best.pos.Y, proot.Position.Z)
					if best.mark then
						best.mark.Text = "❗"
					end
					local key = Config.guardSoundKey(Config.Assets.guardKinds[best.rival])
					for pl in pairs(sessions) do
						local pr = getRoot(pl)
						if pr and (pr.Position - best.pos).Magnitude < 60 then
							notify(pl, "", key)
						end
					end
				end
			end
		end
	end
	for _, g in ipairs(world.guards) do
		local r = g.stats
		local bonus = vigilanceOf(g.terr)
		if bonus ~= g.vigBonus or not g.rv then -- vue et ouïe majorées par la vigilance du territoire (recalculé seulement quand le bonus change)
			g.vigBonus, g.rv = bonus, Guard.boosted(r, bonus)
		end
		local rv = g.rv
		g.cd -= dt
		g.st = g.st or { state = "patrol", timer = 0, lost = 0 }
		g.look = g.look or Vector3.new(g.dir, 0, 0)
		-- perception de la cible (poursuivie ou la plus proche)
		local target = g.target
		local ts = target and sessions[target]
		if not (ts and alive(target) and getRoot(target) and Config.zoneUnlocked(ts.data.story.ch, g.rival)) then
			target, ts = nil, nil
		end
		if not target and (g.st.state == "patrol" or g.st.state == "alert" or g.st.state == "return") then
			g.scan = (g.scan or 0) - dt
			if g.scan <= 0 then
				g.scan = 0.15
				target = candidate(g, rv)
				ts = target and sessions[target]
			else
				target, ts = nil, nil
			end
		end
		local percept = { sees = false, hears = false, dist = math.huge, atHome = false }
		local troot = target and getRoot(target)
		if troot then
			local v = troot.AssemblyLinearVelocity
			local speed = math.sqrt(v.X * v.X + v.Z * v.Z)
			percept = Guard.perceive(
				{ x = g.pos.X, z = g.pos.Z, fx = g.look.X, fz = g.look.Z },
				{ x = troot.Position.X, z = troot.Position.Z, speed = speed },
				rv, GC
			)
			if percept.sees or percept.hears then
				g.last = Vector3.new(troot.Position.X, g.pos.Y, troot.Position.Z)
			end
		end
		local home = Vector3.new(math.clamp(g.pos.X, g.cx - g.patrolHalf, g.cx + g.patrolHalf), g.pos.Y, g.patrolZ)
		percept.atHome = (home - g.pos).Magnitude < 1
		local prev = g.st.state
		local ev
		g.st, ev = Guard.nextState(g.st, dt, percept, gcFor(g.rival))
		local state = g.st.state
		if state ~= prev then
			if state == "alert" or state == "chase" then -- aboiement ou grognement pour les joueurs proches (une fois par changement d'état)
				local key = Config.guardSoundKey(Config.Assets.guardKinds[g.rival])
				for pl in pairs(sessions) do
					local pr = getRoot(pl)
					if pr and (pr.Position - g.pos).Magnitude < 60 then
						notify(pl, "", key)
					end
				end
			end
			local mark = g.mark
			if mark then
				mark.Text = MARKS[state] or ""
			end
			if state == "chase" or state == "patrol" or state == "return" then
				g.target = (state == "chase") and target or nil
			end
			if state ~= "chase" then
				g.charge = nil -- l'alarme du nid s'arrête avec la poursuite
			end
			if state == "chase" then
				g.target = target or g.target
			elseif state == "return" or state == "patrol" then
				g.target = nil
				g.wps = nil
			end
		end
		local look = nil
		local prevPos = g.pos
		local want = false -- le gardien DEVRAIT-il avancer ? (sert à la détection de blocage)
		if state == "patrol" then
			want = true
			g.pos += Vector3.new(g.dir * r.patrolSpeed * dt, 0, 0)
			if g.pos.X > g.cx + g.patrolHalf then
				g.dir = -1
			elseif g.pos.X < g.cx - g.patrolHalf then
				g.dir = 1
			end
			look = Vector3.new(g.dir, 0, 0)
		elseif state == "alert" then
			local to = g.last and (g.last - g.pos) or g.look -- s'arrête et se tourne vers le bruit ou la dernière position vue
			look = Vector3.new(to.X, 0, to.Z)
		elseif state == "chase" or state == "lostChase" then
			local goal = (state == "chase" and troot) and Vector3.new(troot.Position.X, g.pos.Y, troot.Position.Z) or g.last
			if goal then
				local aim = aimPoint(g, goal, dt)
				local dv = Vector3.new(aim.X - g.pos.X, 0, aim.Z - g.pos.Z)
				want = (goal - g.pos).Magnitude > GC.attackRange
				if dv.Magnitude > 0.01 then
					look = dv.Unit
					g.pos += look * math.min(dv.Magnitude, r.guardSpeed * dt)
				end
				local flat = Vector3.new(goal.X - g.pos.X, 0, goal.Z - g.pos.Z)
				if state == "chase" and ts and flat.Magnitude < GC.attackRange and g.cd <= 0 and troot ~= nil and not safeSpot(ts, troot, g) then -- jamais de coup dans la zone sûre (A.5, comme la simulation)
					if hitPlayer(ts, g) then
						g.cd = GC.attackCd
					end
				end
			end
		else -- retour
			local dv = home - g.pos
			want = dv.Magnitude >= 1
			if dv.Magnitude >= 1 then
				look = dv.Unit
				g.pos += look * math.min(dv.Magnitude, r.patrolSpeed * 1.6 * dt)
			end
		end
		-- le gardien reste dans le disque de SON territoire (Config.TERR), même en poursuite
		do
			local nx, nz = Guard.clampToDisc(g.pos.X, g.pos.Z, g.tx, g.tz, g.clampR)
			g.pos = Vector3.new(nx, g.pos.Y, nz)
		end
		-- blocage : devrait bouger mais n'avance pas depuis plus de 4 s -> retour doux à son poste, état remis à zéro
		g.stuck = g.stuck or { t = 0 }
		local moved = (g.pos - prevPos).Magnitude
		if Guard.stuckStep(g.stuck, dt, moved, want, GC) then
			g.pos = Vector3.new(g.cx, g.pos.Y, g.patrolZ)
			g.wps, g.target, g.last = nil, nil, nil
			g.st = { state = "patrol", timer = 0, lost = 0 }
			g.stuckFixes = (g.stuckFixes or 0) + 1
			pcall(function()
				g.model:SetAttribute("StuckFixes", g.stuckFixes)
			end)
			look = Vector3.new(g.dir, 0, 0)
		end
		if look and look.Magnitude > 0.01 then
			g.look = look.Unit
		end
		-- orientation vers la marche + animation procédurale (rebond et roulis en marchant, respiration à l'arrêt)
		g.speedNow = (g.speedNow or 0) * 0.8 + (moved / math.max(dt, 1e-3)) * 0.2
		local by, roll = Guard.walkPose(os.clock(), g.speedNow)
		g.model:PivotTo(CFrame.lookAt(g.pos + Vector3.new(0, by, 0), g.pos + Vector3.new(0, by, 0) + g.look) * CFrame.Angles(0, 0, roll))
	end
end

---------------------------------------------------------------- Pièges des territoires (lot 4) : fils à clochettes, boue, herse, dalles d'alarme, lanternes
-- Traps (pur) décide, ce code applique : alarme = les gardiens du territoire foncent vers l'endroit (état « perte de cible » = ils vont à la dernière
-- position connue puis reprennent leur poste, et repèrent le joueur s'il y est toujours) ; boue = vitesse x0,6 (applySpeed) ; herse = Part animée à 10 Hz.
local trapsWorld = world.traps or { layouts = {}, lights = {}, plates = {} }
local ALARM_TEXT = { bell = "🔔 Un fil à clochettes a sonné : les gardiens accourent !", plate = "🚨 Dalle d'alarme : les gardiens accourent !", light = "🔦 Une lanterne t'a repéré : les gardiens accourent !" }

local function alarmGuards(terr, x, z)
	for _, g in ipairs(world.guards) do
		if g.terr == terr and g.st and g.st.state ~= "chase" then
			g.st = { state = "lostChase", timer = 0, lost = 0 }
			g.last = Vector3.new(x, g.pos.Y, z)
			g.target, g.wps = nil, nil
			if g.mark then
				g.mark.Text = "❗"
			end
		end
	end
end

local function trapsStep(_dt)
	local now = os.clock()
	for player, s in pairs(sessions) do
		local root = getRoot(player)
		if root and alive(player) then
			local px, pz = root.Position.X, root.Position.Z
			for key, L in pairs(trapsWorld.layouts) do
				local ps = s.traps[key]
				if (px - L.cx) ^ 2 + (pz - L.cz) ^ 2 <= (L.r + 8) ^ 2 then
					if not ps then
						ps = Traps.newPlayerState()
						s.traps[key] = ps
					end
					for _, ev in ipairs(Traps.playerStep(ps, L, Config.TRAPS, now, px, pz)) do
						if ev.kind == "mud" then
							applySpeed(s)
							notify(player, "🟤 De la boue ! Tu es ralenti.")
						else
							alarmGuards(key, px, pz)
							notify(player, ALARM_TEXT[ev.kind] or "🔔", "caught")
							if ev.kind == "plate" then
								for _, pl in ipairs(trapsWorld.plates) do
									if pl.key == key and pl.index == ev.index then
										pl.part.Color = Color3.fromRGB(255, 220, 90)
										task.delay(0.8, function()
											pl.part.Color = Color3.fromRGB(150, 60, 60)
										end)
									end
								end
							end
						end
					end
				elseif ps then
					s.traps[key] = nil
					applySpeed(s)
				end
			end
		end
	end
	for _, ln in ipairs(trapsWorld.lights) do -- lanternes : le faisceau tourne (0,5 tour/s)
		local l = ln.light
		local a = Traps.lanternAngle(now, l)
		local dx, dz = math.cos(a), math.sin(a)
		local mid = Vector3.new(l.x + dx * l.range / 2, ln.y, l.z + dz * l.range / 2)
		ln.part.CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
	end
	local gt = trapsWorld.gate
	local gl = trapsWorld.layouts.zed
	if gt and gl and gl.gate then -- herse de la cour de Zed : cycle 3 s ouverte / 3 s fermée, solide quand elle est descendue
		local lift = Traps.gateLift(now, gl.gate, Config.TRAPS.gateWindow)
		if lift ~= gt.lift then
			gt.lift = lift
			gt.part.CFrame = gt.baseCF + Vector3.new(0, -5.5 + 8.5 * lift, 0)
		end
		local solid = Traps.gateSolid(now, gl.gate, Config.TRAPS.gateWindow)
		if gt.solid ~= solid then
			gt.solid = solid
			gt.part.CanCollide = solid
		end
	end
end

---------------------------------------------------------------- Mode Château : salles à pièges, chrono, coffre final, classement des temps
local serverMode = "arena" -- « castle » si le premier joueur arrive du hub avec TeleportData.mode == "castle"
local castleWorld = world.castle

local function castleTeleport(s, room, depth)
	local root = getRoot(s.player)
	if root then
		local wx, wz = Castle.toWorld(room, 0, depth or 3)
		root.CFrame = CFrame.new(wx, 4, wz)
		root.AssemblyLinearVelocity = Vector3.zero
		s.noCheckUntil = os.clock() + 2
	end
end

function castleEnter(s)
	s.castle = { deaths = 0, maxRoom = 1, t0 = nil, finished = false }
	castleTeleport(s, 1, -4)
	notify(s.player, "🏰 Le Château : traverse 5 salles à pièges (pics, lames, boulets, portes). Le chrono démarre à la première salle. Coffre final : œuf rare !", "event")
end

-- Donne un œuf dans un emplacement libre (protégé quelques secondes) ; base pleine : l'équivalent de la moitié du prix en pièces. Retourne true si l'œuf est placé.
local function giveEgg(s, tier)
	local d = s.data
	local i = freeSlot(s)
	if not i then
		d.coins += Config.eggCoinValue(tier) * 0.5
		return false
	end
	d.slots[i] = { k = "e", t = tier, ends = os.time() + hatchTime(s, tier), shield = os.time() + shieldTime(s) }
	refreshPad(s, i)
	return true
end

local function castleDamage(s, kind, room)
	local dmg = Config.CASTLE.damage[kind] or 20
	local hp, hit, inv = Guard.applyDamage(s.hp, dmg, s.iframes, GC)
	if not hit then
		return
	end
	s.iframes, s.sinceHit = inv, 0
	setHp(s, hp)
	local label = kind == "spikes" and "des pics" or (kind == "blade" and "une lame" or (kind == "knight" and "un chevalier" or "un boulet"))
	notify(s.player, "💥 Touché par " .. label .. " : -" .. dmg .. " ❤️ (" .. math.floor(hp + 0.5) .. "/" .. GC.maxHp .. ")", "hurt")
	if hp <= 0 then -- défaite : retour au début de la salle, pv rétablis (jamais de perte d'œuf)
		local rootNow = getRoot(s.player)
		if rootNow and Config.purchasable(Config.PRODUCTS.Revive) then -- offre « Relancer maintenant » (produit payant, non bloquante)
			s.revive = { pos = rootNow.Position, room = room, expires = os.clock() + Config.REVIVE.offerSeconds }
			s.player:SetAttribute("ReviveUntil", os.time() + Config.REVIVE.offerSeconds)
		end
		s.castle.deaths += 1
		setHp(s, GC.maxHp)
		s.iframes = GC.respawnIframes
		castleTeleport(s, room, 3)
		notify(s.player, "🏰 Tu retentes la salle " .. room .. " (" .. s.castle.deaths .. " défaite(s)).", "caught")
	end
end

local castleBoardTimer = 0
local function castleBoardRefresh()
	task.spawn(function()
		local top = Data.castleTop(Config.CASTLE.boardSize)
		if castleWorld and castleWorld.board then
			local lines = { "🏰 Meilleurs temps" }
			for i, e in ipairs(top) do
				lines[#lines + 1] = i .. ". " .. e.name .. "  " .. Castle.formatTime(e.time)
			end
			if #top == 0 then
				lines[#lines + 1] = "(aucun pour l'instant)"
			end
			castleWorld.board.Text = table.concat(lines, "\n")
		end
	end)
end

local function castleStep(dt)
	Builder.animProps(os.clock())
	if not castleWorld then
		return
	end
	local T = os.clock()
	-- animation des pièges (positions répliquées 10 fois par seconde)
	for r, rec in ipairs(castleWorld.rooms) do
		local room = Castle.room(r)
		for i, sp in ipairs(Castle.spikes(room)) do
			local v = rec.spikes[i]
			local state = Castle.spikeState(T, sp, room)
			if state == "warning" and v.lastState ~= "warning" then
				rec.newWarn = true
			end
			v.lastState = state
			local tipY = state == "danger" and 0.9 or (state == "warning" and 0.05 or -1)
			v.tip.Position = Vector3.new(v.wx, tipY, v.wz)
			Builder.animSpike(v, tipY, state)
			v.tip.Color = state == "danger" and Color3.fromRGB(255, 90, 90) or (state == "warning" and Color3.fromRGB(255, 214, 90) or Color3.fromRGB(210, 214, 222))
		end
		for i, bl in ipairs(Castle.blades(room)) do
			local v = rec.blades[i]
			local angle = Castle.bladeAngle(T, bl, room)
			v.arm.CFrame = CFrame.new(v.wx, 1.4, v.wz) * CFrame.Angles(0, angle, 0)
			Builder.animBlade(v, angle)
		end
		for i, ba in ipairs(Castle.balls(room)) do
			local v = rec.balls[i]
			local bx = Castle.ballX(T, ba, room)
			local bp = bx and Vector3.new(Castle.ORIGIN.x + bx, ba.radius, v.wz) or Vector3.new(Castle.ORIGIN.x, -10, v.wz)
			v.part.Position = bp
			Builder.animBall(v, bp.X, bp.Y, bp.Z)
		end
		if rec.newWarn then -- pics qui sortent : un son par salle (au plus toutes les 0,8 s) pour les joueurs de la salle
			rec.newWarn = false
			if T - (rec.lastSpikeSfx or -9) > 0.8 then
				rec.lastSpikeSfx = T
				for pl, ps in pairs(sessions) do
					local pr = ps.castle and getRoot(pl)
					if pr and Castle.roomAt(pr.Position.X, pr.Position.Z) == r then
						notify(pl, "", "spikes")
					end
				end
			end
		end
		for i, kn in ipairs(Castle.knights(room)) do
			local v = rec.knights[i]
			local kx, dir = Castle.knightPos(T, kn)
			v.part.Position = Vector3.new(Castle.ORIGIN.x + kx, 3, v.wz)
			Builder.animKnight(v, Castle.ORIGIN.x + kx, v.wz, dir, 4 * kn.amp / kn.period)
		end
		local open = Castle.doorIsOpen(T, room)
		rec.door.Position = Vector3.new(rec.doorX, open and 14 or rec.doorClosedY, rec.doorZ)
		rec.door.CanCollide = not open
		Builder.animDoor(rec, open)
	end
	-- joueurs dans le donjon : chrono, touches
	for player, s in pairs(sessions) do
		local root = getRoot(player)
		if s.castle and root and alive(player) and not s.castle.finished then
			local r, lx, lz = Castle.roomAt(root.Position.X, root.Position.Z)
			if r then
				s.castle.maxRoom = math.max(s.castle.maxRoom, r)
				if r == 1 and lz > 2 and not s.castle.t0 then
					s.castle.t0 = T
					notify(player, "⏱ Chrono lancé !")
				end
				local kind = Castle.hit(T, Castle.room(r), lx, lz)
				if kind then
					castleDamage(s, kind, r)
				end
			end
		end
	end
	castleBoardTimer += dt
	if castleBoardTimer >= Config.CASTLE.boardSeconds then
		castleBoardTimer = 0
		castleBoardRefresh()
	end
end
task.defer(castleBoardRefresh)

function castleFinish(s, root, prompt)
	local c = s.castle
	local holder = prompt.Parent
	if not (c and c.t0 and not c.finished and holder and (root.Position - holder.Position).Magnitude <= 18) then
		return
	end
	if c.maxRoom < Castle.ROOMS then
		return notify(s.player, "Il faut traverser les " .. Castle.ROOMS .. " salles avant d'ouvrir le coffre.")
	end
	c.finished = true
	notify(s.player, "", "fanfare")
	Builder.openChest()
	local seconds = os.clock() - c.t0
	local reward = Castle.reward(seconds, income(s), c.deaths)
	s.data.coins += reward.coins
	local placed = giveEgg(s, reward.eggTier)
	qp(s, "castle", 1)
	Lot7.L16.addXp(s, "pve") -- lot 16 : victoire au Château = victoire PvE
	Data.castleSubmit(s.player, seconds)
	notify(s.player, "🏆 Château terminé en " .. Castle.formatTime(seconds) .. " (" .. c.deaths .. " défaite(s)) : +" .. Config.fmt(reward.coins) .. " 🪙 et un œuf " .. Config.TIERS[reward.eggTier].name .. (placed and " dans ta base !" or " (base pleine : converti en pièces)."), "claim")
	sync(s)
	task.delay(4, function()
		if s.player.Parent and sessions[s.player] == s then
			s.castle = nil
			local root2 = getRoot(s.player)
			if root2 and s.plot then
				root2.CFrame = s.plot.spawn.CFrame + Vector3.new(0, 4, 0)
			end
			castleBoardRefresh()
		end
	end)
end

---------------------------------------------------------------- Événements serveur
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "EventTint"
tint.Parent = Lighting
local evTimer = rng:NextNumber(25, 40)

local function setEvent(cfg, seconds)
	if cfg then
		currentEvent = { cfg = cfg, ends = os.time() + (type(seconds) == "number" and seconds or Config.EVENT_DURATION) } -- seconds : événement offert plus long (énigme, lot 6)
		workspace:SetAttribute("EventKey", cfg.key)
		workspace:SetAttribute("EventEnds", currentEvent.ends)
		tint.TintColor = cfg.tint
		for _, p in ipairs(Players:GetPlayers()) do
			notify(p, cfg.emoji .. " " .. cfg.name .. " ! " .. cfg.desc, "event")
		end
	else
		currentEvent = nil
		workspace:SetAttribute("EventKey", nil)
		workspace:SetAttribute("EventEnds", nil)
		tint.TintColor = Color3.new(1, 1, 1)
	end
	for _, s in pairs(sessions) do
		sync(s)
	end
end

local function eventStep(dt)
	if currentEvent then
		if os.time() >= currentEvent.ends then
			setEvent(nil)
			evTimer = rng:NextNumber(Config.EVENT_GAP[1], Config.EVENT_GAP[2])
		end
	else
		evTimer -= dt
		if evTimer <= 0 then
			setEvent(Config.EVENTS[rng:NextInteger(1, #Config.EVENTS)])
		end
	end
end

-- Énigme de la Mère Poule (lot 6) : construite ici car elle déclenche l'événement « Pluie de chance » (setEvent) ; le gestionnaire de prompts la lit via `Hen`.
Hen = HenQuest.new({
	Config = Config, Riddle = Riddle, Builder = Builder, world = world, sessions = sessions, RHen = RHen,
	notify = notify, sync = sync, getRoot = getRoot, freeSlot = freeSlot, hatchTime = hatchTime, shieldTime = shieldTime, refreshPad = refreshPad,
	income = income, story = sp, setEvent = setEvent,
	onSolved = function(s)
		tele.log(s.player, "puzzle_solved")
		L15.weekly(s, "riddle", 1) -- lot 15 : quête de la semaine « énigmes »
	end,
})

---------------------------------------------------------------- Boucles de jeu
local function fastTick(dt)
	for player, s in pairs(sessions) do
		local ok, err = pcall(function()
			local d = s.data
			local root = getRoot(player)
			local hum = getHum(player)
			if s.stun > 0 then
				s.stun -= dt
				if s.stun <= 0 and hum then
					hum.PlatformStand = false
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end
			if not (root and hum and hum.Health > 0) then
				return
			end
			-- piste d'entraînement (ancien tapis roulant) : il faut courir dessus
			if s.stun <= 0 and world.treadmillContains(root.Position) and hum.MoveDirection.Magnitude > 0.1 then
				local rate = 0.8 * (1 + 0.35 * d.up.tm) * (evKey() == "run" and 3 or 1)
				d.speed += rate * dt
				qp(s, "train", dt)
				sp(s, "train", dt)
			end
			applySpeed(s)
			-- contrôle de vitesse : si le joueur parcourt bien plus que sa vitesse autorisée, on le remet en place
			local pos = root.Position
			if s.lastPos and s.stun <= 0 and os.clock() > s.noCheckUntil then
				local moved = Vector3.new(pos.X - s.lastPos.X, 0, pos.Z - s.lastPos.Z).Magnitude
				local allowed = (Config.walkSpeed(d.speed) * speedMul(s) + 16) * dt * 1.4 + 3
				if moved > allowed then
					s.flags += 1
					if s.flags >= 3 then
						root.CFrame = CFrame.new(s.lastPos) * root.CFrame.Rotation
						s.flags = 0
						warn("[AntiCheat] " .. player.Name .. " remis en place (vitesse anormale)")
						pos = s.lastPos
					end
				else
					s.flags = 0
				end
			end
			if s.lastPos and (pos - s.lastPos).Magnitude > 0.3 then
				s.lastActive = os.clock() -- déplacement = joueur actif
			end
			s.lastPos = pos
			-- intrusion : un autre joueur entre dans la base d'un hôte (alarme au niveau 3, chien de garde au niveau 5)
			do
				local host = nil
				for _, o in pairs(sessions) do
					if o ~= s and o.plot then
						local rel = o.plot.cf:PointToObjectSpace(pos)
						if Config.inBase(o.baseLevel or 1, rel.X, rel.Z, rel.Y) then
							host = o
							break
						end
					end
				end
				if host ~= s.intruderIn then
					s.intruderIn = host
					if host then
						onIntrusion(host, s)
					end
				end
			end
			-- dépôt des œufs dans sa base
			if #s.carry > 0 and inPlot(s, root) then
				local i = freeSlot(s)
				if not i then
					if os.clock() - s.lastFull > 4 then
						s.lastFull = os.clock()
						notify(player, "Base pleine ! Vends un pet ou agrandis-la.")
					end
				else
					local e = table.remove(s.carry, 1)
					d.slots[i] = { k = "e", t = e.t, ends = os.time() + e.rem, shield = os.time() + shieldTime(s), rv = (e.rv == true or (e.belt == true and e.paid == 0)) or nil, rvAt = e.rvAt } -- lot 7b : un œuf gratuit (bienvenue) ou volé par corbeau reste non indemnisable
					refreshPad(s, i)
					Builder.burst(s.plot.pads[i].part.Position + Vector3.new(0, 2, 0), Config.TIERS[e.t].color, 12, false)
					rebuildCarry(s)
					applySpeed(s)
					sync(s)
				end
			end
			-- fraîcheur : un œuf Légendaire+ pris chez Zed refroidit s'il n'atteint pas la base à temps -> il regagne son nid
			if #s.carry > 0 then
				local nowc, cooled, soonest = os.clock(), false, 0
				for i = #s.carry, 1, -1 do
					local e = s.carry[i]
					if Traps.expired(e, nowc) then
						table.remove(s.carry, i)
						returnEgg(e)
						cooled = true
					elseif e.fresh then
						soonest = (soonest == 0) and (e.fresh - nowc) or math.min(soonest, e.fresh - nowc)
					end
				end
				if cooled then
					notify(player, "🧊 L'œuf a refroidi et regagne son nid")
					rebuildCarry(s)
					applySpeed(s)
					sync(s)
				end
				player:SetAttribute("FreshLeft", math.ceil(soonest))
			elseif player:GetAttribute("FreshLeft") ~= 0 then
				player:SetAttribute("FreshLeft", 0)
			end
			-- porte de base : fin de la fermeture
			if s.doorPart and os.clock() >= (s.lockUntil or 0) then
				setDoorBarrier(s, false)
			end
		end)
		if not ok then
			warn("[fastTick] " .. tostring(err))
		end
	end
end

local function petLabel(s, sl)
	local def = Config.PETS[sl.p]
	return string.format("%s %s\n+%s/s", def.emoji, Config.petName(sl.p, sl.s, sl.m), Config.fmt(Config.petIncome(sl.p, sl.s, sl.m) * gmult(s)))
end

local function slowTick(dt)
	eventStep(dt)
	tele.ccu(Players:GetPlayers(), serverMode) -- lot 14 : fréquentation du serveur, 1 échantillon / 60 s au plus (Telemetry.ccu)
	tele.step()
	for _, n in ipairs(world.nests) do
		if not n.egg then
			n.rt -= dt
			if n.rt <= 0 then
				setNestEgg(n, wpick(Config.foldWeights(n.weights or Config.RIVALS[n.rival].weights)))
			end
		end
	end
	local now = os.time()
	for player, s in pairs(sessions) do
		local ok, err = pcall(function()
			local d = s.data
			d.played += dt -- temps de jeu cumulé (secondes, sauvegardé) : protection débutant
			refreshNewbie(s)
			Lot7.Cal.tick(s)
			L15.tick(s, dt) -- lot 15 : jour UTC (compteurs PNJ, semaine, plumes), rencontres de PNJ toutes les 5 s, offres expirées
			local inc = income(s)
			local active = os.clock() - s.lastActive <= Config.IDLE.seconds
			if (player:GetAttribute("Idle") == true) == active then
				player:SetAttribute("Idle", not active) -- le client affiche « 💤 revenus en pause »
			end
			if active then
				d.coins += inc * dt
				qp(s, "earn", inc * dt)
			end
			Lot7.privStep(s, dt, active) -- tapis privé : un œuf gratuit toutes les 120 s d'activité
			ensureQuests(s)
			storyRefresh(s)
			s.syncT += dt
			if s.syncT >= 10 then
				s.syncT = 0
				RState:FireClient(player, snapshot(s))
			end
			for i = 1, cap(s) do
				local sl = d.slots[i]
				if sl and sl.k == "e" then
					if now >= sl.ends then
						hatch(s, i)
					else
						local lbl = s.labels[i]
						if lbl then
							local txt = "🥚 " .. Config.fmtTime(sl.ends - now) .. ((sl.shield or 0) > now and "  🛡" or "")
							if lbl.Text ~= txt then
								lbl.Text = txt
							end
						end
					end
				elseif sl and sl.k == "p" then
					local lbl = s.labels[i]
					if lbl then
						local txt = petLabel(s, sl)
						if lbl.Text ~= txt then
							lbl.Text = txt
						end
					end
				end
			end
			-- régénération des pv (rapide dans la base, lente ailleurs après un délai sans coup)
			if s.hp < GC.maxHp then
				local root = getRoot(player)
				local atBase = root ~= nil and s.plot ~= nil and (root.Position - s.plot.spawn.Position).Magnitude < 40
				local newHp = Guard.regen(s.hp, s.sinceHit, dt, atBase, GC)
				if newHp ~= s.hp then
					setHp(s, newHp)
				end
			end
			pushStats(s)
		end)
		if not ok then
			warn("[slowTick] " .. tostring(err))
		end
	end
end

local acc1, acc2, acc3, acc4 = 0, 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	guardsStep(dt)
	acc4 += dt
	if acc4 >= 0.1 then
		local d4 = acc4
		acc4 = 0
		local okT, errT = pcall(trapsStep, d4)
		if not okT then
			warn("[traps] " .. tostring(errT))
		end
	end
	acc3 += dt
	if acc3 >= Config.CASTLE.step then
		local d3 = acc3
		acc3 = 0
		castleStep(d3)
	end
	acc2 += dt
	if acc2 >= 0.25 then
		local d2 = acc2
		acc2 = 0
		fastTick(d2)
	end
	acc1 += dt
	if acc1 >= 1 then
		local d1 = acc1
		acc1 = 0
		slowTick(d1)
	end
end)

---------------------------------------------------------------- Tapis roulant central (lot 3 de la refonte)
-- Le serveur fait tout : Belt.step à 10 Hz (apparitions et sorties), un œuf visible par œuf du tapis (rareté et prix lisibles AVANT l'achat), un prompt
-- par œuf, achat par réservation atomique (Belt.tryBuy) après validation de la distance, des pièces et du sac. L'œuf acheté passe dans les bras du joueur
-- (s.carry, comme un œuf chipé) et doit être rapporté à la base. Tout œuf visuel est détruit à sa sortie (bac) ou à son achat : aucun objet ne fuit.
local BC = Config.BELT
local beltSt = Belt.new(rng:NextInteger(1, 2147483000), os.clock() + 2)
local beltFolder = Instance.new("Folder")
beltFolder.Name = "BeltEggs"
beltFolder.Parent = workspace
local beltEggs = {} -- [id] = { egg = œuf logique (Belt), part, prompt }
K8.beltPanelAt, K8.beltPanelKey = 0, "" -- panneau du tapis (lot 8B : dans K8, limite de 200 variables locales)
local BELT_Y = 3.0 -- hauteur du centre d'un œuf posé sur le tapis
local BELT_REACH = 14 -- distance serveur maximale joueur -> œuf (le prompt s'active à 10 ; marge pour la latence et le défilement)

local function beltRemoveVisual(id)
	local v = beltEggs[id]
	if v then
		beltEggs[id] = nil
		if v.egg.forUser and not v.egg.claimedBy then
			local op = Players:GetPlayerByUserId(v.egg.forUser)
			local os_ = op and sessions[op]
			if os_ and os_.welcome == "offered" then
				os_.welcome = "gone" -- l'œuf de bienvenue est tombé dans le bac sans être pris
				sync(os_)
			end
		end
		if v.part then
			v.part:Destroy() -- détruit aussi le prompt, l'étiquette, la lumière et le halo
		end
	end
end

local function beltAnnounce(tier)
	local t = Config.TIERS[tier]
	for _, p in ipairs(Players:GetPlayers()) do
		notify(p, "✨ Un œuf " .. t.name .. " arrive sur le tapis du marché !", Config.hatchSoundKey(tier, false))
	end
end

local function beltAddVisual(egg, ownerName)
	local t = Config.TIERS[egg.tier]
	local part = Builder.egg(egg.tier, true)
	local x = Belt.positionX(Config, egg, os.clock()) or Config.Map2.belt.x0
	part.CFrame = CFrame.new(x, BELT_Y, Config.Map2.belt.z)
	part:SetAttribute("EggId", egg.id)
	part:SetAttribute("Tier", egg.tier)
	part:SetAttribute("Price", egg.price)
	if egg.forUser then
		part:SetAttribute("ForUser", egg.forUser)
	end
	CollectionService:AddTag(part, "EggShake")
	local rare = Config.tierAtLeast(egg.tier, "announce")
	if rare then
		CollectionService:AddTag(part, "BeltRare") -- annonce visuelle côté client
	end
	local pr = Instance.new("ProximityPrompt")
	if egg.forUser then
		pr.ActionText = "Prendre (gratuit)"
		pr.ObjectText = "Œuf de bienvenue"
	else
		pr.ActionText = "Acheter 🪙 " .. Config.fmt(egg.price)
		pr.ObjectText = "Œuf " .. t.name
	end
	pr.HoldDuration = 0.3
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Enabled = not rare -- Légendaire et plus : le prompt s'active après Config.BELT.legendaryDelay (voir beltStep)
	pr:SetAttribute("EggId", egg.id)
	if egg.forUser then
		pr:SetAttribute("ForUser", egg.forUser)
	end
	pr.Parent = part
	CollectionService:AddTag(pr, "BeltEgg")
	local label
	if egg.forUser then
		label = "🎁 Œuf de bienvenue de " .. tostring(ownerName or "?") .. "\nGratuit"
	else
		label = t.name .. "\n🪙 " .. Config.fmt(egg.price)
	end
	Builder.sign(part, label, t.color, 3, 200)
	part.Parent = beltFolder
	beltEggs[egg.id] = { egg = egg, part = part, prompt = pr }
	if rare then
		beltAnnounce(egg.tier)
	end
end

local function beltPanelUpdate(now)
	local b = world.belt
	if not b then
		return
	end
	local info = Belt.panel(Config, beltSt, now)
	local key = info.active .. "|" .. info.status
	if key == K8.beltPanelKey then
		return
	end
	K8.beltPanelKey = key
	local mark = "▶ "
	b.panel.normal.Text = (info.active == "normal" and mark or "") .. "Standard : " .. info.normal
	b.panel.golden.Text = (info.active == "golden" and mark or "") .. "Doré : " .. info.golden
	b.panel.normal.TextColor3 = info.active == "normal" and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(190, 190, 205)
	b.panel.golden.TextColor3 = info.active == "golden" and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(190, 190, 205)
	b.panel.status.Text = info.status
end

local function beltStep()
	local now = os.clock()
	BC.interval = L15.Rewards.activeEvents(Config, os.time()).beltSeconds -- lot 15 : week-end chanceux (4 s au lieu de 5)
	local spawned, removed = Belt.step(Config, beltSt, now)
	for _, e in ipairs(removed) do
		beltRemoveVisual(e.id)
	end
	for _, e in ipairs(spawned) do
		local owner = e.forUser and Players:GetPlayerByUserId(e.forUser)
		beltAddVisual(e, owner and owner.DisplayName)
	end
	local alive_ = {}
	for _, e in ipairs(beltSt.eggs) do
		alive_[e.id] = true
	end
	local stale = {}
	for id in pairs(beltEggs) do
		if not alive_[id] then
			stale[#stale + 1] = id -- vendu, parti ou jamais revu dans la liste du tapis : plus aucun objet orphelin
		end
	end
	for _, id in ipairs(stale) do
		beltRemoveVisual(id)
	end
	for _, e in ipairs(beltSt.eggs) do
		local v = beltEggs[e.id]
		if v then
			local x = Belt.positionX(Config, e, now)
			if x then
				v.part.CFrame = CFrame.new(x, BELT_Y, Config.Map2.belt.z)
			end
			if not v.prompt.Enabled and now - e.born >= BC.legendaryDelay then
				v.prompt.Enabled = true
			end
		end
	end
	if now - K8.beltPanelAt >= 1 then
		K8.beltPanelAt = now
		beltPanelUpdate(now)
	end
end

task.spawn(function()
	while true do
		task.wait(0.1)
		local ok, err = pcall(beltStep)
		if not ok then
			warn("[belt] " .. tostring(err))
		end
	end
end)

-- Action serveur INTERNE : ajoute des secondes de tapis doré (cumulables, plafonnées). Le produit Robux la branchera plus tard (lot 7) ; aucun ProcessReceipt ici.
local function goldenBeltAdd(seconds, byName)
	local left = Belt.addGolden(Config, beltSt, os.clock(), seconds, byName)
	K8.beltPanelKey = ""
	return left
end
Builder.beltHooks = { goldenAdd = goldenBeltAdd, stats = function() -- crochet interne (tests, lot 7) : jamais exposé aux clients
	local n = 0
	for _ in pairs(beltEggs) do
		n += 1
	end
	return { eggs = #beltSt.eggs, visuals = n, children = #beltFolder:GetChildren(), sold = beltSt.sold, goldenLeft = Belt.goldenLeft(beltSt, os.clock()) }
end }

-- Œuf de bienvenue : une fois par joueur, 20 s après l'arrivée, si hatched < 5 ; gratuit, étiqueté à son nom, achetable par lui seul.
local function beltWelcome(player, s)
	for _ = 1, 8 do
		if not (player.Parent and sessions[player] == s) then
			return
		end
		local egg = Belt.welcome(Config, beltSt, player.UserId, s.data.hatched, os.clock())
		if egg then
			s.welcome = "offered"
			beltAddVisual(egg, player.DisplayName)
			notify(player, "🎁 Un œuf de bienvenue t'attend sur le tapis du marché : il est gratuit, et il est à toi !", "event")
			sync(s)
			return
		end
		if s.data.hatched >= BC.welcome.maxHatched or beltSt.welcomed[player.UserId] then
			s.welcome = "none"
			sync(s)
			return
		end
		task.wait(1.5) -- tapis plein : on réessaie
	end
	s.welcome = "none"
end

local BELT_MSG = {
	late = "Trop tard ! Quelqu'un a pris cet œuf.",
	gone = "Trop tard ! Cet œuf n'est plus sur le tapis.",
	cooldown = "Attends un peu avant d'acheter un autre œuf.",
	wait = "Attends un instant : cet œuf rare vient d'arriver.",
	reserved = "Cet œuf de bienvenue est réservé à un autre joueur.",
	legendaryLimit = "Un seul œuf Légendaire ou plus par minute et par joueur.",
}

function beltBuy(player, prompt)
	local s, root = sessions[player], getRoot(player)
	if not s or not root or not alive(player) or s.stun > 0 then
		return
	end
	local now = os.clock()
	if now - (s.lastBeltTry or -10) < 0.25 then
		return -- anti-rafale
	end
	s.lastBeltTry = now
	local id = prompt:GetAttribute("EggId")
	local v = type(id) == "number" and beltEggs[id] or nil
	if not v or prompt.Parent ~= v.part then
		notify(player, BELT_MSG.late, "refuse") -- l'œuf a déjà été pris (ou est tombé dans le bac) pendant que la demande voyageait
		return
	end
	if (root.Position - v.part.CFrame.Position).Magnitude > BELT_REACH then
		return
	end
	if #s.carry >= carryCap(s.data) then
		notify(player, "Sac plein ! Rapporte tes œufs à ta base.")
		return
	end
	local ok, res = Belt.tryBuy(Config, beltSt, player.UserId, id, s.data.coins, now)
	if not ok then
		if res == "poor" then
			notify(player, "Pas assez de pièces : il te faut " .. Config.fmt(v.egg.price) .. " 🪙.", "refuse")
		else
			notify(player, BELT_MSG[res] or "Achat impossible.", "refuse")
		end
		return
	end
	local egg = res
	s.data.coins -= egg.price
	beltRemoveVisual(egg.id)
	Builder.burst(v.part.CFrame.Position, Config.TIERS[egg.tier].color, 10, false)
	s.carry[#s.carry + 1] = { t = egg.tier, rem = hatchTime(s, egg.tier), belt = true, paid = egg.price }
	if egg.forUser then
		s.welcome = "taken"
	end
	afterTake(s, "🥚 Œuf " .. Config.TIERS[egg.tier].name .. (egg.price > 0 and (" acheté (-" .. Config.fmt(egg.price) .. " 🪙)") or " pris") .. " ! Porte-le vite dans ta base.", egg.price > 0 and "belt_buy" or "claim") -- lot 10 : son approuvé du tapis
end

---------------------------------------------------------------- Actions du client
local actions = {}

-- Retour au hub : la progression est sauvegardée d'abord ; si la téléportation échoue, le joueur reste en jeu avec un message clair.
function actions.toHub(s)
	local now = os.clock()
	if s.leaving or now - (s.toHubAt or -100) < 15 then
		return
	end
	if Config.Game.roleFor(game.PlaceId) ~= "game" then
		return notify(s.player, "Le hub n'est pas disponible depuis ce lieu.")
	end
	s.toHubAt = now
	if not s.noSave then
		Data.save(s.player, s.data)
	end
	local res = Party.returnToHub(Config, {
		teleport = function(players, placeId, _, data)
			local opts = Instance.new("TeleportOptions")
			opts:SetTeleportData(data)
			TeleportService:TeleportAsync(placeId, players, opts)
		end,
		log = warn,
	}, s.player, serverPartyId)
	if res.ok then
		notify(s.player, "🏠 Retour au hub…")
	else
		notify(s.player, "⚠️ " .. res.message)
	end
end

-- Porte de base : ferme la base pendant Config.lockSeconds(niveau) secondes (aucun vol d'emplacement), puis recharge Config.DOOR.cooldown secondes.
function actions.lockDoor(s)
	local now = os.clock()
	if (s.lockUntil or 0) > now then
		return
	end
	if (s.lockReadyAt or 0) > now then
		notify(s.player, "🔒 La porte se recharge : encore " .. math.ceil(s.lockReadyAt - now) .. " s.")
		return
	end
	local dur = Config.lockSeconds(s.baseLevel or 1)
	s.lockUntil = now + dur
	s.lockReadyAt = s.lockUntil + Config.DOOR.cooldown
	local okT, server = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	if not okT or type(server) ~= "number" then
		server = os.time()
	end
	s.player:SetAttribute("DoorUntil", server + dur)
	s.player:SetAttribute("DoorReady", server + dur + Config.DOOR.cooldown)
	setDoorBarrier(s, true)
	notify(s.player, "🔒 Porte fermée pendant " .. dur .. " s : personne ne peut voler tes œufs.")
end

-- Fin anticipée de la protection débutant (« Je suis prêt pour le PvP »).
function actions.newbieOff(s)
	if isNewbie(s) then
		s.data.newbieOff = true
		refreshNewbie(s)
		sync(s)
	end
end

function actions.sync(s)
	sync(s)
end

function actions.buyEgg(s, tier)
	if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > #Config.TIERS then
		return
	end
	if not Config.tierLive(tier) then -- lot 9 : rareté sans espèce publiée (Peu commun tant que le lot 11 n'est pas livré)
		return notify(s.player, "🥚 Les œufs " .. Config.TIERS[tier].name .. " arrivent bientôt !", "refuse")
	end
	if tier > Config.SHOP_MAX_TIER then -- lot 8A (B.3) : Mythique et Cosmique seulement au tapis du marché
		return notify(s.player, "🎪 Les œufs " .. Config.TIERS[tier].name .. " ne se trouvent qu'au tapis du marché !", "refuse")
	end
	local d = s.data
	local price = Config.EGG_PRICE[tier]
	if d.coins < price then
		return notify(s.player, "Pas assez de pièces !", "refuse")
	end
	local i = freeSlot(s)
	if not i then
		return notify(s.player, "Base pleine !")
	end
	d.coins -= price
	tele.economy(s.player, price, d.coins, "egg_r" .. tier) -- lot 9 : pièces dépensées en œufs
	d.slots[i] = { k = "e", t = tier, ends = os.time() + hatchTime(s, tier), shield = os.time() + shieldTime(s) }
	refreshPad(s, i)
	notify(s.player, "", "buy")
	sync(s)
end

function actions.buyUp(s, key)
	local u = type(key) == "string" and Config.upgrade(key)
	if not u then
		return
	end
	local d = s.data
	local l = d.up[key]
	if l >= u.max then
		return
	end
	local cost = u.cost(l)
	if d.coins < cost then
		return notify(s.player, "Pas assez de pièces !", "refuse")
	end
	d.coins -= cost
	notify(s.player, "", "buy")
	d.up[key] = l + 1
	if key == "slots" then
		refreshAllPads(s)
	end
	sync(s)
end

function actions.sell(s, i)
	if not validSlot(i) then
		return
	end
	local sl = s.data.slots[i]
	if not sl or sl.k ~= "p" then
		return
	end
	s.data.coins += Config.sellValue(sl.p, sl.s, sl.m)
	s.data.slots[i] = false
	qp(s, "sell", 1)
	refreshPad(s, i)
	rebuildFollowers(s)
	sync(s)
end

-- Revend un œuf d'un emplacement (25 % du prix). Validé côté serveur : emplacement existant, contient un œuf.
function actions.sellEgg(s, i)
	if not validSlot(i) then
		return
	end
	local sl = s.data.slots[i]
	if not sl or sl.k ~= "e" then
		return
	end
	s.data.coins += Config.eggSellValue(sl.t)
	s.data.slots[i] = false
	refreshPad(s, i)
	qp(s, "sell", 1)
	sync(s)
end

-- Revend les doublons de pets (garde le meilleur de chaque espèce). Les pets revendus quittent la liste de ceux qui suivent le joueur.
function actions.sellDupes(s)
	local d = s.data
	local list, total = Config.dupesToSell(d.slots, cap(s))
	if #list == 0 then
		return notify(s.player, "Aucun doublon à revendre.")
	end
	for _, i in ipairs(list) do
		d.slots[i] = false
		refreshPad(s, i)
		for n = #d.equip, 1, -1 do
			if d.equip[n] == i then
				table.remove(d.equip, n)
			end
		end
		qp(s, "sell", 1)
	end
	d.coins += total
	rebuildFollowers(s)
	notify(s.player, "⭐ " .. #list .. " doublon(s) échangé(s) : +" .. Config.fmt(total) .. " 🪙", "claim")
	sync(s)
end

-- Dialogue de la Mère Poule (lot 6) : boutons « J'y vais ! », « Explique encore », « 💡 Un coup de bec », « 🔁 Réécouter » (intentions seulement).
function actions.henGo(s)
	return Hen and Hen.go(s)
end
function actions.henExplain(s)
	return Hen and Hen.explain(s)
end
function actions.henHint(s)
	return Hen and Hen.hint(s)
end
function actions.henReplay(s)
	return Hen and Hen.replay(s)
end

function actions.rebirth(s)
	local d = s.data
	if d.coins < Config.rebirthCost(d.rb) then
		return notify(s.player, "Pas assez de pièces pour renaître.", "refuse")
	end
	-- Correctif : remise à zéro par LISTE BLANCHE (le profil n'est plus reconstruit). Repartent de zéro : pièces, améliorations, emplacements de la base (pets
	-- et œufs posés ; l'œuf de départ gratuit revient), suiveurs, gains hors ligne non récupérés, horodatage des revenus. TOUT le reste survit : achats uniques
	-- (once, starter), passe de combat (season), calendrier et séries (cal, calStreak, calLast, grace, streak), quêtes (jour, semaine, bonus), plumes d'événement,
	-- sac d'œufs et coffre de débordement, PNJ, réglages, combat / ligues / duels (battle), jetons, parchemins, plumes, titres, cosmétiques, pose, boosts
	-- payés ou gagnés, XP de dresseur, tickets d'arène, temps de jeu (protection débutant), reçus, succès, index, journal de vol, Corbeau, tapis privé.
	local fresh = Data.default()
	dropCarry(s)
	for _, k in ipairs({ "coins", "up", "slots", "equip", "pendingAway", "last" }) do
		d[k] = fresh[k]
	end
	d.rb = d.rb + 1
	refreshAllPads(s)
	rebuildFollowers(s)
	storyRefresh(s)
	sync(s)
	notify(s.player, string.format("🌅 Renaissance ! Revenus x%.1f", 1 + 0.5 * d.rb), "claim")
end

function actions.equip(s, i)
	if not validSlot(i) then
		return
	end
	local d = s.data
	local sl = d.slots[i]
	if not sl or sl.k ~= "p" then
		return
	end
	local at
	for n, v in ipairs(d.equip) do
		if v == i then
			at = n
		end
	end
	if at then
		table.remove(d.equip, at)
	else
		if #d.equip >= Lot7.L16.followerMax(s) then
			return notify(s.player, "Maximum " .. Lot7.L16.followerMax(s) .. " pets qui te suivent.")
		end
		d.equip[#d.equip + 1] = i
	end
	rebuildFollowers(s)
	sync(s)
end

function actions.claimQuest(s, i)
	local q = type(i) == "number" and s.data.quests[i]
	if not q or q.claimed or q.prog < q.goal then
		return
	end
	q.claimed = true
	Lot7.Calendar.addQuest(Config, s.data.cal) -- lot 9b : une mission réclamée compte pour le rattrapage « 3 missions » du calendrier
	L15.plume(s, "quest") -- lot 15 : plumes d'événement (plafond du jour)
	tele.log(s.player, "daily_quest_completed")
	Lot7.L16.addXp(s, "daily") -- lot 16 : XP du passe de combat (quête du jour réclamée)
	s.data.coins += q.rew
	local extra = ""
	if (q.re or 0) > 0 and Config.TIERS[q.re] then
		extra = extra .. (giveEgg(s, q.re) and (" + œuf " .. Config.TIERS[q.re].name) or " (base pleine : œuf converti en pièces)")
	end
	if (q.rb or 0) > 0 then
		s.data.luckUntil = math.max(os.time(), s.data.luckUntil) + q.rb
		extra = extra .. " + boost de chance"
	end
	notify(s.player, "🎯 Mission accomplie : +" .. Config.fmt(q.rew) .. " 🪙" .. extra, "claim")
	sync(s)
end

function actions.claimStory(s)
	local st = s.data.story
	local c = chapter(s)
	if not c or st.prog < c.goal then
		return
	end
	local rankBefore = Config.rankFor(st.ch).name
	local reward = Config.storyReward(c, income(s))
	s.data.coins += reward
	st.ch += 1
	st.prog = 0
	updateSign(s)
	notify(s.player, "📜 « " .. c.title .. " » accompli : +" .. Config.fmt(reward) .. " 🪙", "claim")
	local nextChapter = chapter(s)
	if nextChapter then
		notify(s.player, "📖 Chapitre " .. (st.ch + 1) .. " : " .. nextChapter.title .. " (Missions > Histoire)")
	else
		notify(s.player, "👑 Histoire terminée : tu es Roi des Couvées !", "event")
	end
	for _, z in ipairs(Config.ZONES) do
		if z.chapter > 0 and z.chapter == st.ch then
			notify(s.player, "🔓 " .. z.name .. " est ouvert ! Ses œufs sont plus rares.", "event")
		end
	end
	local rank = Config.rankFor(st.ch)
	if rank.name ~= rankBefore then
		notify(s.player, "🎖 Nouveau rang : " .. rank.emoji .. " " .. rank.name .. " !", "event")
	end
	storyRefresh(s) -- le chapitre suivant peut être déjà accompli (espèces déjà découvertes...)
	sync(s)
end

-- Mémorise qu'une cinématique a été vue (ou passée) : elle ne se rejouera pas à la prochaine connexion.
function actions.cineSeen(s, id)
	if type(id) ~= "string" then
		return
	end
	for _, known in ipairs(Config.CINE_IDS) do
		if known == id then
			if not s.data.cine[id] then
				s.data.cine[id] = true
				sync(s)
			end
			return
		end
	end
end

function actions.claimAch(s, id)
	local a = type(id) == "string" and Config.achievement(id)
	if not a then
		return
	end
	local d = s.data
	local tier = d.ach[a.id] or 0
	if tier >= #a.goals then
		return
	end
	local value = statValues(s)[a.stat]
	if not value or value < a.goals[tier + 1] then
		return
	end
	local reward = Config.achReward(tier + 1, income(s))
	d.ach[a.id] = tier + 1
	d.coins += reward
	notify(s.player, "🏅 Succès « " .. a.name .. " » (palier " .. (tier + 1) .. ") : +" .. Config.fmt(reward) .. " 🪙", "claim")
	sync(s)
end

local topCache = {}
function actions.top(s)
	RTop:FireClient(s.player, topCache)
end

function actions.claimAway(s)
	local gain = math.floor(s.data.pendingAway)
	if gain < 1 then
		return
	end
	s.data.pendingAway = 0
	s.data.coins += gain
	notify(s.player, "💰 Gains récupérés : +" .. Config.fmt(gain) .. " 🪙", "claim")
	RState:FireClient(s.player, snapshot(s))
end

-- Lot 15 : série de 7 jours (remplace l'ancien bonus quotidien). arg = nil (suite normale ou jour de grâce automatique), { how = "quest" } (sauvetage gratuit :
-- 3 missions du jour terminées) ou { how = "reset" } (repartir du jour 1). Le sauvetage payant (« product ») n'est JAMAIS accepté du client : seul le reçu
-- StreakRestore le déclenche (ProcessReceipt).
function actions.daily(s, arg)
	local how = type(arg) == "table" and arg.how or nil
	if how ~= "quest" and how ~= "reset" then
		how = nil
	end
	L15.streakClaim(s, how)
end

---------------------------------------------------------------- Lot 9b : calendrier des œufs sur 30 jours
-- Le serveur possède tout : jour UTC (os.time() // 86400), éligibilité, ressources de rattrapage, tirage du jour 30, œuf placé. Le client n'envoie que { day, how }.
-- Une réclamation : verrou s.calBusy (aucune seconde réclamation pendant la sauvegarde), validation (Calendar.check), jour MARQUÉ dans le profil, sauvegarde réussie,
-- ENFIN octroi. Sauvegarde échouée = jour démarqué, rien n'est donné. Mort du serveur entre la sauvegarde et l'octroi : récompense perdue (jamais doublée), limite documentée.
do
	local Calendar, CalSys, CAL = Lot7.Calendar, Lot7.Cal, Config.CALENDAR
	local function age(player)
		local ok, a = pcall(function()
			return player.AccountAge
		end)
		return (ok and type(a) == "number" and a == a) and a or 0
	end
	local function eligible(s)
		return Calendar.eligible(Config, age(s.player), s.data.played)
	end
	local function today()
		return os.time() // 86400
	end
	local refusal = {
		ineligible = "📅 Le calendrier n'est pas encore débloqué pour toi.", day = "📅 Jour invalide.", notStarted = "📅 Le calendrier n'a pas encore commencé.",
		future = "📅 Ce jour n'est pas encore arrivé : reviens à la date prévue !", claimed = "📅 Récompense déjà réclamée.", monthCap = "📅 Les 30 récompenses du cycle sont déjà réclamées.",
		dayCap = "📅 Reviens demain : une seule réclamation de rattrapage par jour.", how = "📅 Choisis comment rattraper ce jour.",
		noResource = "📅 Il te manque de quoi rattraper ce jour (jour de grâce, 3 missions ou un rattrapage).",
	}
	-- Vue du calendrier pour le client : normalise le cycle (renouvelé après 30 jours) ; ne démarre jamais un cycle (voir CalSys.tick).
	function CalSys.snapshot(s)
		local d = s.data
		Calendar.normalize(Config, d.cal, today())
		local ok, why = eligible(s)
		local v = Calendar.view(Config, d.cal, today(), ok, why)
		v.scrolls, v.plumes, v.ftokens = d.scrolls, d.plumes, d.fightTokens
		v.cosm, v.titles = d.cosm, { cal10 = d.titles.cal10 == true, cal25 = d.titles.cal25 == true, cal30 = d.titles.cal30 == true }
		v.playLeft = math.max(0, math.ceil(CAL.minPlayMinutes - d.played / 60))
		v.last = d.calLast
		return v
	end
	-- Une fois par seconde et par joueur (slowTick) : démarre le cycle d'un joueur devenu éligible, renouvelle un cycle fini, prévient d'une récompense disponible.
	function CalSys.tick(s)
		local d = s.data
		local day = today()
		local changed = false
		if d.cal.start == 0 then
			if eligible(s) and Calendar.begin(Config, d.cal, day) then
				changed = true
				notify(s.player, "📅 Calendrier des œufs débloqué ! Ouvre Bonus > Calendrier : un œuf Légendaire t'attend au jour 3.", "claim")
			end
		elseif Calendar.normalize(Config, d.cal, day) then
			changed = true
			notify(s.player, "📅 Nouveau cycle de 30 jours : la récompense du jour 1 t'attend.", "claim")
		end
		if changed or s.calSeenDay ~= day then
			s.calSeenDay = day
			sync(s)
		end
	end
	local function applyReward(s, plan)
		local d = s.data
		local bits = {}
		if plan.coins > 0 then
			d.coins += plan.coins
			bits[#bits + 1] = "🪙 " .. Config.fmt(plan.coins)
		end
		if plan.egg then
			-- lot 15 : base puis sac d'œufs (place vérifiée avant la sauvegarde). Si le joueur a tout rempli PENDANT la sauvegarde, repli de giveEgg (pièces) :
			-- la récompense n'est jamais perdue ni doublée.
			local where = L15.storeEggs(s, { plan.egg })
			if not where then
				giveEgg(s, plan.egg)
			end
			bits[#bits + 1] = "🥚 Œuf " .. Config.TIERS[plan.egg].name .. ((where and where[1] == "bag") and " (rangé dans ton sac d'œufs)" or (where and "" or " (base et sac pleins : converti en pièces)"))
		end
		if plan.scrolls > 0 then
			d.scrolls = math.min(CAL.caps.scrolls, d.scrolls + plan.scrolls)
			bits[#bits + 1] = "📜 +" .. plan.scrolls
		end
		if plan.plumes > 0 then
			d.plumes = math.min(CAL.caps.plumes, d.plumes + plan.plumes)
			bits[#bits + 1] = "🪶 +" .. plan.plumes
		end
		if plan.tokens > 0 then
			d.fightTokens = math.min(CAL.caps.tokens, d.fightTokens + plan.tokens)
			bits[#bits + 1] = "⚔️ +" .. plan.tokens
		end
		if plan.cosm and CAL.cosmetics[plan.cosm] then
			d.cosm[plan.cosm] = true
			bits[#bits + 1] = CAL.cosmetics[plan.cosm].emoji .. " " .. CAL.cosmetics[plan.cosm].name
		end
		if plan.title and CAL.titles[plan.title] then
			d.titles[plan.title] = true
			bits[#bits + 1] = "🏷 " .. CAL.titles[plan.title].name
		end
		return table.concat(bits, " · ")
	end
	function CalSys.claim(s, day, how)
		local d = s.data
		local cal = d.cal
		if s.leaving or s.calBusy ~= true then
			return
		end
		if how ~= "grace" and how ~= "quest" and how ~= "paid" then
			how = "today"
		end
		-- un rattrapage PAYANT d'un jour au tirage aléatoire (jour 30) : seulement si PolicyService a confirmé « non restreint » (rien n'est débité ici : le jeton est déjà acheté)
		if how == "paid" and type(day) == "number" and Calendar.isRandom(Config, day) and Lot7.awaitPolicy(s) then
			notify(s.player, "📅 Ce rattrapage n'est pas disponible pour ton compte.")
			return
		end
		if s.leaving or sessions[s.player] ~= s then
			return
		end
		local now = today()
		local okE, why = eligible(s)
		if okE and cal.start == 0 then
			Calendar.begin(Config, cal, now)
		end
		Calendar.normalize(Config, cal, now)
		local ok, code = Calendar.check(Config, cal, now, day, how, okE)
		if not ok then
			if code == "ineligible" then
				notify(s.player, why == "age" and ("📅 Il faut un compte Roblox d'au moins " .. CAL.minAccountAgeDays .. " jour pour le calendrier.") or ("📅 Encore " .. math.max(1, math.ceil(CAL.minPlayMinutes - d.played / 60)) .. " min de jeu avant de débloquer le calendrier."))
			else
				notify(s.player, refusal[code] or refusal.day)
			end
			sync(s)
			return
		end
		local plan = Calendar.plan(Config, day, rng:NextNumber(), income(s))
		if plan.egg and not L15.Rewards.canStore(Lot7.L16.bagCfg(s), d.slots, cap(s), d.eggBag, 1) then -- lot 15 : base OU sac d'œufs
			notify(s.player, "📅 Ta base et ton sac d'œufs sont pleins : libère une place, un œuf t'attend (rien n'est perdu).")
			return
		end
		-- 1. jour marqué dans le profil (état d'avant gardé pour l'annuler), 2. sauvegarde, 3. octroi
		local before = { days = cal.days, grace = cal.grace, catch = cal.catch, qc = cal.qc, dayD = cal.dayD, dayN = cal.dayN, streak = d.calStreak, last = d.calLast }
		local streak = Calendar.apply(Config, cal, now, day, how)
		d.calStreak, d.calLast = streak, now
		if not s.noSave and not Data.save(s.player, d, false) then
			cal.days, cal.grace, cal.catch, cal.qc, cal.dayD, cal.dayN = before.days, before.grace, before.catch, before.qc, before.dayD, before.dayN
			d.calStreak, d.calLast = before.streak, before.last
			notify(s.player, "📅 Sauvegarde impossible pour l'instant : réessaie dans un moment (rien n'a été perdu).")
			sync(s)
			return
		end
		local text = applyReward(s, plan)
		notify(s.player, "📅 Jour " .. day .. (how == "today" and "" or " rattrapé") .. " : " .. text, (function()
			for _, m in ipairs(CAL.milestones) do
				if m == day then
					return "calendar_milestone"
				end
			end
			return "calendar_claim"
		end)()) -- lot 10 : sons approuvés
		tele.log(s.player, "calendar_claim_day", day, how == "today" and "_today" or nil)
		if how ~= "today" then
			tele.log(s.player, "calendar_catchup", day, "_" .. how)
		end
		tele.log(s.player, "calendar_streak", streak)
		if Calendar.claimedCount(cal) >= CAL.days then
			tele.log(s.player, "calendar_cycle_complete", cal.cycle)
		end
		sync(s)
		if not s.noSave then -- l'octroi est sauvegardé tout de suite (au mieux) : la sauvegarde automatique le reprendrait sinon dans la minute
			task.spawn(function()
				Data.save(s.player, d, s.leaving == true)
			end)
		end
	end
end

function actions.calClaim(s, arg)
	if type(arg) ~= "table" or s.calBusy then
		return
	end
	s.calBusy = true
	local ok, err = pcall(Lot7.Cal.claim, s, arg.day, arg.how)
	s.calBusy = nil
	if not ok then
		warn("[Calendrier] " .. tostring(err))
	end
end

RAction.OnServerEvent:Connect(function(player, action, arg)
	local s = sessions[player]
	if not s or type(action) ~= "string" then
		return
	end
	local now = os.clock()
	if now - s.lastAct < 0.08 then
		return
	end
	s.lastAct = now
	s.lastActive = now -- toute action = joueur actif
	local fn = actions[action]
	if fn then
		local ok, err = pcall(fn, s, arg)
		if not ok then
			warn("[Action " .. action .. "] " .. tostring(err))
		end
	end
end)

---------------------------------------------------------------- Arène des pets (PvE : tour des Dresseurs)
-- Le serveur possède tout : l'équipe est relue dans le profil à chaque combat, la graine est tirée ici, le client n'envoie qu'une intention par tour
-- (« attack », « skill », « swap1 » à « swap3 ») et rejoue les événements reçus. Récompense versée UNE fois (s.battle est vidé avant le paiement).
local Battle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Battle"))
local TW = Config.TOWER
-- LOT 14 : classé en direct (file MemoryStore, apparieur élu, serveur réservé « ranked »). Règles pures : Shared/Ranked ; transport : PvpLive
-- (runtime injecté). Fermé tant que Config.PVP_LIVE.enabled = false ou que l'expérience compte moins de PVP_LIVE.minCCU joueurs simultanés.
-- Rangé dans la table Lot7 : AUCUNE nouvelle variable locale (le bloc principal est à la limite de 200).
Lot7.Live = (function()
	local PvpLive = require(script.Parent:WaitForChild("PvpLive"))
	return PvpLive.new(Config, require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ranked")), Battle, PvpLive.robloxRuntime(Config, {
		save = function(player, d)
			local ss = sessions[player]
			if ss and ss.noSave then
				return true -- profil en lecture seule (version plus récente, Studio) : rien à écrire
			end
			return Data.save(player, d)
		end,
		send = function(player, msg)
			RBattle:FireClient(player, msg)
		end,
		notify = notify,
		sync = function(ss)
			RState:FireClient(ss.player, snapshot(ss))
		end,
		log = warn,
	}))
end)()

local function battleDay(s)
	local day = os.time() // 86400
	local b = s.data.battle
	if b.day ~= day then
		b.day, b.fights, b.repeats = day, 0, 0
	end
	return b
end

local function battleUnits(s)
	local units = {}
	for _, idx in ipairs(s.data.battle.team) do
		local sl = validSlot(idx) and s.data.slots[idx]
		if sl and sl.k == "p" then
			units[#units + 1] = Battle.unit(Config, sl)
		end
	end
	return units
end

function actions.setTeam(s, arg)
	if s.battle or type(arg) ~= "table" then
		return
	end
	local team, seen = {}, {}
	for i = 1, TW.teamSize do
		local v = arg[i]
		if type(v) == "number" and v == v and v % 1 == 0 and validSlot(v) and not seen[v] then
			local sl = s.data.slots[v]
			if sl and sl.k == "p" then
				seen[v] = true
				team[#team + 1] = v
			end
		end
	end
	s.data.battle.team = team
	RState:FireClient(s.player, snapshot(s))
end

-- PvP : saison en cours, remise à zéro douce des trophées et récompense de la saison écoulée (une seule fois, selon le palier atteint).
local function pvpState(s)
	local pv = s.data.battle.pvp
	local season = Config.pvpSeason(os.time())
	if pv.season ~= season then
		local rw = pv.season > 0 and L15.Duel.seasonReward(Config.LEAGUE_SEASON.rewards, pv.trophies) or nil -- lot 13 (E.4) : paliers étendus (100 à 1500)
		if rw then
			local parts = {}
			if (rw.coins or 0) > 0 then
				s.data.coins += rw.coins
				parts[#parts + 1] = "+" .. Config.fmt(rw.coins) .. " 🪙"
			end
			local eggT = rw.eggName and Config.tierIndexByName(rw.eggName) or rw.eggTier
			if rw.eggName and eggT then -- palier 1500 : base, puis sac d'œufs, puis coffre de débordement (jamais perdu, un seul crédit)
				local where = Lot7.L16.storeEgg(s, eggT)
				parts[#parts + 1] = "un œuf " .. Config.TIERS[eggT].name .. (where == "bag" and " (dans ton sac d'œufs)" or (where == "overflow" and " (dans le coffre de débordement)" or ""))
			elseif eggT and Config.TIERS[eggT] then
				giveEgg(s, eggT)
				parts[#parts + 1] = "un œuf " .. Config.TIERS[eggT].name
			end
			if rw.potion or rw.potionSeconds then
				local secs = rw.potionSeconds or Config.LUCK_POTION_SECONDS
				s.data.luckUntil = math.max(os.time(), s.data.luckUntil) + secs
				parts[#parts + 1] = "potion de chance (" .. math.floor(secs / 60) .. " min)"
			end
			notify(s.player, "🏆 Fin de saison PvP : " .. pv.trophies .. " trophées -> " .. table.concat(parts, " + ") .. (rw.title and (" · 👑 " .. rw.title .. " " .. pv.season) or ""), "claim")
		end
		pv.season, pv.trophies, pv.wins, pv.losses = season, L15.Duel.seasonReset(pv.trophies, Config.LEAGUE_SEASON.resetAbove, Config.LEAGUE_SEASON.resetFactor), 0, 0 -- lot 13 (E.4) : max(300, floor(t x 0,6)) au-delà de 300
	end
	local day = os.time() // 86400
	if pv.day ~= day then
		pv.day, pv.fights = day, 0
	end
	return pv
end

local function pvpPublishAsync(s)
	local pv = s.data.battle.pvp
	local team, season, trophies, player = {}, pv.season, pv.trophies, s.player
	for _, e in ipairs(pv.defense) do
		team[#team + 1] = { p = e.p, s = e.s, m = e.m }
	end
	if #team > 0 then
		task.spawn(function()
			pcall(Data.pvpPublish, player, team, trophies, season)
		end)
	end
end

-- LOT 12 B : cartes de récompense (D.5). Le tirage est enregistré dans le profil (battle.pendingPick) AVANT l'envoi : déconnexion ou relance ne retire pas la récompense.
-- Délai de 15 s tenu par le SERVEUR (première carte d'office). Jamais exposé par snapshot : les cartes ne sortent que par { k = "pick" }.
function L15.pickHooks(s)
	local h = { where = nil }
	-- Carte Œuf : place libre cherchée AVANT ; base pleine -> sac d'œufs puis coffre de débordement (lot 15/16), jamais l'ancien giveEgg (demi-prix) ni de perte.
	h.giveEgg = function(t)
		if freeSlot(s) then
			h.where = "slot"
			return giveEgg(s, t)
		end
		h.where = Lot7.L16.storeEgg(s, t)
		return h.where == "bag" or h.where == "overflow" or h.where == "slot"
	end
	return h
end
function L15.sendPick(s)
	local pk = s.data.battle.pendingPick
	if not pk then
		return
	end
	if L15.BR.expired(pk, os.time()) then
		return L15.claimPick(s, nil, nil)
	end
	local v = L15.BR.view(Config, pk, os.time())
	RBattle:FireClient(s.player, { k = "pick", id = v.id, cards = v.cards, seconds = v.seconds, floor = v.floor })
	task.delay(v.seconds + 1, function()
		local cur = s.data.battle.pendingPick
		if s.player.Parent and sessions[s.player] == s and cur and cur.id == v.id then
			L15.claimPick(s, nil, nil)
		end
	end)
end
function L15.claimPick(s, id, index)
	local b = s.data.battle
	local card, auto = L15.BR.claim(b.pendingPick, id, index, os.time())
	if not card then
		return -- index ou identifiant invalide : rien n'est consommé
	end
	b.pendingPick = nil -- vidé AVANT d'attribuer : aucun double gain
	local hooks = L15.pickHooks(s)
	local out = L15.BR.grant(Config, s.data, card, hooks, os.time(), L15.PetXp)
	local _, _, desc = L15.BR.cardText(Config, card)
	local note = (out and out.converted and " (converti en pièces)") or (hooks.where == "bag" and " (base pleine : rangé dans ton sac d'œufs)") or (hooks.where == "overflow" and " (base et sac pleins : rangé dans le coffre de débordement)") or ""
	RBattle:FireClient(s.player, { k = "picked", text = desc .. note, auto = auto })
	RState:FireClient(s.player, snapshot(s))
end
-- Propose les 3 cartes à la fin d'un combat gagné (mode « first » / « repeat » / « npc »), puis les envoie.
function L15.offerPick(s, floor, mode)
	local b = s.data.battle
	local pick = L15.BR.offer(Config, b.pendingPick, { floor = floor, income = income(s), mode = mode }, rng:NextInteger(1, 2147483000), os.time(), game:GetService("HttpService"):GenerateGUID(false))
	b.pendingPick = pick
	return pick
end
function actions.battlePick(s, arg) -- arg = { id, i } ; le dispatcher RAction fournit déjà la limitation de fréquence ; tout est revalidé par L15.BR.claim
	if type(arg) == "table" and type(arg.id) == "string" and #arg.id <= 64 and type(arg.i) == "number" then
		L15.claimPick(s, arg.id, arg.i)
	end
end

local function battleFinish(s)
	local bt = s.battle
	s.battle = nil -- vidé AVANT tout paiement : aucune double récompense possible
	local st, win = bt.st, bt.st.winner == 1
	local b = s.data.battle
	local rewards = {}
	if not bt.pvp then -- lot 13 (B.4) : ratio PvE (tour et PNJ) affiché dans l'intro
		b.pve = type(b.pve) == "table" and b.pve or { w = 0, l = 0 }
		if win then
			b.pve.w = math.min(1e7, (b.pve.w or 0) + 1)
		else
			b.pve.l = math.min(1e7, (b.pve.l or 0) + 1)
		end
	end
	if bt.npc then
		return L15.fightEnd(s, bt, win) -- lot 15 : combat de PNJ (résultat déclaré par le serveur, une seule fois)
	end
	if bt.pvp then
		local pv = pvpState(s)
		if win then
			local gain = Config.pvpGain(pv.trophies, bt.pvp.trophies)
			pv.trophies, pv.wins = pv.trophies + gain, pv.wins + 1
			rewards.trophies = gain
		else
			local loss = math.min(pv.trophies, Config.PVP.loss)
			pv.trophies, pv.losses = pv.trophies - loss, pv.losses + 1
			rewards.trophies = -loss
		end
		rewards.total = pv.trophies
		if win then
			L15.weekly(s, "pvp", 1) -- lot 15 : quête de la semaine « duels »
			Lot7.L16.addXp(s, "pvp") -- lot 16 : XP du passe de combat (victoire PvP, validée par le serveur)
		end
		pvpPublishAsync(s)
		L15.PetXp.addToTeam(s.data.slots, b.team, L15.PetXp.award("pvp", L15.PetXp.combat("pvp", win, 0), L15.PetXp.boostMul(s.data, os.time()))) -- lot 12 B : XP de pet (PvP)
		RBattle:FireClient(s.player, { k = "end", win = win, rewards = rewards, best = b.best, floor = 0, pvp = true, foe = bt.pvp.name, view = Battle.view(st) })
		RState:FireClient(s.player, snapshot(s))
		return
	end
	local sendAfter = false
	if win then
		L15.onPve(s) -- lot 15 : quête bonus, quête de la semaine et plumes d'une victoire PvE
		local first = bt.floor > b.best
		if first then
			b.best = bt.floor
			tele.log(s.player, "tower_floor_reached", bt.floor)
		end
		if first or b.repeats < TW.dailyRepeats + Lot7.L16.arenaExtra(s) then -- lot 16 : les tickets d'arène ajoutent des combats RÉCOMPENSÉS
			if not first then
				b.repeats += 1
			end
			rewards.first = first
			L15.qk(s, "pveWin", { rewarded = true, units = st.sides[1].units, weekType = L15.Rewards.rotation(Config, L15.Rewards.weekOf(os.time() // 86400)).type }) -- A11 : victoire de tour RÉCOMPENSÉE
			rewards.pick = true -- lot 12 B : le client attend { k = "pick" } (3 cartes) et masque « Continuer » ; remplace Config.towerReward
			L15.offerPick(s, bt.floor, first and "first" or "repeat")
			sendAfter = true
		else
			rewards.limited = true
		end
	end
	L15.PetXp.addToTeam(s.data.slots, b.team, L15.PetXp.award("pve", L15.PetXp.combat("pve", win, bt.floor), L15.PetXp.boostMul(s.data, os.time()))) -- lot 12 B : XP de pet (tour)
	RBattle:FireClient(s.player, { k = "end", win = win, rewards = rewards, best = b.best, floor = bt.floor, view = Battle.view(st) })
	RState:FireClient(s.player, snapshot(s))
	if sendAfter then
		L15.sendPick(s)
	end
end

local function battleStep(s, act)
	local bt = s.battle
	if not bt or bt.st.over then
		return
	end
	local events = Battle.turn(bt.st, act)
	bt.deadline = os.clock() + TW.turnSeconds
	if bt.st.over then
		RBattle:FireClient(s.player, { k = "turn", events = events, view = Battle.view(bt.st) })
		battleFinish(s)
	else
		RBattle:FireClient(s.player, { k = "turn", events = events, view = Battle.view(bt.st), seconds = TW.turnSeconds })
	end
end

function actions.pvpDefense(s)
	if s.battle then
		return
	end
	local pv = pvpState(s)
	local def = {}
	for _, idx in ipairs(s.data.battle.team) do
		local sl = validSlot(idx) and s.data.slots[idx]
		if sl and sl.k == "p" then
			def[#def + 1] = { p = sl.p, s = sl.s, m = sl.m }
		end
	end
	if #def == 0 then
		notify(s.player, "🛡 Choisis d'abord une équipe de pets.", "refuse")
		return
	end
	pv.defense = def
	pvpPublishAsync(s)
	notify(s.player, "🛡 Équipe de défense enregistrée (" .. #def .. " pet" .. (#def > 1 and "s" or "") .. "). Les autres joueurs peuvent l'affronter.", "buy")
	RState:FireClient(s.player, snapshot(s))
end

function actions.pvpStart(s)
	if s.battle or s.castle or s.pvpPending then
		return
	end
	local pv = pvpState(s)
	if #pv.defense == 0 then
		notify(s.player, "🛡 Enregistre d'abord ton équipe de défense pour entrer au classement.", "refuse")
		return
	end
	if pv.fights >= Config.PVP.dailyFights then
		notify(s.player, "🏆 Limite de combats classés atteinte pour aujourd'hui (" .. Config.PVP.dailyFights .. ").", "refuse")
		return
	end
	local mine = battleUnits(s)
	if #mine == 0 then
		notify(s.player, "⚔️ Compose d'abord une équipe de pets.", "refuse")
		return
	end
	s.pvpPending = true -- la recherche d'adversaire attend le DataStore : un seul départ à la fois
	local player = s.player
	task.spawn(function()
		local okOpp, opp = pcall(Data.pvpOpponent, player.UserId, pv.trophies, pv.season, rng:NextInteger(0, 4))
		s.pvpPending = nil
		if not (okOpp and sessions[player] == s) or s.battle then
			return
		end
		if not opp then -- aucun autre joueur classé : adversaire fantôme de la tour, au niveau des trophées
			local floor = math.min(Config.TOWER.floors, 1 + pv.trophies // 40)
			local ghost = {}
			for _, u in ipairs(Battle.towerTeam(Config, floor)) do
				ghost[#ghost + 1] = { p = u.p, s = u.s, m = u.m }
			end
			opp = { name = "Dresseur fantôme", team = ghost, trophies = pv.trophies }
		end
		local foes = {}
		for _, e in ipairs(opp.team) do
			foes[#foes + 1] = Battle.unit(Config, e)
		end
		pv.fights += 1
		s.battle = { st = Battle.new(rng:NextInteger(1, 2147483000), battleUnits(s), foes), floor = 0, pvp = { name = opp.name, trophies = opp.trophies }, deadline = os.clock() + TW.turnSeconds }
		RBattle:FireClient(player, { k = "start", floor = 0, foe = "🏆 " .. opp.name, pvp = true, view = Battle.view(s.battle.st), seconds = TW.turnSeconds })
	end)
end

-- LOT 14 : file en direct. Fermée (désactivée, moins de 60 joueurs simultanés, comptage inconnu) = classé asynchrone directement.
function actions.liveQueue(s)
	local ok, why = Lot7.Live.enqueue(s, { busy = s.battle ~= nil or s.castle ~= nil or s.pvpPending == true or #s.carry > 0 or s.leaving == true, serverMode = serverMode, party = serverPartyId })
	if ok then
		return
	elseif why == "closed" then
		return actions.pvpStart(s)
	elseif why == "fights" then
		notify(s.player, "🏆 Limite de combats classés en direct atteinte pour aujourd'hui (" .. Config.PVP_LIVE.dailyFights .. ").", "refuse")
	elseif why == "cap" then
		notify(s.player, "🏆 Plafond de trophées du jour atteint en direct (" .. Config.PVP_LIVE.dailyTrophyCap .. ") : reviens demain ou joue en classé enregistré.", "refuse")
	elseif why == "team" then
		notify(s.player, "⚔️ Compose d'abord une équipe de pets.", "refuse")
	elseif why == "busy" then
		notify(s.player, "⚔️ Termine d'abord ce que tu fais (combat, œuf porté, château).", "refuse")
	end
end

function actions.liveCancel(s)
	Lot7.Live.cancel(s)
end

function actions.towerStart(s, floor)
	if s.battle or s.castle or type(floor) ~= "number" or floor ~= floor or floor % 1 ~= 0 then
		return
	end
	local b = battleDay(s)
	if floor < 1 or floor > TW.floors or floor > b.best + 1 then
		notify(s.player, "🔒 Étage verrouillé : bats d'abord l'étage " .. (b.best + 1) .. ".", "refuse")
		return
	end
	if b.fights >= TW.dailyFights + Lot7.L16.arenaExtra(s) then -- lot 16 : tickets d'arène du jour (combats en plus)
		notify(s.player, "⚔️ Limite de combats atteinte pour aujourd'hui (" .. (TW.dailyFights + Lot7.L16.arenaExtra(s)) .. "). Reviens demain !", "refuse")
		Lot7.L16.event(s, "towerQuotaExhausted") -- lot 16 : offre contextuelle « Ticket d'arène » (si elle est permise)
		return
	end
	local mine = battleUnits(s)
	if #mine == 0 then
		notify(s.player, "⚔️ Compose d'abord une équipe de pets (1 à " .. TW.teamSize .. ").", "refuse")
		return
	end
	b.fights += 1
	local seed = rng:NextInteger(1, 2147483000)
	L15.boostUnits(mine) -- lot 15 : type « en forme » de la semaine (+20 % d'attaque, PvE seulement)
	s.battle = { st = Battle.new(seed, mine, Battle.towerTeam(Config, floor)), floor = floor, deadline = os.clock() + TW.turnSeconds }
	RBattle:FireClient(s.player, { k = "start", floor = floor, foe = Config.towerFoeName(floor), view = Battle.view(s.battle.st), seconds = TW.turnSeconds })
end

function actions.battleAct(s, arg)
	if Lot7.Live.act(s, arg) then
		return -- lot 14 : combat classé en direct (deux joueurs)
	end
	local bt = s.battle
	if bt and bt.duel then
		return L15.duel.act(s, arg) -- lot 13 : duel local (deux joueurs)
	end
	if not bt or type(arg) ~= "string" then
		return
	end
	local act
	if arg == "attack" or arg == "skill" then
		act = { kind = arg }
	else
		local n = tonumber(arg:match("^swap(%d)$"))
		if n then
			act = { kind = "swap", to = n }
		end
	end
	if not act or Battle.validate(bt.st, 1, act) then
		notify(s.player, "⚔️ Action impossible.", "refuse")
		return
	end
	battleStep(s, act)
end

function actions.battleQuit(s)
	if Lot7.Live.quit(s) then
		return -- lot 14 : abandon d'un combat en direct = forfait
	end
	if s.battle and s.battle.duel then
		return L15.duel.quit(s) -- lot 13 : abandon d'un duel = forfait
	end
	if s.battle then
		s.battle.st.over, s.battle.st.winner = true, 2 -- abandon = défaite (le combat compte dans la limite du jour)
		battleFinish(s)
	end
end

task.spawn(function() -- tour limité à 10 s : action par défaut (attaque)
	while true do
		task.wait(1)
		for _, s in pairs(sessions) do
			local bt = s.battle
			if bt and not bt.duel and os.clock() > bt.deadline then -- lot 13 : les duels ont leur propre minuteur (L15.duel)
				pcall(battleStep, s, { kind = "attack" })
			end
		end
	end
end)

---------------------------------------------------------------- Duel local (lot 13, E.1 E.2 B.4) : défis, sable du colisée, tours à deux, spectateurs ; AUCUN trophée
-- Règles PURES dans ReplicatedStorage/Duel.lua (tests/lot13.luau) ; ce bloc lit l'état des joueurs et applique les décisions. Une seule variable locale (D, rangée
-- aussi dans L15.duel) : le bloc principal est proche de la limite Luau de 200 variables locales.
-- Le client n'envoie que : duelChallenge(userId), duelAnswer({ from, accept }), duelOff(bool) et, pendant le duel, battleAct / battleQuit (routés ici).
-- Chaque demande est revalidée par le serveur (distance, états des DEUX joueurs relus à l'acceptation, cooldown, défis en attente, équipe, réglage « refuser »).
do
	local D = { book = L15.Duel.newBook(), matches = {}, C = Config.DUEL }
	L15.duel = D
	D.REFUSE = {
		self = "⚔️ Tu ne peux pas te défier toi-même.", range = "⚔️ Trop loin pour un duel (approche-toi).", egg = "⚔️ Pas de duel avec un œuf dans les mains.", chased = "⚔️ Pas de duel pendant une poursuite.",
		dialogue = "⚔️ Un dialogue est en cours.", castle = "⚔️ Pas de duel en mode Château.", newbie = "⚔️ Protection débutant : désactive-la pour combattre.", busy = "⚔️ Un combat est déjà en cours.",
		flying = "⚔️ Pas de duel pendant un vol d'œuf.", cinematic = "⚔️ Pas de duel pendant une éclosion.",
		cooldown = "⚔️ Tu as déjà défié ce joueur : attends un peu.", pendingOut = "⚔️ Ton défi précédent est encore en attente.", crowded = "⚔️ Ce joueur a déjà plusieurs défis.",
		expired = "⚔️ Ce défi a expiré.", none = "⚔️ Ce défi n'est plus valable.", off = "⚔️ Ce joueur refuse les duels (réglage).", team = "⚔️ Compose d'abord une équipe de pets (Arène).",
		foeTeam = "⚔️ Ce joueur n'a pas encore d'équipe de pets.",
	}
	function D.flags(s)
		local root = getRoot(s.player)
		local c = root and L15.ctx and L15.ctx(s, root) or {}
		return {
			userId = s.player.UserId, carryingEgg = c.carrying == true or #s.carry > 0, chased = c.chased == true, inDialogue = c.pending == true,
			inCastle = s.castle ~= nil or serverMode == "castle", newbie = isNewbie(s), busy = s.battle ~= nil or s.pvpPending == true or s.leaving == true or serverMode == "ranked" or (Lot7.Live ~= nil and Lot7.Live.queued[s.player.UserId] ~= nil), -- lot 14 : en file classée = occupé
			flying = holds[s.player] ~= nil, inCinematic = os.clock() < (s.cineUntil or 0),
		}
	end
	function D.ctx(s, t)
		local r1, r2 = getRoot(s.player), getRoot(t.player)
		if not r1 or not r2 then
			return nil
		end
		return { a = D.flags(s), b = D.flags(t), distance = (r1.Position - r2.Position).Magnitude }
	end
	function D.find(s) -- duel en cours du joueur (id, match, côté 1 = défieur / 2 = défié)
		for id, d in pairs(D.matches) do
			if d.a == s then
				return id, d, 1
			elseif d.b == s then
				return id, d, 2
			end
		end
		return nil
	end
	function D.spectators(d) -- joueurs proches du colisée (hors duellistes) : reçoivent le bandeau du duel
		local A, out = Config.Map2.arena, {}
		for p, ss in pairs(sessions) do
			if ss ~= d.a and ss ~= d.b then
				local r = getRoot(p)
				if r and (Vector3.new(r.Position.X - A.x, 0, r.Position.Z - A.z)).Magnitude <= D.C.spectatorRange then
					out[#out + 1] = p
				end
			end
		end
		return out
	end
	function D.broadcast(d, msg) -- msg du point de vue du défieur (camp 1)
		for _, p in ipairs(D.spectators(d)) do
			RBattle:FireClient(p, msg)
		end
	end
	function D.watch(d, events)
		return { k = "duelWatch", a = d.a.player.DisplayName, b = d.b.player.DisplayName, view = Battle.view(d.st), events = events, over = d.st.over, winner = d.winnerName }
	end
	function D.place(s, side) -- sur le sable, face à face (±sandOffset en X), personnage figé pendant le duel
		local root = getRoot(s.player)
		if not root then
			return
		end
		local A = Config.Map2.arena
		local x = A.x + (side == 1 and -D.C.sandOffset or D.C.sandOffset)
		s.duelBack = root.Position
		root.CFrame = CFrame.lookAt(Vector3.new(x, 4, A.z), Vector3.new(A.x, 4, A.z))
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = true
		s.noCheckUntil, s.lastPos = os.clock() + 2, nil
	end
	function D.release(s) -- personnage libéré et ramené où il était avant le duel
		local root = getRoot(s.player)
		if root then
			root.Anchored = false
			if s.duelBack then
				root.CFrame = CFrame.new(s.duelBack + Vector3.new(0, 1, 0))
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
		s.duelBack, s.noCheckUntil, s.lastPos = nil, os.clock() + 2, nil
	end

	function actions.duelOff(s, v)
		if type(v) ~= "boolean" then
			return
		end
		s.data.settings.duelOff = v
		RState:FireClient(s.player, snapshot(s))
	end

	function actions.duelChallenge(s, arg) -- arg = userId du joueur défié
		if type(arg) ~= "number" or arg ~= arg or arg % 1 ~= 0 then
			return
		end
		local target = Players:GetPlayerByUserId(arg)
		local t = target and sessions[target]
		if not t then
			return
		end
		if t == s then
			notify(s.player, D.REFUSE.self, "refuse")
			return
		end
		if #battleUnits(s) == 0 then
			notify(s.player, D.REFUSE.team, "refuse")
			return
		end
		if t.data.settings.duelOff == true then
			notify(s.player, D.REFUSE.off, "refuse")
			return
		end
		if #battleUnits(t) == 0 then
			notify(s.player, D.REFUSE.foeTeam, "refuse")
			return
		end
		local ctx = D.ctx(s, t)
		if not ctx then
			return
		end
		local ok, why = L15.Duel.request(D.book, ctx, os.clock(), D.C)
		if not ok then
			notify(s.player, D.REFUSE[why] or D.REFUSE.busy, "refuse")
			return
		end
		notify(s.player, "⚔️ Défi envoyé à " .. target.DisplayName .. " (" .. D.C.requestTimeout .. " s pour répondre).", "buy")
		RBattle:FireClient(target, { k = "duelAsk", from = s.player.DisplayName, fromId = s.player.UserId, seconds = D.C.requestTimeout })
	end

	function D.start(f, s, id)
		local unitsA, unitsB = battleUnits(f), battleUnits(s)
		local st = Battle.new(rng:NextInteger(1, 2147483000), unitsA, unitsB)
		local d = { id = id, m = L15.Duel.newMatch(f.player.UserId, s.player.UserId), a = f, b = s, st = st, act = {}, deadline = os.clock() + D.C.turnSeconds + D.C.introSeconds }
		D.matches[id] = d
		f.battle = { duel = id, st = st, deadline = math.huge } -- s.battle occupé : tour, PvP, PNJ, équipe et nouveaux défis bloqués par les gardes existantes
		s.battle = { duel = id, st = st, deadline = math.huge }
		D.place(f, 1)
		D.place(s, 2)
		local view = Battle.view(st)
		local function side(me, foe, mineView)
			local w, l = L15.Duel.recordFor("duel", me.data.battle)
			local fw, fl = L15.Duel.recordFor("duel", foe.data.battle)
			return {
				me = { name = me.player.DisplayName, userId = me.player.UserId, wins = w, losses = l, trophies = me.data.battle.pvp.trophies, league = L15.Duel.leagueText(Config.LEAGUES, me.data.battle.pvp.trophies) },
				foe = { name = foe.player.DisplayName, userId = foe.player.UserId, wins = fw, losses = fl, trophies = foe.data.battle.pvp.trophies, league = L15.Duel.leagueText(Config.LEAGUES, foe.data.battle.pvp.trophies) },
				view = mineView,
			}
		end
		local ia, ib = side(f, s, view), side(s, f, L15.Duel.mirrorView(view))
		local A = Config.Map2.arena
		RBattle:FireClient(f.player, { k = "start", floor = 0, duel = true, foe = "⚔️ " .. s.player.DisplayName, view = ia.view, seconds = D.C.turnSeconds + D.C.introSeconds, intro = { me = ia.me, foe = ia.foe }, arena = { x = A.x, z = A.z, side = 1 } })
		RBattle:FireClient(s.player, { k = "start", floor = 0, duel = true, foe = "⚔️ " .. f.player.DisplayName, view = ib.view, seconds = D.C.turnSeconds + D.C.introSeconds, intro = { me = ib.me, foe = ib.foe }, arena = { x = A.x, z = A.z, side = 2 } })
		D.broadcast(d, D.watch(d, {}))
	end

	function actions.duelAnswer(s, arg) -- arg = { from = userId, accept = bool }
		if type(arg) ~= "table" or type(arg.from) ~= "number" or arg.from ~= arg.from then
			return
		end
		local fromPlayer = Players:GetPlayerByUserId(arg.from)
		local f = fromPlayer and sessions[fromPlayer]
		if not f or f == s then
			L15.Duel.decline(D.book, s.player.UserId, arg.from, os.clock(), D.C)
			return
		end
		local accept = arg.accept == true
		if accept and (#battleUnits(s) == 0 or #battleUnits(f) == 0) then
			L15.Duel.decline(D.book, s.player.UserId, arg.from, os.clock(), D.C)
			notify(s.player, #battleUnits(s) == 0 and D.REFUSE.team or D.REFUSE.foeTeam, "refuse")
			notify(f.player, "⚔️ Duel annulé : une équipe de pets est vide.", "refuse")
			return
		end
		local ok, id, cancelled = L15.Duel.answer(D.book, s.player.UserId, arg.from, accept, os.clock(), D.C, accept and D.ctx(f, s) or nil)
		if not ok then
			if id == "declined" then
				notify(f.player, "⚔️ " .. s.player.DisplayName .. " a refusé ton défi.", "refuse")
			elseif id ~= "none" then
				notify(f.player, D.REFUSE[id] or "⚔️ Défi annulé.", "refuse")
				notify(s.player, D.REFUSE[id] or "⚔️ Défi annulé.", "refuse")
			end
			return
		end
		for _, c in ipairs(cancelled) do
			local p = Players:GetPlayerByUserId(c.from)
			if p then
				notify(p, "⚔️ Défi annulé : ce joueur est déjà en duel.", "refuse")
			end
			local q = Players:GetPlayerByUserId(c.to)
			if q then
				RBattle:FireClient(q, { k = "duelAskEnd", fromId = c.from })
			end
		end
		D.start(f, s, id)
	end

	function D.act(s, arg) -- intention d'un duelliste pour le tour en cours (une seule par tour, validée par le moteur)
		local id, d, side = D.find(s)
		if not id or d.st.over then
			return
		end
		local act = L15.Duel.parseAction(arg)
		if not act or Battle.validate(d.st, side, act) then
			notify(s.player, "⚔️ Action impossible.", "refuse")
			return
		end
		if d.act[side] then
			return -- déjà choisie pour ce tour
		end
		d.act[side] = act
		if d.act[1] and d.act[2] then
			D.resolve(id)
		end
	end

	function D.resolve(id) -- joue le tour (action manquante = attaque), compte l'inactivité, diffuse
		local d = D.matches[id]
		if not d then
			return
		end
		local actedA, actedB = d.act[1] ~= nil, d.act[2] ~= nil
		local events = Battle.turn(d.st, d.act[1] or { kind = "attack" }, d.act[2] or { kind = "attack" })
		d.act = {}
		d.deadline = os.clock() + D.C.turnSeconds
		local verdict = L15.Duel.noteTurn(d.m, actedA, actedB, D.C)
		local winner
		if d.st.over then
			winner = d.st.winner == 1 and "a" or "b"
		elseif verdict == "forfeitA" then
			winner = "b"
		elseif verdict == "forfeitB" then
			winner = "a"
		end
		local view = Battle.view(d.st)
		local over = d.st.over or verdict ~= "continue"
		RBattle:FireClient(d.a.player, { k = "turn", duel = true, events = events, view = view, seconds = (not over) and D.C.turnSeconds or nil })
		RBattle:FireClient(d.b.player, { k = "turn", duel = true, events = L15.Duel.mirrorEvents(events), view = L15.Duel.mirrorView(view), seconds = (not over) and D.C.turnSeconds or nil })
		if over then
			D.finish(id, winner, verdict == "cancelled" and "cancelled" or (d.st.over and "ko" or "afk"))
		else
			D.broadcast(d, D.watch(d, events))
		end
	end

	-- Fin du duel (KO, forfait d'inactivité, abandon, départ, annulation). winner = "a" | "b" | nil. Récompenses : Duel.settle (10/jour, 3/paire/jour),
	-- pièces seulement (jamais de trophée ni de Robux) ; départ / abandon avant earlyMinTurns tours = personne n'est payé. leaver = session qui part (pas de pièces).
	function D.finish(id, winner, reason, leaver)
		local d = D.matches[id]
		if not d then
			return
		end
		D.matches[id] = nil -- retiré AVANT tout paiement : aucune double récompense
		d.m.over, d.m.winner = true, winner
		local early = reason == "leave" or reason == "quit"
		local oa, ob = L15.Duel.outcomes(d.m)
		d.winnerName = winner == "a" and d.a.player.DisplayName or (winner == "b" and d.b.player.DisplayName or nil)
		for _, e in ipairs({ { d.a, d.b, oa, 1 }, { d.b, d.a, ob, 2 } }) do
			local me, foe, outcome, side = e[1], e[2], e[3], e[4]
			me.battle = nil
			if sessions[me.player] == me then
				local res = L15.Duel.settle(me.data.battle.duel, foe.player.UserId, outcome, os.time(), income(me), D.C)
				local coins = me ~= leaver and L15.Duel.payable(res, d.m.turns, early, D.C.earlyMinTurns) or 0
				if coins > 0 then
					L15.qk(me, "duelPaid", { coins = coins }) -- A11 : quête « duel » (duels payés seulement : plafonds jour et paire de Duel.settle)
					me.data.coins += coins
					L15.PetXp.addToTeam(me.data.slots, me.data.battle.team, L15.PetXp.award("pvp", L15.PetXp.combat("pvp", res.won, 0), L15.PetXp.boostMul(me.data, os.time()))) -- XP de pet : seulement les duels payés (plafonnés)
				end
				if me ~= leaver then
					D.release(me)
					local view = Battle.view(d.st)
					local text = reason == "cancelled" and "⚔️ Duel annulé (personne n'a joué)." or ((res.won and "⚔️ Duel gagné" or "⚔️ Duel perdu")
						.. (reason == "afk" and " (forfait d'inactivité)" or (early and (me == (winner == "a" and d.a or d.b) and (reason == "leave" and " (l'adversaire est parti)" or " (abandon de l'adversaire)") or " (abandon)") or ""))
						.. (coins > 0 and (" : +" .. Config.fmt(coins) .. " 🪙") or (res.reason == "dayCap" and " · limite de 10 duels récompensés atteinte aujourd'hui" or (res.reason == "pairCap" and " · déjà 3 duels récompensés contre ce joueur aujourd'hui" or " · amical : pas de récompense"))))
					RBattle:FireClient(me.player, { k = "end", duel = true, win = res.won, rewards = { coins = coins > 0 and coins or nil, duelText = text, cancelled = reason == "cancelled" }, best = me.data.battle.best, floor = 0, foe = foe.player.DisplayName, view = side == 1 and view or L15.Duel.mirrorView(view) })
					notify(me.player, text, res.won and "claim" or "refuse")
					RState:FireClient(me.player, snapshot(me))
				end
			end
		end
		L15.Duel.finish(D.book, d.a.player.UserId)
		L15.Duel.finish(D.book, d.b.player.UserId)
		d.st.over = true
		D.broadcast(d, D.watch(d, {}))
	end

	function D.quit(s) -- abandon = forfait
		local id, d, side = D.find(s)
		if id then
			d.st.over = true
			D.finish(id, side == 1 and "b" or "a", "quit")
		end
	end

	function L15.duelLeave(s) -- départ d'un joueur (appelé par PlayerRemoving AVANT la sauvegarde) : forfait, défis retirés, rien ne reste en mémoire
		local id, _, side = D.find(s)
		if id then
			D.finish(id, side == 1 and "b" or "a", "leave", s)
		end
		for _, p in pairs(D.book.pending) do
			if p.to == s.player.UserId then
				local q = Players:GetPlayerByUserId(p.from)
				if q then
					notify(q, "⚔️ Défi annulé : ce joueur est parti.", "refuse")
				end
			elseif p.from == s.player.UserId then
				local q = Players:GetPlayerByUserId(p.to)
				if q then
					RBattle:FireClient(q, { k = "duelAskEnd", fromId = p.from })
				end
			end
		end
		L15.Duel.finish(D.book, s.player.UserId)
		s.duelBack = nil
	end

	task.spawn(function() -- délais : défis expirés, tours de 10 s (action par défaut = attaque), purge des cooldowns
		while true do
			task.wait(0.5)
			pcall(function()
				local now = os.clock()
				for _, e in ipairs(L15.Duel.expire(D.book, now, D.C)) do
					local p, q = Players:GetPlayerByUserId(e.from), Players:GetPlayerByUserId(e.to)
					if p then
						notify(p, "⚔️ Pas de réponse : défi expiré.", "refuse")
					end
					if q then
						RBattle:FireClient(q, { k = "duelAskEnd", fromId = e.from })
					end
				end
				for id, d in pairs(D.matches) do
					if now > d.deadline then
						local ok, err = pcall(D.resolve, id)
						if not ok then
							warn("[Duel] " .. tostring(err))
							D.finish(id, nil, "cancelled")
						end
					end
				end
				L15.Duel.prune(D.book, now, D.C)
			end)
		end
	end)
end

task.spawn(function() -- lot 14 : file, apparieur, arène et retours, une fois par seconde (chaque appel réseau est dans un pcall côté PvpLive)
	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(player)
			Lot7.Live.teleportFailed(player)
		end)
	end)
	while true do
		task.wait(1)
		local ok, err = pcall(Lot7.Live.step, sessions)
		if not ok then
			warn("[PvpLive] " .. tostring(err))
		end
	end
end)

---------------------------------------------------------------- Lot 15 : PNJ, série de 7 jours, quêtes bonus et hebdomadaires, sac d'œufs, rotation, événements
-- Le SERVEUR décide de tout (jour UTC, rencontres, offres, résultats des combats) ; le client n'envoie que des identifiants ou des booléens (actions npcAnswer,
-- npcOff, daily, bagPlace, bonusClaim, weeklyClaim, plumeBuy) et n'affiche que des vues. Modules purs : ReplicatedStorage/Npc et Rewards (tests/lot15.luau).
-- Tous les œufs donnés passent par L15.storeEggs (base puis sac d'œufs, ATOMIQUE : tout ou rien, jamais de perte). Aucun Robux dans un dialogue de PNJ,
-- aucun échange entre joueurs, aucune rareté interdite (FORBIDDEN_GIFT_TIERS) donnée par un PNJ, la série ou les quêtes.
do
	local Npc, Rewards = L15.Npc, L15.Rewards
	local E = Config.NPC_ENCOUNTER
	L15.QP_WEEKLY = { hatch = "hatch", steal = "steal", discover = "collect" } -- types de missions du jour (qp) -> thèmes de la semaine
	local MSG = {
		unknown = "Cette offre n'est plus valable.", used = "Cette offre n'est plus valable.", owner = "Cette offre n'est plus valable.", state = "Cette offre n'est plus valable.",
		expired = "Trop tard : le PNJ est reparti.", coins = "Il te manque des pièces pour cette offre.", changed = "Tes pets ont changé depuis l'offre : elle est annulée.",
		bagFull = "Ta base et ton sac d'œufs sont pleins : libère une place d'abord (rien n'est perdu).",
	}
	local function today()
		return os.time() // 86400
	end
	local function tierName(t)
		return Config.TIERS[t] and Config.TIERS[t].name or "?"
	end
	function L15.book(s)
		local b = L15.books[s.player]
		if not b then
			b = Npc.newBook()
			L15.books[s.player] = b
		end
		return b
	end
	-- Fabrique d'emplacement d'œuf (incubation et bouclier comme tous les œufs posés).
	function L15.mkEgg(s)
		return function(tier)
			return { k = "e", t = tier, ends = os.time() + hatchTime(s, tier), shield = os.time() + shieldTime(s) }
		end
	end
	-- Range des œufs (base puis sac, tout ou rien) et rafraîchit les pads remplis. Retourne la liste « slot » / « bag » ou (nil, "bagFull") sans rien modifier.
	function L15.storeEggs(s, tiers)
		local d = s.data
		local before = {}
		for i = 1, cap(s) do
			before[i] = not d.slots[i]
		end
		local ok, where = Rewards.storeEggs(Lot7.L16.bagCfg(s), d.slots, cap(s), d.eggBag, tiers, L15.mkEgg(s))
		if not ok then
			return nil, where
		end
		for i = 1, cap(s) do
			if before[i] and d.slots[i] then
				refreshPad(s, i)
			end
		end
		return where
	end
	local function saveSoon(s)
		if not s.noSave then
			task.spawn(function()
				Data.save(s.player, s.data, s.leaving == true)
			end)
		end
	end
	-- Missions du jour TERMINÉES (progression au but), pour la quête bonus et le sauvetage gratuit de la série.
	function L15.questsDone(s)
		local n = 0
		if s.data.qday == today() then
			for _, q in ipairs(s.data.quests) do
				if q.prog >= q.goal then
					n = n + 1
				end
			end
		end
		return n
	end
	-- Synchronise le jour UTC : compteurs des PNJ, semaine des quêtes, plumes (événement en cours ; connexion créditée une fois par jour).
	function L15.daySync(s)
		local d, t = s.data, today()
		Npc.rollDay(d.npc, t)
		Rewards.weeklySync(Config, d.weekly, Rewards.weekOf(t))
		local ev, key = Rewards.limitedEvent(Config, t)
		Rewards.plumeSync(Config, d.event, t, key)
		if ev and Rewards.plumeAdd(Config, d.event, "login", true) > 0 then
			notify(s.player, "🪶 " .. ev.name .. " : +" .. Config.PLUMES.login .. " plumes d'événement (connexion du jour).", "claim")
		end
		return ev
	end
	function L15.weekly(s, key, n)
		L15.daySync(s)
		Rewards.weeklyAdd(Config, s.data.weekly, key, n)
	end
	function L15.plume(s, source)
		local ev = L15.daySync(s)
		local got = Rewards.plumeAdd(Config, s.data.event, source, ev ~= nil)
		if got > 0 then
			notify(s.player, "🪶 +" .. got .. " plumes d'événement (" .. s.data.event.p .. ")")
		end
	end
	function L15.onHatch(s, tier)
		s.revealAt, s.revealTier = os.time(), tier
		if Config.tierAtLeast(tier, "fullCine") then
			s.cineUntil = os.clock() + 20 -- grande cinématique d'éclosion côté client : aucun PNJ pendant ce temps
		end
		L15.daySync(s)
		Rewards.bonusEvent(Config, s.data.weekly, today(), s.data.story.ch, L15.questsDone(s) >= 3, { kind = "hatch", tier = tier })
	end
	function L15.onPve(s)
		Lot7.L16.addXp(s, "pve") -- lot 16 : XP du passe de combat (victoire PvE : tour, PNJ, château), décidée par le serveur
		L15.daySync(s)
		Rewards.bonusEvent(Config, s.data.weekly, today(), s.data.story.ch, L15.questsDone(s) >= 3, { kind = "pve" })
		Rewards.weeklyAdd(Config, s.data.weekly, "pve", 1)
		L15.plume(s, "pve")
	end
	-- Type « en forme » de la semaine : +20 % d'attaque en PvE (tour, PNJ). Les types de Battle (Nature) suivent les noms de la rotation (Plante).
	function L15.boostUnits(units)
		local rot = Rewards.rotation(Config, Rewards.weekOf(today()))
		for _, u in ipairs(units) do
			local ty = u.type == "Nature" and "Plante" or u.type
			local mul = Rewards.typeDamage(Config, rot, ty, true)
			if mul ~= 1 then
				u.atk = math.floor(u.atk * mul + 0.5)
			end
		end
	end

	---------------------------------------------------------------- PNJ : inventaire, contexte, emplacement, rencontre
	function L15.inv(s)
		local d = s.data
		local eq, team, pets, seen, teamTiers = {}, {}, {}, {}, {}
		for _, i in ipairs(d.equip) do
			eq[i] = true
		end
		for _, i in ipairs(d.battle.team) do
			team[i] = true
		end
		for i = 1, Config.SLOTS_MAX do
			local sl = d.slots[i]
			if sl and sl.k == "p" then
				local def = false
				for _, e in ipairs(d.battle.pvp.defense) do -- défense PvP = copies : tout pet identique est protégé (prudent)
					if e.p == sl.p and e.s == sl.s and e.m == sl.m then
						def = true
					end
				end
				pets[#pets + 1] = { slot = i, p = sl.p, s = sl.s, m = sl.m, follower = eq[i] == true, team = team[i] == true, defense = def }
				if team[i] and Config.PETS[sl.p] then
					teamTiers[#teamTiers + 1] = Config.PETS[sl.p].tier
				end
			end
		end
		for k in pairs(d.dex) do
			local n = tonumber(k)
			if n then
				seen[n] = true
			end
		end
		return {
			coins = d.coins, pets = pets, seen = seen, avgLevel = 1, teamTiers = teamTiers,
			typeOf = function(p)
				local ty = Battle.SPECIES_TYPE[p]
				return ty == "Nature" and "Plante" or ty
			end,
		}
	end
	local function chased(player)
		for _, g in ipairs(world.guards) do
			if g.target == player and g.st and g.st.state == "chase" then
				return true
			end
		end
		return false
	end
	-- Point d'apparition : à approachRange studs du joueur, sur la place ou un chemin (zone « arena »), jamais dans un territoire ni sur une base, dans la carte.
	function L15.spot(root)
		local B = Config.Map2.bounds
		local px, pz = root.Position.X, root.Position.Z
		local a0 = rnd() * math.pi * 2
		for k = 0, 7 do
			local a = a0 + k * math.pi / 4
			local x, z = px + math.cos(a) * E.approachRange, pz + math.sin(a) * E.approachRange
			local ok = x > B.x0 + 10 and x < B.x1 - 10 and z > B.z0 + 10 and z < B.z1 - 10 and Config.zoneAt(x, z) == "arena"
			for _, pl in ipairs(world.plots) do
				if ok and pl.spawn and (Vector3.new(x, 0, z) - Vector3.new(pl.spawn.Position.X, 0, pl.spawn.Position.Z)).Magnitude < 34 then
					ok = false
				end
			end
			if ok then
				return x, z
			end
		end
		return nil
	end
	-- Contexte F.2 connu du serveur. « flying » = vol d'œuf en cours (appui long sur un nid ou un œuf) ; cinématique = grande éclosion récente.
	function L15.ctx(s, root)
		local zone = Config.zoneAt(root.Position.X, root.Position.Z)
		return {
			sessionStart = s.npcStart, carrying = #s.carry > 0, chased = chased(s.player), inDuel = s.battle ~= nil or s.pvpPending == true,
			inCastle = s.castle ~= nil or serverMode == "castle", inCinematic = os.clock() < (s.cineUntil or 0), flying = holds[s.player] ~= nil,
			inTerritory = zone ~= "arena", pending = L15.book(s).current ~= nil, lastRevealAt = s.revealAt, lastRevealTier = s.revealTier,
		}
	end
	local function offerText(o)
		if o.sub == "buy" then
			return Npc.say(Config, "pip", "offer1", { rarity = tierName(o.getEgg), price = Config.fmt(o.price) })
		elseif o.sub == "dupes" then
			return Npc.say(Config, "pip", "offer2", { r = tierName(o.dupeTier), r2 = tierName(o.getEgg) })
		elseif o.sub == "species" then
			return Npc.say(Config, "nora", "offer", { species = Config.PETS[o.getSpecies.p].name, dupe = Config.PETS[o.take[1].p].name, fee = Config.fmt(o.price) })
		end
		local names = {}
		for _, e in ipairs(o.team or {}) do
			local def = Config.PETS[e.p]
			names[#names + 1] = def and (def.emoji .. " " .. def.name) or "?"
		end
		return "Équipe adverse : " .. table.concat(names, ", ") .. (o.kind == "champion" and " · victoire = Œuf " .. tierName(o.guaranteedEgg) .. " garanti" or "")
	end
	-- Une tentative de rencontre (toutes les 5 s par joueur). Rien n'est consommé si elle échoue (Npc.encounter est atomique).
	function L15.tryEncounter(s)
		local root = getRoot(s.player)
		if not (root and alive(s.player)) then
			return
		end
		local d = s.data
		local now = os.time()
		local okSpawn = Npc.canSpawn(Config, d.npc, now, today(), L15.ctx(s, root))
		if not okSpawn then
			return
		end
		local x, z = L15.spot(root)
		if not x then
			return
		end
		local o = Npc.encounter(Config, d.npc, L15.book(s), s.player.UserId, now, today(), L15.ctx(s, root), L15.inv(s), rnd)
		if not o then
			return
		end
		local def = Config.NPCS[o.npc]
		L15.remote:FireClient(s.player, {
			k = "offer", id = o.id, npc = o.npc, kind = o.kind, name = def.name, emoji = def.emoji, model = o.npc,
			approach = Npc.say(Config, o.npc, "approach"), text = offerText(o), buttons = Config.DIALOGUES[o.npc].buttons,
			view = Npc.view(Config, o, Lot7.Odds), x = x, z = z, seconds = E.offerSeconds,
		})
		tele.log(s.player, "npc_encounter", 1, "_" .. o.npc)
	end
	function L15.tick(s, dt)
		s.npcT = (s.npcT or 0) + dt
		if s.npcT < 5 then
			return
		end
		s.npcT = 0
		L15.daySync(s)
		Npc.sweep(L15.book(s), os.time()) -- le PNJ repart sans pénalité après 60 s (le client le fait disparaître de son côté)
		L15.tryEncounter(s)
	end

	---------------------------------------------------------------- PNJ : réponses du joueur
	local function said(s, npcKey, text, ok)
		L15.remote:FireClient(s.player, { k = "said", npc = npcKey, text = text, ok = ok == true })
	end
	function L15.decline(s, id)
		local ok, res = Npc.decline(Config, s.data.npc, L15.book(s), id, s.player.UserId, os.time())
		if not ok then
			return said(s, nil, MSG[res] or MSG.unknown, false)
		end
		said(s, res.npc, res.gone and (Npc.say(Config, res.npc, "gone") ~= "" and Npc.say(Config, res.npc, "gone") or "Je ne reviendrai pas aujourd'hui. À demain !") or Npc.say(Config, res.npc, "refuse"), true)
	end
	-- Équipe adverse : 3 espèces existantes dont la puissance totale = puissance de l'équipe du joueur x powerMul (U(0,9 ; 1,1), Kaï x1,3).
	function L15.foes(o, mine)
		local pp, fp = 0, 0
		for _, u in ipairs(mine) do
			pp = pp + Battle.power(u)
		end
		for _, e in ipairs(o.team) do
			fp = fp + Battle.power(Battle.unit(Config, { p = e.p, s = 2, m = 1 }))
		end
		local scale = fp > 0 and math.clamp(pp * o.powerMul / fp, 0.2, 20) or 1
		local foes = {}
		for _, e in ipairs(o.team) do
			foes[#foes + 1] = Battle.unit(Config, { p = e.p, s = 2, m = 1 }, scale)
		end
		return foes
	end
	function L15.accept(s, id, confirm2)
		local d, book, now, uid = s.data, L15.book(s), os.time(), s.player.UserId
		local o = book.offers[id]
		if not o or o.userId ~= uid then
			return said(s, nil, MSG.unknown, false)
		end
		if o.kind == "trade" then
			local freed = 0
			for _, t in ipairs(o.take) do
				if t.slot <= cap(s) then
					freed = freed + 1
				end
			end
			if o.getEgg and Rewards.freeSlots(d.slots, cap(s)) + freed + (Lot7.L16.bagCfg(s).EGG_BAG.size - #d.eggBag) < 1 then
				return said(s, o.npc, MSG.bagFull, false)
			end
			local ok, eff = Npc.accept(Config, book, id, uid, now, L15.inv(s), { confirm2 = confirm2 })
			if not ok then
				if eff == "confirm2" then
					return L15.remote:FireClient(s.player, { k = "confirm2", id = id })
				end
				return said(s, o.npc, MSG[eff] or MSG.unknown, false)
			end
			-- effet appliqué EN UNE FOIS (aucune attente entre le retrait et le don) ; l'offre est déjà retirée du carnet : aucun rejeu possible
			d.coins = d.coins + eff.coins
			for _, i in ipairs(eff.take) do
				d.slots[i] = false
			end
			local got = {}
			if eff.species then
				local i = eff.take[1]
				local sp = eff.species
				local odds = Lot7.Odds.forPet(Config, sp.p, sp.s, sp.m)
				d.slots[i] = { k = "p", p = sp.p, s = sp.s, m = sp.m, o = odds, ov = odds and Config.ODDS.version or nil }
				local key = tostring(sp.p)
				if not d.dex[key] then
					d.dex[key] = { n = 0, b = 0 }
					s.species = s.species + 1
					qp(s, "discover", 1)
				end
				d.dex[key].n = d.dex[key].n + 1
				d.dex[key].b = math.max(d.dex[key].b, Config.SIZES[sp.s].mult * Config.MUTS[sp.m].mult)
				got[#got + 1] = Config.PETS[sp.p].emoji .. " " .. Config.PETS[sp.p].name
			end
			for _, i in ipairs(eff.take) do
				refreshPad(s, i)
			end
			if eff.egg then
				local where = L15.storeEggs(s, { eff.egg }) -- place garantie (vérifiée avant l'acceptation, les emplacements donnés sont libérés)
				got[#got + 1] = "🥚 Œuf " .. tierName(eff.egg) .. ((where and where[1] == "bag") and " (dans ton sac d'œufs)" or "")
			end
			rebuildFollowers(s)
			Npc.noteAccepted(d.npc, eff.npc)
			L15.weekly(s, "npc", 1)
			L15.qk(s, "npcTrade") -- A11 : échange de PNJ conclu (offre déjà retirée du carnet)
			said(s, eff.npc, "Marché conclu ! Tu reçois : " .. table.concat(got, ", ") .. ".", true)
			notify(s.player, "🤝 Échange avec " .. Config.NPCS[eff.npc].name .. " : " .. table.concat(got, ", "), "claim")
			tele.log(s.player, "npc_trade", 1, "_" .. eff.npc)
			sync(s)
			saveSoon(s)
			return
		end
		-- combat (Lina, Bruno) ou Champion errant (Kaï)
		if s.battle or s.castle or s.pvpPending then
			return said(s, o.npc, "Termine d'abord ce que tu fais, je t'attends !", false)
		end
		local mine = battleUnits(s)
		if #mine == 0 then
			return said(s, o.npc, "Compose d'abord ton équipe de pets (bouton ⚔️ Arène), puis reviens me voir !", false)
		end
		if o.kind == "champion" and not Rewards.canStore(Lot7.L16.bagCfg(s), d.slots, cap(s), d.eggBag, 1) then
			return said(s, o.npc, MSG.bagFull, false)
		end
		local ok, acc = Npc.accept(Config, book, id, uid, now, L15.inv(s), {})
		if not ok then
			return said(s, o.npc, MSG[acc] or MSG.unknown, false)
		end
		local foes = L15.foes(acc, mine)
		L15.boostUnits(mine)
		local def = Config.NPCS[acc.npc]
		s.battle = { st = Battle.new(rng:NextInteger(1, 2147483000), mine, foes), floor = 0, npc = { id = acc.id, key = acc.npc, name = def.emoji .. " " .. def.name }, deadline = os.clock() + TW.turnSeconds }
		L15.remote:FireClient(s.player, { k = "fight", id = acc.id })
		RBattle:FireClient(s.player, { k = "start", floor = 0, foe = def.emoji .. " " .. def.name, npc = true, view = Battle.view(s.battle.st), seconds = TW.turnSeconds })
	end
	-- Fin d'un combat de PNJ (appelé par battleFinish, s.battle déjà vidé). Npc.resolve est à usage unique : la récompense ne peut pas être versée deux fois.
	function L15.fightEnd(s, bt, win)
		local d = s.data
		local ok, out = Npc.resolve(Config, L15.book(s), bt.npc.id, s.player.UserId, os.time(), win)
		local rewards = {}
		local text = ""
		local pickAfter = false
		if ok then
			if out.won then
				L15.onPve(s)
				L15.qk(s, "pveWin", { rewarded = true, units = bt.st.sides[1].units, weekType = Rewards.rotation(Config, Rewards.weekOf(today())).type }) -- A11 : victoire de PNJ (Npc.resolve : une fois)
				local coins = math.floor(math.max(Config.STREAK.coinFloor, income(s) * 300) * (out.rewardMul or 1))
				d.coins = d.coins + coins
				rewards.coins = coins
				local eggT = out.egg
				if not eggT and out.cardEgg and rnd() * 100 < (out.cardPct or 0) then
					eggT = out.cardEgg
				end
				if eggT then
					if L15.storeEggs(s, { eggT }) then
						rewards.egg = eggT
					else
						local c2 = math.floor(Config.eggCoinValue(eggT) * 0.5)
						d.coins = d.coins + c2
						rewards.coins = coins + c2
					end
				end
				text = Npc.say(Config, out.npc, "win")
			else
				-- défaite : rien n'est perdu ; l'XP de pet (PetXp) est versée plus bas, victoire ou défaite
				text = Npc.say(Config, out.npc, "lose", { tip = Npc.tip(Config, { npc = out.npc }) })
			end
			L15.PetXp.addToTeam(d.slots, d.battle.team, L15.PetXp.award("npc", L15.PetXp.combat("npc", out.won, 0), L15.PetXp.boostMul(d, os.time()))) -- lot 12 B : XP de pet (PNJ), seule source d'XP
			if out.won then
				L15.offerPick(s, 0, "npc") -- lot 12 B : 3 cartes (valeurs x0,6) après une victoire contre un PNJ
				rewards.pick = true
				pickAfter = true
			end
			L15.weekly(s, "npc", 1)
			tele.log(s.player, "npc_fight", out.won and 1 or 0, "_" .. out.npc)
		end
		RBattle:FireClient(s.player, { k = "end", win = win, rewards = rewards, best = d.battle.best, floor = 0, npc = true, foe = bt.npc.name, view = Battle.view(bt.st) })
		if pickAfter then
			L15.sendPick(s)
		end
		if text ~= "" then
			said(s, bt.npc.key, text, win)
		end
		RState:FireClient(s.player, snapshot(s))
		saveSoon(s)
	end
	function actions.npcAnswer(s, arg)
		if type(arg) ~= "table" or type(arg.id) ~= "string" or #arg.id > 48 then
			return
		end
		if arg.action == "decline" then
			L15.decline(s, arg.id)
		elseif arg.action == "accept" then
			L15.accept(s, arg.id, arg.confirm2 == true)
		end
	end
	-- « Ne plus être interpellé » : réglage sauvegardé ; l'activer retire aussi l'offre en cours (sans pénalité).
	function actions.npcOff(s, v)
		if type(v) ~= "boolean" then
			return
		end
		s.data.npc.off = v
		if v then
			local book = L15.book(s)
			if book.current then
				book.offers[book.current] = nil
				book.current = nil
			end
			L15.remote:FireClient(s.player, { k = "clear" })
		end
		notify(s.player, v and "🤫 Les PNJ ne t'interpelleront plus (réglage dans Plus)." or "👋 Les PNJ peuvent de nouveau t'interpeller.")
		sync(s)
	end

	---------------------------------------------------------------- Série de 7 jours, sac d'œufs, quêtes bonus et de la semaine, plumes
	local STREAK_MSG = {
		done = "🔥 Série déjà réclamée aujourd'hui : reviens demain !", rescue = "🔥 Ta série va se perdre : choisis comment la sauver (menu Bonus).",
		noQuest = "🔥 Termine d'abord les 3 missions du jour pour sauver ta série gratuitement.", noProduct = "🔥 Le sauvetage payant a déjà servi cette semaine.",
		bagFull = "🔥 Ta base et ton sac d'œufs sont pleins : libère une place, ta récompense t'attend (rien n'est perdu).",
	}
	-- Réclame la série du jour. how : nil, "quest", "reset" (client) ou "product" (reçu StreakRestore vérifié). Retourne (true) ou (false, code).
	function L15.streakClaim(s, how)
		if s.streakBusy then
			return false, "busy"
		end
		s.streakBusy = true
		local d = s.data
		local g = { daily = d.daily, streak = d.streak, grace = d.grace }
		local ctx = { income = income(s), vip = s.passes.VipBase == true, questsDone = L15.questsDone(s), slots = d.slots, cap = cap(s), bag = d.eggBag, mkEgg = L15.mkEgg(s) }
		local before = {}
		for i = 1, cap(s) do
			before[i] = not d.slots[i]
		end
		local ok, res = Rewards.streakClaim(Lot7.L16.bagCfg(s), g, today(), how, ctx)
		s.streakBusy = nil
		if not ok then
			if how ~= "product" then
				notify(s.player, STREAK_MSG[res] or STREAK_MSG.done, "refuse")
				sync(s)
			end
			return false, res
		end
		d.daily, d.streak = g.daily, g.streak
		for i = 1, cap(s) do
			if before[i] and d.slots[i] then
				refreshPad(s, i)
			end
		end
		local gr, bits = res.grant, {}
		if gr.coins > 0 then
			d.coins = d.coins + gr.coins
			bits[#bits + 1] = "🪙 " .. Config.fmt(gr.coins)
		end
		for _, t in ipairs(gr.eggs) do
			bits[#bits + 1] = "🥚 Œuf " .. tierName(t)
		end
		if gr.luck then
			d.luckUntil = math.max(os.time(), d.luckUntil) + gr.luck.minutes * 60
			bits[#bits + 1] = "🧪 Potion de chance " .. gr.luck.minutes .. " min"
		end
		if gr.boost then
			d.xp2Until = math.max(os.time(), d.xp2Until) + gr.boost.minutes * 60
			bits[#bits + 1] = "📜 XP x" .. gr.boost.mul .. " " .. gr.boost.minutes .. " min"
		end
		if gr.fragments > 0 then
			d.puzzle.fragments = d.puzzle.fragments + gr.fragments
			bits[#bits + 1] = "🧩 +" .. gr.fragments .. " fragment du Grand Œuf"
		end
		local bagged = false
		for _, w in ipairs(res.where or {}) do
			bagged = bagged or w == "bag"
		end
		notify(s.player, "🔥 Série jour " .. res.day .. "/7" .. (res.state == "grace" and " (jour de grâce utilisé)" or "") .. " : " .. table.concat(bits, " · ") .. (bagged and " (œuf rangé dans ton sac)" or ""), res.day == #Config.STREAK.days and "calendar_milestone" or "calendar_claim")
		tele.log(s.player, "streak_claim", res.day, "_" .. tostring(res.state))
		sync(s)
		saveSoon(s)
		return true
	end
	function actions.bagPlace(s)
		local d = s.data
		local ok, tier, i = Rewards.bagTake(d.slots, cap(s), d.eggBag, L15.mkEgg(s))
		if not ok then
			notify(s.player, tier == "empty" and "🎒 Ton sac d'œufs est vide." or "🎒 Ta base est pleine : libère un emplacement pour poser l'œuf.", "refuse")
			return
		end
		refreshPad(s, i)
		notify(s.player, "🎒 Œuf " .. tierName(tier) .. " posé dans ta base.", "claim")
		sync(s)
	end
	local function eggsText(gr)
		local bits = {}
		for _, t in ipairs(gr.eggs) do
			bits[#bits + 1] = "Œuf " .. tierName(t)
		end
		return table.concat(bits, ", ")
	end
	local function store(s)
		local before = {}
		for i = 1, cap(s) do
			before[i] = not s.data.slots[i]
		end
		return { slots = s.data.slots, cap = cap(s), bag = s.data.eggBag, mkEgg = L15.mkEgg(s) }, before
	end
	local function refreshFilled(s, before)
		for i = 1, cap(s) do
			if before[i] and s.data.slots[i] then
				refreshPad(s, i)
			end
		end
	end
	function actions.bonusClaim(s)
		L15.daySync(s)
		local st, before = store(s)
		local ok, gr = Rewards.bonusClaim(Lot7.L16.bagCfg(s), s.data.weekly, today(), s.data.story.ch, st)
		if not ok then
			notify(s.player, gr == "claimed" and "⭐ Quête bonus déjà réclamée aujourd'hui." or (gr == "bagFull" and MSG.bagFull or "⭐ Quête bonus pas encore terminée."), "refuse")
			return
		end
		refreshFilled(s, before)
		notify(s.player, "⭐ Quête bonus : " .. eggsText(gr), "claim")
		sync(s)
		saveSoon(s)
	end
	function actions.weeklyClaim(s, which)
		if which ~= 5 and which ~= 7 then
			return
		end
		L15.daySync(s)
		local st, before = store(s)
		local ok, gr = Rewards.weeklyClaim(Lot7.L16.bagCfg(s), s.data.weekly, which, st)
		if not ok then
			notify(s.player, gr == "claimed" and "📆 Récompense de la semaine déjà réclamée." or (gr == "bagFull" and MSG.bagFull or "📆 Pas encore assez de quêtes de la semaine terminées."), "refuse")
			return
		end
		refreshFilled(s, before)
		local sx = (gr.seasonXp or 0) > 0 and Lot7.L16.addXp(s, "weekly") or nil -- lot 16 : quêtes de la semaine 7/7 -> XP du passe de combat (remplace l'ancien seasonXp)
		notify(s.player, "📆 Quêtes de la semaine " .. which .. "/7 : " .. eggsText(gr) .. ((sx and sx.gained > 0) and (" + " .. sx.gained .. " XP de passe de combat") or ""), "claim")
		sync(s)
		saveSoon(s)
	end
	function actions.plumeBuy(s)
		local ev = L15.daySync(s)
		local st, before = store(s)
		local ok, t = Rewards.plumeBuyExclusive(Lot7.L16.bagCfg(s), s.data.event, ev ~= nil, st, Lot7.L16.openEv(os.time()))
		if not ok then
			local m = { inactive = "🪶 Aucun événement en cours.", limit = "🪶 Tu as déjà obtenu le maximum d'Œufs Exclusifs de cet événement.", plumes = "🪶 Il te faut " .. Config.PLUMES.exclusiveCost .. " plumes d'événement.",
				notLive = "🪶 L'Œuf Exclusif arrive bientôt : garde tes plumes pour cet événement.", closed = "🪶 Aucune espèce Exclusif n'est disponible pendant cet événement : garde tes plumes.", bagFull = MSG.bagFull }
			notify(s.player, m[t] or m.inactive, "refuse")
			return
		end
		refreshFilled(s, before)
		notify(s.player, "🪶 Œuf " .. tierName(t) .. " obtenu contre " .. Config.PLUMES.exclusiveCost .. " plumes !", "jackpot_rare")
		sync(s)
		saveSoon(s)
	end
	-- Vue envoyée au client (snapshot) : série, récompenses des 7 jours, sac, quêtes bonus et de la semaine, événements, rotation, réglage PNJ.
	function L15.view(s)
		local d, t = s.data, today()
		L15.daySync(s)
		local plan = Rewards.streakPlan(Config, { daily = d.daily, streak = d.streak, grace = d.grace }, t, { questsDone = L15.questsDone(s) })
		local days = {}
		for i = 1, #Config.STREAK.days do
			local gr = Rewards.streakReward(Config, i, d.grace.weeks, income(s), s.passes.VipBase == true)
			days[i] = { eggs = gr.eggs, coins = gr.coins, luck = gr.luck and gr.luck.minutes or nil, boost = gr.boost and gr.boost.minutes or nil, fragments = gr.fragments, mythic = gr.mythicWeek }
		end
		local q = Rewards.bonusQuest(Config, t, d.story.ch)
		local bq = (type(d.weekly.bq) == "table" and d.weekly.bq.d == t) and d.weekly.bq or { prog = 0, claimed = false }
		local themes = {}
		for i, th in ipairs(Config.QUESTS.weekly.themes) do
			themes[i] = { text = th.text, prog = d.weekly.prog[i], goal = th.goal }
		end
		local act = Rewards.activeEvents(Config, os.time())
		local rot = Rewards.rotation(Config, Rewards.weekOf(t))
		local exIdx = Rewards.tierIdx(Config, Config.PLUMES.exclusiveName)
		return {
			streak = { state = plan.state, day = plan.day, missed = plan.missed, streak = plan.streak, canQuest = plan.canQuest == true, canProduct = plan.canProduct == true and Config.purchasable(Config.PRODUCTS.StreakRestore), lost = plan.lost, weeks = d.grace.weeks, graceFree = not (d.grace.week == Rewards.weekOf(t) and d.grace.used >= 1) },
			days = days, bag = #d.eggBag, bagMax = Lot7.L16.bagCfg(s).EGG_BAG.size, questsDone = L15.questsDone(s),
			bonus = { text = q.text, prog = math.min(bq.prog, q.goal), goal = q.goal, egg = q.egg, unlocked = L15.questsDone(s) >= 3, claimed = bq.claimed == true },
			weekly = { themes = themes, done = Rewards.weeklyDone(Config, d.weekly), c5 = d.weekly.c5, c7 = d.weekly.c7 },
			ev = { weekend = act.weekend, golden = act.golden, limited = act.limited and act.limited.name or nil, plumes = d.event.p, got = d.event.x, cost = Config.PLUMES.exclusiveCost, max = Config.PLUMES.maxExclusivePerEvent, exclusiveLive = exIdx ~= nil and Config.tierLive(exIdx) },
			rot = { type = rot.type, featured = rot.featured },
			npcOff = d.npc.off == true,
		}
	end

	---------------------------------------------------------------- Modèles : PNJ publiés aux clients, calendrier mural, décor d'événement
	function L15.publishNpc(assets)
		local n = 0
		pcall(function()
			local folder = ReplicatedStorage:FindFirstChild("NpcTemplates") or Instance.new("Folder")
			folder.Name = "NpcTemplates"
			for key in pairs(Config.Assets.models.npc) do
				local clone = assets.cloneModel("npc", key)
				if clone then
					local old = folder:FindFirstChild(key)
					if old then
						old:Destroy()
					end
					clone.Name = key
					for _, dd in ipairs(clone:GetDescendants()) do
						if dd:IsA("BasePart") then
							dd.Anchored, dd.CanCollide, dd.CanQuery, dd.CanTouch = true, false, false, false
						end
					end
					clone.Parent = folder
					n = n + 1
				end
			end
			folder.Parent = ReplicatedStorage
		end)
		return n
	end
	-- Angle (degrés) qui tourne la face avant (-Z) d'un modèle posé en (x, z) vers le point (tx, tz) (sans math.atan2).
	local function faceDeg(x, z, tx, tz)
		local dx, dz = x - tx, z - tz
		local r = math.sqrt(dx * dx + dz * dz)
		if r < 1e-3 then
			return 0
		end
		local a = math.acos(math.clamp(dz / r, -1, 1))
		return math.deg(dx < 0 and -a or a)
	end
	-- Calendrier mural (hub.calendar) à côté du kiosque, tourné vers la place ; prompt « Calendrier » validé par Kiosk.handle (même action que le kiosque).
	function L15.placeCalendar(assets)
		if not K8.world or K8.world:FindFirstChild("CalendarBoard") then
			return false
		end
		local model = assets.cloneModel("hub", "calendar")
		if not model then
			return false
		end
		local K, B, P = Config.Map2.kiosk, Config.CALENDAR_BOARD, Config.Map2.plaza
		local x, z = K.x + B.dx, K.z + B.dz
		model.Name = "CalendarBoard"
		if not assets.place(model, x, z, faceDeg(x, z, P.x, P.z), B.height, K8.world) then
			return false
		end
		local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local pr = Instance.new("ProximityPrompt")
			pr.Name = "KioskPrompt_calendarBoard"
			pr.ActionText, pr.ObjectText, pr.HoldDuration, pr.MaxActivationDistance, pr.RequiresLineOfSight = "Calendrier", "📅 Calendrier des œufs", 0, 12, false
			pr:SetAttribute("KioskAction", "calendar")
			CollectionService:AddTag(pr, "KioskPrompt")
			pr.Parent = part
		end
		return true
	end
	-- Décor de l'événement limité du jour (EVENTS_CAL) : modèle Blender ou repli procédural ; retiré à la fin de l'événement. force = reconstruire.
	function L15.placeEventDecor(force)
		if not K8.world then
			return
		end
		local ev = Rewards.limitedEvent(Config, today())
		local key = ev and ev.decor or ""
		if L15.decorKey == key and not force then
			return
		end
		L15.decorKey = key
		local old = K8.world:FindFirstChild("EventDecor")
		if old then
			old:Destroy()
		end
		if not ev then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "EventDecor"
		folder.Parent = K8.world
		local spot, mk = Config.EVENT_DECOR_SPOT, Config.EVENT_DECOR[key]
		local model = mk and L15.assets and L15.assets.cloneModel("event", mk)
		if model and L15.assets.place(model, spot.x, spot.z, faceDeg(spot.x, spot.z, 0, 0), spot.height, folder) then
			return
		end
		local ball = Instance.new("Part") -- repli procédural : une grosse boule aux couleurs de l'événement et son nom
		ball.Name = "EventDecorFallback"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(6, 6, 6)
		ball.Anchored, ball.CanCollide = true, false
		ball.Material = Enum.Material.SmoothPlastic
		ball.Color = ev.id == "halloween" and Color3.fromRGB(255, 140, 30) or (ev.id == "xmas" and Color3.fromRGB(40, 160, 70) or Color3.fromRGB(255, 170, 220))
		ball.Position = Vector3.new(spot.x, 3, spot.z)
		ball.Parent = folder
		local bb = Instance.new("BillboardGui")
		bb.Size, bb.StudsOffset, bb.MaxDistance = UDim2.fromOffset(220, 40), Vector3.new(0, 5, 0), 80
		bb.Parent = ball
		local lbl = Instance.new("TextLabel")
		lbl.Size, lbl.BackgroundTransparency, lbl.Text, lbl.TextScaled, lbl.Font, lbl.TextColor3 = UDim2.fromScale(1, 1), 1, "🎉 " .. ev.name, true, Enum.Font.GothamBold, Color3.new(1, 1, 1)
		lbl.Parent = bb
	end
	L15.placeEventDecor(false)
	task.spawn(function()
		while true do
			task.wait(600)
			pcall(L15.placeEventDecor, false)
		end
	end)
end

function actions.ravenList(s)
	return Lot7.ravenList(s)
end
function actions.ravenGo(s, arg)
	return Lot7.ravenGo(s, arg)
end
function actions.setBlockRavens(s, v)
	return Lot7.setBlockRavens(s, v)
end

---------------------------------------------------------------- Lot 7 : Corbeau chipeur, tapis privé, bonus serveur, PolicyService
-- Tout est décidé ICI, par le serveur : le client n'envoie que des intentions (ravenList, ravenGo { u, i }, setBlockRavens), jamais un contexte. Les règles pures sont dans
-- Raven.lua (canLaunch, settle, compensation...), testées une par une ; ce bloc construit les contextes d'après les sessions et applique les décisions.
do
	local RV = Config.REMOTE_STEAL
	local flights = {} -- [Player voleur] = vol en cours (un seul par voleur)
	local bySlot = {} -- [Player victime] = { [emplacement] = vol } : un seul corbeau par œuf
	local ravensFolder = Instance.new("Folder")
	ravensFolder.Name = "Ravens"
	ravensFolder.Parent = workspace

	local MSG = {
		invalid = "🐦‍⬛ Cible invalide.", self = "🐦‍⬛ Tu ne peux pas viser ta propre base.", noToken = "🐦‍⬛ Tu n'as plus de jeton de corbeau (Bonus > Corbeau chipeur).",
		alreadyFlying = "🐦‍⬛ Ton corbeau est déjà en vol.", dailyLimit = "🐦‍⬛ Limite atteinte : " .. RV.dailyMax .. " vols à distance réussis par jour.",
		castle = "🐦‍⬛ Pas de corbeau dans le mode Château.", newbie = "🐣 Protection débutant : pas de corbeau pour toi, ni contre toi.",
		tooYoung = "🐦‍⬛ Le corbeau demande " .. RV.minPlayMinutes .. " min de jeu à toi et " .. RV.victimMinMinutes .. " min à ta cible.",
		accountAge = "🐦‍⬛ Le corbeau demande un compte Roblox de " .. RV.minAccountAgeDays .. " jours au moins, pour toi comme pour ta cible.", recentlyStolen = "🛡 Cet œuf vient d'être volé par un corbeau : il est protégé un moment.", noSlot = "🐦‍⬛ Libère un emplacement dans ta base d'abord.",
		levelGap = "🐦‍⬛ Cette base est trop petite pour ton corbeau.", victimShield = "🛡 Cette base est protégée pour l'instant.", victimCooldown = "🛡 Cette base a déjà reçu un corbeau récemment.",
		grace = "🛡 Ce joueur vient d'arriver : ses œufs sont protégés.", friendBlocked = "🐦‍⬛ Ce joueur refuse les corbeaux de ses amis.", notEgg = "🐦‍⬛ Il faut un œuf en incubation.",
		tier = "🐦‍⬛ Cet œuf est trop rare pour un corbeau.", eggShield = "🛡 Cet œuf est encore protégé.", tooLate = "🐦‍⬛ Cet œuf éclôt trop bientôt.",
		targeted = "🐦‍⬛ Un corbeau vise déjà cet œuf.", gone = "🐦‍⬛ Joueur ou œuf introuvable.", busy = "🐦‍⬛ Patiente un instant.", cooldown = "🐦‍⬛ Ton corbeau se repose : encore quelques secondes.",
	}

	local function inCastleMode(s)
		return s.castle ~= nil or serverMode == "castle"
	end
	local function rollDaily(d)
		d.raven.day, d.raven.n = Raven.rollDaily(d.raven.day, d.raven.n, os.time())
	end
	function Lot7.ravenLeft(s) -- vols à distance restants aujourd'hui (sans modifier le profil)
		local _, n = Raven.rollDaily(s.data.raven.day, s.data.raven.n, os.time())
		return math.max(0, RV.dailyMax - n)
	end
	function Lot7.serverBuffs()
		return { golden = math.floor(Belt.goldenLeft(beltSt, os.clock())), luck = math.max(0, math.floor(Lot7.luckUntil - os.time())), luckBy = Lot7.luckBy, goldenBy = beltSt.goldenBy }
	end

	-- Journal serveur : print + DataStore RavenLog (en arrière-plan, jamais bloquant). File BORNÉE (Config.REMOTE_STEAL.logQueueMax : au-delà, la plus ancienne entrée est jetée avec un
	-- avertissement) vidée par UN seul travailleur, par lots de logBatch entrées ; Data.logRavenBatch réessaie un nombre borné de fois, un lot définitivement échoué est abandonné (journal
	-- de secours : les warn/print serveur). Un DataStore lent ou en panne ne peut donc ni bloquer le jeu ni faire grossir la mémoire.
	local logQueue, logWorker = {}, false
	Lot7.logDropped = 0
	function Lot7.logPending()
		return #logQueue + (logWorker and 1 or 0)
	end
	local function pumpLog()
		if logWorker then
			return
		end
		logWorker = true
		task.spawn(function()
			while #logQueue > 0 do
				local batch = {}
				while #logQueue > 0 and #batch < RV.logBatch do
					batch[#batch + 1] = table.remove(logQueue, 1)
				end
				local ok, res = pcall(Data.logRavenBatch, batch)
				if not (ok and res) then
					Lot7.logDropped += #batch
					warn("[Raven] journal : lot de " .. #batch .. " entrée(s) abandonné après essais (" .. tostring(ok and res or res) .. ")")
				end
			end
			logWorker = false
		end)
	end
	function Lot7.logEnqueue(entry)
		if #logQueue >= RV.logQueueMax then
			table.remove(logQueue, 1)
			Lot7.logDropped += 1
			warn("[Raven] journal : file pleine (" .. RV.logQueueMax .. "), entrée la plus ancienne jetée")
		end
		logQueue[#logQueue + 1] = entry
		pumpLog()
	end
	local function logEvent(f, result)
		print(string.format("[Raven] %s (%d) -> %s (%d) : œuf %s, résultat %s", f.thiefName, f.thiefId, f.victimName, f.victimId, Config.TIERS[f.tier].name, result))
		Lot7.logEnqueue({ thief = f.thiefId, thiefName = f.thiefName, victim = f.victimId, victimName = f.victimName, tier = f.tier, result = result, at = os.time() })
	end

	-- Amitié (appel réseau, avec cache de 5 min par session). Échec = considéré ami : le refus de la victime est respecté (repli prudent).
	local function friendsWith(s, other)
		s.friendCache = s.friendCache or {}
		local c = s.friendCache[other.UserId]
		if c and os.clock() - c.t < 300 then
			return c.v
		end
		local ok, res = pcall(function()
			return s.player:IsFriendsWith(other.UserId)
		end)
		local v = (not ok) or res == true
		s.friendCache[other.UserId] = { v = v, t = os.clock() }
		return v
	end

	-- Ancienneté du compte en jours : valeur d'origine incertaine (propriété Roblox) -> nombre ou 0 (refusé).
	local function ageDays(player)
		local ok, a = pcall(function()
			return player.AccountAge
		end)
		return (ok and type(a) == "number" and a == a) and a or 0
	end
	-- CONTEXTES de Raven.canLaunch : construits ICI d'après les sessions (aucun champ ne vient du client).
	local function thiefCtx(s)
		rollDaily(s.data)
		return { userId = s.player.UserId, tokens = s.data.tokens.remoteSteal, level = s.baseLevel or 1, playMinutes = s.data.played / 60, freeSlot = freeSlot(s) ~= nil,
			dailyDone = s.data.raven.n, flying = flights[s.player] ~= nil, newbie = isNewbie(s), inCastle = inCastleMode(s), accountAgeDays = ageDays(s.player) }
	end
	local function victimCtx(vs, friend)
		return { userId = vs.player.UserId, level = vs.baseLevel or 1, playMinutes = vs.data.played / 60, newbie = isNewbie(vs), inCastle = inCastleMode(vs), graceUntil = vs.graceUntil or 0,
			shieldUntil = vs.data.raven.sh, ravenCooldownUntil = vs.data.raven.cd, friendOfThief = friend == true, blockFriendRavens = vs.data.settings.blockFriendRavens == true, accountAgeDays = ageDays(vs.player) }
	end
	local function eggCtx(vs, i)
		local sl = vs.data.slots[i]
		if i > cap(vs) or type(sl) ~= "table" or sl.k ~= "e" then
			return nil
		end
		return { tier = sl.t, incubating = true, eggShieldUntil = sl.shield or 0, endsAt = sl.ends, rvAt = type(sl.rvAt) == "number" and sl.rvAt or nil }
	end

	function Lot7.addLog(vs, name, tier, kind)
		Raven.logPush(vs.data.stealLog, { n = string.sub(tostring(name), 1, 24), t = tier, at = os.time(), k = kind }, RV.logMax)
	end
	-- Vol PHYSIQUE subi : journal et bouclier post-vol de 5 min (il protège contre les corbeaux ; le vol physique garde ses propres règles).
	function Lot7.onPhysicalSteal(vs, thiefName, tier)
		Lot7.addLog(vs, thiefName, tier, "p")
		vs.data.raven.sh = math.max(vs.data.raven.sh, os.time() + RV.postStealShield)
	end

	---------------------------------------------------------------- Oiseau
	local function lerpPos(a, b, u)
		return a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u, a.z + (b.z - a.z) * u
	end
	local function placeBird(bird, x, y, z, ax, ay, az)
		local dx, dy, dz = ax - x, ay - y, az - z
		if dx * dx + dy * dy + dz * dz < 1e-4 then
			bird:PivotTo(CFrame.new(x, y, z))
		else
			bird:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(ax, ay, az)))
		end
	end
	local function moveBird(f, now)
		local bird = f.bird
		if not (bird and bird.Parent) then
			return
		end
		local t = (now - f.t0) / RV.flightSeconds
		local x, y, z = Raven.birdPos(f.from, f.to, t, 0.3)
		local ax, ay, az = Raven.birdPos(f.from, f.to, math.min(1, t + 0.06), 0.3)
		placeBird(bird, x, y, z, ax, ay, az)
		f.flap = not f.flap
		Builder.ravenFlap(bird, f.flap)
	end
	-- Départ après le vol (réussi : vers la base du voleur ; chassé : loin). Temporaire et borné : l'oiseau est TOUJOURS détruit à la fin.
	local function depart(bird, from, to, secs)
		if not bird then
			return
		end
		task.spawn(function()
			local t0, flap = os.clock(), false
			while bird.Parent and os.clock() - t0 < secs do
				local u = math.min(1, (os.clock() - t0) / secs)
				local x, y, z = lerpPos(from, to, u)
				placeBird(bird, x, y, z, to.x, to.y, to.z)
				flap = not flap
				Builder.ravenFlap(bird, flap)
				task.wait(0.1)
			end
			pcall(function()
				bird:Destroy()
			end)
		end)
	end

	---------------------------------------------------------------- Fin d'un vol
	local function release(f)
		flights[f.thief.player] = nil
		local list = bySlot[f.victim.player]
		if list then
			list[f.slot] = nil
			if next(list) == nil then
				bySlot[f.victim.player] = nil
			end
		end
	end
	local function refund(f)
		if f.refunded then
			return -- jamais deux fois
		end
		f.refunded = true
		local tk = f.thief.data.tokens
		tk.remoteSteal = math.min(RV.tokenMax, tk.remoteSteal + 1) -- le jeton en vol est compté dans le plafond d'achat : jamais perdu
	end

	local function finish(f, decision, reason)
		release(f) -- d'abord : plus aucun état partagé ne dépend de ce vol, même si la suite lève une erreur
		local s, vs = f.thief, f.victim
		local bird = f.bird
		f.bird = nil
		local result = decision == "aborted" and ("aborted:" .. reason) or decision
		if decision == "success" then
			local now = os.time()
			local rem = math.max(0, f.ref.ends - now)
			local ti = freeSlot(s)
			local rvv = vs.data.raven
			rvv.icDay, rvv.ic = Raven.rollDaily(rvv.icDay, rvv.ic, now) -- indemnités reçues aujourd'hui (jour UTC)
			local comp = Raven.indemnity(Config, f.tier, f.ref.rv == true, rvv.ic) -- 0 si l'œuf est non indemnisable ; plafonné par jour et par victime (lot 7b)
			-- 1. données (opérations de table seulement : rien ne peut échouer à mi-chemin)
			s.data.slots[ti] = { k = "e", t = f.tier, ends = now + rem, shield = now + shieldTime(s), rv = true, rvAt = now } -- temps restant conservé, bouclier d'œuf normal ; marqué : plus jamais indemnisé, pas de revol avant 20 min
			vs.data.slots[f.slot] = false
			vs.data.coins += comp
			rvv.ic += comp
			Lot7.compPaid += comp -- compteur de session (tests, journal)
			vs.data.raven.cd = now + RV.victimCooldown
			vs.data.raven.sh = math.max(vs.data.raven.sh, now + RV.postStealShield)
			rollDaily(s.data)
			s.data.raven.n += 1 -- compte aux 3 vols par jour ; ne compte PAS dans `stolen` ni dans les quêtes de vol (classement)
			Lot7.addLog(vs, f.thiefName, f.tier, "r")
			-- 2. visuels et messages (un échec ici ne défait pas le vol)
			local okV, errV = pcall(function()
				local pad = vs.plot.pads[f.slot].part
				refreshPad(vs, f.slot)
				refreshPad(s, ti)
				Builder.flyEgg(f.tier, pad.Position + Vector3.new(0, 2, 0), s.player.UserId)
				local tp = s.plot.pads[ti].part.Position
				depart(bird, f.to, { x = tp.X, y = tp.Y + 9, z = tp.Z }, 2)
				bird = nil
			end)
			if not okV then
				warn("[Raven] visuels : " .. tostring(errV))
			end
			if bird then
				pcall(function()
					bird:Destroy()
				end)
			end
			local tn = Config.TIERS[f.tier].name
			notify(vs.player, "🐦‍⬛ Le corbeau de " .. f.thiefName .. " a emporté ton œuf " .. tn .. ". " .. (comp > 0 and ("Tu reçois 🪙 " .. Config.fmt(comp)) or "Pas d'indemnité (œuf non indemnisable ou plafond du jour atteint)") .. " et " .. math.floor(RV.postStealShield / 60) .. " min à l'abri des corbeaux.", "caught")
			notify(s.player, "🐦‍⬛ Ton corbeau rapporte un œuf " .. tn .. " de " .. f.victimName .. " ! (temps restant conservé)", "steal")
		else
			refund(f) -- chassé ou annulé : jeton rendu, sans remboursement Robux
			if bird then
				if decision == "chased" then
					depart(bird, f.to, { x = f.to.x + 40, y = f.to.y + 30, z = f.to.z }, 1.5)
				else
					pcall(function()
						bird:Destroy()
					end)
				end
			end
			if decision == "chased" then
				notify(s.player, "🐦‍⬛ " .. f.victimName .. " a chassé ton corbeau. Jeton rendu.", "refuse")
				notify(vs.player, "🐦‍⬛ Tu as chassé le corbeau de " .. f.thiefName .. " !", "claim")
			elseif reason == "victimGone" then
				notify(s.player, "🐦‍⬛ " .. f.victimName .. " a quitté la partie : ton corbeau rentre. Jeton rendu.")
			elseif reason == "eggGone" then
				notify(s.player, "🐦‍⬛ L'œuf n'est plus là (éclos ou volé) : ton corbeau rentre. Jeton rendu.")
			elseif reason == "thiefGone" then
				notify(vs.player, "🐦‍⬛ Le corbeau de " .. f.thiefName .. " est reparti.")
			elseif reason == "castle" then
				notify(s.player, "🐦‍⬛ Un des deux joueurs est entré au Château : ton corbeau rentre. Jeton rendu.")
				notify(vs.player, "🐦‍⬛ Le corbeau de " .. f.thiefName .. " est reparti.")
			elseif reason == "newbie" then
				notify(s.player, "🐣 Protection débutant : ton corbeau rentre. Jeton rendu.")
			elseif reason == "shutdown" then
				notify(s.player, "🐦‍⬛ Le serveur ferme : ton corbeau rentre. Jeton rendu.")
			else
				notify(s.player, "🐦‍⬛ Le vol a échoué (" .. tostring(reason) .. "). Jeton rendu.", "refuse")
			end
		end
		RRaven:FireClient(vs.player, "end", { slot = f.slot, result = result })
		if sessions[s.player] == s and not s.leaving then
			RRaven:FireClient(s.player, "end", { slot = f.slot, result = result })
		end
		logEvent(f, result)
		if sessions[s.player] == s then
			sync(s)
		end
		if sessions[vs.player] == vs then
			sync(vs)
		end
	end

	local function worldOf(f, now)
		local s, vs = f.thief, f.victim
		local sl = vs.data.slots[f.slot]
		local still = sl == f.ref and type(sl) == "table" and sl.k == "e"
		local t = os.time()
		return { thiefHere = sessions[s.player] == s and not s.leaving, victimHere = sessions[vs.player] == vs and not vs.leaving, eggStill = still, eggLeft = still and (sl.ends - t) or 0,
			chased = f.chased, shielded = vs.data.raven.sh > t, thiefFreeSlot = freeSlot(s) ~= nil, now = now, endsAt = f.endsAt,
			inCastle = inCastleMode(s) or inCastleMode(vs), newbie = isNewbie(s) or isNewbie(vs) } -- château et protection débutant relus à chaque pas (lot 7b)
	end

	local function step()
		local now = os.clock()
		local list = {}
		for _, f in pairs(flights) do
			list[#list + 1] = f
		end
		for _, f in ipairs(list) do
			local ok, err = pcall(function()
				local decision, reason = Raven.settle(worldOf(f, now))
				if decision == "pending" and now > f.endsAt + 5 then
					decision, reason = "aborted", "timeout" -- filet de sécurité : un vol ne reste jamais bloqué
				end
				if decision == "pending" then
					moveBird(f, now)
				else
					finish(f, decision, reason)
				end
			end)
			if not ok then
				warn("[Raven] " .. tostring(err))
				if flights[f.thief.player] == f then
					pcall(finish, f, "aborted", "error")
					flights[f.thief.player] = nil
				end
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.1)
			if next(flights) then
				step()
			end
		end
	end)

	-- Départ d'un joueur : tout vol qui le concerne est annulé AVANT sa sauvegarde (le jeton du voleur lui est rendu dans son profil).
	function Lot7.onLeave(s)
		local list = {}
		for _, f in pairs(flights) do
			if f.thief == s or f.victim == s then
				list[#list + 1] = f
			end
		end
		for _, f in ipairs(list) do
			pcall(finish, f, "aborted", f.thief == s and "thiefGone" or "victimGone")
		end
		flights[s.player] = nil
		bySlot[s.player] = nil
		s.friendCache, s.priv = nil, nil
	end
	-- Fermeture du serveur (BindToClose, AVANT les sauvegardes) : tout vol en cours est annulé et son jeton rendu dans le profil, qui est sauvegardé juste après.
	function Lot7.abortAll()
		local list = {}
		for _, f in pairs(flights) do
			list[#list + 1] = f
		end
		for _, f in ipairs(list) do
			local ok, err = pcall(finish, f, "aborted", "shutdown")
			if not ok then
				warn("[Raven] abortAll : " .. tostring(err))
				release(f)
				refund(f) -- repli : le jeton est rendu quoi qu'il arrive (sans effet s'il l'a déjà été)
			end
		end
	end
	function Lot7.flightCount()
		local n, m = 0, 0
		for _ in pairs(flights) do
			n += 1
		end
		for _, l in pairs(bySlot) do
			for _ in pairs(l) do
				m += 1
			end
		end
		return n, m, #ravensFolder:GetChildren()
	end

	-- La victime touche son œuf (dans sa base) : le corbeau est chassé.
	function Lot7.chase(s, i)
		local list = bySlot[s.player]
		local f = list and list[i]
		if not f or f.chased then
			return
		end
		local root = getRoot(s.player)
		if not root or not alive(s.player) or not inPlot(s, root) then
			if os.clock() - (s.lastChaseMsg or -10) > 2 then
				s.lastChaseMsg = os.clock()
				notify(s.player, "🐦‍⬛ Reviens dans ta base pour chasser le corbeau !", "refuse")
			end
			return
		end
		f.chased = true -- résolu au prochain pas (0,1 s) par Raven.settle
	end

	---------------------------------------------------------------- Actions du client
	-- Liste des cibles : joueurs éligibles et leurs œufs éligibles (rareté et temps restant), calculée par le serveur avec les MÊMES règles que le lancement.
	function Lot7.ravenList(s)
		local clock = os.clock()
		if clock - (s.lastRavenList or -10) < RV.tryGap then
			return
		end
		s.lastRavenList = clock
		local cands = {}
		for _, vs in pairs(sessions) do
			if vs ~= s and not vs.leaving then
				cands[#cands + 1] = vs
			end
		end
		table.sort(cands, function(a, b)
			return a.player.UserId < b.player.UserId
		end)
		local friends = {}
		for _, vs in ipairs(cands) do
			friends[vs] = friendsWith(s, vs.player) -- peut attendre le réseau (mis en cache) : tout est relu ensuite
		end
		if sessions[s.player] ~= s or s.leaving then
			return
		end
		local t = thiefCtx(s)
		local now = os.time()
		local ideal = { userId = -1, level = t.level, playMinutes = 1e9, newbie = false, inCastle = false, graceUntil = 0, shieldUntil = 0, ravenCooldownUntil = 0, friendOfThief = false, blockFriendRavens = false, accountAgeDays = 1e9 }
		local okSelf, whySelf = Raven.canLaunch(Config, t, ideal, { tier = 1, incubating = true, eggShieldUntil = 0, endsAt = math.huge }, now)
		local targets = {}
		for _, vs in ipairs(cands) do
			if sessions[vs.player] == vs and not vs.leaving then
				local vctx = victimCtx(vs, friends[vs])
				local eggs = {}
				for i = 1, cap(vs) do
					local ectx = eggCtx(vs, i)
					if ectx and not (bySlot[vs.player] and bySlot[vs.player][i]) and Raven.canLaunch(Config, t, vctx, ectx, now) then
						eggs[#eggs + 1] = { i = i, t = ectx.tier, left = math.max(0, math.floor(ectx.endsAt - now)) }
					end
				end
				if #eggs > 0 then
					targets[#targets + 1] = { u = vs.player.UserId, name = vs.player.DisplayName, eggs = eggs }
				end
			end
		end
		RRaven:FireClient(s.player, "list", { tokens = s.data.tokens.remoteSteal, left = Lot7.ravenLeft(s), blocked = (not okSelf) and (MSG[whySelf] or MSG.invalid) or nil, targets = targets })
	end

	function Lot7.ravenGo(s, arg)
		if type(arg) ~= "table" then
			return
		end
		local uid, slot = arg.u, arg.i
		if type(uid) ~= "number" or uid % 1 ~= 0 or not validSlot(slot) then
			return
		end
		local clock = os.clock()
		if s.ravenBusy or clock - (s.lastRavenTry or -10) < RV.tryGap then
			return notify(s.player, MSG.busy, "refuse")
		end
		s.lastRavenTry = clock
		if clock - (s.lastRavenGo or -100) < RV.launchCooldown then
			return notify(s.player, MSG.cooldown, "refuse")
		end
		local vp = Players:GetPlayerByUserId(uid)
		local vs = vp and sessions[vp]
		if not vs or vs.leaving or vs == s then
			return notify(s.player, vs == s and MSG.self or MSG.gone, "refuse")
		end
		s.ravenBusy = true
		local friend = friendsWith(s, vp) -- seul point d'attente : tout ce qui suit est relu après lui
		s.ravenBusy = nil
		if sessions[s.player] ~= s or s.leaving or sessions[vp] ~= vs or vs.leaving then
			return
		end
		if bySlot[vp] and bySlot[vp][slot] then
			return notify(s.player, MSG.targeted, "refuse")
		end
		local ectx = eggCtx(vs, slot)
		if not ectx then
			return notify(s.player, MSG.notEgg, "refuse")
		end
		local ok, why = Raven.canLaunch(Config, thiefCtx(s), victimCtx(vs, friend), ectx, os.time())
		if not ok then
			return notify(s.player, MSG[why] or MSG.invalid, "refuse")
		end
		-- Décollage : le jeton est débité D'ABORD, avant toute construction ; si la construction échoue (erreur, pad introuvable...), il est rendu et rien n'est enregistré.
		local sl = vs.data.slots[slot]
		s.data.tokens.remoteSteal -= 1
		local f, bird
		local okF, errF = pcall(function()
			local pad = vs.plot.pads[slot].part
			local plaza = Config.Map2.plaza
			f = {
				thief = s, victim = vs, slot = slot, ref = sl, tier = sl.t, t0 = os.clock(), endsAt = os.clock() + RV.flightSeconds, chased = false, flap = false,
				thiefId = s.player.UserId, victimId = vp.UserId, thiefName = s.player.DisplayName, victimName = vp.DisplayName,
				from = { x = plaza.x, y = 30, z = plaza.z }, to = { x = pad.Position.X, y = pad.Position.Y + 12, z = pad.Position.Z },
			}
			local okB, b = pcall(Builder.raven, ravensFolder)
			bird = okB and b or nil -- sans oiseau visible le vol reste valable
			f.bird = bird
		end)
		if not okF then
			warn("[Raven] décollage impossible, jeton rendu : " .. tostring(errF))
			if bird then
				pcall(function()
					bird:Destroy()
				end)
			end
			s.data.tokens.remoteSteal = math.min(RV.tokenMax, s.data.tokens.remoteSteal + 1)
			return notify(s.player, "🐦‍⬛ Ton corbeau n'a pas pu décoller. Jeton rendu.", "refuse")
		end
		-- enregistrement (opérations de table seulement : ne peut pas échouer à mi-chemin)
		s.lastRavenGo = os.clock()
		vs.data.raven.cd = math.max(vs.data.raven.cd, os.time() + RV.victimFailCooldown) -- anti-harcèlement : 3 min de répit dès l'alerte ; les 20 min ne sont posées qu'en cas de SUCCÈS (finish)
		flights[s.player] = f
		bySlot[vp] = bySlot[vp] or {}
		bySlot[vp][slot] = f
		local okN, errN = pcall(function()
			local tn = Config.TIERS[sl.t].name
			RRaven:FireClient(vp, "alert", { who = f.thiefName, tier = sl.t, slot = slot, secs = RV.flightSeconds })
			notify(vp, "🐦‍⬛ Le corbeau de " .. f.thiefName .. " vise ton œuf " .. tn .. " ! Touche l'œuf pour le chasser (" .. RV.flightSeconds .. " s).", "caught")
			notify(s.player, "🐦‍⬛ Ton corbeau s'envole vers l'œuf " .. tn .. " de " .. f.victimName .. " (" .. RV.flightSeconds .. " s).", "event")
			RRaven:FireClient(s.player, "flight", { to = f.victimName, tier = sl.t, secs = RV.flightSeconds })
		end)
		if not okN then
			warn("[Raven] messages de décollage : " .. tostring(errN)) -- le vol est enregistré : il se règle normalement
		end
		logEvent(f, "launched")
		sync(s)
	end

	function Lot7.setBlockRavens(s, v)
		if type(v) ~= "boolean" then
			return
		end
		s.data.settings.blockFriendRavens = v
		sync(s)
	end

	---------------------------------------------------------------- Achats : jetons, tapis doré, pluie de chance
	-- Retourne true (livré), (false, message) = reçu NON traité (Roblox le rappellera : rien n'est perdu), ou nil si ce n'est pas un produit du lot 7.
	function Lot7.grant(s, name)
		local n = Raven.tokensFor(Config, name)
		if n > 0 then
			local held = Raven.held(s.data.tokens.remoteSteal, flights[s.player] ~= nil)
			if not Raven.canBuy(Config, held, n) then
				return false, "🐦‍⬛ Tu as déjà " .. held .. " jeton(s) : le maximum est " .. RV.tokenMax .. ". Utilise-en avant de finaliser cet achat (il sera livré automatiquement, rien n'est perdu)."
			end
			s.data.tokens.remoteSteal = Raven.addTokens(Config, s.data.tokens.remoteSteal, n)
			notify(s.player, "🐦‍⬛ +" .. n .. " jeton(s) de corbeau (" .. s.data.tokens.remoteSteal .. "/" .. RV.tokenMax .. ").", "buy")
			return true
		elseif name == "GoldenBelt" then
			local G = Config.BELT.golden
			local left, ok = Raven.stack(Belt.goldenLeft(beltSt, os.clock()), G.seconds, G.maxSeconds)
			if not ok then
				return false, "🌟 Le tapis doré est déjà presque au maximum (" .. Belt.clock(left) .. "). Ton achat sera livré dès qu'il y aura de la place, rien n'est perdu."
			end
			goldenBeltAdd(G.seconds, s.player.DisplayName)
			Lot7.goldenById = s.player.UserId
			announce("🌟 " .. s.player.DisplayName .. " offre le tapis doré à tout le serveur !")
			return true
		elseif name == "ServerLuck" then
			local L = Config.SERVER_LUCK
			local left, ok = Raven.stack(math.max(0, Lot7.luckUntil - os.time()), L.seconds, L.maxSeconds)
			if not ok then
				return false, "🌧️ La pluie de chance est déjà presque au maximum (" .. Config.fmtTime(left) .. "). Ton achat sera livré dès qu'il y aura de la place, rien n'est perdu."
			end
			Lot7.luckUntil, Lot7.luckBy, Lot7.luckById = os.time() + left, s.player.DisplayName, s.player.UserId
			announce("🌧️ " .. s.player.DisplayName .. " offre une pluie de chance : +" .. L.bonus .. " points d'amélioration pour tout le serveur pendant " .. math.floor(L.seconds / 60) .. " min !")
			return true
		end
		return nil
	end

	-- Bonus serveur et fermeture du serveur : la fin du tapis doré / de la pluie de chance est écrite (os.time) dans le profil du DERNIER donateur encore présent à la fermeture
	-- (BindToClose), puis rendue UNE fois (et effacée) à son arrivée sur un autre serveur. Un donateur déjà parti avant la fermeture n'a rien à restituer : limite documentée (CHANGELOG 7b).
	function Lot7.persistBuffs()
		local now = os.time()
		local gl = math.floor(Belt.goldenLeft(beltSt, os.clock()))
		local ll = math.floor(Lot7.luckUntil - now)
		for player, s in pairs(sessions) do
			if not s.noSave then
				if gl > 30 and Lot7.goldenById == player.UserId then
					s.data.srvBuff.g = now + gl
				end
				if ll > 30 and Lot7.luckById == player.UserId then
					s.data.srvBuff.l = now + ll
				end
			end
		end
	end
	function Lot7.restoreBuffs(s)
		local b, now = s.data.srvBuff, os.time()
		if type(b) ~= "table" then
			return
		end
		local G, L = Config.BELT.golden, Config.SERVER_LUCK
		local name, uid = s.player.DisplayName, s.player.UserId
		local gLeft, lLeft = (b.g or 0) - now, (b.l or 0) - now
		b.g, b.l = 0, 0 -- restitué une seule fois (jamais de duplication d'un serveur à l'autre)
		if gLeft > 30 then
			local add = math.min(gLeft, G.maxSeconds) - Belt.goldenLeft(beltSt, os.clock()) -- on ne cumule pas : le plus long des deux
			if add > 0 then
				goldenBeltAdd(add, name)
				Lot7.goldenById = uid
				announce("🌟 Le tapis doré de " .. name .. " est de retour : " .. Belt.clock(math.min(gLeft, G.maxSeconds)) .. " restantes pour tout le serveur !")
			end
		end
		if lLeft > 30 then
			local target = now + math.min(lLeft, L.maxSeconds)
			if target > Lot7.luckUntil then
				Lot7.luckUntil, Lot7.luckBy, Lot7.luckById = target, name, uid
				announce("🌧️ La pluie de chance de " .. name .. " est de retour : " .. Config.fmtTime(target - now) .. " restantes pour tout le serveur !")
			end
		end
	end

	---------------------------------------------------------------- PolicyService
	-- Passes à hasard : actives seulement si PolicyService a confirmé « non restreint » ET que le joueur les possède ; sinon forcées à faux (lot 7b).
	local function applyRandomPasses(s)
		for name, def in pairs(Config.PASSES) do
			if def.random == true then
				s.passes[name] = s.restricted == false and s.ownedRandom[name] == true
			end
		end
		Lot7.privRefresh(s)
		sync(s)
	end
	function Lot7.fetchPolicy(s)
		task.spawn(function()
			local ok, info = pcall(function()
				return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(s.player)
			end)
			if sessions[s.player] ~= s then
				return
			end
			if ok and type(info) == "table" then
				s.restricted = info.ArePaidRandomItemsRestricted ~= false -- seul « false » confirme que les offres à hasard sont permises
			elseif s.restricted == nil then
				s.restricted = true -- échec : repli prudent (offres à hasard masquées et refusées)
				warn("[Policy] " .. s.player.Name .. " : PolicyService indisponible, offres à hasard masquées")
			end
			applyRandomPasses(s)
		end)
		task.delay(8, function() -- délai dépassé : repli prudent (une réponse tardive pourra encore lever la restriction)
			if sessions[s.player] == s and s.restricted == nil then
				s.restricted = true
				applyRandomPasses(s)
			end
		end)
	end
	function Lot7.awaitPolicy(s) -- ProcessReceipt : attend (au plus 10 s) la réponse de PolicyService avant de décider
		local t0 = os.clock()
		while s.restricted == nil and os.clock() - t0 < 10 and sessions[s.player] == s do
			task.wait(0.25)
		end
		return s.restricted ~= false
	end

	---------------------------------------------------------------- Tapis privé (pass PrivateBelt)
	function Lot7.privRefresh(s)
		if passOn(s, "PrivateBelt") and s.plot and not s.leaving then
			Builder.privateBelt(s.plot, s.player.UserId, s.data.pb)
		elseif s.plot then
			Builder.clearPrivateBelt(s.plot)
		end
	end
	-- Un pas par seconde et par joueur (slowTick) : `active` = le joueur a agi ou bougé dans Config.IDLE.seconds. Joueur hors ligne = jamais appelé : aucune production hors ligne.
	function Lot7.privStep(s, dt, active)
		if not passOn(s, "PrivateBelt") then
			return
		end
		s.priv = s.priv or { acc = 0 }
		s.priv.pending = s.data.pb
		local tier = Belt.privateStep(Config, s.priv, dt, active, rnd())
		if tier then
			Lot7.privRefresh(s)
			notify(s.player, "🛤️ Un œuf " .. Config.TIERS[tier].name .. " t'attend sur ton tapis privé (gratuit).", "claim")
			sync(s)
		end
	end
	function Lot7.privTake(s, root, prompt)
		local now = os.clock()
		if now - (s.lastPriv or -10) < 0.25 then
			return
		end
		s.lastPriv = now
		if not passOn(s, "PrivateBelt") or prompt:GetAttribute("Owner") ~= s.player.UserId then
			return notify(s.player, "🛤️ Ce tapis n'est pas à toi.", "refuse")
		end
		local belt = s.plot and s.plot.privateBelt
		local strip = belt and belt:FindFirstChild("PrivateBeltStrip")
		if not strip or prompt.Parent ~= strip or (root.Position - strip.Position).Magnitude > 16 then
			return
		end
		local tier = s.data.pb[1]
		if not tier then
			return
		end
		local i = freeSlot(s)
		if not i then
			return notify(s.player, "Base pleine ! Libère un emplacement pour prendre l'œuf du tapis privé.", "refuse")
		end
		table.remove(s.data.pb, 1)
		s.data.slots[i] = { k = "e", t = tier, ends = os.time() + hatchTime(s, tier), shield = os.time() + shieldTime(s), rv = true } -- gratuit : non indemnisable (lot 7b)
		refreshPad(s, i)
		Lot7.privRefresh(s)
		notify(s.player, "🥚 Œuf " .. Config.TIERS[tier].name .. " pris sur ton tapis privé !", "claim")
		sync(s)
	end

	-- Crochet INTERNE pour les tests (jamais exposé aux clients) : accès aux sessions et compteurs.
	Builder.lot7Hooks = { session = function(p)
		return sessions[p]
	end, logEnqueue = Lot7.logEnqueue, logPending = Lot7.logPending, logDropped = function()
		return Lot7.logDropped
	end, luckPoints = luckPoints, passOn = passOn, flights = Lot7.flightCount, serverBuffs = Lot7.serverBuffs, compPaid = function()
		return Lot7.compPaid
	end, duel = function() -- lot 13 : état des duels (tests de bout en bout seulement)
		return L15.duel
	end, live = function() -- lot 14 : état du classé en direct (tests de bout en bout seulement)
		return Lot7.Live
	end, tele = function() -- lot 14 : télémétrie (échantillons de fréquentation)
		return tele
	end }
end

---------------------------------------------------------------- Lot 16 : boutique en 8 catégories, passe de combat, offres contextuelles, vendeurs, télémétrie
-- Tout vit dans Lot7.L16 (AUCUNE variable locale de plus au niveau du script : limite de 200). Le client n'envoie que des clés ou des numéros (shopBuy, shopEv,
-- seasonView, seasonClaim, seasonAck, overflowTake, emoteSet, offerClose) ; le serveur revalide tout : Shop.canBuy AVANT l'invite d'achat (rien n'est débité
-- si l'achat est refusé : base et sac pleins, possédé, PolicyService, rareté sans espèce), ProcessReceipt livre UNE fois par reçu (L16.grant), la saison
-- ne crédite que ce que Season décide (aucune valeur venue du client). Aucun produit ne touche les stats de combat, l'XP de pet (champ x), les boucliers ou les trophées.
do
	local L16 = Lot7.L16
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Shop = require(Shared:WaitForChild("Shop"))
	local SD = require(Shared:WaitForChild("SeasonData"))
	local S = require(Shared:WaitForChild("Season")).new(Config, SD)
	local Offers = require(Shared:WaitForChild("Offers"))
	local OffersData = require(Shared:WaitForChild("OffersData"))
	local LC = Config.LOT16
	L16.Shop, L16.Season = Shop, S
	local offerState = {} -- [Player] = état des offres de la session (jamais enregistré, libéré au départ)
	local gaps = {} -- [Player] = { [clé] = os.clock() } : pauses anti-rafale des demandes (libérées au départ)
	local bagPlus = setmetatable({ EGG_BAG = { size = Config.EGG_BAG.sizePlus } }, { __index = Config })

	-- A5 : fenêtres ouvertes des espèces d'événement / de saison (événement limité en cours, saison en cours), calculées par le SERVEUR seul.
	function L16.openEv(now)
		return L15.Rewards.openSpeciesEvents(Config, now, S.currentSeason(now).n)
	end
	-- Config vue par les règles du sac d'œufs : 20 places avec le passe EggBagPlus, 10 sinon.
	function L16.bagCfg(s)
		return (s and s.passes and s.passes.EggBagPlus == true) and bagPlus or Config
	end
	function L16.followerMax(s)
		return s.passes.Collector == true and Config.MAX_FOLLOWERS_COLLECTOR or Config.MAX_FOLLOWERS
	end
	-- Points de chance : Double chance = x2 puis 70 au plus ; sans elle, 70 au plus (= Rules.MAX_UP).
	function L16.luckTotal(points, doubled)
		return Shop.luckTotal(points, doubled)
	end
	function L16.hatchQualifies(tier)
		return S.hatchQualifies(tier)
	end
	-- Tickets d'arène du jour UTC en cours (combats de tour récompensés en plus).
	function L16.arenaExtra(s)
		local a = s.data.arenaTk
		return (type(a) == "table" and a.day == os.time() // 86400) and a.n or 0
	end
	local function gap(s, key, sec)
		local g = gaps[s.player]
		if not g then
			g = {}
			gaps[s.player] = g
		end
		local now = os.clock()
		if g[key] and now - g[key] < sec and now >= g[key] then
			return false
		end
		g[key] = now
		return true
	end
	local function restrictedFlag(s)
		return not (s.restricted == false) -- Shop / Offers : nil ou true = restreint (repli prudent), false = autorisé
	end
	local function ownedPasses(s)
		local out = {}
		for name in pairs(Config.PASSES) do
			out[name] = s.passes[name] == true or s.ownedRandom[name] == true
		end
		return out
	end
	-- Profil vu par Shop (forme du module pur) : base, sac, passes possédés, achats uniques, saison en cours.
	function L16.shopProfile(s)
		local d = s.data
		local se, cur = S.migrate(d, os.time())
		local once = {}
		for k, v in pairs(d.once) do
			once[k] = v
		end
		return { cap = cap(s), slots = d.slots, eggBag = d.eggBag, passes = ownedPasses(s), once = once, season = { cur = cur.n, premium = se.premium, plus = se.plus }, open = L16.openEv(os.time()) }
	end

	---------------------------------------------------------------- Rangement des œufs : base, puis sac, puis coffre de débordement (jamais de perte)
	function L16.storeEgg(s, tier)
		local where = L15.storeEggs(s, { tier })
		if where then
			return where[1]
		end
		Shop.overflowAdd(s.data, tier, 1)
		return "overflow"
	end
	function actions.overflowTake(s)
		if not gap(s, "ovf", 0.3) then
			return
		end
		local d = s.data
		for t = #Config.TIERS, 1, -1 do
			local k = tostring(t)
			local n = d.overflow[k]
			if type(n) == "number" and n > 0 then
				local where = L15.storeEggs(s, { t })
				if not where then
					return notify(s.player, Shop.MSG_ROOM, "refuse")
				end
				d.overflow[k] = n > 1 and n - 1 or nil
				notify(s.player, "📦 Œuf " .. Config.TIERS[t].name .. " sorti du coffre de débordement (" .. (where[1] == "slot" and "dans ta base" or "dans ton sac") .. ").", "claim")
				sync(s)
				return
			end
		end
	end

	---------------------------------------------------------------- Passe de combat (Season.lua décide de tout)
	local function coinsFor(s, minutes)
		return math.floor(math.max(Config.COIN_PACK_MIN * minutes / Config.COIN_PACK_MINUTES, income(s) * minutes * 60))
	end
	-- Applique les grants de Season (paliers réclamés, premium crédité). Retourne un texte court.
	function L16.applyGrants(s, grants)
		local d, bits = s.data, {}
		for _, g in ipairs(grants or {}) do
			if g.kind == "coins" and type(g.minutes) == "number" then
				local c = coinsFor(s, g.minutes)
				d.coins += c
				bits[#bits + 1] = "🪙 " .. Config.fmt(c)
			elseif g.kind == "egg" and type(g.tier) == "number" and Config.TIERS[g.tier] then
				for _ = 1, math.max(1, math.floor(g.n or 1)) do
					L16.storeEgg(s, g.tier)
				end
				bits[#bits + 1] = "🥚 " .. (g.n or 1) .. " x Œuf " .. Config.TIERS[g.tier].name
			elseif g.kind == "token" and type(g.n) == "number" then
				d.fightTokens = math.min(Config.CALENDAR.caps.tokens, d.fightTokens + g.n)
				bits[#bits + 1] = "⚔️ " .. g.n .. " jeton(s) de combat"
			elseif g.kind == "scroll" and type(g.n) == "number" then
				d.scrolls = math.min(Config.CALENDAR.caps.scrolls, d.scrolls + g.n)
				bits[#bits + 1] = "📜 " .. g.n .. " parchemin(s)"
			elseif (g.kind == "cosmetic" or g.kind == "aura") and type(g.id) == "string" then
				d.cosm[g.id] = true
				bits[#bits + 1] = "🎀 " .. tostring(g.label or g.id)
			elseif g.kind == "species" and type(g.name) == "string" then
				-- espèce Exclusif FIXE de la saison : posée comme pet si une place est libre, sinon un œuf de sa rareté (débordement : jamais perdu)
				local idx
				for i, p in ipairs(Config.PETS) do
					if p.name == g.name then
						idx = i
					end
				end
				local slot = freeSlot(s)
				if idx and slot then
					d.slots[slot] = { k = "p", p = idx, s = 1, m = 1 }
					local key = tostring(idx)
					d.dex[key] = d.dex[key] or { n = 0, b = 0 }
					d.dex[key].n += 1
					d.dex[key].b = math.max(d.dex[key].b, 1)
					refreshPad(s, slot)
				else
					L16.storeEgg(s, g.tier)
				end
				bits[#bits + 1] = "✨ " .. g.name
			end
		end
		return table.concat(bits, ", ")
	end
	function L16.addXp(s, source)
		local r = S.addXp(s.data, source, os.time())
		if source == "pve" or source == "pvp" or source == "duel" then
			L16.victory(s)
		end
		if r.ok and #r.tiersUp > 0 and r.tier > 0 then
			notify(s.player, "🏅 Passe de combat : palier " .. r.tier .. " atteint ! Récompense à réclamer (Boutique › Passe de combat).", "claim")
			tele.event(s.player, "progression", "season", r.tier)
		end
		return r
	end
	function L16.seasonPush(s)
		local now = os.time()
		K8.remote:FireClient(s.player, { panel = "season", view = S.view(s.data, now), recap = S.recap(s.data, now), startsAt = Config.SEASON.start })
	end
	function actions.seasonView(s)
		if gap(s, "sview", 0.5) then
			L16.seasonPush(s)
		end
	end
	local CLAIM_MSG = { bad = "Palier inconnu.", locked = "🔒 Palier pas encore atteint.", premium = "🏅 Piste premium : il faut le passe premium de cette saison.", already = "✅ Déjà réclamé.",
		none = "Rien à réclamer sur ce palier.", expired = "⌛ La saison précédente est close : ces récompenses sont perdues.", noseason = "🏅 Le passe de combat n'a pas encore commencé." }
	function actions.seasonClaim(s, arg)
		if type(arg) ~= "table" or not gap(s, "sclaim", 0.25) then
			return
		end
		local which = arg.prev == true and "prev" or nil
		local now = os.time()
		local grants, label
		if arg.all == true then
			local r = S.claimAll(s.data, now, which)
			if r.claimed == 0 then
				return notify(s.player, "Rien à réclamer pour l'instant.", "refuse")
			end
			grants, label = r.grants, r.claimed .. " récompense(s)"
		else
			local r = S.claim(s.data, arg.tier, arg.track, now, which)
			if not r.ok then
				return notify(s.player, CLAIM_MSG[r.reason] or CLAIM_MSG.bad, "refuse")
			end
			grants, label = r.grants, "palier " .. r.tier
		end
		notify(s.player, "🏅 Passe de combat (" .. label .. ") : " .. L16.applyGrants(s, grants), "claim")
		sync(s)
		L16.seasonPush(s)
	end
	function actions.seasonAck(s)
		if gap(s, "sack", 0.5) then
			S.ackRecap(s.data, os.time())
			L16.seasonPush(s)
		end
	end

	---------------------------------------------------------------- Poses de victoire (cosmétiques, achat unique)
	function actions.emoteSet(s, n)
		if type(n) ~= "number" or n ~= n or n % 1 ~= 0 or n < 0 or n > #LC.emotes then
			return
		end
		if n > 0 and s.data.once["EmoteVictory" .. n] ~= true then
			return notify(s.player, "🎭 Cette pose n'est pas à toi.", "refuse")
		end
		s.data.emote = n
		sync(s)
	end
	function L16.victory(s)
		local n = s.data.emote
		if type(n) == "number" and n > 0 and s.data.once["EmoteVictory" .. n] == true then
			s.player:SetAttribute("VictoryPose", n)
			s.player:SetAttribute("VictoryAt", os.clock()) -- le client joue la pose (effet visuel seulement)
		end
		if not s.l16Win and (s.data.played or 0) < 7200 then
			s.l16Win = true
			tele.event(s.player, "onboarding", "first_battle_win")
		end
	end

	---------------------------------------------------------------- Boutique : contrôles AVANT l'invite d'achat (rien n'est débité en cas de refus)
	local WHY = {
		unknown = "🛒 Cet achat n'existe pas.", noId = Config.UNAVAILABLE_MESSAGE, policy = "🛒 Cette offre n'est pas disponible pour ton compte.",
		notLive = "🥚 Cet œuf n'est pas encore disponible.", owned = "✅ Tu possèdes déjà cet achat.", needPremium = "🏅 Il faut d'abord le passe de combat premium de la saison.",
		hasPremium = "🏅 Tu as déjà le passe premium : prends la version « suite » ou « sans passe ».", faisDeLaPlace = Shop.MSG_ROOM .. " Rien n'est débité.",
		noseason = "🏅 Le passe de combat n'a pas encore commencé (1er décembre 2026, UTC).",
	}
	-- Limites de RÉSERVE du moteur (pas des plafonds d'achat) : jetons de corbeau, rattrapages du calendrier ; série à sauver ; relance seulement après une défaite.
	local function engineBlock(s, key)
		local d = s.data
		local pack = Config.REMOTE_STEAL.packs[key]
		if pack and d.tokens.remoteSteal + pack > Config.REMOTE_STEAL.tokenMax then
			return "🐦‍⬛ Tu as déjà " .. d.tokens.remoteSteal .. " jeton(s) de corbeau (" .. Config.REMOTE_STEAL.tokenMax .. " en réserve au plus) : utilise-en d'abord. Rien n'est débité."
		end
		if key == "CalendarCatchup" and (tonumber(d.cal.catch) or 0) >= Config.CALENDAR.catchupMax then
			return "📅 Tu as déjà " .. Config.CALENDAR.catchupMax .. " rattrapages en réserve : utilises-en d'abord. Rien n'est débité."
		end
		if key == "StreakRestore" then
			local plan = L15.Rewards.streakPlan(Config, { daily = d.daily, streak = d.streak, grace = d.grace }, os.time() // 86400, { questsDone = L15.questsDone(s) })
			if plan.state ~= "rescue" then
				return "🔥 Ta série n'est pas en danger : rien à sauver. Rien n'est débité."
			end
		end
		if key == "Revive" and not (s.revive and s.castle and not s.castle.finished) then
			return "💫 La relance se propose juste après une défaite au Château."
		end
		return nil
	end
	function L16.canBuy(s, key)
		local ok, why = Shop.canBuy(L16.shopProfile(s), L16.bagCfg(s), key, restrictedFlag(s))
		if not ok then
			return false, WHY[why] or WHY.unknown
		end
		local block = engineBlock(s, key)
		if block then
			return false, block
		end
		return true
	end
	function actions.shopBuy(s, key)
		if type(key) ~= "string" or #key > 40 or not gap(s, "buy", 1) then
			return
		end
		local isPass = type(Config.PASSES[key]) == "table" and Config.PASSES[key].cat ~= nil
		local def = isPass and Config.PASSES[key] or Config.PRODUCTS[key]
		if type(def) ~= "table" or def.cat == nil then
			return
		end
		local ok, msg = L16.canBuy(s, key)
		if not ok then
			return notify(s.player, msg, "refuse")
		end
		tele.event(s.player, "funnel", "prompt", s.funnel)
		local player = s.player
		pcall(function()
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, def.id)
			else
				MarketplaceService:PromptProductPurchase(player, def.id)
			end
		end)
	end
	-- Mesure de l'entonnoir d'achat (vue de la boutique, ouverture d'une fiche) : aucune donnée personnelle, pause par joueur.
	function actions.shopEv(s, arg)
		if type(arg) ~= "table" or not gap(s, "shopEv", 0.5) then
			return
		end
		if arg.k == "view" then
			s.funnel = "f" .. (os.time() % 1000000) .. "_" .. rng:NextInteger(1, 999999)
			tele.event(s.player, "funnel", "shop_view", s.funnel)
			if not s.l16Shop and s.data.hatched < 30 then
				s.l16Shop = true
				tele.event(s.player, "onboarding", "first_shop_view")
			end
		elseif arg.k == "card" and type(arg.key) == "string" and (Config.PRODUCTS[arg.key] or Config.PASSES[arg.key]) then
			tele.event(s.player, "funnel", "card_open", s.funnel)
		end
	end

	---------------------------------------------------------------- Livraison d'un reçu (appelée par ProcessReceipt, PolicyService déjà vérifié, reçu non encore traité)
	-- Retourne true (livré), false + message (NotProcessedYet : RIEN n'a été modifié, Roblox rejouera), ou nil (produit livré par l'ancien code).
	local SEASON_KIND = { SeasonPremium = "premium", SeasonPremiumPlus = "premiumPlus", SeasonUpgradePlus = "upgradePlus" }
	local L16_KEYS = { StarterPack = true, CoinPack = true, CoinPackS = true, LuckPotion = true, LuckPotionMini = true, DoubleLuck = true, ArenaTickets = true, BundleLegend = true, BundleRoyal = true, BundleRoyalNoPass = true }
	function L16.grant(s, name, def)
		local d, now = s.data, os.time()
		if not (L16_KEYS[name] or SEASON_KIND[name] or type(def.eggTier) == "number" or (def.once == true and def.cat == "cosmetics")) then
			return nil
		end
		local eggs = Shop.eggsOf(name)
		for _, e in ipairs(eggs) do
			if not Config.tierLive(e.tier) then
				return false, "🥚 Cet œuf n'est pas encore disponible : ton achat sera livré plus tard (rien n'est perdu)."
			end
		end
		local withPremium = SEASON_KIND[name] ~= nil or name == "BundleRoyal" or name == "BundleRoyalNoPass"
		if withPremium and S.currentSeason(now).n == 0 then
			return false, "🏅 Le passe de combat n'a pas encore commencé : ton achat sera livré à son ouverture (rien n'est perdu)."
		end
		local bits, comp = {}, 0
		if def.once == true and d.once[name] == true then
			comp = def.robux -- achat unique déjà fait (course entre deux invites) : compensé en pièces, jamais un second octroi
		else
			for _, e in ipairs(eggs) do
				for _ = 1, e.n do
					L16.storeEgg(s, e.tier)
				end
				bits[#bits + 1] = (e.n > 1 and (e.n .. " x ") or "") .. "🥚 Œuf " .. Config.TIERS[e.tier].name
			end
			if SEASON_KIND[name] then
				local r = S.buyPremium(d, SEASON_KIND[name], now)
				if not r.ok and r.reason == "needPremium" then
					r = S.buyPremium(d, "premium", now) -- complément (400) payé sans premium (invite lancée hors de la boutique) : le premium (399) est donné, jamais plus que le prix payé
				end
				if r.ok then
					bits[#bits + 1] = "🏅 " .. def.name .. (r.credited > 0 and (" (" .. r.credited .. " palier(s) crédité(s) : " .. L16.applyGrants(s, r.grants) .. ")") or "")
				else
					comp = def.robux -- déjà possédé cette saison (course) : compensé en pièces
				end
			elseif name == "BundleRoyal" or name == "BundleRoyalNoPass" then
				local r = S.buyPremium(d, "premium", now) -- « sans passe » payé sans premium (course) : le premium est donné aussi (décision : équivalent plein)
				if r.ok then
					bits[#bits + 1] = "🏅 Passe de combat premium" .. (r.credited > 0 and (" (" .. L16.applyGrants(s, r.grants) .. ")") or "")
				elseif name == "BundleRoyal" then
					comp = Config.PRODUCTS.SeasonPremium.robux -- premium déjà possédé : la part « passe » est compensée en pièces
				end
			end
			if name == "StarterPack" then
				d.coins += Config.STARTER_PACK.coins
				d.luckUntil = math.max(now, d.luckUntil) + Config.LUCK_POTION_SECONDS
				bits[#bits + 1] = "🪙 " .. Config.fmt(Config.STARTER_PACK.coins) .. " et une potion de chance"
			elseif name == "CoinPack" or name == "CoinPackS" then
				local c = name == "CoinPack" and math.max(Config.COIN_PACK_MIN, income(s) * Config.COIN_PACK_MINUTES * 60) or math.max(LC.coinPackS.min, income(s) * LC.coinPackS.minutes * 60)
				d.coins += math.floor(c)
				bits[#bits + 1] = "🪙 " .. Config.fmt(c)
			elseif name == "LuckPotion" or name == "LuckPotionMini" then
				d.luckUntil = math.max(now, d.luckUntil) + (name == "LuckPotion" and Config.LUCK_POTION_SECONDS or LC.luckMiniSeconds)
				bits[#bits + 1] = "🧪 " .. def.name
			elseif name == "DoubleLuck" or name == "BundleLegend" then
				d.doubleUntil = math.max(now, d.doubleUntil) + (name == "DoubleLuck" and LC.doubleSeconds or LC.legendDoubleSeconds) -- durées cumulables, puissance plafonnée à 70
				bits[#bits + 1] = "🍀 Double chance"
			elseif name == "ArenaTickets" then
				local today = now // 86400
				local a = d.arenaTk
				d.arenaTk = { day = today, n = (a.day == today and a.n or 0) + LC.arenaTickets }
				bits[#bits + 1] = "🎫 +" .. LC.arenaTickets .. " combats de tour aujourd'hui"
			end
			if def.once == true then
				d.once[name] = true
				if name == "StarterPack" then
					d.starter = true
				end
				if def.cat == "cosmetics" then
					local n = tonumber(name:match("(%d+)$"))
					if n and d.emote == 0 then
						d.emote = n -- première pose achetée : choisie d'office (modifiable dans le menu)
					end
					bits[#bits + 1] = "🎭 " .. def.name
				end
			end
		end
		if comp > 0 then
			local coins = math.floor(math.max(Config.COIN_PACK_MIN, income(s) * Config.timeRobux(comp)))
			d.coins += coins
			bits[#bits + 1] = "🪙 " .. Config.fmt(coins) .. " (déjà possédé : compensé en pièces)"
		end
		notify(s.player, "🛒 " .. def.name .. " : " .. table.concat(bits, " · "), "buy")
		return true
	end

	---------------------------------------------------------------- Offres contextuelles (Offers.lua : 3 par session, 300 s d'écart, jamais en action, jamais après un achat)
	local function offerProfile(s)
		local d = s.data
		local owned = {}
		for k, v in pairs(d.once) do
			owned[k] = v
		end
		local best = 0
		for k in pairs(d.dex) do
			local p = Config.PETS[tonumber(k) or 0]
			if p and p.tier > best then
				best = p.tier
			end
		end
		return { owned = owned, passes = ownedPasses(s), dayNumber = math.max(1, os.time() // 86400 - (d.firstSeen > 0 and d.firstSeen or os.time() // 86400) + 1), bestTier = best, hatchedTotal = d.hatched }
	end
	local function offerCtx(s, flags)
		local d = s.data
		local now = os.time()
		local baseFull = freeSlot(s) == nil
		local bagFull = #d.eggBag >= L16.bagCfg(s).EGG_BAG.size
		local plan = L15.Rewards.streakPlan(Config, { daily = d.daily, streak = d.streak, grace = d.grace }, now // 86400, { questsDone = L15.questsDone(s) })
		local b = d.battle
		local ctx = {
			Config = Config, data = OffersData, restricted = restrictedFlag(s),
			baseFull = baseFull, bagFull = bagFull, streakAtRisk = plan.state == "rescue",
			firstLegend = s.l16Legend ~= nil and now - s.l16Legend < 600,
			towerQuotaExhausted = b.day == now // 86400 and b.fights >= Config.TOWER.dailyFights + L16.arenaExtra(s),
			inCombat = s.battle ~= nil or s.pvpPending == true, carrying = #s.carry > 0, castleTimer = s.castle ~= nil, flying = s.flying == true,
			calm = s.battle == nil and s.castle == nil and #s.carry == 0 and os.clock() - (s.lastSteal or 0) > 60,
		}
		for k, v in pairs(flags or {}) do
			ctx[k] = v
		end
		return ctx
	end
	function L16.tryOffer(s, flags)
		local st = offerState[s.player]
		if not st or s.leaving then
			return
		end
		local now = os.time()
		if st.current then
			if Offers.expired(st, now, offerCtx(s)) then
				st.current = nil
			else
				return
			end
		end
		local ok, o = pcall(Offers.pick, st, offerProfile(s), now, offerCtx(s, flags))
		if ok and o then
			Offers.onShown(st, o, now)
			K8.remote:FireClient(s.player, { panel = "offer", offer = o })
		end
	end
	function L16.event(s, flag)
		L16.tryOffer(s, { [flag] = true })
	end
	function actions.offerClose(s)
		local st = offerState[s.player]
		if st and gap(s, "offerClose", 0.3) then
			Offers.onClosed(st, os.time())
		end
	end
	function L16.bought(s, key)
		local st = offerState[s.player]
		if st then
			Offers.onBought(st, key, os.time()) -- aucune offre pendant 600 s après TOUT achat (pas de relance incitative)
		end
	end
	task.spawn(function() -- moments calmes et drapeaux durables (série en danger, base pleine, quota de tour) : un essai toutes les 20 s par joueur
		while true do
			task.wait(20)
			for _, ss in pairs(sessions) do
				pcall(L16.tryOffer, ss, nil)
			end
		end
	end)

	---------------------------------------------------------------- Arrivée / départ / vue
	function L16.join(s)
		local now = os.time()
		offerState[s.player] = Offers.newState(now)
		S.migrate(s.data, now)
		tele.event(s.player, "version", Config.BUILD)
		if s.data.hatched == 0 then
			tele.event(s.player, "onboarding", "join")
		end
		local rc = S.recap(s.data, now)
		if rc and not rc.expired then
			task.delay(10, function()
				if sessions[s.player] == s then
					notify(s.player, "🏅 La saison " .. rc.n .. " du passe de combat est terminée (palier " .. rc.tier .. ") : " .. (rc.unclaimedFree + rc.unclaimedPremium) .. " récompense(s) à réclamer encore " .. rc.graceDaysLeft .. " jour(s).", "claim")
				end
			end)
		end
	end
	function L16.leave(s)
		offerState[s.player] = nil
		gaps[s.player] = nil
	end
	local function hasBit(mask, t)
		return math.floor((tonumber(mask) or 0) / 2 ^ (t - 1)) % 2 == 1
	end
	function L16.view(s)
		local d, now = s.data, os.time()
		local se, cur = S.migrate(d, now)
		local tier = S.tierOf(se.xp)
		local claimable = false
		if cur.n > 0 then
			for t = 1, tier do
				if (SD.FREE[t] and not hasBit(se.claimedFree, t)) or (se.premium == se.n and SD.PREMIUM_TRACK[t] and not hasBit(se.claimedPrem, t)) then
					claimable = true
				end
			end
		end
		return {
			once = d.once, overflow = Shop.overflowCount(d), bagMax = L16.bagCfg(s).EGG_BAG.size, emote = d.emote, followerMax = L16.followerMax(s),
			doubleLeft = math.max(0, d.doubleUntil - now), arenaLeft = L16.arenaExtra(s), owned = ownedPasses(s), open = L16.openEv(now), -- A5 : affichage seulement (le serveur recalcule)
			season = { cur = cur.n, premium = se.premium, plus = se.plus, tier = tier, xp = se.xp, daysLeft = cur.daysLeft or 0, startsAt = Config.SEASON.start, claimable = claimable, prev = se.prev ~= nil and not se.prev.seen },
		}
	end
end

---------------------------------------------------------------- Game Passes
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local s = sessions[player]
	if not (s and purchased) then
		return
	end
	for name, def in pairs(Config.PASSES) do
		if Config.purchasable(def) and def.id == passId then
			if def.random == true and s.restricted ~= false then
				warn("[Policy] " .. player.Name .. " : achat du pass « " .. name .. " » refusé (offres à hasard restreintes)") -- jamais livré à un joueur restreint
				notify(player, "🛒 Cette offre n'est pas disponible pour ton compte.")
			else
				s.passes[name] = true
				if def.random == true then
					s.ownedRandom[name] = true
				end
				if name == "PrivateBelt" then
					Lot7.privRefresh(s)
				end
			end
		end
	end
	if passId == Config.PASSES.ExtraSlots.id and s.plot then
		refreshLocks(s) -- +4 emplacements : cadenas levés sans recréer les pads occupés
	end
	Lot7.L16.bought(s, "pass") -- lot 16 : aucune offre à l'écran juste après un achat
	sync(s)
end)

---------------------------------------------------------------- Produits développeur (achats Robux ponctuels)
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local s = player and sessions[player]
	if not s then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local rid = tostring(info.PurchaseId)
	local function persist()
		-- PurchaseGranted seulement une fois la sauvegarde réussie ; sinon Roblox rappellera ProcessReceipt (le reçu en mémoire n'est
		-- compté « traité » qu'après une sauvegarde réussie, la livraison n'est donc jamais refaite : s.pendingReceipts).
		if not s.noSave and not Data.save(player, s.data, s.leaving == true) then -- joueur en train de partir : libère aussi le verrou (sinon ce reçu le reprendrait après sa sauvegarde de départ)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		s.pendingReceipts[rid] = nil
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if s.pendingReceipts[rid] then
		return persist() -- déjà livré en mémoire, il ne reste qu'à sauvegarder
	end
	if s.data.receipts[rid] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local granted = false
	for name, def in pairs(Config.PRODUCTS) do
		if Config.purchasable(def) and def.id == info.ProductId then
			if def.random == true and Lot7.awaitPolicy(s) then
				notify(player, "🛒 Cette offre n'est pas disponible pour ton compte.")
				return Enum.ProductPurchaseDecision.NotProcessedYet -- offre à hasard refusée côté serveur (PolicyService) : rien n'est livré
			end
			if s.pendingReceipts[rid] or s.data.receipts[rid] then
				return Enum.ProductPurchaseDecision.NotProcessedYet -- reçu livré pendant l'attente (appel concurrent du même reçu) : le deuxième appel ne livre rien
			end
			local l16ok, l16msg = Lot7.L16.grant(s, name, def) -- lot 16 : œufs (base, sac, débordement), packs, saison, chance, pièces, tickets, poses
			local l7ok, l7msg
			if l16ok == nil then
				l7ok, l7msg = Lot7.grant(s, name)
			end
			if l16ok == false then
				notify(player, l16msg)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			elseif l16ok == true then
				-- livré par le lot 16 ; le reçu est enregistré plus bas
			elseif l7ok == false then
				notify(player, l7msg)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			elseif l7ok == true then
				-- livré par le lot 7 (jetons, tapis doré, pluie de chance) ; le reçu est enregistré plus bas
			elseif name == "CalendarCatchup" then
				-- lot 9b : un jeton de rattrapage du calendrier (plafond Config.CALENDAR.catchupMax : au-delà, rien n'est débité, le reçu sera rejoué)
				if not Lot7.Calendar.addCatch(Config, s.data.cal) then
					notify(player, "📅 Tu as déjà " .. Config.CALENDAR.catchupMax .. " rattrapages : utilises-en avant de finaliser cet achat (il sera livré automatiquement, rien n'est perdu).")
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				notify(player, "📅 +1 rattrapage du calendrier (" .. s.data.cal.catch .. "/" .. Config.CALENDAR.catchupMax .. ").", "buy")
			elseif name == "StreakRestore" then
				-- lot 15 : sauvetage payant de la série (lot 16 : sans plafond d'achat), seulement si la série est réellement à sauver (vérifié aussi AVANT l'invite) ; sinon rien n'est livré (rejoué plus tard)
				local okS, why = L15.streakClaim(s, "product")
				if not okS then
					notify(player, why == "bagFull" and "🔥 Base et sac d'œufs pleins : libère une place, ton achat sera livré automatiquement." or "🔥 Ta série n'a pas besoin d'être sauvée : ton achat n'est pas livré (rien n'est perdu).")
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
			elseif name == "InstantHatch" then
				for i = 1, cap(s) do
					hatch(s, i)
				end
			elseif name == "Revive" then
				local rv = s.revive
				s.revive = nil
				player:SetAttribute("ReviveUntil", nil)
				local root = getRoot(player)
				if s.castle and not s.castle.finished and rv and os.clock() <= rv.expires + 5 and root then
					-- relance sur place : retour là où il est tombé, pv pleins, invulnérable un moment, la défaite n'est pas comptée
					root.CFrame = CFrame.new(rv.pos + Vector3.new(0, 3, 0))
					root.AssemblyLinearVelocity = Vector3.zero
					s.noCheckUntil = os.clock() + 2
					setHp(s, GC.maxHp)
					s.iframes = Config.REVIVE.iframes
					s.castle.deaths = math.max(0, s.castle.deaths - 1)
					notify(player, "💫 Relance ! Tu repars de là où tu es tombé.", "claim")
				else
					-- l'offre a expiré (ou il a quitté le château) : l'achat n'est jamais perdu, il est remplacé par une potion de chance
					s.data.luckUntil = math.max(os.time(), s.data.luckUntil) + Config.LUCK_POTION_SECONDS
					notify(player, "💫 L'offre de relance avait expiré : une potion de chance t'est offerte à la place.", "claim")
				end
			end
			granted = true
			tele.log(player, "purchase_tier", def.robux, "_p" .. tele.priceTier(def.robux))
			tele.event(player, "funnel", "receipt", s.funnel) -- lot 16 (I.2) : entonnoir d'achat
			Lot7.L16.bought(s, name) -- lot 16 : aucune offre à l'écran juste après un achat
		end
	end
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local now = os.time()
	for k, t in pairs(s.data.receipts) do
		if type(t) ~= "number" or now - t > 30 * 86400 then
			s.data.receipts[k] = nil
		end
	end
	s.data.receipts[rid] = now
	s.pendingReceipts[rid] = true
	sync(s)
	return persist()
end

---------------------------------------------------------------- Cycle de vie des joueurs
local function claimPlot(player)
	for _, pl in ipairs(world.plots) do
		if not pl.owner then
			pl.owner = player
			pl.nameLabel.Text = "🏠 Base de " .. player.DisplayName
			return pl
		end
	end
	return nil
end

local function releasePlot(s)
	setDoorBarrier(s, false)
	Builder.clearPrivateBelt(s.plot)
	if s.badge then
		s.badge:Destroy()
		s.badge = nil
	end
	for i = 1, Config.SLOTS_MAX do
		clearPad(s, i)
		s.plot.pads[i].lock.Enabled = true
		s.plot.pads[i].part.Transparency = 0.7
		s.plot.pads[i].frame.Color = Color3.fromRGB(50, 52, 58)
		s.plot.pads[i].frame.Material = Enum.Material.SmoothPlastic
	end
	s.plot.owner = nil
	s.plot.nameLabel.Text = "Base libre"
	Builder.clearBase(s.plot)
end

-- Partie pleine (5 joueurs au plus) ou lieu de jeu ouvert en trop : le joueur est renvoyé au hub (ou expulsé avec un message si le hub est injoignable).
local function bounceToHub(player, message)
	local hub = Config.Game.Places.hub
	local role = Config.Game.roleFor(game.PlaceId)
	if role == "game" and type(hub) == "number" and hub > 0 then
		local opts = Instance.new("TeleportOptions")
		opts:SetTeleportData({ from = "game", reason = "full" })
		local ok = pcall(function()
			TeleportService:TeleportAsync(hub, { player }, opts)
		end)
		if ok then
			return
		end
	end
	player:Kick(message)
end


local function onJoin(player)
	local okJ, joinData = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	local admitted, why = Party.admitJoin(serverPartyId, okJ and joinData or nil, #Players:GetPlayers() - 1, Config.Game.MaxPlayers, Config.Game.roleFor(game.PlaceId))
	if not admitted then
		bounceToHub(player, why == "full" and ("Cette partie est pleine (" .. Config.Game.MaxPlayers .. " joueurs maximum). Réessaie avec une autre partie.") or "Tu ne fais pas partie de cette partie.")
		return
	end
	if serverPartyId == nil and okJ and type(joinData) == "table" and type(joinData.partyId) == "string" then
		serverPartyId = joinData.partyId
	end
	if okJ and type(joinData) == "table" and joinData.mode == "castle" and next(sessions) == nil then
		serverMode = "castle" -- le premier joueur détermine le mode du serveur réservé
	elseif okJ and type(joinData) == "table" and joinData.mode == "ranked" and next(sessions) == nil then
		serverMode = "ranked" -- lot 14 : serveur réservé d'un match classé en direct (le match est vérifié dans PvpMatch_v1, pas dans le TeleportData)
	end
	local late = next(sessions) ~= nil -- arrivée dans une partie déjà commencée
	local waitedLeave = 0
	while leavingSave[player.UserId] and waitedLeave < 20 and player.Parent do -- il vient de partir : attendre la fin de sa sauvegarde (sinon on lirait un profil périmé puis on l'écraserait)
		task.wait(0.25)
		waitedLeave += 0.25
	end
	local d, noSave = Data.load(player)
	if not d then
		player:Kick("Impossible de charger tes données. Reconnecte-toi dans un instant.")
		return
	end
	if pendingSaves[player.UserId] and not noSave then
		d = pendingSaves[player.UserId] -- il revient avant que sa dernière sauvegarde ait réussi : ce profil (plus récent) fait foi
		pendingSaves[player.UserId] = nil
	end
	if not player.Parent then
		if not noSave then
			Data.save(player, d, true) -- libère le verrou de session
		end
		return
	end
	local plot = claimPlot(player)
	if not plot then
		if not noSave then
			Data.save(player, d, true) -- libère le verrou de session avant de refuser
		end
		player:Kick("Serveur plein. Réessaie dans un autre serveur.")
		return
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local function stat(name)
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
		return v
	end
	local rankStat = Instance.new("StringValue")
	rankStat.Name = "Rang"
	rankStat.Parent = ls
	local s = {
		species = speciesCount(d), lsRank = rankStat,
		player = player, data = d, plot = plot, carry = {}, carryParts = {}, labels = {}, passes = {},
		graceUntil = late and (os.time() + Config.Game.LateJoinGrace) or 0, hp = Config.GUARD.maxHp, iframes = 0, sinceHit = 99, stun = 0, lastAct = 0, lastActive = os.clock(), lastTap = 0, lastSteal = 0, lastFull = 0, noSave = noSave,
		followers = {}, ownedRandom = {}, pendingReceipts = {}, holdSeen = false, flags = 0, noCheckUntil = 0, syncT = 0, leaving = false, traps = {},
		runes = { 1, 1, 1, 1 }, lastRune = 0, runeLock = 0,
		lsCoins = stat("Pièces"), lsSpeed = stat("Vitesse"), lsRb = stat("Renaissances"),
	}
	ls.Parent = player
	player:SetAttribute("Hp", Config.GUARD.maxHp)
	player:SetAttribute("MaxHp", Config.GUARD.maxHp)
	sessions[player] = s
	do -- lot 9 (mesure de rétention) : jours UTC de première et de dernière connexion, aucune donnée personnelle
		local today = os.time() // 86400
		if d.firstSeen == 0 then
			d.firstSeen = today
		end
		local back = d.lastSeen ~= today and tele.retentionDay(d.firstSeen, today) or nil
		if back then
			tele.log(player, "retention_day" .. back)
		end
		d.lastSeen = today
		s.joinClock = os.clock()
		s.npcStart = os.time() -- lot 15 : 8 premières minutes de la session sans PNJ
	end
	if plot and plot.spawn then
		player:SetAttribute("BaseX", plot.spawn.Position.X) -- le client affiche la distance à la base sur la bannière de zone
		player:SetAttribute("BaseZ", plot.spawn.Position.Z)
	end
	if late then
		notify(player, "🛡 Tu arrives en cours de partie : tes œufs sont protégés " .. Config.Game.LateJoinGrace .. " s.")
	end

	for name, def in pairs(Config.PASSES) do
		s.passes[name] = false
		if Config.purchasable(def) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.id)
			end)
			if def.random == true then
				s.ownedRandom[name] = ok and owns == true -- passe à hasard : possédée mais INACTIVE tant que PolicyService n'a pas confirmé « non restreint » (voir fetchPolicy)
			else
				s.passes[name] = ok and owns == true
			end
		end
	end

	Lot7.restoreBuffs(s) -- tapis doré / pluie de chance offerts par ce joueur sur un serveur fermé depuis : le temps restant est rendu une fois
	Lot7.fetchPolicy(s) -- offres à hasard : masquées et refusées tant que PolicyService n'a pas confirmé qu'elles sont permises
	Lot7.L16.join(s) -- lot 16 : passe de combat (saison à jour, récapitulatif), offres contextuelles, version publiée (télémétrie)
	s.baseLevel = levelOf(s) -- le revenu (gains hors ligne compris) dépend du niveau de maison ; la base est construite plus bas par applyBase
	-- gains hors-ligne (les œufs éclosent seuls grâce aux horodatages)
	local away = math.clamp(os.time() - d.last, 0, Config.IDLE.offlineMaxSeconds)
	if away > 30 then
		local gain = income(s) * away * Config.IDLE.offlineRate
		d.pendingAway = math.min(d.pendingAway + gain, math.max(income(s), 1) * Config.IDLE.offlineMaxSeconds * Config.IDLE.offlineRate) -- mis de côté (plafonné) : se récupère d'un clic (claimAway)
	end
	if d.pendingAway >= 1 then
		notify(player, "💤 Gains pendant ton absence : " .. Config.fmt(d.pendingAway) .. " 🪙 : touche « Récupérer »")
	end

	ensureQuests(s)
	pvpState(s) -- nouvelle saison : récompense de la précédente et remise à zéro douce
	if serverMode == "ranked" then
		Lot7.Live.arenaJoin(s, okJ and joinData or nil) -- lot 14 : joueur du match (sinon renvoyé chez lui)
	end
	applyBase(s, false)
	updateSign(s)
	refreshAllPads(s)
	Lot7.privRefresh(s) -- tapis privé (pass) : œufs en attente sauvegardés
	s.welcome = "wait"
	task.delay(5, function() -- lot 12 B : reconnexion avec un tirage de cartes en attente : mêmes cartes, temps restant (échu : première carte d'office)
		if player.Parent and sessions[player] == s and not s.battle then
			L15.sendPick(s)
		end
	end)
	task.delay(Config.BELT.welcome.delay, function()
		beltWelcome(player, s) -- œuf de bienvenue du tapis (une fois, 20 s après l'arrivée)
	end)
	player:SetAttribute("PlotCF", plot.cf) -- position de la base : sert aux caméras des cinématiques (réplication sûre)
	player.RespawnLocation = plot.spawn
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		s.stun = 0
		s.carry = {}
		s.carryParts = {}
		s.lastPos = nil
		s.followers = {}
		applySpeed(s)
		task.spawn(function()
			char:WaitForChild("HumanoidRootPart", 10)
			if player.Parent and sessions[player] == s then
				rebuildFollowers(s)
				if serverMode == "castle" and not s.castle then
					castleEnter(s) -- serveur de mode Château : arrivée directement à l'entrée du donjon
				end
			end
		end)
		hum.Died:Connect(function()
			dropCarry(s)
			clearFollowers(s)
			task.delay(3, function()
				if player.Parent and sessions[player] == s then
					pcall(function()
						player:LoadCharacterAsync()
					end)
				end
			end)
		end)
	end)
	if player.Parent then
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)
		if not ok then
			warn("[onJoin] LoadCharacterAsync : " .. tostring(err))
		end
		if player.Parent then
			sync(s)
		end
	end
end

Players.PlayerAdded:Connect(onJoin)
-- Filet de sécurité : personnage garanti dans la zone, replacement si chute (voir Spawn / SpawnGuard, traces [Spawn] en console serveur)
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpawnGuard")).attach({
	role = "game",
	safeCFrame = function(p)
		local ss = sessions[p]
		local sp = ss and ss.plot and ss.plot.spawn
		if sp then
			return sp.CFrame + Vector3.new(0, 4, 0)
		end
		local pa = Config.Map2.plazaArrival
		return CFrame.new(pa.x, 8, pa.z) -- sur la place du marché, près de la rose des portails : toujours au sol
	end,
})
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

-- Profils dont la sauvegarde de départ a échoué : réessayée en arrière-plan (délais croissants, 10 essais), abandonnée si le joueur est revenu
-- (sa nouvelle session reprend ce profil au chargement) ; vidée aussi à la fermeture du serveur (BindToClose).
function saveLater(player, d)
	local uid = player.UserId
	pendingSaves[uid] = d
	task.spawn(function()
		local delay = 4
		for _ = 1, 10 do
			task.wait(delay)
			delay = math.min(delay * 2, 60)
			if pendingSaves[uid] ~= d then
				return
			end
			if Players:GetPlayerByUserId(uid) then
				return -- revenu : le chargement a repris pendingSaves, rien à écraser
			end
			if Data.save(player, d, true) then
				pendingSaves[uid] = nil
				return
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	local s = sessions[player]
	if not s then
		return
	end
	s.leaving = true -- l'autosave ne doit plus reprendre le verrou de session après ce point
	L15.duelLeave(s) -- lot 13 : duel en cours = forfait (défaite comptée dans le profil AVANT la sauvegarde ci-dessous), défis retirés
	do -- lot 9b : une réclamation du calendrier en cours (sauvegarde puis octroi) se termine AVANT la sauvegarde de départ
		local t0 = os.clock()
		while s.calBusy and os.clock() - t0 < 15 do
			task.wait(0.1)
		end
	end
	K8.Kiosk.forget(player) -- lot 8B : pause du kiosque (table à clés faibles : facultatif)
	K8.Sellers.forget(player) -- lot 16 : pause des vendeurs
	Lot7.L16.leave(s) -- lot 16 : état des offres et des pauses du joueur libéré (aucune fuite)
	L15.books[player] = nil -- lot 15 : carnet d'offres libéré (pas de fuite mémoire) ; les compteurs du profil restent (aucune rencontre relancée en se reconnectant)
	tele.log(player, "session_length", os.clock() - (s.joinClock or os.clock()))
	tele.flush(player)
	Lot7.Live.onLeave(s) -- lot 14 : retrait de la file ; combat en direct en cours = forfait écrit dans le profil AVANT la sauvegarde ci-dessous
	Lot7.onLeave(s) -- annule tout vol de corbeau en cours (jeton rendu au voleur AVANT la sauvegarde), vide les états du joueur
	dropCarry(s)
	clearFollowers(s)
	holds[player] = nil
	if not s.noSave then
		leavingSave[player.UserId] = true
		local okSave = Data.save(player, s.data, true) -- libère le verrou
		if not okSave then
			saveLater(player, s.data) -- DataStore en panne ou lent : on réessaie en arrière-plan (la progression n'est pas perdue)
		end
		leavingSave[player.UserId] = nil
		Data.submit(player, s.data)
	end
	releasePlot(s)
	sessions[player] = nil
end)

-- sauvegarde automatique toutes les 60 s
task.spawn(function()
	while true do
		task.wait(60)
		for player, s in pairs(sessions) do
			if not s.noSave and not s.leaving then
				task.spawn(function()
					Data.save(player, s.data)
					Data.submit(player, s.data)
				end)
			end
		end
	end
end)

game:BindToClose(function()
	pcall(Lot7.abortAll) -- d'abord : tout vol de corbeau en cours est annulé et son jeton rendu dans le profil, AVANT les sauvegardes ci-dessous
	pcall(Lot7.persistBuffs) -- fin du tapis doré / de la pluie de chance écrite dans le profil du donateur présent
	local pending = 0
	for uid, d in pairs(pendingSaves) do -- profils de joueurs déjà partis dont la sauvegarde a échoué
		pending += 1
		task.spawn(function()
			local ghost = Players:GetPlayerByUserId(uid) or { UserId = uid, Name = "joueur " .. uid }
			if Data.save(ghost, d, true) then
				pendingSaves[uid] = nil
			end
			pending -= 1
		end)
	end
	for player, s in pairs(sessions) do
		if not s.noSave then
			pending += 1
			task.spawn(function()
				Data.save(player, s.data, true)
				pending -= 1
			end)
		end
	end
	local t0 = os.clock()
	while (pending > 0 or Lot7.logPending() > 0) and os.clock() - t0 < 25 do -- (le journal RavenLog est vidé dans la même limite de temps)
		task.wait()
	end
end)

-- classement global : rafraîchi toutes les 2 minutes
task.spawn(function()
	while true do
		topCache = Data.top(10)
		task.wait(120)
	end
end)

print("[Chipe-Œufs] serveur prêt")
