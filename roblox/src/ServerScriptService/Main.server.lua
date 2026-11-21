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

---------------------------------------------------------------- Monde
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
	assets.loadAll()
	assets.loadPets()
	assets.loadProps()
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
	assets.loadGroup("base")
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
end)

local world = Builder.build()
local rng = Random.new()
local sessions = {} -- [Player] = session
local leavingSave = {} -- userId -> true tant que la sauvegarde de départ de ce joueur est en cours (une reconnexion attend)
local pendingSaves, saveLater = {}, nil -- profils à sauvegarder en arrière-plan (voir saveLater)
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
	return type(i) == "number" and i % 1 == 0 and i >= 1 and i <= 12
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

local function cap(d)
	return Rules.capacity(d.up)
end
local function carryCap(d)
	return Rules.carryCapacity(d.up)
end
local function hatchTime(s, tier)
	return Rules.hatchTime(tier, s.data.up.inc, s.passes.Fast == true)
end
local function shieldTime(s)
	return Rules.shieldTime(s.data.up.lock) * (s.passes.VipBase == true and Config.VIP_SHIELD_MUL or 1)
end
-- Multiplicateur de vitesse de marche (pass « Vitesse+ »), appliqué aussi à la tolérance anti-triche.
local function speedMul(s)
	return s.passes.Speed == true and Config.SPEED_PASS_MUL or 1
end
local function freeSlot(d)
	for i = 1, cap(d) do
		if not d.slots[i] then
			return i
		end
	end
	return nil
end

local function gmult(s)
	return Rules.multiplier(s.data.rb, s.data.up.food, evKey() == "gold", s.passes.Coins2x == true, Config.collectionBonus(s.species or 0))
end

local function income(s)
	return Rules.income(s.data.slots, cap(s.data), gmult(s))
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
	return { hatched = d.hatched, stolen = d.stolen, species = s.species, rb = d.rb, puzzles = d.puzzle.solved }
end

---------------------------------------------------------------- Synchronisation client
local function snapshot(s)
	local d = s.data
	local slots = {}
	for i = 1, 12 do
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
		cap = cap(d),
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
		baseLevel = s.baseLevel,
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

---------------------------------------------------------------- Vitesse / étourdissement
local function applySpeed(s)
	local hum = getHum(s.player)
	if hum and s.stun <= 0 then
		local ws = Config.walkSpeed(s.data.speed) * speedMul(s) * 0.93 ^ #s.carry
		if math.abs(hum.WalkSpeed - ws) > 0.05 then
			hum.WalkSpeed = ws
		end
	end
end

---------------------------------------------------------------- Œufs portés
local function rebuildCarry(s)
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
	pr.HoldDuration = Config.stealTime(0)
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Kind", "Nest")
	pr:SetAttribute("Nest", n.index)
	pr:SetAttribute("Rival", n.rival) -- le client masque le prompt tant que la zone est verrouillée
	pr.Parent = egg
	CollectionService:AddTag(pr, "StealPrompt")
	Builder.sign(egg, Config.TIERS[tier].name, Config.TIERS[tier].color, 3, 160)
end

for i, n in ipairs(world.nests) do
	n.index = i
	setNestEgg(n, wpick(Config.RIVALS[n.rival].weights))
end

---------------------------------------------------------------- Pads d'une base
local hatch, speedUpEgg -- déclarations anticipées

local function clearPad(s, i)
	local pad = s.plot.pads[i]
	if pad.content then
		pad.content:Destroy()
		pad.content = nil
	end
	s.labels[i] = nil
end

local function refreshPad(s, i, animate)
	clearPad(s, i)
	local d = s.data
	local pad = s.plot.pads[i]
	local locked = i > cap(d)
	pad.lock.Enabled = locked
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
		Builder.nest(pad.part.Position + Vector3.new(0, 0.3, 0), content) -- l'œuf repose sur un nid
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
	for i = 1, 12 do
		refreshPad(s, i)
	end
end

---------------------------------------------------------------- Retour / chute des œufs portés
local function returnEgg(e)
	if e.rival then
		for _, n in ipairs(world.nests) do
			if n.rival == e.rival and not n.egg then
				setNestEgg(n, e.t)
				return
			end
		end
	elseif e.from then
		local vp = Players:GetPlayerByUserId(e.from)
		local vs = vp and sessions[vp]
		if vs then
			local i = freeSlot(vs.data)
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
		returnEgg(e)
	end
	s.carry = {}
	rebuildCarry(s)
	applySpeed(s)
	if s.player.Parent then
		sync(s)
	end
end

local function afterTake(s)
	rebuildCarry(s)
	applySpeed(s)
	sync(s)
	notify(s.player, "🥚 Œuf volé ! Rapporte-le vite à ta base.", "steal")
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
-- Reconstruit l'apparence de la base au niveau courant et publie le niveau (attributs lus par le client : effet de montée de niveau, interface).
local function applyBase(s, announce)
	local level, nxt = Config.baseLevel(s.data.baseScore)
	local before = s.baseLevel
	s.baseLevel = level
	if before ~= level and s.plot then
		Builder.baseUpgrade(s.plot, level)
	end
	s.player:SetAttribute("BaseLevel", level)
	s.player:SetAttribute("BaseScore", s.data.baseScore)
	if announce and before and level > before then
		local lv = Config.BASE_LEVELS[level]
		notify(s.player, "🏠 Ta base passe au niveau " .. level .. " : " .. lv.emoji .. " " .. lv.name .. (nxt and (" · prochain palier : " .. nxt.name) or " · niveau maximum !"), "claim")
	end
end

