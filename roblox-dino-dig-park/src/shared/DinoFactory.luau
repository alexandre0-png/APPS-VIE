-- DinoFactory.luau : construit un modèle de dinosaure à partir de blocs (serveur + client/Viewport).

local Config = require(script.Parent.Config)
local DinoShapes = require(script.Parent.DinoShapes)
local Economy = require(script.Parent.Economy)

local DinoFactory = {}

local function lighten(c, a)
	return Color3.new(math.min(1, c.R + a), math.min(1, c.G + a), math.min(1, c.B + a))
end
local function darken(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local GOLD_BODY = Color3.fromRGB(255, 200, 40)
local GOLD_ACCENT = Color3.fromRGB(255, 140, 30)

function DinoFactory.roleColors(def, golden)
	local body, accent = def.body, def.accent
	if golden then
		body, accent = GOLD_BODY, GOLD_ACCENT
	end
	return {
		body = body,
		belly = lighten(body, 0.25),
		dark = darken(body, 0.65),
		accent = accent,
		eye = Color3.fromRGB(15, 15, 15),
		tooth = Color3.fromRGB(250, 250, 245),
	}
end

-- key : "rex" ou "rex:g". Retourne un Model dont le pivot est au sol, centre de l'origine.
function DinoFactory.build(key, options)
	options = options or {}
	local id, golden = Economy.parseKey(key)
	local def = Config.DinoById[id]
	if not def then
		return nil
	end
	local colors = DinoFactory.roleColors(def, golden)
	local scale = def.scale * (options.scaleMul or 1)
	local material = Enum.Material.SmoothPlastic
	if golden then
		material = Enum.Material.Metal
	elseif def.material and Enum.Material[def.material] then
		material = Enum.Material[def.material]
	end

	local model = Instance.new("Model")
	model.Name = def.name
	model:SetAttribute("DinoKey", key)
	model.WorldPivot = CFrame.new(0, 0, 0)

	local function addPart(spec, sign)
		local part = Instance.new("Part")
		part.Name = spec.role
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Color = colors[spec.role] or colors.body
		if spec.role == "eye" or spec.role == "tooth" then
			part.Material = Enum.Material.SmoothPlastic
		else
			part.Material = material
		end
		if golden and spec.role ~= "eye" and spec.role ~= "tooth" then
			part.Reflectance = 0.15
		end
		part.Size = Vector3.new(spec.size[1] * scale, spec.size[2] * scale, spec.size[3] * scale)
		local pos = Vector3.new(spec.pos[1] * sign * scale, spec.pos[2] * scale, spec.pos[3] * scale)
		local cf = CFrame.new(pos)
		if spec.rot then
			cf = cf * CFrame.Angles(math.rad(spec.rot[1]), math.rad(spec.rot[2] * sign), math.rad(spec.rot[3] * sign))
		end
		part.CFrame = cf
		part.Parent = model
		return part
	end

	for _, spec in ipairs(DinoShapes.get(def.archetype)) do
		addPart(spec, 1)
		if spec.mirror then
			addPart(spec, -1)
		end
	end

	if def.neon or (golden and options.sparkle) then
		local first = model:FindFirstChildWhichIsA("BasePart")
		if first then
			local att = Instance.new("Attachment")
			att.Position = Vector3.new(0, 3 * scale, 0)
			att.Parent = first
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Rate = 4
			pe.Lifetime = NumberRange.new(1, 2)
			pe.Speed = NumberRange.new(1, 3)
			pe.Size = NumberSequence.new(0.6, 0)
			pe.LightEmission = 1
			pe.Color = ColorSequence.new(def.accent)
			pe.Parent = att
		end
	end
	return model
end

return DinoFactory
