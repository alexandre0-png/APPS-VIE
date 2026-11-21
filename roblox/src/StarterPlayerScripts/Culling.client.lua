-- LocalScript : StarterPlayer/StarterPlayerScripts/Culling
-- Masque les zones (domaines) éloignées du joueur : au-delà de Config.Culling.cullAt studs du bord d'une zone, ses Parts passent en transparence locale totale
-- (LocalTransparencyModifier = 1) et ses lumières, particules, faisceaux, feux et étiquettes sont coupés ; en dessous de showAt, tout revient. Rien n'est détruit ni
-- déplacé : les collisions et la réplication serveur ne changent pas. Découpé en lots par image, coupé par Config.Culling.enabled = false.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Culling = require(Shared:WaitForChild("Culling"))
if not Config.Culling.enabled then
	return
end
local player = Players.LocalPlayer

local zones = {} -- { x, z, radius, names = { dossiers }, culled, items = nil | { instances }, itemsAt }
for i, riv in ipairs(Config.RIVALS) do
	local x, z = Config.rivalCenter(i)
	zones[i] = { x = x, z = z, radius = Config.Map.plateauRadius, names = { "Rival_" .. riv.name, "Terrace_" .. riv.name }, culled = false }
end

local SWITCHABLE = { PointLight = true, SpotLight = true, SurfaceLight = true, ParticleEmitter = true, Beam = true, Fire = true, Smoke = true, Sparkles = true, BillboardGui = true, SurfaceGui = true, Highlight = true }

local function collect(zone)
	local world = workspace:FindFirstChild("World")
	local items = {}
	if world then
		for _, name in ipairs(zone.names) do
			local folder = world:FindFirstChild(name)
			if folder then
				for _, d in ipairs(folder:GetDescendants()) do
					if d:IsA("BasePart") or SWITCHABLE[d.ClassName] then
						items[#items + 1] = d
					end
				end
			end
		end
	end
	zone.items, zone.itemsAt = items, os.clock()
	return items
end

-- Applique l'état (masqué ou visible) à tous les éléments d'une zone, lot par lot (jamais plus de Config.Culling.batch par image).
local function apply(zone, hide)
	local items = (zone.items and os.clock() - zone.itemsAt < Config.Culling.refresh) and zone.items or collect(zone)
	for _, lot in ipairs(Culling.chunks(items, Config.Culling.batch)) do
		for _, d in ipairs(lot) do
			pcall(function()
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = hide and 1 or 0
				else
					d.Enabled = not hide
				end
			end)
		end
		task.wait()
	end
end

task.spawn(function()
	while true do
		task.wait(Config.Culling.interval)
		local ok = pcall(function()
			local cam = workspace.CurrentCamera
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local pos = root and root.Position or (cam and cam.CFrame.Position)
			if not pos then
				return
			end
			for _, zone in ipairs(zones) do
				local d = Culling.distanceTo(pos.X, pos.Z, zone)
				local hide = Culling.decide(d, zone.culled, Config.Culling.cullAt, Config.Culling.showAt)
				if hide ~= zone.culled then
					zone.culled = hide
					apply(zone, hide)
				end
			end
		end)
		if not ok then
			warn("[Culling] désactivé pour cette session après une erreur")
			break
		end
	end
end)
