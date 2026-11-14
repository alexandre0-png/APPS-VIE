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
	local assets = require(script.Parent:WaitForChild("Assets")).new(Config, {
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
end)

local world = Builder.build()
local rng = Random.new()
local sessions = {} -- [Player] = session

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
local function shieldTime(d)
	return Rules.shieldTime(d.up.lock)
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
	return Rules.rollPet(eggTier, up, evKey() == "alien", rnd, guaranteed)
end

---------------------------------------------------------------- Missions quotidiennes
local QUEST_TYPES = { "steal", "hatch", "earn", "train", "pvp", "discover", "sell" }

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
		else -- pvp, discover
			goal = rng:NextInteger(1, 2)
		end
		out[#out + 1] = { t = t, goal = goal, prog = 0, rew = math.floor(math.max(250, inc * 150)), claimed = false }
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
		local ws = Config.walkSpeed(s.data.speed) * 0.93 ^ #s.carry
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
				vs.data.slots[i] = { k = "e", t = e.t, ends = os.time() + e.rem, shield = os.time() + shieldTime(vs.data) }
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

---------------------------------------------------------------- Éclosion
function hatch(s, i)
	local d = s.data
	local sl = d.slots[i]
	if not sl or sl.k ~= "e" then
		return
	end
	local guaranteed = sl.t < #Config.TIERS and d.pity >= Config.PITY_EVERY - 1
	local p = rollPet(s, sl.t, guaranteed)
	if p.tier > sl.t then
		d.pity = 0
	elseif sl.t < #Config.TIERS then
		d.pity += 1
	end
	d.slots[i] = { k = "p", p = p.p, s = p.s, m = p.m }
	d.hatched += 1
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
	sp(s, "tier", 1, { tier = def.tier })
	if p.m > 1 then
		sp(s, "mut", 1)
	end
	storyRefresh(s)
	local big = def.tier >= 4 or p.m > 1 or p.s >= 4
	local col = Config.MUTS[p.m].color or Config.TIERS[def.tier].color
	Builder.burst(s.plot.pads[i].part.Position + Vector3.new(0, 3, 0), col, big and 90 or 25, big)
	RHatch:FireClient(s.player, { p = p.p, s = p.s, m = p.m, slot = i, inc = Config.petIncome(p.p, p.s, p.m) * gmult(s) })
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
		d.slots[i] = { k = "e", t = tier, ends = os.time() + hatchTime(s, tier), shield = os.time() + shieldTime(d) }
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
	notify(s.player, sct.emoji .. " " .. sct.name .. " : +" .. Config.fmt(reward) .. " 🪙", "claim")
	sync(s)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
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

---------------------------------------------------------------- Gardiens PNJ
local function catchPlayer(s, g)
	local r = Config.RIVALS[g.rival]
	local root = getRoot(s.player)
	local hum = getHum(s.player)
	dropCarry(s)
	s.stun = 1.3
	s.noCheckUntil = os.clock() + 2
	if hum then
		hum.PlatformStand = true
	end
	if root then
		local away = (root.Position - g.pos) * Vector3.new(1, 0, 1)
		away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
		root.AssemblyLinearVelocity = away * 45 + Vector3.new(0, 35, 0)
	end
	g.state = "return"
	g.cd = 2.5
	notify(s.player, "🐕 Le gardien de " .. r.name .. " t'a attrapé !", "caught")
end

-- rival : seuls les joueurs dont ce domaine est ouvert peuvent être ciblés (un joueur qui longe la barrière est ignoré)
local function nearestTarget(pos, maxDist, rival)
	local best, bd = nil, maxDist
	for player, s in pairs(sessions) do
		if s.stun <= 0 and Config.zoneUnlocked(s.data.story.ch, rival) and alive(player) then
			local root = getRoot(player)
			if root then
				local dv = root.Position - pos
				local dd = Vector3.new(dv.X, 0, dv.Z).Magnitude
				if dd < bd then
					best, bd = player, dd
				end
			end
		end
	end
	return best
end

local function guardsStep(dt)
	for _, g in ipairs(world.guards) do
		local r = Config.RIVALS[g.rival]
		g.cd -= dt
		local look
		if g.state == "patrol" then
			g.pos += Vector3.new(g.dir * r.patrolSpeed * dt, 0, 0)
			if g.pos.X > g.cx + 12 then
				g.dir = -1
			elseif g.pos.X < g.cx - 12 then
				g.dir = 1
			end
			look = Vector3.new(g.dir, 0, 0)
			g.scan = (g.scan or 0) - dt
			if g.cd <= 0 and g.scan <= 0 then
				g.scan = 0.15
				local t = nearestTarget(g.pos, 16, g.rival)
				if t then
					g.state, g.target, g.lost = "chase", t, 0
				end
			end
		elseif g.state == "chase" then
			local t = g.target
			local s = t and sessions[t]
			local root = t and getRoot(t)
			if not (s and root and s.stun <= 0 and alive(t)) then
				g.lost = 2
			else
				local dv = root.Position - g.pos
				local flat = Vector3.new(dv.X, 0, dv.Z)
				local dd = flat.Magnitude
				local fromHome = Vector3.new(root.Position.X - g.cx, 0, root.Position.Z - (g.patrolZ - 12)).Magnitude
				if fromHome > 55 or dd > 40 then
					g.lost += dt
				else
					g.lost = 0
				end
				if dd > 0.01 then
					look = flat.Unit
					g.pos += look * math.min(dd, r.guardSpeed * dt)
				end
				if dd < 4.5 and g.cd <= 0 then
					catchPlayer(s, g)
				end
			end
			if g.lost > 1.2 then
				g.state, g.target = "return", nil
			end
		else
			local home = Vector3.new(math.clamp(g.pos.X, g.cx - 12, g.cx + 12), g.pos.Y, g.patrolZ)
			local dv = home - g.pos
			if dv.Magnitude < 1 then
				g.state = "patrol"
			else
				look = dv.Unit
				g.pos += look * math.min(dv.Magnitude, r.patrolSpeed * 1.6 * dt)
			end
		end
		if look and look.Magnitude > 0.01 then
			g.model:PivotTo(CFrame.lookAt(g.pos, g.pos + look))
		end
	end
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
local function inPlot(s, root)
	local rel = s.plot.cf:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= 27 and math.abs(rel.Z) <= 27 and rel.Y < 30
end

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
				local allowed = (Config.walkSpeed(d.speed) + 16) * dt * 1.4 + 3
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
					d.slots[i] = { k = "e", t = e.t, ends = os.time() + e.rem, shield = os.time() + shieldTime(d) }
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
			pushStats(s)
		end)
		if not ok then
			warn("[slowTick] " .. tostring(err))
		end
	end
end

local acc1, acc2 = 0, 0
RunService.Heartbeat:Connect(function(dt)
	guardsStep(dt)
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
		return notify(s.player, "Pas assez de pièces !")
	end
	local i = freeSlot(d)
	if not i then
		return notify(s.player, "Base pleine !")
	end
	d.coins -= price
	d.slots[i] = { k = "e", t = tier, ends = os.time() + hatchTime(s, tier), shield = os.time() + shieldTime(d) }
	refreshPad(s, i)
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
		return notify(s.player, "Pas assez de pièces !")
	end
	d.coins -= cost
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

function actions.rebirth(s)
	local d = s.data
	if d.coins < Config.rebirthCost(d.rb) then
		return notify(s.player, "Pas assez de pièces pour renaître.")
	end
	local fresh = Data.default()
	fresh.speed, fresh.rb, fresh.dex = d.speed, d.rb + 1, d.dex
	fresh.daily, fresh.streak, fresh.stolen, fresh.hatched = d.daily, d.streak, d.stolen, d.hatched
	fresh.quests, fresh.qday, fresh.receipts, fresh.luckUntil = d.quests, d.qday, d.receipts, d.luckUntil
	fresh.story, fresh.pity = d.story, d.pity
	fresh.puzzle, fresh.ach = d.puzzle, d.ach
	fresh.cine = d.cine
	fresh.secrets = d.secrets
	dropCarry(s)
	s.data = fresh
	refreshAllPads(s)
	rebuildFollowers(s)
	storyRefresh(s)
	sync(s)
	notify(s.player, string.format("♻️ Renaissance ! Revenus x%.1f", 1 + 0.5 * fresh.rb), "claim")
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
	notify(s.player, "🎯 Mission accomplie : +" .. Config.fmt(q.rew) .. " 🪙", "claim")
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
	local reward = math.floor(math.max(200, income(s) * 600) * math.min(streak, 7))
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
	if s.data.receipts[rid] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local granted = false
	for name, def in pairs(Config.PRODUCTS) do
		if Config.purchasable(def) and def.id == info.ProductId then
			if name == "InstantHatch" then
				for i = 1, cap(s.data) do
					hatch(s, i)
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
	sync(s)
	if not s.noSave and not Data.save(player, s.data) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
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

local serverPartyId = nil -- identifiant de la partie de ce serveur (celui du premier joueur envoyé par le hub)

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
	local late = next(sessions) ~= nil -- arrivée dans une partie déjà commencée
	local d, noSave = Data.load(player)
	if not d then
		player:Kick("Impossible de charger tes données. Reconnecte-toi dans un instant.")
		return
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
		graceUntil = late and (os.time() + Config.Game.LateJoinGrace) or 0, stun = 0, lastAct = 0, lastTap = 0, lastSteal = 0, lastFull = 0, noSave = noSave,
		followers = {}, holdSeen = false, flags = 0, noCheckUntil = 0, syncT = 0, leaving = false,
		runes = { 1, 1, 1, 1 }, lastRune = 0, runeLock = 0,
		lsCoins = stat("Pièces"), lsSpeed = stat("Vitesse"), lsRb = stat("Renaissances"),
	}
	ls.Parent = player
	sessions[player] = s
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
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
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
		Data.save(player, s.data, true) -- libère le verrou
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