---------------------------------------------------------------- Éclosion
function hatch(s, i)
	local d = s.data
	local sl = d.slots[i]
	if not sl or sl.k ~= "e" then
		return
	end
	local guaranteed = sl.t < #Config.TIERS and d.pity >= Config.PITY_EVERY - 1
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
	RHatch:FireClient(s.player, { p = p.p, s = p.s, m = p.m, slot = i, inc = Config.petIncome(p.p, p.s, p.m) * gmult(s), oneIn = oneIn < math.huge and oneIn or 0, egg = sl.t })
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
	local i = freeSlot(d)
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

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
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
		if not h or h.prompt ~= prompt or os.clock() - h.t < Config.stealTime(s.data.up.fing) * 0.7 then
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
		s.carry[#s.carry + 1] = { t = t, rem = hatchTime(s, t), rival = n.rival }
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
	local r = Config.RIVALS[g.rival]
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
	return math.abs(rel.X) <= 27 and math.abs(rel.Z) <= 27 and rel.Y < 30
end

-- Zone de sécurité : la base du joueur et l'entrée du plateau (sommet de la rampe) ne sont jamais ciblées.
local function safeSpot(s, root, rival)
	if s.plot and inPlot(s, root) then
		return true
	end
	local ramp = Config.rampOf(rival)
	return math.sqrt((root.Position.X - ramp.top[1]) ^ 2 + (root.Position.Z - ramp.top[2]) ^ 2) < GC.safeRadius
end

local function candidate(g, r)
	local best, bd = nil, math.max(r.viewDist, r.hearRadius) + 2
	for player, s in pairs(sessions) do
		if Config.zoneUnlocked(s.data.story.ch, g.rival) and alive(player) then
			local root = getRoot(player)
			if root and not safeSpot(s, root, g.rival) then
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

local function guardsStep(dt)
	for _, s in pairs(sessions) do -- invulnérabilité et temps depuis le dernier coup
		s.iframes = math.max(0, (s.iframes or 0) - dt)
		s.sinceHit = (s.sinceHit or 99) + dt
	end
	for _, g in ipairs(world.guards) do
		local r = Config.RIVALS[g.rival]
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
				target = candidate(g, r)
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
				r, GC
			)
			if percept.sees or percept.hears then
				g.last = Vector3.new(troot.Position.X, g.pos.Y, troot.Position.Z)
			end
		end
		local home = Vector3.new(math.clamp(g.pos.X, g.cx - 12, g.cx + 12), g.pos.Y, g.patrolZ)
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
		if state == "patrol" then
			g.pos += Vector3.new(g.dir * r.patrolSpeed * dt, 0, 0)
			if g.pos.X > g.cx + 12 then
				g.dir = -1
			elseif g.pos.X < g.cx - 12 then
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
			if dv.Magnitude >= 1 then
				look = dv.Unit
				g.pos += look * math.min(dv.Magnitude, r.patrolSpeed * 1.6 * dt)
			end
		end
		if look and look.Magnitude > 0.01 then
			g.look = look.Unit
			g.model:PivotTo(CFrame.lookAt(g.pos, g.pos + g.look))
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
	local i = freeSlot(d)
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
			Builder.animKnight(v, Castle.ORIGIN.x + kx, v.wz, dir)
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
			-- tapis roulant : il faut courir dessus
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
			s.lastPos = pos
			-- dépôt des œufs dans sa base
			if #s.carry > 0 and inPlot(s, root) then
				local i = freeSlot(d)
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
				setNestEgg(n, wpick(Config.RIVALS[n.rival].weights))
			end
		end
	end
	local now = os.time()
	for player, s in pairs(sessions) do
		local ok, err = pcall(function()
			local d = s.data
			local inc = income(s)
			d.coins += inc * dt
			qp(s, "earn", inc * dt)
			ensureQuests(s)
			storyRefresh(s)
			s.syncT += dt
			if s.syncT >= 10 then
				s.syncT = 0
				RState:FireClient(player, snapshot(s))
			end
			for i = 1, cap(d) do
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

local acc1, acc2, acc3 = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	guardsStep(dt)
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
	local i = freeSlot(d)
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
	local list, total = Config.dupesToSell(d.slots, cap(d))
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
	fresh.puzzle, fresh.ach = d.puzzle, d.ach
	fresh.cine = d.cine
	fresh.secrets = d.secrets
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
	local fn = actions[action]
	if fn then
		local ok, err = pcall(fn, s, arg)
		if not ok then
			warn("[Action " .. action .. "] " .. tostring(err))
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
				if not freeSlot(s.data) then
					notify(player, "Base pleine : libère une place, ton achat sera livré automatiquement.")
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				giveEgg(s, Config.EXCLUSIVE_EGG_TIER)
			elseif name == "InstantHatch" then
				for i = 1, cap(s.data) do
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
	for i = 1, 12 do
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
		graceUntil = late and (os.time() + Config.Game.LateJoinGrace) or 0, hp = Config.GUARD.maxHp, iframes = 0, sinceHit = 99, stun = 0, lastAct = 0, lastTap = 0, lastSteal = 0, lastFull = 0, noSave = noSave,
		followers = {}, pendingReceipts = {}, holdSeen = false, flags = 0, noCheckUntil = 0, syncT = 0, leaving = false,
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

	-- gains hors-ligne (les œufs éclosent seuls grâce aux horodatages)
	local away = math.clamp(os.time() - d.last, 0, 4 * 3600)
	if away > 30 then
		local gain = income(s) * away * 0.4
		d.coins += gain
		notify(player, "Pendant ton absence : +" .. Config.fmt(gain) .. " 🪙")
	end

	ensureQuests(s)
	applyBase(s, false)
	updateSign(s)
	refreshAllPads(s)
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
		return CFrame.new(0, 8, 60) -- à côté du tapis roulant : toujours au sol de l'arène
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
