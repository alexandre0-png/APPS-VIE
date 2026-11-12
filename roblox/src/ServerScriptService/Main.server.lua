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
local Data = require(script.Parent:WaitForChild("Data"))
local Builder = require(script.Parent:WaitForChild("Builder"))

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
local world = Builder.build()
local rng = Random.new()
local sessions = {} -- [Player] = session

local function wpick(ws)
	local total = 0
	for _, w in ipairs(ws) do
		total += w
	end
	local r = rng:NextNumber() * total
	for i, w in ipairs(ws) do
		r -= w
		if r < 0 then
			return i
		end
	end
	return #ws
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
local function notify(player, msg)
	if player and player.Parent then
		RNotify:FireClient(player, msg)
	end
end

---------------------------------------------------------------- Règles
local currentEvent = nil -- { cfg, ends }
local function evKey()
	return currentEvent and currentEvent.cfg.key or nil
end

local function cap(d)
	return 4 + d.up.slots
end
local function carryCap(d)
	return 1 + d.up.bag
end
local function hatchTime(d, tier)
	return Config.HATCH[tier] * 0.9 ^ d.up.inc
end
local function shieldTime(d)
	return Config.SHIELD_BASE + Config.SHIELD_PER_LEVEL * d.up.lock
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
	local d = s.data
	local m = (1 + 0.5 * d.rb) * (1 + 0.2 * d.up.food)
	if evKey() == "gold" then
		m *= 2
	end
	if s.passes.Coins2x then
		m *= 2
	end
	return m
end

local function income(s)
	local d = s.data
	local total = 0
	for i = 1, cap(d) do
		local sl = d.slots[i]
		if sl and sl.k == "p" then
			total += Config.petIncome(sl.p, sl.s, sl.m)
		end
	end
	return total * gmult(s)
end

local function pickTier(s, tier)
	local up = 0
	if tier < #Config.TIERS then
		up = 12 + 3 * s.data.up.luck
		if evKey() == "luck" then
			up += 10
		end
		if s.passes.Lucky then
			up += 10
		end
		if os.time() < s.data.luckUntil then
			up += Config.LUCK_POTION_BONUS
		end
	end
	local down = tier > 1 and 22 or 0
	local i = wpick({ down, 100 - up - down, up })
	return tier + i - 2
end

local sizeWeights = {}
for i, z in ipairs(Config.SIZES) do
	sizeWeights[i] = z.weight
end

