--[[
	Atmosphere.lua : effets visuels côté client
	- fenêtres et lampadaires allumés la nuit (tag "Lit")
	- phares des véhicules occupés la nuit
	- gyrophares de police
	- étoiles dorées qui tournent / masquées une fois collectées
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local State = require(script.Parent.State)

local Atmosphere = {}

local isNight = false
local lit = {} -- [part] = {material, color}
local litList = {}

local function nightNow()
	local t = Lighting.ClockTime
	return t >= 18.3 or t < 5.7
end

local function applyLit(part, night)
	local info = lit[part]
	if not info or not part.Parent then
		return
	end
	if night and info.on then
		part.Material = Enum.Material.Neon
		part.Color = info.warm
	else
		part.Material = info.material
		part.Color = info.color
	end
end

local function registerLit(part)
	if not part:IsA("BasePart") or lit[part] then
		return
	end
	local h = (math.floor(part.Position.X * 7 + part.Position.Y * 13 + part.Position.Z * 3)) % 10
	lit[part] = {
		material = part.Material, color = part.Color, on = h < 7,
		warm = (part.Material == Enum.Material.Neon) and part.Color or Color3.fromRGB(255, 226 - h * 4, 150 + h * 3),
	}
	table.insert(litList, part)
	if part.Material == Enum.Material.Neon then
		lit[part].on = false -- lampadaires : déjà lumineux
	end
	applyLit(part, isNight)
end

local function setNight(night)
	isNight = night
	-- appliqué par lots pour éviter une saccade
	task.spawn(function()
		local n = 0
		for i = #litList, 1, -1 do
			local p = litList[i]
			if not p.Parent then
				lit[p] = nil
				table.remove(litList, i)
			else
				applyLit(p, night)
				n += 1
				if n % 150 == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end
	end)
end

function Atmosphere.init()
	for _, p in ipairs(CollectionService:GetTagged("Lit")) do
		registerLit(p)
	end
	CollectionService:GetInstanceAddedSignal("Lit"):Connect(registerLit)

	-- boucle lente : nuit / phares
	task.spawn(function()
		while true do
			local night = nightNow()
			if night ~= isNight then
				setNight(night)
			end
			for _, hl in ipairs(CollectionService:GetTagged("Headlight")) do
				local light = hl:FindFirstChildOfClass("SpotLight")
				local seat = hl.Parent and hl.Parent:FindFirstChild("DriverSeat")
				if light then
					light.Enabled = night and seat ~= nil and seat.Occupant ~= nil
				end
			end
			task.wait(1)
		end
	end)

	-- gyrophares
	task.spawn(function()
		local flip = false
		while true do
			flip = not flip
			for _, p in ipairs(CollectionService:GetTagged("SirenA")) do
				p.Transparency = flip and 0 or 0.7
			end
			for _, p in ipairs(CollectionService:GetTagged("SirenB")) do
				p.Transparency = flip and 0.7 or 0
			end
			task.wait(0.22)
		end
	end)

	-- étoiles dorées
	local t0 = os.clock()
	local function starVisible(part)
		local id = part:GetAttribute("StarId")
		local taken = id and State.collected[id]
		part.LocalTransparencyModifier = taken and 1 or 0
		local l = part:FindFirstChildOfClass("PointLight")
		if l then
			l.Enabled = not taken
		end
		return not taken
	end
	local bases = {}
	RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, part in ipairs(CollectionService:GetTagged("GoldStar")) do
			bases[part] = bases[part] or part.CFrame
			if starVisible(part) then
				local b = bases[part]
				part.CFrame = CFrame.new(b.Position + Vector3.new(0, math.sin(t * 2 + b.X) * 0.6, 0)) * CFrame.Angles(math.rad(45), t * 1.5, math.rad(45))
			end
		end
	end)
end

return Atmosphere
