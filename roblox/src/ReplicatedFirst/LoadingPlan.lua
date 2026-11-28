-- ModuleScript : ReplicatedFirst/LoadingPlan
-- Écran de chargement : logique PURE (aucun service, aucune instance), testée hors Roblox. Le script LoadingScreen.client.lua l'appelle à chaque image.
-- Vit dans ReplicatedFirst (et non ReplicatedStorage) : ce dossier est répliqué en premier, ReplicatedStorage peut arriver après l'écran.
-- L'identifiant de l'image est donc répété ici ; Config.LOADING.image (ReplicatedStorage) doit rester identique (test « tests/loading.luau »).
-- Style : pas d'affectation composée ni de saut de boucle (modules partagés, lupa).
local LoadingPlan = {}

LoadingPlan.CFG = {
	image = "rbxassetid://140180423430231", -- Decal approuvé « Chipe-Oeufs accroche v2 », 1920 x 1080 (16:9) avec le titre
	imageRatio = 16 / 9,
	bg = { 14, 20, 48 }, -- bleu nuit, affiché tout de suite et conservé si l'image n'arrive pas
	text = "Chargement des œufs…",
	minShow = 2, -- secondes d'affichage minimales avant le fondu
	maxShow = 25, -- délai maximal : au-delà, on quitte l'écran quoi qu'il arrive (le jeu n'est jamais bloqué)
	hold = 0.25, -- le temps de remplir la barre à 100 % avant le fondu
	fade = 0.5, -- durée du fondu
	smooth = 6, -- vitesse de lissage de la barre (1 / s)
	cropMin = 1.5, -- plage de ratios d'écran (largeur / hauteur) où l'image est rognée (Crop) ; ailleurs elle est entière (Fit)
	cropMax = 2.0,
}

local function num(v, default)
	if type(v) == "number" and v == v and v > -math.huge and v < math.huge then
		return v
	end
	return default
end

local function clamp01(v)
	if v < 0 then
		return 0
	elseif v > 1 then
		return 1
	end
	return v
end

-- ScaleType de l'image 16:9 selon l'écran : "Crop" (remplit, rogne < 16 % de la largeur ou de la hauteur) proche du 16:9, "Fit" (image entière,
-- bandes bleu nuit autour) pour un téléphone en portrait, un écran carré ou ultra-large : le titre n'est jamais coupé ni déformé.
function LoadingPlan.scaleType(width, height, cfg)
	cfg = cfg or LoadingPlan.CFG
	local w, h = num(width, 0), num(height, 0)
	if w <= 0 or h <= 0 then
		return "Fit"
	end
	local r = w / h
	if r >= cfg.cropMin and r <= cfg.cropMax then
		return "Crop"
	end
	return "Fit"
end

-- L'image n'est affichée que si son préchargement a réussi (AssetFetchStatus.Success, avec ou sans préfixe « Enum.AssetFetchStatus. »).
function LoadingPlan.imageVisible(status)
	if status == nil then
		return false
	end
	local s = tostring(status)
	return s == "Success" or s == "Enum.AssetFetchStatus.Success"
end

function LoadingPlan.new(cfg)
	return {
		cfg = cfg or LoadingPlan.CFG,
		elapsed = 0,
		shown = 0, -- progression affichée, 0..1, ne recule jamais
		phase = "show", -- "show" -> "fade" -> "done"
		fadeT = 0,
		alpha = 0, -- transparence de l'écran (0 opaque, 1 invisible)
		done = false,
		imageVisible = false,
		maxQueue = 0,
	}
end

-- input = { dt, imageStatus, queue (éléments restant à charger), gameLoaded (bool), character (bool) } ; toute valeur invalide est ignorée.
function LoadingPlan.update(st, input)
	if st.done then
		return st
	end
	input = input or {}
	local cfg = st.cfg
	local dt = num(input.dt, 0)
	if dt < 0 then
		dt = 0
	elseif dt > 1 then
		dt = 1
	end
	st.elapsed = st.elapsed + dt
	if input.imageStatus ~= nil then
		st.imageVisible = LoadingPlan.imageVisible(input.imageStatus)
	end
	local imageDone = input.imageStatus ~= nil
	-- Fraction des éléments préchargés : la file ContentProvider.RequestQueueSize donne le reste, on retient son maximum comme total.
	local q = num(input.queue, 0)
	if q < 0 then
		q = 0
	end
	if q > st.maxQueue then
		st.maxQueue = q
	end
	local frac = 0
	if st.maxQueue > 0 then
		frac = clamp01(1 - q / st.maxQueue)
	elseif imageDone then
		frac = 1
	end
	local target = 0.05
	if imageDone then
		target = target + 0.15
	end
	target = target + 0.5 * frac
	if input.gameLoaded == true then
		target = target + 0.2
	end
	if input.character == true then
		target = target + 0.1
	end
	local creep = math.min(0.8, st.elapsed / cfg.maxShow * 0.8) -- plancher lié au temps : la barre ne reste jamais figée
	if creep > target then
		target = creep
	end
	if target > 1 then
		target = 1
	end
	if st.phase == "show" then
		if (input.character == true and st.elapsed >= cfg.minShow) or st.elapsed >= cfg.maxShow then
			st.phase = "fade"
			st.fadeT = 0
		end
	end
	local rate = cfg.smooth
	if st.phase ~= "show" then
		target = 1
		rate = rate * 3
	end
	local nxt = st.shown + (target - st.shown) * (1 - math.exp(-rate * dt))
	if nxt > st.shown then
		st.shown = clamp01(nxt)
	end
	if st.phase == "fade" then
		st.fadeT = st.fadeT + dt
		if st.fadeT > cfg.hold then
			st.alpha = clamp01((st.fadeT - cfg.hold) / cfg.fade)
		end
		if st.fadeT >= cfg.hold + cfg.fade then
			st.phase = "done"
			st.done = true
			st.alpha = 1
			st.shown = 1
		end
	end
	return st
end

return LoadingPlan
