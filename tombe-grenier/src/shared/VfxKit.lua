--[[
  VfxKit : effets visuels de l'ambiance horreur (modèles Blender blancs recolorés, tweens, particules légères).
  - Données pures (PRESETS, QUALITY, THEMES, plan) : testées sans Roblox (tools/lua/test_animations.py).
  - Exécution côté client (VfxKit.play) : tout est sous pcall, nettoyé par Debris, plafonné selon l'appareil.
  Les modèles viennent de ReplicatedStorage.Vfx (copiés par le serveur après leur chargement, sans bloquer le jeu) ;
  sans modèle, une forme de secours (anneau, sphère ou colonne néon) joue le même effet : jamais d'erreur.
]]
local VfxKit = {}

-- Teintes froides par thème (le thème « or » sert aux objets précieux, « rouge » au monstre)
VfxKit.THEMES = {
	froid = { primary = { 120, 170, 255 }, accent = { 205, 228, 255 } },
	or_ = { primary = { 255, 205, 110 }, accent = { 255, 240, 200 } },
	rouge = { primary = { 190, 50, 60 }, accent = { 255, 120, 110 } },
	pale = { primary = { 170, 200, 190 }, accent = { 225, 240, 235 } },
}

-- Qualité : « bas » = téléphone (3 effets, 40 particules par émetteur, ni Beam ni Highlight)
VfxKit.QUALITY = {
	haut = { maxConcurrent = 8, maxParticles = 120, beam = true, highlight = true, pieces = 5 },
	moyen = { maxConcurrent = 5, maxParticles = 80, beam = false, highlight = true, pieces = 3 },
	bas = { maxConcurrent = 3, maxParticles = 40, beam = false, highlight = false, pieces = 2 },
}

-- Modèles Blender (noms dans ReplicatedStorage.Vfx), diamètre ou taille de référence en studs
VfxKit.MODELS = {
	cercle = { name = "vfx cercle runique", size = 12 },
	ailes = { name = "vfx ailes", size = 10 },
	halo = { name = "vfx halo", size = 4 },
	rayons = { name = "vfx rayons", size = 12 },
	etoile = { name = "vfx etoile", size = 4 },
	cristaux = { name = "vfx cristaux", size = 4 },
	onde = { name = "vfx onde", size = 6 },
	torii = { name = "vfx torii", size = 10 },
	spirale = { name = "vfx spirale", size = 6 },
	pilier = { name = "vfx pilier lumiere", size = 12 },
	etincelles = { name = "vfx etincelles", size = 5 },
	cone = { name = "vfx cone lumiere", size = 8 },
	bouclier = { name = "vfx bouclier", size = 8 },
}

