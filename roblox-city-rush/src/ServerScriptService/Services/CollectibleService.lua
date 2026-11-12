--[[
	CollectibleService : 30 étoiles dorées cachées dans la ville (stockées par joueur).
	Détection par proximité côté serveur (aucune confiance accordée au client).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local RemoteService = require(script.Parent.RemoteService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)

local CollectibleService = {}

local stars = {} -- { id, pos }
local RADIUS = 9

local function collectedList(profile)
	local list = {}
	for key in pairs(profile.Collected) do
		table.insert(list, tonumber(key))
	end
	table.sort(list)
	return list
end

local function sendList(player)
	local profile = DataService.get(player)
	if profile then
		RemoteService.fire("Collected", player, collectedList(profile), #stars)
	end
end

local function collect(player, profile, id)
	profile.Collected[tostring(id)] = true
	local count = 0
	for _ in pairs(profile.Collected) do
		count += 1
	end
	profile.Stats.collected = count
	local paid = EconomyService.addCash(player, Config.Collectibles.Reward, "star")
	EconomyService.addXP(player, 15)
	RemoteService.notify(player, string.format("Étoile dorée %d/%d  +%s", count, #stars, Util.formatCash(paid)), "star")
	local bonus = Config.Collectibles.Milestones[count]
	if bonus then
		local b = EconomyService.addCash(player, bonus, "milestone")
		RemoteService.notify(player, string.format("Palier %d étoiles ! Bonus %s", count, Util.formatCash(b)), "levelup")
	end
	DataService.markDirty(player)
	EconomyService.checkAchievements(player)
	EconomyService.markState(player)
	sendList(player)
end

function CollectibleService.init(world)
	local folder = Instance.new("Folder")
	folder.Name = "Stars"
	folder.Parent = world.Root

	for i, pos in ipairs(world.StarSpots) do
		local p = Instance.new("Part")
		p.Name = "GoldStar"
		p.Size = Vector3.new(3.4, 3.4, 3.4)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(45), 0, math.rad(45))
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 205, 40)
		p:SetAttribute("StarId", i)
		p.Parent = folder
		game:GetService("CollectionService"):AddTag(p, "GoldStar")
		local light = Instance.new("PointLight")
		light.Color = p.Color
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = p
		table.insert(stars, { id = i, pos = pos })
	end

	DataService.Loaded:Connect(function(player)
		sendList(player)
	end)
	RemoteService.on("RequestState", 1, nil, sendList)
end

function CollectibleService.start()
	Util.supervise("CollectibleService", function()
		while true do
			task.wait(0.2)
			for _, player in ipairs(Players:GetPlayers()) do
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local profile = DataService.get(player)
				if hrp and profile then
					local pos = hrp.Position
					for _, s in ipairs(stars) do
						if (s.pos - pos).Magnitude < RADIUS and not profile.Collected[tostring(s.id)] then
							collect(player, profile, s.id)
						end
					end
				end
			end
		end
	end)
end

return CollectibleService
