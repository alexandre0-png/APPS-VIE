-- ModuleScript : ReplicatedStorage/Shared/VfxKit
-- Effets visuels 3D : DONNÉES PURES (préréglages nommés = séquences de pièces Blender, émetteurs de particules, faisceau, surbrillance) et
-- fonctions de planification testées hors de Roblox (qualité Élevé / Moyen / Bas, plafonds mobiles, effets par rareté), puis EXÉCUTION côté
-- client (VfxKit.play) : chaque pièce est un modèle Blender blanc (`Nom__FFFFFF`, Neon) cloné depuis ReplicatedStorage.VfxTemplates, recoloré
-- par code, ancré, sans collision, dont la transparence, l'échelle, la rotation et la hauteur sont animées par TweenService ; tout est nettoyé
-- (Debris) et protégé par pcall : un effet qui échoue ne casse jamais le jeu.
-- Utilisation : local Vfx = require(Shared.VfxKit).new(Config, Easing)
local VfxKit = {}

-- Modèles Blender d'effets (clé = nom du fichier Blender, voir Config.Assets.models.vfx).
VfxKit.MODELS = { "cercle_runique", "ailes", "halo", "rayons", "etoile", "cristaux", "onde", "torii", "spirale", "pilier_lumiere", "etincelles", "cone_lumiere", "bouclier" }

