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
local Data = require(script.Parent:WaitForChild("Data"))
local Builder = require(script.Parent:WaitForChild("Builder"))
local Rules = require(script.Parent:WaitForChild("Rules")).new(Config) -- règles pures (tirages, revenus), testées avec Lune

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
local rng = Random.new()
local sessions = {} -- [Player] = session
local leavingSave = {} -- userId -> true tant que la sauvegarde de départ de ce joueur est en cours (une reconnexion attend)
local pendingSaves, saveLater = {}, nil -- profils à sauvegarder en arrière-plan (voir saveLater)
local beltBuy -- définie avec le tapis roulant central (section dédiée) ; déclarée ici car le gestionnaire de prompts l'utilise
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
	return s.passes.Speed == true and Config.SPEED_PASS_MUL or 1
end
local function freeSlot(s)
	for i = 1, cap(s) do
		if not s.data.slots[i] then
			return i
		end
	end
	return nil
end

-- Multiplicateur de revenu : renaissances, Festin, événement, passe, collection, puis bonus de la maison évolutive (1 + 5 % à 50 %, REFONTE lot 5).
local function gmult(s)
	return Rules.multiplier(s.data.rb, s.data.up.food, evKey() == "gold", s.passes.Coins2x == true, Config.collectionBonus(s.species or 0)) * Rules.levelMul(s.baseLevel or 1)
end

local function income(s)
	return Rules.income(s.data.slots, cap(s), gmult(s))
end

local function rollPet(s, eggTier, guaranteed)
	local up = Rules.upPoints(s.data.up.luck, evKey() == "luck", s.passes.Lucky == true, os.time() < s.data.luckUntil)
	local alien = evKey() == "alien"
	return Rules.rollPet(eggTier, up, alien, rnd, guaranteed), up, alien
end

---------------------------------------------------------------- Missions quotidiennes
local QUEST_TYPES = { "steal", "hatch", "earn", "train", "pvp", "discover", "sell", "castle", "rare", "secret" }

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

---------------------------------------------------------------- Énigme du jour (identique pour tous) et statistiques de succès
local riddleCache = { day = -1, riddle = nil }
local function currentRiddle()
	local day = os.time() // 86400
	if riddleCache.day ~= day then
		riddleCache.day = day
		riddleCache.riddle = Config.riddleFor(day)
		for _, lbl in ipairs(world.riddleLabels) do
			lbl.Text = riddleCache.riddle.text
		end
	end
	return riddleCache.riddle
end
currentRiddle() -- écrit l'énoncé sur les panneaux dès le démarrage

