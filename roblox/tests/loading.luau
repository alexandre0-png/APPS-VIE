--!nocheck
-- Écran de chargement : ReplicatedFirst/LoadingPlan (pur) et LoadingScreen.client.lua (exécuté dans le runtime factice). Rien n'est vu dans Studio.
-- Mesuré : progression lissée et monotone, minimum 2 s, maximum 25 s, fondu puis fin, ScaleType selon le ratio, repli fond bleu nuit si l'image échoue,
-- contraste du texte, identifiant identique à Config.LOADING, aucune instance ni connexion restante après fermeture, déclaré dans les .project.json et build_place.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime? }. Style : pas de `+=`, pas de `continue`.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local T = {}
	local C3 = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } }
	local Config = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = C3 })()
	local planSrc = fs.readFile("roblox/src/ReplicatedFirst/LoadingPlan.lua")
	local P = luau.load(planSrc, { debugName = "LoadingPlan" })()
	local scriptSrc = fs.readFile("roblox/src/ReplicatedFirst/LoadingScreen.client.lua")
	local function has(s, w)
		return string.find(s, w, 1, true) ~= nil
	end
	local function lin(c)
		c = c / 255
		if c <= 0.03928 then
			return c / 12.92
		end
		return ((c + 0.055) / 1.055) ^ 2.4
	end
	local function lum(rgb)
		return 0.2126 * lin(rgb[1]) + 0.7152 * lin(rgb[2]) + 0.0722 * lin(rgb[3])
	end
	local function contrast(a, b)
		local la, lb = lum(a), lum(b)
		return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
	end
	-- Simule `seconds` secondes à 30 images/s ; `inputs(t)` donne les entrées de l'image courante. Retourne l'état et l'historique de progression.
	local function run(st, seconds, inputs)
		local hist = {}
		local t = 0
		while t < seconds and not st.done do
			t = t + 1 / 30
			local inp = inputs(t)
			inp.dt = 1 / 30
			P.update(st, inp)
			hist[#hist + 1] = st.shown
		end
		return t, hist
	end
	local function monotone(hist)
		local ok = true
		for i = 2, #hist do
			if hist[i] < hist[i - 1] then
				ok = false
			end
		end
		return ok
	end

	suite("Écran de chargement : configuration et identifiant")
	check("Config.LOADING.image = rbxassetid://140180423430231 = LoadingPlan.CFG.image", Config.LOADING.image == "rbxassetid://140180423430231" and P.CFG.image == Config.LOADING.image)
	check("fond bleu nuit (14, 20, 48), minimum 2 s, maximum 25 s", P.CFG.bg[1] == 14 and P.CFG.bg[2] == 20 and P.CFG.bg[3] == 48 and P.CFG.minShow == 2 and P.CFG.maxShow == 25)
	check("texte « Chargement des œufs… », contraste blanc / bleu nuit >= 4,5 et même sur la bande à 80 % d'opacité sur du blanc", P.CFG.text == "Chargement des œufs…" and contrast({ 255, 255, 255 }, P.CFG.bg) >= 4.5
		and contrast({ 255, 255, 255 }, { math.floor(0.8 * 14 + 0.2 * 255), math.floor(0.8 * 20 + 0.2 * 255), math.floor(0.8 * 48 + 0.2 * 255) }) >= 4.5)
	check("module pur : pas de += / continue / GetService / Instance", not has(planSrc, "+=") and not has(planSrc, "continue") and not has(planSrc, "GetService") and not has(planSrc, "Instance"))

	suite("Écran de chargement : ScaleType selon l'écran")
	check("16:9 (1920x1080, 1280x720) et 16:10, 3:2 : Crop", P.scaleType(1920, 1080) == "Crop" and P.scaleType(1280, 720) == "Crop" and P.scaleType(1920, 1200) == "Crop" and P.scaleType(1500, 1000) == "Crop")
	check("téléphone en portrait (360x800), carré, ultra-large 21:9, 4:3 : Fit (titre jamais coupé)", P.scaleType(360, 800) == "Fit" and P.scaleType(800, 800) == "Fit" and P.scaleType(2560, 1080) == "Fit" and P.scaleType(1024, 768) == "Fit")
	check("tailles invalides (nil, 0, NaN, texte) : Fit", P.scaleType(nil, nil) == "Fit" and P.scaleType(0, 0) == "Fit" and P.scaleType(0 / 0, 100) == "Fit" and P.scaleType("a", "b") == "Fit")
	check("imageVisible : Success seulement (avec ou sans préfixe Enum)", P.imageVisible("Success") and P.imageVisible("Enum.AssetFetchStatus.Success") and not P.imageVisible("Failure") and not P.imageVisible(nil) and not P.imageVisible("Enum.AssetFetchStatus.TimedOut"))

	suite("Écran de chargement : progression, minimum, maximum")
	-- Cas rapide : tout est prêt dès le début (personnage reçu à 0,3 s)
	T.st = P.new()
	T.t, T.hist = run(T.st, 60, function(t)
		return { imageStatus = "Success", queue = 0, gameLoaded = true, character = t > 0.3 }
	end)
	check("chargement rapide : jamais fermé avant 2 s d'affichage (" .. string.format("%.2f", T.t) .. " s au total)", T.t >= 2 and T.t <= 3.2)
	check("barre monotone (aucun recul) et dans [0, 1]", monotone(T.hist) and T.hist[1] >= 0 and T.hist[#T.hist] == 1)
	check("barre lissée : pas de saut supérieur à 25 % entre deux images", (function()
		local big = false
		for i = 2, #T.hist do
			if T.hist[i] - T.hist[i - 1] > 0.25 then
				big = true
			end
		end
		return not big
	end)())
	check("fin : phase done, transparence 1, barre pleine", T.st.done and T.st.phase == "done" and T.st.alpha == 1 and T.st.shown == 1)
	-- Fondu : transparence croissante, jamais avant 2 s
	T.st = P.new()
	T.alphaMono, T.prevA, T.firstFade = true, 0, nil
	T.t = 0
	while not T.st.done and T.t < 30 do
		T.t = T.t + 1 / 30
		P.update(T.st, { dt = 1 / 30, imageStatus = "Success", queue = 0, gameLoaded = true, character = true })
		if T.st.alpha < T.prevA then
			T.alphaMono = false
		end
		T.prevA = T.st.alpha
		if T.st.alpha > 0 and not T.firstFade then
			T.firstFade = T.t
		end
	end
	check("fondu : transparence croissante, démarre après 2 s, dure environ " .. P.CFG.fade .. " s", T.alphaMono and T.firstFade >= 2 and T.t - T.firstFade <= P.CFG.fade + 0.2)
	-- Personnage tardif : l'écran reste tant qu'il n'est pas là (jusqu'au maximum)
	T.st = P.new()
	T.t, T.hist = run(T.st, 12, function()
		return { imageStatus = "Success", queue = 0, gameLoaded = true, character = false }
	end)
	check("sans personnage : toujours affiché après 12 s, barre monotone et sous 100 %", not T.st.done and T.st.phase == "show" and monotone(T.hist) and T.st.shown < 1)
	-- Maximum : rien n'arrive jamais (pas d'image, file bloquée, pas de personnage)
	T.st = P.new()
	T.t, T.hist = run(T.st, 120, function()
		return { imageStatus = "Failure", queue = 50, gameLoaded = false, character = false }
	end)
	check("tout bloqué : quitte l'écran au maximum (25 s + fondu), pas plus (" .. string.format("%.1f", T.t) .. " s)", T.st.done and T.t >= 25 and T.t <= 26.2)
	check("tout bloqué : barre monotone, remplie à la fin", monotone(T.hist) and T.hist[#T.hist] == 1)
	check("image en échec : image masquée, fond bleu nuit seul (repli)", T.st.imageVisible == false and P.CFG.bg[3] == 48)
	T.st = P.new()
	P.update(T.st, { dt = 0.1, imageStatus = "Success" })
	check("image préchargée : visible", T.st.imageVisible == true)
	T.st = P.new()
	P.update(T.st, { dt = 0.1 })
	check("image pas encore arrivée : masquée, fond seul", T.st.imageVisible == false)
	-- File de préchargement qui se vide : la barre avance, jamais de recul même si la file regrossit
	T.st = P.new()
	T.qs = { 10, 8, 20, 5, 0, 0 }
	T.prev, T.ok = 0, true
	for i = 1, #T.qs do
		P.update(T.st, { dt = 0.5, imageStatus = "Success", queue = T.qs[i], gameLoaded = false, character = false })
		if T.st.shown < T.prev then
			T.ok = false
		end
		T.prev = T.st.shown
	end
	check("file qui regrossit : la barre ne recule pas", T.ok)
	-- Entrées invalides
	T.st = P.new()
	P.update(T.st, { dt = 0 / 0, queue = "x", gameLoaded = "oui", character = 1 })
	P.update(T.st, { dt = -5, queue = -3 })
	P.update(T.st, nil)
	P.update(T.st, { dt = 1e9 })
	check("entrées invalides (NaN, négatif, texte, nil, énorme) : aucune erreur, valeurs bornées", T.st.shown >= 0 and T.st.shown <= 1 and T.st.elapsed <= 1.0001)

	suite("Écran de chargement : script client (runtime factice)")
	check("déclaré : RemoveDefaultLoadingScreen, IgnoreGuiInset, ResetOnSpawn faux, DisplayOrder élevé, PreloadAsync, pcall, garde-fou", has(scriptSrc, "RemoveDefaultLoadingScreen()") and has(scriptSrc, "gui.IgnoreGuiInset = true")
		and has(scriptSrc, "gui.ResetOnSpawn = false") and has(scriptSrc, "gui.DisplayOrder = 1000") and has(scriptSrc, "PreloadAsync") and has(scriptSrc, "task.delay(CFG.maxShow + 3, close)"))
	check("fermeture : toutes les connexions (Heartbeat, CharacterAdded, ViewportSize) déconnectées puis ScreenGui détruit", has(scriptSrc, ":Disconnect()") and has(scriptSrc, "gui:Destroy()") and has(scriptSrc, "conns[#conns + 1] = RunService.Heartbeat:Connect")
		and has(scriptSrc, "conns[#conns + 1] = player.CharacterAdded:Connect") and has(scriptSrc, "ViewportSize\"):Connect"))
	check("sécurité : aucun remote, aucune donnée du joueur affichée (pas de Name / DisplayName / UserId)", not has(scriptSrc, "FireServer") and not has(scriptSrc, "RemoteEvent") and not has(scriptSrc, "DisplayName") and not has(scriptSrc, "UserId") and not has(scriptSrc, "player.Name"))
	check("déclaré dans les 3 .project.json et dans build_place.py", has(fs.readFile("roblox/default.project.json"), "src/ReplicatedFirst") and has(fs.readFile("roblox/game.project.json"), "src/ReplicatedFirst")
		and has(fs.readFile("roblox/hub.project.json"), "src/ReplicatedFirst") and has(fs.readFile("roblox/tools/build_place.py"), "ReplicatedFirst/LoadingScreen.client.lua") and has(fs.readFile("roblox/tools/build_place.py"), "ReplicatedFirst/LoadingPlan.lua"))
	if env.newRuntime then
		local function launch(opts)
			local RT = env.newRuntime({ fs = fs, luau = luau, placeId = 1 })
			if not RT then
				return nil
			end
			local S = RT.services
			S.ReplicatedFirst = RT.instance("ReplicatedFirst", "ReplicatedFirst")
			S.ContentProvider = RT.instance("ContentProvider", "ContentProvider")
			local cp = rawget(S.ContentProvider, "__props")
			cp.RequestQueueSize = 0
			cp.PreloadAsync = function(_, _, cb)
				if opts.preloadError then
					error("réseau")
				end
				if cb then
					cb("rbxassetid://140180423430231", opts.status or "Enum.AssetFetchStatus.Success")
				end
			end
			RT.removed = 0
			rawget(S.ReplicatedFirst, "__props").RemoveDefaultLoadingScreen = function()
				RT.removed = RT.removed + 1
			end
			rawget(RT.game, "__props").IsLoaded = function()
				return RT.gameLoaded == true
			end
			RT.gameLoaded = opts.loaded ~= false
			local p = RT.instance("Player", "Testeur")
			RT.setLocalPlayer(p)
			RT.player = p
			rawget(p, "__props").Character = false -- pas encore de personnage (le proxy factice rendrait sinon un faux « présent »)
			local before = #RT.all
			local e = {}
			for k, v in pairs(RT.env) do
				e[k] = v
			end
			e.script = { Parent = { WaitForChild = function() return "LoadingPlan" end } }
			e.require = function() return luau.load(planSrc, { debugName = "LoadingPlan" })() end
			RT.task.spawn(function()
				luau.load(scriptSrc, { debugName = "LoadingScreen", environment = e })()
			end)
			RT.before = before
			RT.signalsAtStart = nil
			return RT
		end
		local function screenGui(RT)
			local pg = RT.player:FindFirstChild("PlayerGui")
			return pg and pg:FindFirstChild("LoadingScreen") or nil
		end
		local function countDescendants(RT)
			local g = screenGui(RT)
			return g and #g:GetDescendants() or 0
		end

		-- 1. Déroulé normal : écran visible, pas de fermeture avant 2 s, fermeture après l'arrivée du personnage, tout nettoyé
		local RT = launch({})
		if RT then
			RT.step(0.5)
			check("écran créé tout de suite (ScreenGui LoadingScreen dans PlayerGui), écran Roblox par défaut retiré", screenGui(RT) ~= nil and RT.removed == 1)
			local g = screenGui(RT)
			check("ScreenGui : IgnoreGuiInset, ResetOnSpawn faux, DisplayOrder 1000", g ~= nil and g.IgnoreGuiInset == true and g.ResetOnSpawn == false and g.DisplayOrder == 1000)
			local back = g and g:FindFirstChild("Back")
			local splash = back and back:FindFirstChild("Splash")
			check("fond bleu nuit et image (Image = rbxassetid://140180423430231) présents", back ~= nil and back.BackgroundColor3.R == 14 / 255 and splash ~= nil and splash.Image == "rbxassetid://140180423430231")
			check("image affichée après préchargement réussi, ScaleType choisi (1280x720 : Crop)", splash ~= nil and splash.Visible == true and tostring(splash.ScaleType):find("Crop") ~= nil)
			rawget(RT.player, "__props").Character = RT.instance("Model", "Perso")
			RT.fire(RT.player, "CharacterAdded", rawget(RT.player, "__props").Character)
			RT.step(0.8)
			check("personnage reçu mais < 2 s d'affichage : écran toujours là", screenGui(RT) ~= nil)
			RT.step(3)
			check("après 2 s et le personnage : écran détruit (plus rien dans PlayerGui)", screenGui(RT) == nil)
			local pgui = RT.player:FindFirstChild("PlayerGui")
			local leftovers = pgui and #pgui:GetDescendants() or -1
			check("aucune instance de l'écran restante après fermeture", leftovers == 0)
			check("aucune erreur de script" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
			local before = #RT.all
			RT.step(60)
			check("rien ne se recrée ensuite (watchdog sans effet après fermeture)", #RT.all == before and screenGui(RT) == nil)
		end

		-- 2. Image en échec (PreloadAsync lève une erreur) et jeu lent : fond seul, puis fermeture au maximum sans personnage
		local RT2 = launch({ preloadError = true, loaded = false })
		if RT2 then
			RT2.step(3)
			local g = screenGui(RT2)
			local splash = g and g:FindFirstChild("Back") and g:FindFirstChild("Back"):FindFirstChild("Splash")
			check("préchargement en erreur : écran bleu nuit gardé, image masquée, aucune erreur", g ~= nil and splash ~= nil and splash.Visible == false and #RT2.errors == 0)
			RT2.step(20)
			check("à 23 s sans personnage : toujours là (maximum 25 s)", screenGui(RT2) ~= nil)
			RT2.step(5)
			check("après le maximum : écran détruit même sans personnage ni jeu chargé", screenGui(RT2) == nil and #RT2.errors == 0)
		end

		-- 3. Statut d'échec renvoyé par PreloadAsync : image masquée
		local RT3 = launch({ status = "Enum.AssetFetchStatus.Failure" })
		if RT3 then
			RT3.step(1)
			local g = screenGui(RT3)
			local splash = g and g:FindFirstChild("Back") and g:FindFirstChild("Back"):FindFirstChild("Splash")
			check("statut Failure : image masquée, fond seul", splash ~= nil and splash.Visible == false)
		end

		-- 4. Personnage déjà présent au démarrage : ferme quand même seulement après 2 s
		local RT4 = launch({})
		if RT4 then
			rawget(RT4.player, "__props").Character = RT4.instance("Model", "Perso")
			RT4.step(1)
			check("personnage déjà là : toujours affiché à 1 s", screenGui(RT4) ~= nil)
		end
	else
		suite("Écran de chargement : runtime factice indisponible, suite sautée")
	end
end