-- Préréglages. Pièce : { model, at (retard s), dur (s), s0/s1 (échelle de départ/arrivée, 1 = taille Blender), t0/t1 (transparence), spin (rad/s),
-- rise (studs montés pendant l'effet), style (Back, Elastic, Quint, Quad, Sine), dir (Out, In, InOut), color ("rarity" | "white" | {r,g,b} 0-255) }.
-- L'ordre des pièces est leur priorité : la qualité Basse n'en garde que les premières. Particules : { count, life, speed, size, color }.
VfxKit.PRESETS = {
	aura_runique = {
		pieces = {
			{ model = "cercle_runique", at = 0, dur = 1.8, s0 = 0.3, s1 = 1.15, t0 = 0.9, t1 = 1, spin = 1.4, style = "Back", dir = "Out", color = "rarity", peak = 0.35 },
			{ model = "halo", at = 0.1, dur = 1.6, s0 = 0.5, s1 = 1.0, t0 = 0.85, t1 = 1, spin = -0.8, style = "Quint", dir = "Out", color = "rarity", peak = 0.4 },
		},
		particles = { count = 24, life = 1.4, speed = 5, size = 0.35, color = "rarity" },
		minQuality = "low",
	},
	aura_ailes = {
		pieces = { { model = "ailes", at = 0.2, dur = 2.2, s0 = 0.2, s1 = 1.2, t0 = 0.8, t1 = 1, rise = 1.5, style = "Elastic", dir = "Out", color = "rarity", peak = 0.3 } },
		particles = { count = 18, life = 1.8, speed = 3, size = 0.3, color = "rarity" },
		highlight = true,
		minQuality = "medium",
	},
	onde_de_choc = {
		pieces = { { model = "onde", at = 0, dur = 0.9, s0 = 0.2, s1 = 3.2, t0 = 0.2, t1 = 1, style = "Quint", dir = "Out", color = "rarity", peak = 0.2 } },
		particles = { count = 14, life = 0.8, speed = 14, size = 0.3, color = "rarity" },
		minQuality = "low",
	},
	pilier_revelation = {
		pieces = {
			{ model = "pilier_lumiere", at = 0.15, dur = 1.8, s0 = 0.1, s1 = 1.1, t0 = 0.7, t1 = 1, style = "Quint", dir = "Out", color = "rarity", peak = 0.25 },
			{ model = "rayons", at = 0.2, dur = 1.6, s0 = 0.4, s1 = 1.3, t0 = 0.75, t1 = 1, spin = 0.9, style = "Quint", dir = "Out", color = "rarity", peak = 0.3 },
			{ model = "cone_lumiere", at = 0.3, dur = 1.5, s0 = 0.6, s1 = 1.0, t0 = 0.8, t1 = 1, style = "Sine", dir = "InOut", color = "white", peak = 0.45 },
		},
		particles = { count = 30, life = 2, speed = 8, size = 0.4, color = "white" },
		beam = true,
		minQuality = "low",
	},
	bouclier = {
		pieces = { { model = "bouclier", at = 0, dur = 1.4, s0 = 0.5, s1 = 1.0, t0 = 0.8, t1 = 1, spin = 0.6, style = "Back", dir = "Out", color = { 90, 200, 255 }, peak = 0.45 } },
		highlight = true,
		minQuality = "low",
	},
	etincelles = {
		pieces = { { model = "etincelles", at = 0, dur = 1.6, s0 = 0.5, s1 = 1.2, t0 = 0.3, t1 = 1, rise = 3, style = "Quad", dir = "Out", color = "rarity", peak = 0.1 } },
		particles = { count = 30, life = 1.5, speed = 9, size = 0.3, color = "rarity" },
		minQuality = "low",
	},
	spirale_montee = {
		pieces = {
			{ model = "spirale", at = 0, dur = 2.4, s0 = 0.4, s1 = 1.2, t0 = 0.6, t1 = 1, spin = 3, rise = 8, style = "Quint", dir = "Out", color = "rarity", peak = 0.2 },
			{ model = "etoile", at = 1.0, dur = 1.2, s0 = 0.2, s1 = 1.4, t0 = 0.5, t1 = 1, spin = 1, rise = 10, style = "Back", dir = "Out", color = "white", peak = 0.2 },
		},
		particles = { count = 26, life = 2.2, speed = 6, size = 0.35, color = "rarity" },
		minQuality = "medium",
	},
	portail_torii = {
		pieces = {
			{ model = "torii", at = 0.3, dur = 2.6, s0 = 0.3, s1 = 1.0, t0 = 0.85, t1 = 1, style = "Back", dir = "Out", color = "rarity", peak = 0.3 },
			{ model = "cristaux", at = 0.5, dur = 2.2, s0 = 0.2, s1 = 1.0, t0 = 0.8, t1 = 1, spin = 0.4, style = "Elastic", dir = "Out", color = "rarity", peak = 0.3 },
		},
		particles = { count = 22, life = 2, speed = 4, size = 0.4, color = "rarity" },
		minQuality = "medium",
	},
}

-- Qualités. Mobile = Bas : au plus 3 effets simultanés, 40 particules par émetteur, jamais de faisceau (Beam).
VfxKit.QUALITY = {
	high = { rank = 3, maxConcurrent = 8, particleCap = 120, beams = true, maxPieces = 3, highlight = true },
	medium = { rank = 2, maxConcurrent = 5, particleCap = 70, beams = false, maxPieces = 2, highlight = true },
	low = { rank = 1, maxConcurrent = 3, particleCap = 40, beams = false, maxPieces = 1, highlight = false },
}

-- Effets (préréglages) joués pour une éclosion : ampleur croissante avec la rareté (1 Commun discret .. 5 Mythique) ; Cosmique et secret sont
-- spectaculaires. Retourne la liste ordonnée des préréglages et un facteur d'ampleur (échelle).
-- Lot 9 : tables indexées par rareté (1..10), sans seuil codé en dur ; les raretés migrées gardent leurs effets d'avant.
VfxKit.HATCH_AMP = { 0.55, 0.65, 0.75, 0.95, 1.2, 1.45, 1.8, 1.9, 1.9, 2 }
VfxKit.HATCH_FX = {
	{ "etincelles" },
	{ "etincelles" },
	{ "etincelles", "onde_de_choc" },
	{ "aura_runique", "onde_de_choc" },
	{ "pilier_revelation", "aura_runique", "aura_ailes", "onde_de_choc" },
	{ "pilier_revelation", "aura_runique", "aura_ailes", "spirale_montee", "onde_de_choc" },
	{ "pilier_revelation", "spirale_montee", "aura_runique", "aura_ailes", "portail_torii", "onde_de_choc" },
	{ "pilier_revelation", "spirale_montee", "aura_runique", "aura_ailes", "portail_torii", "onde_de_choc" },
	{ "pilier_revelation", "spirale_montee", "aura_runique", "aura_ailes", "portail_torii", "onde_de_choc" },
	{ "pilier_revelation", "spirale_montee", "aura_runique", "aura_ailes", "portail_torii", "onde_de_choc" },
}
function VfxKit.hatchEffects(tier, secret)
	tier = math.floor(math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), #VfxKit.HATCH_FX))
	if secret then
		return { "pilier_revelation", "spirale_montee", "portail_torii", "aura_runique", "onde_de_choc", "etincelles" }, 2
	end
	return VfxKit.HATCH_FX[tier], VfxKit.HATCH_AMP[tier]
end

-- Qualité : tactile = Bas, sinon Élevé ; `override` (« high », « medium », « low ») la remplace.
function VfxKit.quality(isTouch, override)
	if override and VfxKit.QUALITY[override] then
		return override
	end
	return isTouch and "low" or "high"
end

function VfxKit.new(Config, Easing)
	local K = { active = 0 }

	-- Couleur (r, g, b en 0-255) d'une rareté ; blanc si inconnue.
	function K.rarityColor(tier)
		local t = Config.TIERS[tier]
		local c = t and t.color
		if c then
			return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
		end
		return { 255, 255, 255 }
	end

	local function resolveColor(spec, tier)
		if spec == "white" then
			return { 255, 255, 255 }
		elseif type(spec) == "table" then
			return spec
		end
		return K.rarityColor(tier)
	end

	-- Courbe nommée (style de TweenService) sur [0, 1] : Back, Elastic, Quint, Quad, Sine (sortie ou entrée-sortie).
	function K.curve(style, x)
		x = Easing.clamp01(x)
		if style == "Back" then
			return Easing.outBack(x)
		elseif style == "Elastic" then
			return Easing.outElastic(x)
		elseif style == "Quint" then
			return 1 - (1 - x) ^ 5
		elseif style == "Quad" then
			return Easing.outQuad(x)
		end
		return Easing.inOutSine(x)
	end

	-- Plan concret d'un préréglage pour une rareté et une qualité : pièces (priorité, nombre limité par la qualité), particules plafonnées,
	-- faisceau seulement en Élevé, surbrillance selon la qualité, durée totale. nil si préréglage inconnu ou trop exigeant pour la qualité.
	-- amp multiplie l'échelle (ampleur selon la rareté).
	function K.plan(name, tier, quality, amp)
		local preset = VfxKit.PRESETS[name]
		local q = VfxKit.QUALITY[quality]
		if not preset or not q then
			return nil
		end
		local need = VfxKit.QUALITY[preset.minQuality or "low"]
		if q.rank < need.rank then
			return nil
		end
		amp = (type(amp) == "number" and amp == amp and amp > 0) and math.min(amp, 3) or 1
		local pieces, duration = {}, 0
		for i, p in ipairs(preset.pieces) do
			if i > q.maxPieces then
				break
			end
			pieces[#pieces + 1] = {
				model = p.model, at = p.at, dur = p.dur, s0 = p.s0 * amp, s1 = p.s1 * amp, t0 = p.t0, t1 = p.t1, spin = p.spin or 0, rise = (p.rise or 0) * amp,
				style = p.style, dir = p.dir, color = resolveColor(p.color, tier), peak = p.peak,
			}
			duration = math.max(duration, p.at + p.dur)
		end
		local particles = nil
		if preset.particles then
			particles = {
				count = math.min(preset.particles.count, q.particleCap), life = preset.particles.life, speed = preset.particles.speed,
				size = preset.particles.size, color = resolveColor(preset.particles.color, tier),
			}
		end
		return {
			name = name, pieces = pieces, particles = particles, beam = preset.beam == true and q.beams, highlight = preset.highlight == true and q.highlight,
			duration = duration,
		}
	end

	-- Admission : combien d'effets peuvent encore démarrer (limite de simultanéité de la qualité).
	function K.admit(active, quality)
		local q = VfxKit.QUALITY[quality]
		return q ~= nil and type(active) == "number" and active < q.maxConcurrent
	end

	-- Liste ordonnée des plans d'une éclosion, tronquée à la simultanéité de la qualité (rien de plus que ce que le téléphone peut jouer).
	function K.hatchPlans(tier, secret, quality, activeNow)
		local names, amp = VfxKit.hatchEffects(tier, secret)
		local out = {}
		local active = activeNow or 0
		for _, name in ipairs(names) do
			if not K.admit(active + #out, quality) then
				break
			end
			local plan = K.plan(name, tier, quality, amp)
			if plan then
				out[#out + 1] = plan
			end
		end
		return out
	end

	-- Transparence d'une pièce à la progression p (0..1) : monte en fondu vers `peak` (visibilité maximale) puis disparaît ; valeur dans [0, 1].
	function K.transparencyAt(piece, p)
		p = Easing.clamp01(p)
		local appear = 0.25
		if p < appear then
			return piece.t0 + (piece.peak - piece.t0) * K.curve("Quad", p / appear)
		end
		local e = (p - appear) / (1 - appear)
		return math.min(math.max(piece.peak + (piece.t1 - piece.peak) * K.curve("Sine", e), 0), 1)
	end

	-- Échelle d'une pièce à la progression p.
	function K.scaleAt(piece, p)
		return piece.s0 + (piece.s1 - piece.s0) * K.curve(piece.style, p)
	end

	---------------------------------------------------------------- Exécution (client)
	-- env = { clone(model) -> Model|nil, tween = TweenService, debris = Debris, parent = Instance, spawn = task.spawn, delay = task.delay, color = Color3.fromRGB }
	-- Retourne true si l'effet a démarré. Tout est sous pcall ; l'effet est détruit à la fin (Debris) quoi qu'il arrive.
	function K.play(env, plan, cframe, opts)
		if not plan or K.active >= 99 then
			return false
		end
		local started = false
		local ok = pcall(function()
			local folder = Instance.new("Folder")
			folder.Name = "Vfx_" .. plan.name
			folder.Parent = env.parent
			env.debris:AddItem(folder, plan.duration + 1.5)
			K.active += 1
			env.delay(plan.duration + 1.4, function()
				K.active = math.max(0, K.active - 1)
			end)
			for _, piece in ipairs(plan.pieces) do
				env.delay(piece.at, function()
					pcall(function()
						local model = env.clone(piece.model)
						if not model then
							return
						end
						model.Parent = folder
						local color = env.color(piece.color[1], piece.color[2], piece.color[3])
						for _, d in ipairs(model:GetDescendants()) do
							if d:IsA("BasePart") then
								d.Anchored = true
								d.CanCollide = false
								d.CanQuery = false
								d.CanTouch = false
								d.CastShadow = false
								d.Color = color
								d.Transparency = piece.t0
							end
						end
						local base = model:GetScale()
						local pivot = cframe
						local value = Instance.new("NumberValue")
						value.Parent = folder
						local function apply(p)
							if not model.Parent then
								return
							end
							pcall(function()
								model:ScaleTo(math.max(0.01, base * K.scaleAt(piece, p)))
								model:PivotTo(pivot * CFrame.new(0, piece.rise * p, 0) * CFrame.Angles(0, piece.spin * p * piece.dur, 0))
								local tr = K.transparencyAt(piece, p)
								for _, d in ipairs(model:GetDescendants()) do
									if d:IsA("BasePart") then
										d.Transparency = tr
									end
								end
							end)
						end
						apply(0)
						value.Changed:Connect(apply)
						env.tween:Create(value, TweenInfo.new(piece.dur, Enum.EasingStyle.Linear), { Value = 1 }):Play() -- les courbes sont appliquées par apply (Back, Elastic, Quint...)
					end)
				end)
			end
			if plan.particles then
				local anchor = Instance.new("Part")
				anchor.Anchored = true
				anchor.CanCollide = false
				anchor.CanQuery = false
				anchor.Transparency = 1
				anchor.Size = Vector3.new(1, 1, 1)
				anchor.CFrame = cframe
				anchor.Parent = folder
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new(env.color(plan.particles.color[1], plan.particles.color[2], plan.particles.color[3]))
				e.Rate = 0
				e.Lifetime = NumberRange.new(plan.particles.life * 0.6, plan.particles.life)
				e.Speed = NumberRange.new(plan.particles.speed * 0.5, plan.particles.speed)
				e.SpreadAngle = Vector2.new(180, 180)
				e.LightEmission = 1
				e.Size = NumberSequence.new(plan.particles.size)
				e.Parent = anchor
				e:Emit(plan.particles.count) -- plafonné par la qualité (40 sur téléphone)
			end
			if plan.beam then -- faisceau vertical (qualité Élevée seulement)
				local top = Instance.new("Part")
				top.Anchored = true
				top.CanCollide = false
				top.CanQuery = false
				top.Transparency = 1
				top.Size = Vector3.new(1, 1, 1)
				top.CFrame = cframe * CFrame.new(0, 14, 0)
				top.Parent = folder
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Parent = top
				a1.Parent = folder:FindFirstChildOfClass("Part") or top
				local beam = Instance.new("Beam")
				beam.Attachment0, beam.Attachment1 = a0, a1
				beam.Width0, beam.Width1 = 0.6, 2.2
				beam.LightEmission = 1
				beam.Transparency = NumberSequence.new(0.35, 1)
				beam.Color = ColorSequence.new(env.color(plan.pieces[1] and plan.pieces[1].color[1] or 255, plan.pieces[1] and plan.pieces[1].color[2] or 255, plan.pieces[1] and plan.pieces[1].color[3] or 255))
				beam.Parent = top
			end
			if plan.highlight and opts and opts.target then
				local hl = Instance.new("Highlight")
				hl.FillTransparency = 0.8
				hl.OutlineTransparency = 0.2
				hl.FillColor = env.color(plan.pieces[1] and plan.pieces[1].color[1] or 255, plan.pieces[1] and plan.pieces[1].color[2] or 255, plan.pieces[1] and plan.pieces[1].color[3] or 255)
				hl.Parent = opts.target
				env.debris:AddItem(hl, plan.duration)
			end
			started = true
		end)
		return ok and started
	end

	return K
end

return VfxKit
