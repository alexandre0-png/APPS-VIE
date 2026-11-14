--[[
  Profile : progression sauvegardée d'un joueur (rang, fins vues, défis, tutoriel, dernières graines).
  Partagée par le hub et la partie (même expérience, même DataStore).
  - newCache(store, Ranks) : logique pure, testable avec un faux DataStore.
  - Profile.load / get / save / attachLabel : branchement Roblox (Players, DataStoreService).
  Un échec du DataStore ne bloque jamais le jeu : le profil reste en mémoire pour la session.
]]
local Profile = {}

local function deepcopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = deepcopy(v)
	end
	return out
end

-- store : { get = function(key) -> data, ok ; set = function(key, data) -> ok }
function Profile.newCache(store, Ranks)
	local cache = {}
	local self = {}

	function self.load(key)
		local data, ok = nil, false
		if store then
			data, ok = store.get(key)
		end
		cache[key] = Ranks.normalize(ok and data or nil)
		return cache[key]
	end

	function self.get(key)
		return cache[key]
	end

	function self.save(key)
		local p = cache[key]
		if not p or not store then
			return false
		end
		return store.set(key, deepcopy(p)) == true
	end

	function self.release(key)
		self.save(key)
		cache[key] = nil
	end

	return self
end

-- Branchement Roblox ---------------------------------------------------------------------------

local cache = nil

local function init()
	if cache then
		return cache
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Ranks = require(Shared.Ranks)
	local store = nil
	if Config.Replay.StoreProfile then
		local ok, ds = pcall(function()
			return game:GetService("DataStoreService"):GetDataStore(Config.Replay.DataStoreName)
		end)
		if ok and ds then
			store = {
				get = function(key)
					for attempt = 1, 3 do
						local good, value = pcall(function()
							return ds:GetAsync(key)
						end)
						if good then
							return value, true
						end
						task.wait(attempt)
					end
					warn("[Profile] lecture impossible : profil neuf en mémoire")
					return nil, false
				end,
				set = function(key, data)
					for attempt = 1, 3 do
						local good = pcall(function()
							ds:UpdateAsync(key, function()
								return data
							end)
						end)
						if good then
							return true
						end
						task.wait(attempt)
					end
					warn("[Profile] écriture impossible : progression gardée en mémoire seulement")
					return false
				end,
			}
		end
	end
	cache = Profile.newCache(store, Ranks)
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(player)
		cache.release("p" .. player.UserId)
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			cache.save("p" .. player.UserId)
		end
	end)
	return cache
end

function Profile.load(player)
	return init().load("p" .. player.UserId)
end

function Profile.get(player)
	local c = init()
	return c.get("p" .. player.UserId) or c.load("p" .. player.UserId)
end

function Profile.save(player)
	return init().save("p" .. player.UserId)
end

-- Rang et titre au-dessus de la tête (visible de tous), mis à jour à chaque apparition du personnage
function Profile.attachLabel(player)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Ranks = require(Shared.Ranks)
	local Config = require(Shared.Config)
	if not Config.Ranks.Enabled then
		return
	end
	local function put(character)
		task.spawn(function()
			local profile = Profile.get(player)
			local head = character:WaitForChild("Head", 10)
			if not head or not profile then
				return
			end
			local old = head:FindFirstChild("RangTitre")
			if old then
				old:Destroy()
			end
			local gui = Instance.new("BillboardGui")
			gui.Name = "RangTitre"
			gui.Size = UDim2.fromOffset(200, 24)
			gui.StudsOffset = Vector3.new(0, 2.4, 0)
			gui.MaxDistance = 60
			gui.AlwaysOnTop = false
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamMedium
			text.TextSize = 14
			text.TextColor3 = Color3.fromRGB(215, 205, 185)
			text.TextStrokeTransparency = 0.5
			text.Text = Ranks.label(profile)
			text.Parent = gui
			gui.Parent = head
		end)
	end
	player.CharacterAdded:Connect(put)
	if player.Character then
		put(player.Character)
	end
end

return Profile
