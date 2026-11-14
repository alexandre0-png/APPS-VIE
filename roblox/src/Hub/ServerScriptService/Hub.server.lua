-- Script : ServerScriptService/Hub (lieu HUB uniquement)
-- Zones de lancement (1 à 5 joueurs), file d'attente visible, téléportation vers le lieu de jeu, liste des parties d'amis (registre
-- MemoryStore) et bouton Rejoindre. Toute la logique de décision est dans Party (testée) ; ici : Roblox (joueurs, zones, services).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.Game.roleFor(game.PlaceId) == "game" then
	return -- lieu de jeu : le code de la partie (Main) s'en charge
end
local PartyMod = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Party"))
local HubWorld = require(script.Parent:WaitForChild("HubWorld"))

local G = Config.Game
local world = HubWorld.build(Config)

local remote = Instance.new("RemoteEvent")
remote.Name = "HubRemote"
remote.Parent = ReplicatedStorage

local function say(player, text, kind)
	remote:FireClient(player, "msg", text, kind or "info")
end

---------------------------------------------------------------- Registre des parties (MemoryStore), tout sous pcall
local map
do
	local ok, m = pcall(function()
		return MemoryStoreService:GetHashMap(G.RegistryName)
	end)
	if ok then
		map = m
	else
		warn("[Hub] MemoryStore indisponible : pas de liste de parties d'amis (" .. tostring(m) .. ")")
	end
end

local store = {}
function store.get(key)
	assert(map, "MemoryStore indisponible")
	return map:GetAsync(key)
end
function store.update(key, fn)
	assert(map, "MemoryStore indisponible")
	return map:UpdateAsync(key, fn, G.PartyTTL)
end
function store.remove(key)
	if map then
		map:RemoveAsync(key)
	end
end
function store.list()
	assert(map, "MemoryStore indisponible")
	local items = map:ListItemsAsync(100):GetCurrentPage()
	local out = {}
	for _, it in ipairs(items) do
		out[#out + 1] = it.value
	end
	return out
end

local P = PartyMod.new(Config, {
	clock = os.clock,
	guid = function()
		return HttpService:GenerateGUID(false)
	end,
	reserve = function(placeId)
		local code = TeleportService:ReserveServerAsync(placeId)
		return code
	end,
	teleport = function(players, placeId, code, data)
		local opts = Instance.new("TeleportOptions")
		if code then
			opts.ReservedServerAccessCode = code
		end
		opts:SetTeleportData(data)
		TeleportService:TeleportAsync(placeId, players, opts)
	end,
	store = store,
	log = warn,
})

---------------------------------------------------------------- Zones de lancement : qui est dans quel portail
local function rootOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function zoneAt(pos)
	for size, z in pairs(world.zones) do
		local d = (Vector3.new(pos.X, 0, pos.Z) - z.center).Magnitude
		if d <= z.radius then
			return size
		end
	end
	return nil
end

local launching = {} -- userId -> true pendant la téléportation (évite de relancer)

local function doLaunch(group)
	local players = {}
	for _, uid in ipairs(group.members) do
		local p = Players:GetPlayerByUserId(uid)
		if p and p.Parent then
			players[#players + 1] = p
			launching[uid] = true
		end
	end
	if #players == 0 then
		return
	end
	local members = {}
	for _, p in ipairs(players) do
		members[#members + 1] = p.UserId
		say(p, "🚀 Départ vers la partie…", "info")
	end
	local res = P.launch({ size = group.size, members = members, players = players, hostName = players[1].DisplayName })
	if not res.ok then
		for _, p in ipairs(players) do
			launching[p.UserId] = nil
			say(p, "⚠️ " .. res.message, "error")
		end
	else
		task.delay(20, function() -- si la téléportation n'a pas fini par déplacer le joueur, on le libère
			for _, p in ipairs(players) do
				launching[p.UserId] = nil
			end
		end)
	end
end

local function statusText(size)
	local st = P.status(size)
	if st.mode == "empty" then
		return "Libre"
	end
	local base = st.count .. "/" .. size .. " joueur" .. (size > 1 and "s" or "")
	if st.countdown then
		return base .. " · départ " .. math.ceil(st.countdown) .. " s"
	end
	return base
end

local lastStatus = {}
task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			if not launching[player.UserId] then
				local root = rootOf(player)
				local size = root and zoneAt(root.Position) or nil
				local cur = P.where[player.UserId]
				if size ~= cur then
					if size then
						if not P.enter(player.UserId, size) then
							say(player, "Cette zone est pleine, choisis-en une autre.", "info")
						end
					else
						P.leave(player.UserId)
					end
				end
			end
		end
		for _, group in ipairs(P.collectLaunches()) do
			task.spawn(doLaunch, group)
		end
		for size, z in pairs(world.zones) do
			local txt = statusText(size)
			if lastStatus[size] ~= txt then
				lastStatus[size] = txt
				z.status.Text = txt
			end
		end
		task.wait(0.25)
	end
end)

---------------------------------------------------------------- Amis : liste des parties ouvertes, rejoindre
local friendCache = {} -- userId -> { t, set }
local function friendsOf(player)
	local c = friendCache[player.UserId]
	if c and os.clock() - c.t < 90 then
		return c.set
	end
	local set = {}
	local ok = pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		for _ = 1, 5 do
			for _, f in ipairs(pages:GetCurrentPage()) do
				set[f.Id] = true
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok and c then
		return c.set
	end
	friendCache[player.UserId] = { t = os.clock(), set = set }
	return set
end

local lastReq = {}
remote.OnServerEvent:Connect(function(player, action, arg)
	local now = os.clock()
	if now - (lastReq[player] or 0) < 0.4 or type(action) ~= "string" then
		return
	end
	lastReq[player] = now
	if action == "parties" then
		local list, ok = P.visibleFor(player.UserId, friendsOf(player))
		remote:FireClient(player, "parties", list, ok)
	elseif action == "join" then
		if type(arg) ~= "string" or #arg > 64 or launching[player.UserId] then
			return
		end
		launching[player.UserId] = true
		P.leave(player.UserId)
		local res = P.join(arg, player, player.UserId, friendsOf(player))
		if not res.ok then
			launching[player.UserId] = nil
			say(player, "⚠️ " .. res.message, "error")
		else
			say(player, "🚀 Tu rejoins la partie…", "info")
			task.delay(20, function()
				launching[player.UserId] = nil
			end)
		end
	end
end)

---------------------------------------------------------------- Arrivées et départs
Players.PlayerAdded:Connect(function(player)
	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	if ok and type(data) == "table" then
		if type(data.partyId) == "string" then
			P.leaveParty(data.partyId, player.UserId) -- de retour de la partie : la place se libère
		end
		if data.reason == "full" then
			task.delay(2, say, player, "Cette partie était pleine (5 joueurs maximum). Choisis-en une autre !", "info")
		end
	end
end)
Players.PlayerRemoving:Connect(function(player)
	P.leave(player.UserId)
	launching[player.UserId] = nil
	lastReq[player] = nil
	friendCache[player.UserId] = nil
end)