local function rollPet(s, eggTier)
	local tier = pickTier(s, eggTier)
	local ids = {}
	for i, p in ipairs(Config.PETS) do
		if p.tier == tier then
			ids[#ids + 1] = i
		end
	end
	local mw = {}
	for i, m in ipairs(Config.MUTS) do
		mw[i] = m.weight
	end
	if evKey() == "alien" then
		mw[5] *= 5
	end
	return { p = ids[rng:NextInteger(1, #ids)], s = wpick(sizeWeights), m = wpick(mw) }
end

---------------------------------------------------------------- Missions quotidiennes
local QUEST_TYPES = { "steal", "hatch", "earn", "train", "pvp" }

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
		else
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
		quests = d.quests,
		equip = d.equip,
		luckLeft = math.max(0, d.luckUntil - os.time()),
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
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Voler l'œuf"
	pr.ObjectText = "Œuf " .. Config.TIERS[tier].name
	pr.HoldDuration = Config.stealTime(0)
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Kind", "Nest")
	pr:SetAttribute("Nest", n.index)
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

local function refreshPad(s, i)
	clearPad(s, i)
	local d = s.data
	local pad = s.plot.pads[i]
	local locked = i > cap(d)
	pad.lock.Enabled = locked
	pad.part.Transparency = locked and 0.25 or 0.7
	pad.part.Color = locked and Color3.fromRGB(40, 40, 45) or Color3.new(1, 1, 1)
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
				vs.data.slots[i] = { k = "e", t = e.t, ends = os.time() + e.rem, shield = 0 }
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
	notify(s.player, "🥚 Œuf volé ! Rapporte-le vite à ta base.")
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

---------------------------------------------------------------- Éclosion
function hatch(s, i)
	local d = s.data
	local sl = d.slots[i]
	if not sl or sl.k ~= "e" then
		return
	end
	local p = rollPet(s, sl.t)
	d.slots[i] = { k = "p", p = p.p, s = p.s, m = p.m }
	d.hatched += 1
	local key = tostring(p.p)
	local dx = d.dex[key]
	if not dx then
		dx = { n = 0, b = 0 }
		d.dex[key] = dx
	end
	dx.n += 1
	dx.b = math.max(dx.b, Config.SIZES[p.s].mult * Config.MUTS[p.m].mult)
	refreshPad(s, i)
	qp(s, "hatch", 1)
	local def = Config.PETS[p.p]
	local big = def.tier >= 4 or p.m > 1 or p.s >= 4
	local col = Config.MUTS[p.m].color or Config.TIERS[def.tier].color
	Builder.burst(s.plot.pads[i].part.Position + Vector3.new(0, 3, 0), col, big and 90 or 25, big)
	RHatch:FireClient(s.player, { p = p.p, s = p.s, m = p.m, inc = Config.petIncome(p.p, p.s, p.m) * gmult(s) })
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

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local kind = prompt:GetAttribute("Kind")
	if kind ~= "Nest" and kind ~= "Pad" then
		return
	end
	local s = sessions[player]
	local root = getRoot(player)
	if not s or not root or not alive(player) or s.stun > 0 then
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
		local t = n.egg
		setNestEgg(n, nil)
		n.rt = rng:NextNumber(9, 16) * (1 + (n.rival - 1) * 0.3)
		s.carry[#s.carry + 1] = { t = t, rem = hatchTime(s.data, t), rival = n.rival }
		s.data.stolen += 1
		qp(s, "steal", 1)
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
		if (sl.shield or 0) > os.time() then
			notify(player, "🛡 Cet œuf est encore protégé !")
			return
		end
		local pad = vs.plot.pads[i].part
		if (root.Position - pad.Position).Magnitude > 20 then
			return
		end
		vs.data.slots[i] = false
		refreshPad(vs, i)
		s.carry[#s.carry + 1] = { t = sl.t, rem = math.max(0, sl.ends - os.time()), from = vp.UserId }
		s.data.stolen += 1
		qp(s, "steal", 1)
		qp(s, "pvp", 1)
		notify(vp, "😡 " .. player.DisplayName .. " a volé ton œuf ! Rattrape-le !")
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
	notify(s.player, "🐕 Le gardien de " .. r.name .. " t'a attrapé !")
end

local function nearestTarget(pos, maxDist)
	local best, bd = nil, maxDist
	for player, s in pairs(sessions) do
		if s.stun <= 0 and alive(player) then
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
				local t = nearestTarget(g.pos, 16)
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
			notify(p, cfg.emoji .. " " .. cfg.name .. " ! " .. cfg.desc)
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
	d.slots[i] = { k = "e", t = tier, ends = os.time() + hatchTime(d, tier), shield = os.time() + shieldTime(d) }
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
	dropCarry(s)
	s.data = fresh
	refreshAllPads(s)
	rebuildFollowers(s)
	sync(s)
	notify(s.player, string.format("♻️ Renaissance ! Revenus x%.1f", 1 + 0.5 * fresh.rb))
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
	notify(s.player, "🎯 Mission accomplie : +" .. Config.fmt(q.rew) .. " 🪙")
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
	notify(s.player, "🎁 Bonus quotidien : +" .. Config.fmt(reward) .. " 🪙 (série " .. streak .. ")")
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
		if def.id > 0 and def.id == passId then
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
		if def.id > 0 and def.id == info.ProductId then
			if name == "InstantHatch" then
				for i = 1, cap(s.data) do
					hatch(s, i)
				end
			elseif name == "LuckPotion" then
				s.data.luckUntil = math.max(os.time(), s.data.luckUntil) + Config.LUCK_POTION_SECONDS
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
	end
	s.plot.owner = nil
	s.plot.nameLabel.Text = "Base libre"
end

local function onJoin(player)
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
	local s = {
		player = player, data = d, plot = plot, carry = {}, carryParts = {}, labels = {}, passes = {},
		stun = 0, lastAct = 0, lastTap = 0, lastSteal = 0, lastFull = 0, noSave = noSave,
		followers = {}, holdSeen = false, flags = 0, noCheckUntil = 0, syncT = 0,
		lsCoins = stat("Pièces"), lsSpeed = stat("Vitesse"), lsRb = stat("Renaissances"),
	}
	ls.Parent = player
	sessions[player] = s

	for name, def in pairs(Config.PASSES) do
		s.passes[name] = false
		if def.id > 0 then
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
	refreshAllPads(s)
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
					player:LoadCharacter()
				end
			end)
		end)
	end)
	if player.Parent then
		player:LoadCharacter()
		sync(s)
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
			if not s.noSave then
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