-- Préréglages. piece : { model, diameter (studs), lift (studs), color = "primary"|"accent", fade = { from, mid, to },
-- grow = { from, to } (facteur d'échelle), spin (degrés par seconde), rise (studs), ease }.
VfxKit.PRESETS = {
	aura_runique = {
		theme = "froid",
		duration = 2.6,
		pieces = {
			{
				model = "cercle",
				diameter = 7,
				lift = 0.1,
				color = "primary",
				fade = { 1, 0.55, 1 },
				grow = { 0.6, 1 },
				spin = 25,
				ease = "Quint",
			},
			{
				model = "halo",
				diameter = 3,
				lift = 0.4,
				color = "accent",
				fade = { 1, 0.7, 1 },
				grow = { 0.5, 1 },
				ease = "Sine",
			},
		},
		particles = { count = 10, lifetime = 1.6, speed = 0.8, size = 0.15 },
	},
	aura_ailes = {
		theme = "pale",
		duration = 2.2,
		pieces = {
			{
				model = "ailes",
				diameter = 8,
				lift = 3,
				color = "accent",
				fade = { 1, 0.45, 1 },
				grow = { 0.4, 1 },
				ease = "Back",
			},
			{
				model = "halo",
				diameter = 3.5,
				lift = 5,
				color = "primary",
				fade = { 1, 0.6, 1 },
				grow = { 0.6, 1 },
				ease = "Sine",
			},
		},
	},
	onde_de_choc = {
		theme = "rouge",
		duration = 0.9,
		pieces = {
			{
				model = "onde",
				diameter = 16,
				lift = 1,
				color = "accent",
				fade = { 0.25, 0.6, 1 },
				grow = { 0.15, 1 },
				ease = "Quint",
			},
		},
		beam = false,
	},
	pilier_revelation = {
		theme = "or_",
		duration = 3,
		pieces = {
			{
				model = "pilier",
				diameter = 3,
				lift = 0,
				color = "primary",
				fade = { 1, 0.5, 1 },
				grow = { 0.3, 1 },
				ease = "Elastic",
			},
			{
				model = "etincelles",
				diameter = 4,
				lift = 2,
				color = "accent",
				fade = { 1, 0.5, 1 },
				rise = 3,
				ease = "Sine",
			},
		},
		particles = { count = 14, lifetime = 2, speed = 1.2, size = 0.12 },
		beam = true,
	},
	bouclier = {
		theme = "froid",
		duration = 2.4,
		pieces = {
			{
				model = "bouclier",
				diameter = 7,
				lift = 3,
				color = "primary",
				fade = { 1, 0.6, 1 },
				grow = { 0.5, 1 },
				ease = "Back",
			},
		},
		highlight = true,
	},
	etincelles = {
		theme = "pale",
		duration = 1.8,
		pieces = {
			{
				model = "etincelles",
				diameter = 3,
				lift = 1,
				color = "accent",
				fade = { 1, 0.5, 1 },
				rise = 1.5,
				ease = "Sine",
			},
		},
		particles = { count = 8, lifetime = 1.2, speed = 0.6, size = 0.1 },
	},
	spirale_montee = {
		theme = "pale",
		duration = 2,
		pieces = {
			{
				model = "spirale",
				diameter = 3,
				lift = 0,
				color = "accent",
				fade = { 1, 0.6, 1 },
				spin = 120,
				rise = 5,
				ease = "Quint",
			},
		},
		particles = { count = 6, lifetime = 1.5, speed = 0.5, size = 0.1 },
	},
	lueur_enigme = {
		theme = "or_",
		duration = 2.4,
		pieces = {
			{
				model = "cristaux",
				diameter = 2.2,
				lift = 0.2,
				color = "primary",
				fade = { 1, 0.55, 1 },
				grow = { 0.6, 1 },
				ease = "Back",
			},
			{
				model = "etoile",
				diameter = 1.2,
				lift = 1.6,
				color = "accent",
				fade = { 1, 0.6, 1 },
				spin = 60,
				ease = "Sine",
			},
		},
		particles = { count = 6, lifetime = 1.4, speed = 0.4, size = 0.1 },
	},
	portail_torii = {
		theme = "or_",
		duration = 3,
		pieces = {
			{
				model = "torii",
				diameter = 8,
				lift = 0,
				color = "primary",
				fade = { 1, 0.5, 1 },
				grow = { 0.7, 1 },
				ease = "Back",
			},
			{
				model = "halo",
				diameter = 5,
				lift = 4,
				color = "accent",
				fade = { 1, 0.7, 1 },
				grow = { 0.5, 1 },
				ease = "Sine",
			},
			{
				model = "rayons",
				diameter = 10,
				lift = 0.1,
				color = "accent",
				fade = { 1, 0.75, 1 },
				spin = 15,
				ease = "Sine",
			},
		},
		beam = true,
	},
}

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function VfxKit.names()
	local out = {}
	for name in pairs(VfxKit.PRESETS) do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

-- Niveau de qualité selon l'appareil : { touch, width, height } ; override (« haut », « moyen », « bas ») l'emporte.
function VfxKit.quality(device, override)
	if override and VfxKit.QUALITY[override] then
		return override
	end
	device = device or {}
	if device.touch then
		local short = math.min(device.width or 0, device.height or 0)
		return short > 0 and short < 700 and "bas" or "moyen"
	end
	return "haut"
end

-- Plan d'un préréglage pour une qualité donnée : pièces conservées, particules plafonnées, Beam et Highlight selon l'appareil.
function VfxKit.plan(name, quality)
	local preset = VfxKit.PRESETS[name]
	local limits = VfxKit.QUALITY[quality] or VfxKit.QUALITY.moyen
	if not preset then
		return nil
	end
	local pieces = {}
	for i, piece in ipairs(preset.pieces) do
		if i <= limits.pieces then
			table.insert(pieces, piece)
		end
	end
	local particles = nil
	if preset.particles then
		particles = {
			count = math.min(preset.particles.count, limits.maxParticles),
			lifetime = preset.particles.lifetime,
			speed = preset.particles.speed,
			size = preset.particles.size,
		}
	end
	return {
		name = name,
		theme = preset.theme,
		duration = preset.duration,
		pieces = pieces,
		particles = particles,
		beam = preset.beam == true and limits.beam,
		highlight = preset.highlight == true and limits.highlight,
		maxConcurrent = limits.maxConcurrent,
	}
end

function VfxKit.color(theme, which)
	local t = VfxKit.THEMES[theme] or VfxKit.THEMES.froid
	local c = t[which] or t.primary
	return c[1], c[2], c[3]
end

-- Exécution ------------------------------------------------------------------------------------------------------

local active = 0
VfxKit.activeCount = function()
	return active
end

local function easingStyle(name)
	return Enum.EasingStyle[name] or Enum.EasingStyle.Sine
end

local function template(modelKey)
	local spec = VfxKit.MODELS[modelKey]
	if not spec then
		return nil
	end
	local ok, found = pcall(function()
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Vfx")
		return folder and folder:FindFirstChild(spec.name)
	end)
	return ok and found or nil
end

-- Forme de secours : disque, sphère ou colonne néon à la même taille
local function fallbackPiece(modelKey, diameter)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	local tall = modelKey == "pilier" or modelKey == "spirale" or modelKey == "cone"
	if tall then
		part.Size = Vector3.new(diameter * 0.3, diameter * 2, diameter * 0.3)
	elseif modelKey == "cercle" or modelKey == "onde" or modelKey == "rayons" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.15, diameter, diameter)
	else
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(diameter, diameter, diameter)
	end
	return part
end

local function allParts(root)
	local list = {}
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function setupPiece(piece, origin, theme, container)
	local model = template(piece.model)
	local instance
	if model then
		instance = model:Clone()
	else
		instance = fallbackPiece(piece.model, piece.diameter)
	end
	local r, g, b = VfxKit.color(theme, piece.color)
	local color = Color3.fromRGB(r, g, b)
	for _, part in ipairs(allParts(instance)) do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Transparency = piece.fade[1]
	end
	local position = origin + Vector3.new(0, piece.lift or 0, 0)
	if instance:IsA("Model") then
		local ref = VfxKit.MODELS[piece.model].size
		pcall(function()
			instance:ScaleTo(instance:GetScale() * (piece.diameter / ref) * ((piece.grow and piece.grow[1]) or 1))
		end)
		instance:PivotTo(CFrame.new(position))
	else
		instance.CFrame = CFrame.new(position)
			* (instance.Shape == Enum.PartType.Cylinder and CFrame.Angles(0, 0, math.pi / 2) or CFrame.new())
	end
	instance.Parent = container
	return instance, allParts(instance)
end

-- Joue un préréglage au point `origin` (Vector3). opts : { quality, theme, device }. Retourne true si l'effet a démarré.
function VfxKit.play(name, origin, opts)
	opts = opts or {}
	local ok, started = pcall(function()
		local TweenService = game:GetService("TweenService")
		local Debris = game:GetService("Debris")
		local quality = opts.quality or "moyen"
		local plan = VfxKit.plan(name, quality)
		if not plan or active >= plan.maxConcurrent or typeof(origin) ~= "Vector3" then
			return false
		end
		local container = Instance.new("Folder")
		container.Name = "Vfx_" .. name
		container.Parent = workspace
		Debris:AddItem(container, plan.duration + 1)
		active += 1
		task.delay(plan.duration + 0.5, function()
			active = math.max(0, active - 1)
		end)
		local theme = opts.theme or plan.theme
		for _, piece in ipairs(plan.pieces) do
			local ok2 = pcall(function()
				local instance, parts = setupPiece(piece, origin, theme, container)
				local half = plan.duration * 0.45
				local style = easingStyle(piece.ease or "Sine")
				for _, part in ipairs(parts) do
					local up = TweenService:Create(
						part,
						TweenInfo.new(half, style, Enum.EasingDirection.Out),
						{ Transparency = piece.fade[2] }
					)
					up:Play()
					task.delay(half, function()
						pcall(function()
							TweenService:Create(
								part,
								TweenInfo.new(plan.duration - half, Enum.EasingStyle.Sine),
								{ Transparency = piece.fade[3] }
							):Play()
						end)
					end)
					if piece.rise then
						TweenService:Create(
							part,
							TweenInfo.new(plan.duration, Enum.EasingStyle.Sine),
							{ Position = part.Position + Vector3.new(0, piece.rise, 0) }
						):Play()
					end
				end
				if piece.grow and instance:IsA("Model") then
					pcall(function()
						local target = instance:GetScale() / piece.grow[1] * piece.grow[2]
						local steps = 8
						for i = 1, steps do
							task.delay(half * i / steps, function()
								pcall(function()
									instance:ScaleTo(instance:GetScale() + (target - instance:GetScale()) * 0.35)
								end)
							end)
						end
					end)
				end
			end)
			if not ok2 then
				break
			end
		end
		-- Particules : une salve courte, plafonnée par la qualité
		if plan.particles and plan.particles.count > 0 then
			pcall(function()
				local anchor = Instance.new("Part")
				anchor.Anchored = true
				anchor.CanCollide = false
				anchor.Transparency = 1
				anchor.Size = Vector3.new(0.2, 0.2, 0.2)
				anchor.Position = origin + Vector3.new(0, 1, 0)
				anchor.Parent = container
				local emitter = Instance.new("ParticleEmitter")
				emitter.Rate = 0
				emitter.Lifetime = NumberRange.new(plan.particles.lifetime)
				emitter.Speed = NumberRange.new(plan.particles.speed)
				emitter.Size = NumberSequence.new(plan.particles.size)
				emitter.LightEmission = 0.6
				emitter.Parent = anchor
				emitter:Emit(plan.particles.count)
			end)
		end
		-- Highlight : contour léger autour de l'objet visé (opts.adornee), seulement si l'appareil le permet
		if plan.highlight and opts.adornee then
			pcall(function()
				local glow = Instance.new("Highlight")
				glow.Adornee = opts.adornee
				local r, g, b = VfxKit.color(theme, "primary")
				glow.OutlineColor = Color3.fromRGB(r, g, b)
				glow.FillTransparency = 1
				glow.OutlineTransparency = 0.4
				glow.Parent = container
			end)
		end
		return true
	end)
	if not ok then
		return false
	end
	return started == true
end

VfxKit.count = count

return VfxKit
