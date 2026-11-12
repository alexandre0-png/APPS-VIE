--[[
  Atmosphere : poussière en suspension dans chaque pièce, construite par le code (aucun asset).
  Un émetteur de particules par pièce, à faible débit : il donne du volume à la lumière de la lampe
  sans coût de rendu notable. Désactivable via Config.Visual.Dust.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Data = require(Shared.MapData)
local Audio = require(Shared.Audio)

local Atmosphere = {}

local FOLDER_NAME = "TombeAtmosphere"

local function makeEmitter(parent)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Poussiere"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 195, 185))
	emitter.LightEmission = 0.6
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Rate = Config.Visual.DustRate
	emitter.Speed = NumberRange.new(0.05, 0.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-5, 5)
	emitter.Parent = parent
	return emitter
end

-- Construit un point d'émission par pièce, au centre et à mi-hauteur
function Atmosphere.build()
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	if not Config.Visual.Dust then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	-- Souffle de ventilation en boucle, très bas, au centre de la maison (couche sonore continue)
	if Config.Visual.Dust then
		local hum = Instance.new("Part")
		hum.Name = "SoufflePiece"
		hum.Anchored = true
		hum.CanCollide = false
		hum.CanQuery = false
		hum.CanTouch = false
		hum.Transparency = 1
		hum.Size = Vector3.new(1, 1, 1)
		hum.Position = Vector3.new(60, 6, 45)
		hum.Parent = folder
		pcall(Audio.play, "ventilation", hum, { volume = 0.06, range = 30, speed = 0.85, reverb = 2, looped = true })
	end

	for _, r in ipairs(Data.rooms) do
		local base = Data.base[r.level] or 0
		local part = Instance.new("Part")
		part.Name = "DustEmitter_" .. tostring(r.id)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.Position = Vector3.new((r.x0 + r.x1) / 2, base + Data.H / 2, (r.z0 + r.z1) / 2)
		part.Parent = folder
		-- pcall : une erreur sur une pièce ne doit pas empêcher la construction de la carte
		pcall(makeEmitter, part)
	end
end

return Atmosphere
