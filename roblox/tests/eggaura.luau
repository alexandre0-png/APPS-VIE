--!nocheck
-- Lot graphismes 4 : halos d'œufs et bulles de protection (ReplicatedStorage/EggAura pur, StarterPlayerScripts/EggAura.client.lua, attributs posés par le serveur).
-- Rien n'est visible sans Studio : propriétés mesurables seulement (couleur = rareté, visibilité croissante, pulsation lente, plafonds d'instances desktop / mobile,
-- sélection des plus proches, réservoir sans fuite sur 600 images, aucune PointLight ajoutée, attributs Tier / ShieldUntil / Guarded dans le vrai Main).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime? }. Style : pas de `+=`, pas de `continue`, Park-Miller pour le hasard.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local T = {}
	local C3 = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } }
	local Config = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = C3 })()
	local EA = luau.load(fs.readFile("roblox/src/ReplicatedStorage/EggAura.lua"), { debugName = "EggAura" })()
	local seed = 12345
	local function rnd() -- Park-Miller 48271 mod 2^31-1 (produits < 2^53)
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local function has(s, w)
		return string.find(s, w, 1, true) ~= nil
	end

	---------------------------------------------------------------- 1. Styles
	suite("Graphismes 4 : halos d'œufs (couleur = rareté, visibilité croissante, pulsation lente)")
	check("Config.EGG_AURA présent et activé", type(Config.EGG_AURA) == "table" and Config.EGG_AURA.enabled == true)
	local n = #Config.TIERS
	T.colorOk, T.mono, T.slow, T.alphaOk = true, true, true, true
	local prev = nil
	for t = 1, n do
		local st = EA.halo(Config, t)
		local c, ref = st.color, Config.TIERS[t].color
		if not (c and c.R == ref.R and c.G == ref.G and c.B == ref.B) then
			T.colorOk = false
		end
		if prev and not (st.transparency < prev.transparency and st.amplitude > prev.amplitude and st.scale > prev.scale and st.period <= prev.period) then
			T.mono = false
		end
		if st.period < 2 or st.period > 4 then
			T.slow = false
		end
		local lo, hi = 1, 0
		for k = 0, 200 do
			local a = EA.alpha(st, k * st.period / 200, 0.3)
			lo, hi = math.min(lo, a), math.max(hi, a)
		end
		if lo < 0 or hi > 1 or math.abs((hi - lo) - st.amplitude) > 0.01 then
			T.alphaOk = false
		end
		prev = st
	end
	check("couleur du halo = Config.TIERS[t].color pour les " .. n .. " raretés", T.colorOk)
	check("plus la rareté monte, plus le halo est visible : transparence décroissante, amplitude et taille croissantes", T.mono)
	check("pulsation lente : période entre 2 et 4 s pour toutes les raretés", T.slow)
	check("transparence bornée à [0, 1] et amplitude de pulsation mesurée = amplitude du style (sur une période)", T.alphaOk)
	T.top, T.low = EA.halo(Config, n), EA.halo(Config, 1)
	check("rareté max nettement plus visible que la rareté 1 (opacité moyenne au moins x3)", (1 - (T.top.transparency + T.top.amplitude / 2)) >= 3 * (1 - (T.low.transparency + T.low.amplitude / 2)))
	check("halo néon, bulle en champ de force translucide (aucun type de lumière)", T.top.material == "Neon" and EA.bubble(Config, "shield").material == "ForceField" and EA.bubble(Config, "shield").transparency <= 0.4)
	check("bulle : couleur distincte bouclier / gardien", EA.bubble(Config, "guard").color ~= EA.bubble(Config, "shield").color and EA.bubble(Config, "guard").kind == "guard")
	check("rareté invalide : repli sur la rareté 1, sans erreur", EA.halo(Config, 0 / 0).tier == 1 and EA.halo(Config, 99).tier == n and EA.alpha(nil, 1) == 1)
	check("diamètre : halo plus large que l'œuf, bulle plus large que le halo", EA.diameter(Config, 5, 3.2, "halo") > 3.2 and EA.diameter(Config, 5, 3.2, "bubble") > EA.diameter(Config, 5, 3.2, "halo"))

	---------------------------------------------------------------- 2. Plafonds et sélection
	suite("Graphismes 4 : plafonds d'instances (desktop / mobile), plus proches d'abord")
	T.capD, T.capM = EA.caps(Config, false), EA.caps(Config, true)
	check("plafonds desktop 24 halos / 12 bulles ; mobile 10 / 6 ; cadences mobiles plus lentes",
		T.capD.halos == 24 and T.capD.bubbles == 12 and T.capM.halos == 10 and T.capM.bubbles == 6 and T.capM.interval > T.capD.interval and T.capM.frameStep > T.capD.frameStep)
	local items = {}
	for i = 1, 300 do
		local prot = nil
		local r = rnd()
		if r < 0.2 then
			prot = "shield"
		elseif r < 0.3 then
			prot = "guard"
		end
		items[i] = { key = i, x = (rnd() - 0.5) * 400, y = rnd() * 10, z = (rnd() - 0.5) * 400, tier = 1 + math.floor(rnd() * n), protect = prot }
	end
	local cam = { x = 0, y = 5, z = 0 }
	for _, mode in ipairs({ { caps = T.capD, name = "desktop" }, { caps = T.capM, name = "mobile" } }) do
		local sel = EA.select(items, cam, mode.caps)
		local inRange, maxSel, minOut = 0, 0, math.huge
		local chosen = {}
		for _, it in ipairs(sel.halos) do
			chosen[it.key] = true
			local d = math.sqrt((it.x - cam.x) ^ 2 + (it.y - cam.y) ^ 2 + (it.z - cam.z) ^ 2)
			maxSel = math.max(maxSel, d)
		end
		for _, it in ipairs(items) do
			local d = math.sqrt((it.x - cam.x) ^ 2 + (it.y - cam.y) ^ 2 + (it.z - cam.z) ^ 2)
			if d <= mode.caps.range then
				inRange = inRange + 1
				if not chosen[it.key] then
					minOut = math.min(minOut, d)
				end
			end
		end
		local bubOk = #sel.bubbles <= mode.caps.bubbles
		for _, it in ipairs(sel.bubbles) do
			bubOk = bubOk and (it.protect == "shield" or it.protect == "guard")
		end
		check(mode.name .. " : " .. #sel.halos .. " halos sur " .. inRange .. " œufs à portée (plafond " .. mode.caps.halos .. "), les plus proches d'abord", #sel.halos == math.min(inRange, mode.caps.halos) and maxSel <= minOut and maxSel <= mode.caps.range)
		check(mode.name .. " : " .. #sel.bubbles .. " bulles (plafond " .. mode.caps.bubbles .. "), seulement sur des œufs protégés", bubOk)
	end
	check("entrées invalides ignorées sans erreur", #EA.select({ { key = 1, x = 0 / 0, y = 0, z = 0, tier = 1 }, "x", { key = 2 } }, cam, T.capD).halos == 0 and #EA.select(nil, cam, T.capD).halos == 0)

	---------------------------------------------------------------- 3. Réservoir sans fuite
	suite("Graphismes 4 : réservoir d'objets sans fuite (600 images, œufs qui apparaissent et disparaissent)")
	local fake = { alive = 0, made = 0, peak = 0 }
	local factory = {
		make = function(kind)
			fake.alive = fake.alive + 1
			fake.made = fake.made + 1
			fake.peak = math.max(fake.peak, fake.alive)
			return { kind = kind, hidden = false }
		end,
		hide = function(o)
			o.hidden = true
		end,
		destroy = function(o)
			o.dead = true
			fake.alive = fake.alive - 1
		end,
	}
	local mgr = EA.newManager(factory, math.max(T.capD.halos, T.capD.bubbles))
	T.capsOk = true
	local pool = {}
	for i = 1, 80 do
		pool[i] = { key = i, x = (rnd() - 0.5) * 200, y = 2, z = (rnd() - 0.5) * 200, tier = 1 + math.floor(rnd() * n), protect = rnd() < 0.3 and "shield" or nil, on = rnd() < 0.5 }
	end
	for frame = 1, 600 do
		for _, e in ipairs(pool) do
			if rnd() < 0.05 then
				e.on = not e.on
			end
		end
		local list = {}
		for _, e in ipairs(pool) do
			if e.on then
				list[#list + 1] = e
			end
		end
		local camF = { x = math.sin(frame / 50) * 60, y = 5, z = math.cos(frame / 50) * 60 }
		mgr.sync(EA.select(list, camF, T.capD))
		if mgr.count("halo") > T.capD.halos or mgr.count("bubble") > T.capD.bubbles or fake.alive > T.capD.halos + T.capD.bubbles + 2 * mgr.poolMax then
			T.capsOk = false
		end
	end
	check("600 images : jamais plus de 24 halos / 12 bulles vivants ; objets créés en vie <= plafonds + réservoir (pic " .. fake.peak .. ")", T.capsOk)
	mgr.sync({ halos = {}, bubbles = {} })
	check("plus aucun œuf : 0 objet attaché, réservoir borné (" .. #mgr.pool.halo .. " + " .. #mgr.pool.bubble .. " <= " .. 2 * mgr.poolMax .. ")", mgr.count("halo") == 0 and mgr.count("bubble") == 0 and #mgr.pool.halo <= mgr.poolMax and #mgr.pool.bubble <= mgr.poolMax)
	check("réutilisation : " .. fake.made .. " objets créés en tout sur 600 images (aucune création par image)", fake.made <= 2 * (T.capD.halos + T.capD.bubbles))
	mgr.clear()
	check("désactivation : tout est détruit (0 objet en vie)", fake.alive == 0 and #mgr.pool.halo == 0)

	---------------------------------------------------------------- 4. Textes : script client et serveur
	suite("Graphismes 4 : script client (aucune lumière, Parts inertes, mobile réduit) et attributs serveur")
	local cli = fs.readFile("roblox/src/StarterPlayerScripts/EggAura.client.lua")
	local bld = fs.readFile("roblox/src/ServerScriptService/Builder.lua")
	local mainSrc = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
	local mod = fs.readFile("roblox/src/ReplicatedStorage/EggAura.lua")
	check("aucune PointLight / SpotLight / SurfaceLight créée par les halos (budget LightLod <= 4 inchangé)", not has(cli, "Light\")") and not has(mod, "Light\")"))
	check("Parts locales inertes : CanCollide, CanTouch, CanQuery, CastShadow coupés", has(cli, "p.CanCollide = false") and has(cli, "p.CanTouch = false") and has(cli, "p.CanQuery = false") and has(cli, "p.CastShadow = false"))
	check("mobile détecté et plafonds réduits appliqués", has(cli, "TouchEnabled and not UserInputService.KeyboardEnabled") and has(cli, "EggAura.caps(Config, mobile)"))
	check("erreur : connexion coupée, objets détruits (pas de fuite)", has(cli, "conn:Disconnect()") and has(cli, "manager.clear()") and has(cli, "folder:Destroy()"))
	check("clé d'œuf en table faible (aucune référence gardée sur un œuf détruit)", has(cli, 'setmetatable({}, { __mode = "k" })'))
	check("serveur : chaque œuf (Builder.egg) porte Tier et le tag EggAura ; bouclier et nid surveillé publiés",
		has(bld, 'p:SetAttribute("Tier", tier)') and has(bld, 'CollectionService:AddTag(p, "EggAura")') and has(mainSrc, 'egg:SetAttribute("ShieldUntil"') and has(mainSrc, 'egg:SetAttribute("Guarded"'))
	check("pas de += / continue / math.atan2 dans le module partagé", not has(mod, "+=") and not has(mod, "continue") and not has(mod, "atan2"))
	check("place : module et script client dans build_place.py", has(fs.readFile("roblox/tools/build_place.py"), '("EggAura", "EggAura.lua")') and has(fs.readFile("roblox/tools/build_place.py"), '"StarterPlayerScripts/EggAura.client.lua"'))

	---------------------------------------------------------------- 5. Bout en bout
	if type(env.newRuntime) ~= "function" then
		return
	end
	suite("Graphismes 4 : bout en bout (vrai Main) : attributs des œufs, aucune lumière ajoutée")
	T.RT = env.newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game })
	if not T.RT then
		return
	end
	local RT = T.RT
	local main = RT.buildTree("roblox/src", false)
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(2)
	local CS = RT.services.CollectionService
	local cfg = RT.require(RT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config"))
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local function eggsTagged()
		local list = CS:GetTagged("EggAura")
		local out = {}
		for _, e in ipairs(list) do
			if e.Parent then
				out[#out + 1] = e
			end
		end
		return out
	end
	T.nestOk, T.nests, T.guarded = true, 0, 0
	for _, e in ipairs(eggsTagged()) do
		local tier = e:GetAttribute("Tier")
		if type(tier) ~= "number" or not cfg.TIERS[tier] then
			T.nestOk = false
		end
		if e:GetAttribute("Guarded") ~= nil then
			T.nests = T.nests + 1
			if e:GetAttribute("Guarded") == true then
				T.guarded = T.guarded + 1
			end
		end
	end
	check("œufs des nids : Tier valide et Guarded posé (" .. T.guarded .. " surveillés sur " .. T.nests .. ")", T.nestOk and T.nests >= 10 and T.guarded > 0 and T.guarded < T.nests)
	T.p = RT.addPlayer("Aura", 18801, { from = "hub", partyId = "AURA", size = 1, late = false })
	RT.step(3)
	T.s = hooks.session(T.p)
	T.s.data.coins = 1e9
	T.s.graceUntil = 0
	local root = T.p.Character and T.p.Character:FindFirstChild("HumanoidRootPart")
	if root and T.s.plot then
		local c = T.s.plot.spawn.CFrame
		rawget(root, "__props").Position = RT.vec(c.X, 3, c.Z)
		rawget(root, "__props").CFrame = RT.cf(c.X, 3, c.Z)
	end
	RT.now = RT.now + 1
	RT.fire(RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action"), "OnServerEvent", T.p, "buyEgg", 2)
	RT.step(1)
	T.padEgg = nil
	for _, e in ipairs(eggsTagged()) do
		if e:GetAttribute("ShieldUntil") ~= nil and e:GetAttribute("Tier") == 2 then
			T.padEgg = e
		end
	end
	check("œuf posé dans la base : Tier = 2 et ShieldUntil = bouclier du slot (dans le futur)", T.padEgg ~= nil and T.padEgg:GetAttribute("ShieldUntil") > 1700000000 + RT.now - 5)
	check("bout en bout sans erreur" .. (#RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))), #RT.errors == 0)
	RT.removePlayer(T.p)
	RT.step(2)
end
