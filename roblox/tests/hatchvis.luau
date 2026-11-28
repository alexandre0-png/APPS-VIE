--!nocheck
-- Graphismes 5 : visibilité des effets d'éclosion (HatchPlan pur + HatchFx exécuté dans le runtime factice).
-- Propriétés mesurées (rien n'est visible sans Studio) : particules strictement croissantes avec la rareté (version complète ; version mobile non décroissante),
-- pluie dorée dès Légendaire, taille minimale des objets de particules (plan et objets réellement créés), durée minimale de chaque prise, plafonds 220 / 120 / 80.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime? }. Style : pas de `+=`, pas de `continue`.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local T = {}
	local HP = luau.load(fs.readFile("roblox/src/ReplicatedStorage/HatchPlan.lua"), { debugName = "HatchPlan" })()
	local FIXED = { banner = true, text = true, wings = true, pillar = true }
	local Ns = { 5, 141, 24631, 1e6 }

	suite("Graphismes 5 : effets d'éclosion lisibles (plan pur)")
	T.inc, T.incRed, T.why = true, true, ""
	for _, N in ipairs(Ns) do
		local prevF, prevM = -1, -1
		for r = 1, 10 do
			local f, m = HP.plan(r, N), HP.plan(r, N, { reduced = true })
			if f.particles <= prevF then
				T.inc, T.why = false, "N=" .. N .. " r" .. r .. " : " .. f.particles .. " <= " .. prevF
			end
			if m.particles < prevM then
				T.incRed = false
			end
			prevF, prevM = f.particles, m.particles
		end
	end
	local counts = {}
	for r = 1, 10 do
		counts[r] = HP.plan(r, 141).particles
	end
	check("particules strictement croissantes avec la rareté (" .. table.concat(counts, " < ") .. ")" .. (T.inc and "" or " : " .. T.why), T.inc)
	check("version mobile : particules non décroissantes avec la rareté (et toujours <= 50 % de la version complète)", T.incRed)
	check("Divin au moins 3 fois plus de particules que Commun", counts[10] >= 3 * counts[1])
	T.goldOk, T.noGoldLow = true, true
	for r = 1, 10 do
		local f = HP.plan(r, 141)
		local g = HP.goldParticles(f)
		if r >= HP.GOLD_FROM then
			if g < HP.GOLD_MIN or g * 4 < f.particles then
				T.goldOk = false
			end
		elseif g > 0 then
			T.noGoldLow = false
		end
	end
	check("dès Légendaire (r" .. HP.GOLD_FROM .. ") : au moins " .. HP.GOLD_MIN .. " particules dorées et au moins 25 % de l'effet", T.goldOk)
	check("avant Légendaire : pas d'or (l'or reste le signal des grandes raretés)", T.noGoldLow)
	T.sizeOk, T.durOk, T.capOk, T.minSize = true, true, true, math.huge
	for _, N in ipairs(Ns) do
		for r = 1, 10 do
			for _, red in ipairs({ false, true }) do
				local plan = HP.plan(r, N, { reduced = red })
				local ok = HP.check(plan)
				if not ok or plan.objects > HP.MAX_OBJECTS or plan.peakRate > HP.MAX_RATE or plan.duration > HP.MAX_DURATION then
					T.capOk = false
				end
				for _, b in ipairs(plan.beats) do
					if b.n > 0 and not FIXED[b.kind] then
						if type(b.size) ~= "number" or b.size < HP.MIN_PARTICLE_PX or b.size ~= HP.particleSize(r) then
							T.sizeOk = false
						else
							T.minSize = math.min(T.minSize, b.size)
						end
						if b.d < HP.MIN_PARTICLE_SECONDS - 1e-9 then
							T.durOk = false
						end
					end
				end
			end
		end
	end
	check("taille minimale : chaque prise de particules porte size >= " .. HP.MIN_PARTICLE_PX .. " px (croissante : " .. HP.particleSize(1) .. " -> " .. HP.particleSize(10) .. " px)", T.sizeOk and T.minSize >= 18 and HP.particleSize(10) > HP.particleSize(1))
	check("durée suffisante : chaque prise de particules dure au moins " .. HP.MIN_PARTICLE_SECONDS .. " s", T.durOk)
	check("plafonds du plan inchangés : <= 30 objets, <= 40 objets/s, <= 8 s (10 raretés x 4 compteurs x complet / mobile)", T.capOk and HP.MAX_OBJECTS == 30 and HP.MAX_RATE == 40 and HP.MAX_DURATION == 8)

	---------------------------------------------------------------- Exécution réelle
	if type(env.newRuntime) ~= "function" then
		return
	end
	suite("Graphismes 5 : HatchFx exécuté (runtime factice) : tailles réelles, plafonds 220 / 120 / 80")
	local RT = env.newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local made = {}
	local env2 = {}
	for k, v in pairs(RT.env) do
		env2[k] = v
	end
	env2.UDim2 = { -- UDim2 mesurable (le runtime factice rend une table vide)
		fromOffset = function(x, y)
			return { X = { Offset = x or 0, Scale = 0 }, Y = { Offset = y or 0, Scale = 0 } }
		end,
		fromScale = function(x, y)
			return { X = { Offset = 0, Scale = x or 0 }, Y = { Offset = 0, Scale = y or 0 } }
		end,
		new = function(a, b, c, d)
			return { X = { Scale = a or 0, Offset = b or 0 }, Y = { Scale = c or 0, Offset = d or 0 } }
		end,
	}
	env2.Instance = { new = function(class)
		local o = RT.instance(class)
		made[#made + 1] = o
		return o
	end }
	local HatchFx = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/HatchFx.lua"), { debugName = "HatchFx", environment = env2 })()
	local BattleIntro = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/BattleIntro.lua"), { debugName = "BattleIntro", environment = env2 })()
	local TypeFx = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/TypeFx.lua"), { debugName = "TypeFxClient", environment = env2 })()
	check("plafonds durs : HatchFx 220, BattleIntro 120, TypeFx 80 (inchangés)", HatchFx.MAX_INSTANCES == 220 and BattleIntro.MAX_INSTANCES == 120 and TypeFx.MAX_INSTANCES == 80)
	T.worst, T.minPx, T.particlesSeen, T.goldSeen, T.runOk = 0, math.huge, {}, {}, true
	for r = 1, 10 do
		for _, red in ipairs({ false, true }) do
			made = {}
			local g = RT.instance("ScreenGui", "gui")
			g.Enabled = true
			local plan = HP.plan(r, 1e6, { reduced = red })
			local h = HatchFx.play(g, plan, {
				colors = { main = env2.Color3.fromRGB(80, 170, 255), second = env2.Color3.fromRGB(40, 90, 200) }, rarityName = "R" .. r, petText = "🐣",
				slot = { rarity = "Rare", size = "Grand", mut = "", pools = { rarity = { "Commun", "Rare" }, size = { "Mini", "Grand" }, mut = { "", "Doré" } } },
				sound = function() end,
			})
			-- tailles des objets de particules À LA CRÉATION (avant les tweens)
			local n, gold = 0, 0
			local seen = {}
			local t = 0
			while t < plan.duration + 1 do
				for _, o in ipairs(made) do
					if not seen[o] and o.Name == "Particle" then
						seen[o] = true
						n = n + 1
						local sz = o.Size
						local big = sz and math.max(sz.X.Offset, sz.Y.Offset) or 0
						T.minPx = math.min(T.minPx, big)
						local c = o.ClassName == "TextLabel" and o.TextColor3 or o.BackgroundColor3
						if type(c) == "table" and type(c.R) == "number" and math.abs(c.R - 1) < 0.01 and math.abs(c.G - 205 / 255) < 0.01 and math.abs(c.B - 60 / 255) < 0.01 then
							gold = gold + 1
						end
					end
				end
				RT.step(0.05)
				t = t + 0.05
			end
			if h == nil or not h.isDone() then
				T.runOk = false
			else
				T.worst = math.max(T.worst, h.created())
			end
			if not red then
				T.particlesSeen[r], T.goldSeen[r] = n, gold
			end
		end
	end
	check("20 éclosions jouées jusqu'au bout sans erreur" .. (#RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))), T.runOk and #RT.errors == 0)
	check("plafond d'instances HatchFx respecté (pic " .. T.worst .. " <= 220)", T.worst > 0 and T.worst <= HatchFx.MAX_INSTANCES)
	check("objets de particules réellement créés : plus grande dimension >= 18 px (minimum mesuré " .. tostring(T.minPx) .. " px)", T.minPx >= 18 and T.minPx < math.huge)
	T.goldReal = true
	for r = HP.GOLD_FROM, 10 do
		if (T.goldSeen[r] or 0) < 1 then
			T.goldReal = false
		end
	end
	check("dès Légendaire, des particules réellement dorées (RGB 255, 205, 60) apparaissent à l'écran", T.goldReal)
end
