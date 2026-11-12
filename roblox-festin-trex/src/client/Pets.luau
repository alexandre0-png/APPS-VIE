--!nonstrict
-- Rendu local des compagnons de tous les joueurs (le serveur ne publie que l'attribut « Pets »).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))

local PetsRenderer = {}

local entries: { [Player]: { key: string, models: { Model }, cfs: { any } } } = {}

local SLOTS = {
	CFrame.new(-3.5, -1.8, 4),
	CFrame.new(3.5, -1.8, 4.5),
	CFrame.new(0, -1.8, 7.5),
	CFrame.new(-6, -1.8, 7),
}

local function build(def: any): Model
	local color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
	local m = Instance.new("Model")
	m.Name = "Pet_" .. def.Id
	local function add(name: string, size: Vector3, offset: CFrame, c: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = c
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		p:SetAttribute("ox", offset.X)
		p:SetAttribute("oy", offset.Y)
		p:SetAttribute("oz", offset.Z)
		p.CFrame = offset
		return p
	end
	local scale = if def.Rarity == "mythique" then 1.4 elseif def.Rarity == "legendaire" then 1.2 else 1
	local body = add("Body", Vector3.new(1.8, 1.6, 2.6) * scale, CFrame.new(), color)
	add("Head", Vector3.new(1.4, 1.3, 1.5) * scale, CFrame.new(0, 0.9 * scale, 1.6 * scale), color)
	add("Tail", Vector3.new(0.7, 0.7, 1.8) * scale, CFrame.new(0, 0.1, -2.1 * scale), color)
	add("EyeL", Vector3.new(0.25, 0.3, 0.2), CFrame.new(-0.4 * scale, 1.15 * scale, 2.3 * scale), Color3.new(0, 0, 0))
	add("EyeR", Vector3.new(0.25, 0.3, 0.2), CFrame.new(0.4 * scale, 1.15 * scale, 2.3 * scale), Color3.new(0, 0, 0))
	m.PrimaryPart = body
	m.Parent = workspace:FindFirstChild("LocalPets") or (function()
		local f = Instance.new("Folder")
		f.Name = "LocalPets"
		f.Parent = workspace
		return f
	end)()
	return m
end

local function clear(entry: any)
	for _, m in ipairs(entry.models) do
		m:Destroy()
	end
	entry.models = {}
	entry.cfs = {}
end

local function sync(player: Player)
	local str = player:GetAttribute("Pets") or ""
	local entry = entries[player]
	if not entry then
		entry = { key = "", models = {}, cfs = {} }
		entries[player] = entry
	end
	if entry.key == str then
		return
	end
	entry.key = str
	clear(entry)
	if str == "" then
		return
	end
	for id in string.gmatch(str, "[^,]+") do
		local def = Economy.findPet(id)
		if def then
			table.insert(entry.models, build(def))
			table.insert(entry.cfs, false)
		end
	end
end

function PetsRenderer.init()
	local function watch(player: Player)
		sync(player)
		player:GetAttributeChangedSignal("Pets"):Connect(function()
			sync(player)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		local e = entries[p]
		if e then
			clear(e)
			entries[p] = nil
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local alpha = 1 - math.exp(-8 * dt)
		for player, entry in pairs(entries) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			for i, model in ipairs(entry.models) do
				if hrp then
					local slot = SLOTS[i] or SLOTS[1]
					local bob = math.sin(t * 3 + i) * 0.25
					local target = hrp.CFrame * slot * CFrame.new(0, bob, 0)
					-- Garde seulement le cap (yaw) pour que les bêtes restent à plat.
					local pos = target.Position
					local _, yaw, _ = hrp.CFrame:ToOrientation()
					target = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
					local current = entry.cfs[i]
					if not current then
						current = target
					else
						current = current:Lerp(target, alpha)
					end
					entry.cfs[i] = current
					model:PivotTo(current)
				end
			end
		end
	end)
end

return PetsRenderer