local function statValues(s)
	local d = s.data
	return { hatched = d.hatched, stolen = d.stolen, species = s.species, rb = d.rb, puzzles = d.puzzle.solved, tower = d.battle.best }
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
			slots[i] = { k = "p", p = sl.p, s = sl.s, m = sl.m }
		else
			slots[i] = false
		end
	end
	local today = os.time() // 86400
	local nextStreak = (d.daily == today - 1) and d.streak + 1 or 1
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
		dailyReady = d.daily ~= today,
		dailyReward = math.floor(math.max(200, income(s) * 600) * math.min(nextStreak, 7)),
		streak = nextStreak,
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
		riddle = currentRiddle().text,
		puzzleDone = d.puzzle.day == today,
		puzzleSolved = d.puzzle.solved,
		ach = d.ach,
		stats = statValues(s),
		baseScore = d.baseScore,
		away = math.floor(d.pendingAway),
		battle = { pvp = { trophies = d.battle.pvp.trophies, season = d.battle.pvp.season, wins = d.battle.pvp.wins, losses = d.battle.pvp.losses, hasDefense = #d.battle.pvp.defense > 0, fightsLeft = math.max(0, Config.PVP.dailyFights - (d.battle.pvp.day == os.time() // 86400 and d.battle.pvp.fights or 0)) }, team = d.battle.team, best = d.battle.best, fightsLeft = math.max(0, Config.TOWER.dailyFights - (d.battle.day == os.time() // 86400 and d.battle.fights or 0)), repeatsLeft = math.max(0, Config.TOWER.dailyRepeats - (d.battle.day == os.time() // 86400 and d.battle.repeats or 0)) },
		baseLevel = s.baseLevel,
		welcome = s.welcome, -- œuf de bienvenue du tapis : wait / offered / taken / gone / none (onboarding)
		newbie = s.newbie == true, -- protection débutant active (lot 4)
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
	setNestEgg(n, wpick(n.weights or Config.RIVALS[n.rival].weights)) -- enclos sauvage : poids propres (Config.TERR.wild)
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
				vs.data.slots[i] = { k = "e", t = e.t, ends = os.time() + e.rem, shield = os.time() + shieldTime(vs) }
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
local function applyBase(s, celebrate, force)
	local level = levelOf(s)
	local before = s.baseLevel
	s.baseLevel = level
	local built = s.baseBuilt
	local rose = celebrate and built ~= nil and level > built
	if s.plot and (built ~= level or force) then
		Builder.baseUpgrade(s.plot, level, rose and { animate = true } or nil)
		s.baseBuilt = level
		if rose then
			local plot = s.plot
			task.delay(Config.UPGRADE_FX.seconds, function()
				if plot.upgrading then
					Builder.finishUpgrade(plot)
				end
			end)
		end
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
function hatch(s, i)
	local d = s.data
	local sl = d.slots[i]
	if not sl or sl.k ~= "e" then
		return
	end
	local guaranteed = Config.PITY_ENABLED and sl.t < #Config.TIERS and d.pity >= Config.PITY_EVERY - 1
	local p, upPoints, alienBoost = rollPet(s, sl.t, guaranteed)
	local oneIn = Reveal.oneIn(Config, Rules, sl.t, upPoints, alienBoost, p.p, p.s, p.m, guaranteed)
	if p.tier > sl.t then
		d.pity = 0
	elseif sl.t < #Config.TIERS then
		d.pity += 1
	end
	d.slots[i] = { k = "p", p = p.p, s = p.s, m = p.m }
	d.hatched += 1
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
	sp(s, "hatch", 1)
	applyBase(s, true)
	sp(s, "tier", 1, { tier = def.tier })
	if p.m > 1 then
		sp(s, "mut", 1)
	end
	if def.tier >= 3 then
		qp(s, "rare", 1)
	end
	storyRefresh(s)
	local big = def.tier >= 4 or p.m > 1 or p.s >= 4
	local col = Config.MUTS[p.m].color or Config.TIERS[def.tier].color
	Builder.burst(s.plot.pads[i].part.Position + Vector3.new(0, 3, 0), col, big and 90 or 25, big)
	-- Rareté élevée ou tirage secret : cercle runique au sol, particules, pilier de lumière et contour lumineux du pet (Config.AURA)
	local secretHit = oneIn >= Config.REVEAL.secret.oneInAtLeast
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
	RHatch:FireClient(s.player, { p = p.p, s = p.s, m = p.m, slot = i, inc = Config.petIncome(p.p, p.s, p.m) * gmult(s), oneIn = oneIn < math.huge and oneIn or 0, egg = sl.t, upgraded = p.tier > sl.t })
	if def.tier >= 6 or p.m == 5 or p.s == 5 then
		announce("🌟 " .. s.player.DisplayName .. " vient d'obtenir " .. def.emoji .. " " .. Config.petName(p.p, p.s, p.m) .. " !")
	end
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

---------------------------------------------------------------- Énigme des runes
-- Récompense : un œuf (ou son prix en pièces si la base est pleine) + des pièces. Une résolution par jour et par joueur.
local function solvePuzzle(s)
	local d = s.data
	d.puzzle.day = os.time() // 86400
	d.puzzle.solved += 1
	local tier = Config.PUZZLE_EGG_TIER
	local i = freeSlot(s)
	local coins = Config.puzzleCoins(income(s))
	if i then
		d.slots[i] = { k = "e", t = tier, ends = os.time() + hatchTime(s, tier), shield = os.time() + shieldTime(s) }
		refreshPad(s, i)
	else
		coins += Config.EGG_PRICE[tier]
	end
	d.coins += coins
	s.runes = { 1, 1, 1, 1 }
	Builder.burst(world.monumentCenter, Color3.fromRGB(255, 214, 120), 140, true)
	notify(s.player, "🔮 Énigme résolue ! +" .. Config.fmt(coins) .. " 🪙" .. (i and (" et un œuf " .. Config.TIERS[tier].name .. " dans ta base") or " (base pleine : l'œuf est converti en pièces)"), "rare")
	sp(s, "puzzle", 1)
	sync(s)
end

local function rotateRune(s, root, prompt)
	local idx = prompt:GetAttribute("Idx")
	if type(idx) ~= "number" or idx % 1 ~= 0 or idx < 1 or idx > #Config.RUNES then
		return
	end
	if not prompt.Parent or (root.Position - prompt.Parent.Position).Magnitude > 16 then
		return
	end
	local now = os.clock()
	if now - s.lastRune < 0.12 then
		return
	end
	s.lastRune = now
	s.runes[idx] = s.runes[idx] % #Config.RUNES + 1
	sync(s)
end

local function confirmRunes(s, root, prompt)
	if not prompt.Parent or (root.Position - prompt.Parent.Position).Magnitude > 20 then
		return
	end
	local d = s.data
	if d.puzzle.day == os.time() // 86400 then
		notify(s.player, "🔮 Tu as déjà résolu l'énigme du jour. Reviens demain !")
		return
	end
	local now = os.clock()
	if now < s.runeLock then
		notify(s.player, "🔮 Les runes se reposent… patiente quelques secondes.")
		return
	end
	local answer = currentRiddle().answer
	for i = 1, #answer do
		if s.runes[i] ~= answer[i] then
			s.runeLock = now + Config.RUNE_LOCK_SECONDS
			notify(s.player, "🔮 Les runes restent muettes… relis l'énigme de Mère Poule.", "caught")
			return
		end
	end
	solvePuzzle(s)
end

---------------------------------------------------------------- Vol (nids PNJ et bases des joueurs)
-- Le serveur mesure lui-même la durée de maintien du bouton (le client ne fait qu'afficher la barre).
local holds = {}
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
	notify(s.player, sct.emoji .. " " .. sct.name .. " : +" .. Config.fmt(reward) .. " 🪙", "claim")
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
	if s.sinceHit < T.combatLock then
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
	if kind ~= "Nest" and kind ~= "Pad" and kind ~= "Rune" and kind ~= "RuneConfirm" then
		return
	end
	local s = sessions[player]
	local root = getRoot(player)
	if not s or not root or not alive(player) or s.stun > 0 then
		return
	end
	if kind == "Rune" then
		rotateRune(s, root, prompt)
		return
	elseif kind == "RuneConfirm" then
		confirmRunes(s, root, prompt)
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
		afterTake(s)
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
		s.carry[#s.carry + 1] = { t = sl.t, rem = math.max(0, sl.ends - os.time()), from = vp.UserId }
		s.data.stolen += 1
		qp(s, "steal", 1)
		qp(s, "pvp", 1)
		sp(s, "steal", 1, {})
		notify(vp, "😡 " .. player.DisplayName .. " a volé ton œuf ! Rattrape-le !", "caught")
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
				if state == "chase" and ts and flat.Magnitude < GC.attackRange and g.cd <= 0 then
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
		d.coins += Config.EGG_PRICE[tier] * 0.5
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

local function setEvent(cfg)
	if cfg then
		currentEvent = { cfg = cfg, ends = os.time() + Config.EVENT_DURATION }
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
					d.slots[i] = { k = "e", t = e.t, ends = os.time() + e.rem, shield = os.time() + shieldTime(s) }
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
	currentRiddle() -- change l'énoncé à minuit (UTC)
	for _, n in ipairs(world.nests) do
		if not n.egg then
			n.rt -= dt
			if n.rt <= 0 then
				setNestEgg(n, wpick(n.weights or Config.RIVALS[n.rival].weights))
			end
		end
	end
	local now = os.time()
	for player, s in pairs(sessions) do
		local ok, err = pcall(function()
			local d = s.data
			d.played += dt -- temps de jeu cumulé (secondes, sauvegardé) : protection débutant
			refreshNewbie(s)
			local inc = income(s)
			local active = os.clock() - s.lastActive <= Config.IDLE.seconds
			if (player:GetAttribute("Idle") == true) == active then
				player:SetAttribute("Idle", not active) -- le client affiche « 💤 revenus en pause »
			end
			if active then
				d.coins += inc * dt
				qp(s, "earn", inc * dt)
			end
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
local beltPanelAt, beltPanelKey = 0, ""
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
	local rare = egg.tier >= 4
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
	if key == beltPanelKey then
		return
	end
	beltPanelKey = key
	local mark = "▶ "
	b.panel.normal.Text = (info.active == "normal" and mark or "") .. "Standard : " .. info.normal
	b.panel.golden.Text = (info.active == "golden" and mark or "") .. "Doré : " .. info.golden
	b.panel.normal.TextColor3 = info.active == "normal" and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(190, 190, 205)
	b.panel.golden.TextColor3 = info.active == "golden" and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(190, 190, 205)
	b.panel.status.Text = info.status
end

local function beltStep()
	local now = os.clock()
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
	if now - beltPanelAt >= 1 then
		beltPanelAt = now
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
	beltPanelKey = ""
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
	afterTake(s, "🥚 Œuf " .. Config.TIERS[egg.tier].name .. (egg.price > 0 and (" acheté (-" .. Config.fmt(egg.price) .. " 🪙)") or " pris") .. " ! Porte-le vite dans ta base.", egg.price > 0 and "buy" or "claim")
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

function actions.rebirth(s)
	local d = s.data
	if d.coins < Config.rebirthCost(d.rb) then
		return notify(s.player, "Pas assez de pièces pour renaître.", "refuse")
	end
	local fresh = Data.default()
	fresh.speed, fresh.rb, fresh.dex = d.speed, d.rb + 1, d.dex
	fresh.daily, fresh.streak, fresh.stolen, fresh.hatched = d.daily, d.streak, d.stolen, d.hatched
	fresh.quests, fresh.qday, fresh.receipts, fresh.luckUntil = d.quests, d.qday, d.receipts, d.luckUntil
	fresh.story, fresh.pity = d.story, d.pity
	fresh.battle = d.battle -- le meilleur étage de la tour survit à la renaissance (l'équipe est revalidée à chaque combat)
	fresh.puzzle, fresh.ach = d.puzzle, d.ach
	fresh.cine = d.cine
	fresh.secrets = d.secrets
	fresh.baseLevelFloor, fresh.tokens, fresh.settings = d.baseLevelFloor, d.tokens, d.settings -- le niveau de maison, les jetons et les réglages survivent aussi
	fresh.starter, fresh.baseScore = d.starter, d.baseScore -- l'achat unique du pack de départ et la progression de la base survivent à la renaissance
	dropCarry(s)
	s.data = fresh
	refreshAllPads(s)
	rebuildFollowers(s)
	storyRefresh(s)
	sync(s)
	notify(s.player, string.format("🌅 Renaissance ! Revenus x%.1f", 1 + 0.5 * fresh.rb), "claim")
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
		if #d.equip >= Config.MAX_FOLLOWERS then
			return notify(s.player, "Maximum " .. Config.MAX_FOLLOWERS .. " pets qui te suivent.")
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

function actions.daily(s)
	local d = s.data
	local today = os.time() // 86400
	if d.daily == today then
		return notify(s.player, "Bonus déjà récupéré aujourd'hui !")
	end
	local streak = (d.daily == today - 1) and d.streak + 1 or 1
	local reward = math.floor(math.max(200, income(s) * 600) * math.min(streak, 7) * (s.passes.VipBase == true and Config.VIP_DAILY_MUL or 1))
	d.daily, d.streak = today, streak
	d.coins += reward
	notify(s.player, "🎁 Bonus quotidien : +" .. Config.fmt(reward) .. " 🪙 (série " .. streak .. ")", "claim")
	sync(s)
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
		local rw = pv.season > 0 and Config.pvpSeasonReward(pv.trophies) or nil
		if rw then
			s.data.coins += rw.coins
			giveEgg(s, rw.eggTier)
			if rw.potion then
				s.data.luckUntil = math.max(os.time(), s.data.luckUntil) + Config.LUCK_POTION_SECONDS
			end
			notify(s.player, "🏆 Fin de saison PvP : " .. pv.trophies .. " trophées -> +" .. Config.fmt(rw.coins) .. " 🪙 et un œuf " .. Config.TIERS[rw.eggTier].name .. (rw.potion and " + potion de chance" or ""), "claim")
		end
		pv.season, pv.trophies, pv.wins, pv.losses = season, math.floor(pv.trophies / 4), 0, 0
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

local function battleFinish(s)
	local bt = s.battle
	s.battle = nil -- vidé AVANT tout paiement : aucune double récompense possible
	local st, win = bt.st, bt.st.winner == 1
	local b = s.data.battle
	local rewards = {}
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
		pvpPublishAsync(s)
		RBattle:FireClient(s.player, { k = "end", win = win, rewards = rewards, best = b.best, floor = 0, pvp = true, foe = bt.pvp.name, view = Battle.view(st) })
		RState:FireClient(s.player, snapshot(s))
		return
	end
	if win then
		local first = bt.floor > b.best
		if first then
			b.best = bt.floor
		end
		if first or b.repeats < TW.dailyRepeats then
			local rw = Config.towerReward(bt.floor, income(s), first)
			if not first then
				b.repeats += 1
			end
			s.data.coins += rw.coins
			rewards.coins = rw.coins
			if rw.eggTier and rw.eggTier > 0 then
				giveEgg(s, rw.eggTier)
				rewards.egg = rw.eggTier
			end
			if rw.potion then
				s.data.luckUntil = math.max(os.time(), s.data.luckUntil) + Config.LUCK_POTION_SECONDS
				rewards.potion = true
			end
			rewards.first = first
		else
			rewards.limited = true
		end
	end
	RBattle:FireClient(s.player, { k = "end", win = win, rewards = rewards, best = b.best, floor = bt.floor, view = Battle.view(st) })
	RState:FireClient(s.player, snapshot(s))
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

function actions.towerStart(s, floor)
	if s.battle or s.castle or type(floor) ~= "number" or floor ~= floor or floor % 1 ~= 0 then
		return
	end
	local b = battleDay(s)
	if floor < 1 or floor > TW.floors or floor > b.best + 1 then
		notify(s.player, "🔒 Étage verrouillé : bats d'abord l'étage " .. (b.best + 1) .. ".", "refuse")
		return
	end
	if b.fights >= TW.dailyFights then
		notify(s.player, "⚔️ Limite de combats atteinte pour aujourd'hui (" .. TW.dailyFights .. "). Reviens demain !", "refuse")
		return
	end
	local mine = battleUnits(s)
	if #mine == 0 then
		notify(s.player, "⚔️ Compose d'abord une équipe de pets (1 à " .. TW.teamSize .. ").", "refuse")
		return
	end
	b.fights += 1
	local seed = rng:NextInteger(1, 2147483000)
	s.battle = { st = Battle.new(seed, mine, Battle.towerTeam(Config, floor)), floor = floor, deadline = os.clock() + TW.turnSeconds }
	RBattle:FireClient(s.player, { k = "start", floor = floor, foe = Config.towerFoeName(floor), view = Battle.view(s.battle.st), seconds = TW.turnSeconds })
end

function actions.battleAct(s, arg)
	local bt = s.battle
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
			if bt and os.clock() > bt.deadline then
				pcall(battleStep, s, { kind = "attack" })
			end
		end
	end
end)

---------------------------------------------------------------- Game Passes
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local s = sessions[player]
	if not (s and purchased) then
		return
	end
	for name, def in pairs(Config.PASSES) do
		if Config.purchasable(def) and def.id == passId then
			s.passes[name] = true
		end
	end
	if passId == Config.PASSES.ExtraSlots.id and s.plot then
		refreshLocks(s) -- +4 emplacements : cadenas levés sans recréer les pads occupés
	end
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
		if not s.noSave and not Data.save(player, s.data) then
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
			if name == "StarterPack" then
				if s.data.starter then
					return Enum.ProductPurchaseDecision.NotProcessedYet -- achat unique : déjà fait, rien n'est livré
				end
				s.data.starter = true
				s.data.coins += Config.STARTER_PACK.coins
				for _ = 1, Config.STARTER_PACK.eggs do
					giveEgg(s, Config.STARTER_PACK.eggTier)
				end
				s.data.luckUntil = math.max(os.time(), s.data.luckUntil) + Config.LUCK_POTION_SECONDS
			elseif name == "ExclusiveEgg" then
				if not freeSlot(s) then
					notify(player, "Base pleine : libère une place, ton achat sera livré automatiquement.")
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				giveEgg(s, Config.EXCLUSIVE_EGG_TIER)
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
			elseif name == "LuckPotion" then
				s.data.luckUntil = math.max(os.time(), s.data.luckUntil) + Config.LUCK_POTION_SECONDS
			elseif name == "CoinPack" then
				s.data.coins += math.max(Config.COIN_PACK_MIN, income(s) * Config.COIN_PACK_MINUTES * 60)
			end
			granted = true
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
		followers = {}, pendingReceipts = {}, holdSeen = false, flags = 0, noCheckUntil = 0, syncT = 0, leaving = false, traps = {},
		runes = { 1, 1, 1, 1 }, lastRune = 0, runeLock = 0,
		lsCoins = stat("Pièces"), lsSpeed = stat("Vitesse"), lsRb = stat("Renaissances"),
	}
	ls.Parent = player
	player:SetAttribute("Hp", Config.GUARD.maxHp)
	player:SetAttribute("MaxHp", Config.GUARD.maxHp)
	sessions[player] = s
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
			s.passes[name] = ok and owns == true
		end
	end

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
	applyBase(s, false)
	updateSign(s)
	refreshAllPads(s)
	s.welcome = "wait"
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
	while pending > 0 and os.clock() - t0 < 25 do
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
