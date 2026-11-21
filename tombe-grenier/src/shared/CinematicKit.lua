--[[
  CinematicKit : plans de caméra courts et passables (jamais plus de 8 s), pour les moments clés du grenier.
  - Logique pure (plans, durées, trajectoires, easings, refus en cas de danger) : testée sans Roblox.
  - Exécution client (CinematicKit.run) : barres noires, titres, tremblement, flou, bouton « Passer » (Espace, Échap,
    Entrée ou appui), caméra, champ de vision, flou et personnage RESTAURÉS dans tous les cas (fin, passage, erreur, mort,
    départ). Une seule cinématique à la fois : une seconde demande pendant la première est refusée.
  Une prise : { t, path = "travelling"|"orbite"|"plongee"|"dolly", from = {x,y,z}, to = {x,y,z}, look = {x,y,z},
  fov = {début, fin}, ease, shake, slow, title, blur = {début, fin}, tint = {r,g,b}, radius, sweep }.
  Les positions sont relatives au point d'ancrage (la tête du joueur, ou l'objet filmé).
]]
local CinematicKit = {}

CinematicKit.MAX_SECONDS = 8

-- Easings purs : a dans [0, 1] -> [0, 1] (Back et Elastic dépassent un peu 1, c'est voulu)
local function clamp01(a)
	return math.max(0, math.min(1, a))
end
CinematicKit.EASINGS = {
	linear = function(a)
		return a
	end,
	Sine = function(a)
		return 0.5 - 0.5 * math.cos(math.pi * a)
	end,
	Quad = function(a)
		return a < 0.5 and 2 * a * a or 1 - (-2 * a + 2) ^ 2 / 2
	end,
	Quint = function(a)
		return 1 - (1 - a) ^ 5
	end,
	Back = function(a)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
	end,
	Elastic = function(a)
		if a <= 0 then
			return 0
		elseif a >= 1 then
			return 1
		end
		return 2 ^ (-10 * a) * math.sin((a * 10 - 0.75) * (2 * math.pi) / 3) + 1
	end,
}

function CinematicKit.ease(name, a)
	local f = CinematicKit.EASINGS[name] or CinematicKit.EASINGS.Sine
	return f(clamp01(a))
end

-- Plans du grenier. Durée totale de chaque plan <= MAX_SECONDS (testé).
CinematicKit.PLANS = {
	reveil_cercueil = {
		sound = nil,
		shots = {
			{
				t = 2.5,
				path = "travelling",
				from = { 0, 0.4, 0.2 },
				to = { 0, 1.1, 0 },
				look = { 0, 5, -4 },
				fov = { 52, 70 },
				ease = "Quint",
				blur = { 24, 8 },
			},
			{
				t = 2.5,
				path = "orbite",
				radius = 0.5,
				sweep = 120,
				look = { 0, 1.2, 0 },
				fov = { 70, 70 },
				ease = "Sine",
				blur = { 8, 0 },
				height = 1.2,
			},
		},
	},
	apparition_monstre = {
		sound = "sting_monstre",
		ignoreDanger = true, -- c'est l'apparition elle-même : le monstre est proche par définition
		shots = {
			{
				t = 3,
				path = "travelling",
				from = { 0, 0.2, 0 },
				to = { 0, 0.5, 3 },
				look = { 0, 0.5, -6 },
				focus = true,
				fov = { 50, 85 },
				ease = "Quad",
				shake = 0.12,
			},
			{
				t = 2,
				path = "dolly",
				from = { 0, 0.5, 3 },
				to = { 0, 0.5, 1.5 },
				look = { 0, 0.5, -6 },
				focus = true,
				fov = { 85, 45 },
				ease = "Back",
				shake = 0.2,
			},
		},
	},
	objet_precieux = {
		sound = "cle_ramassee",
		vfx = { name = "pilier_revelation", theme = "or_" },
		shots = {
			{
				t = 2.5,
				path = "orbite",
				radius = 1.8,
				sweep = -80,
				look = { 0, 0, 0 },
				fov = { 45, 40 },
				ease = "Sine",
				height = 0.6,
				tint = { 255, 235, 190 },
			},
			{
				t = 1.5,
				path = "dolly",
				from = { 1, 0.6, 1.4 },
				to = { 0.6, 0.4, 0.8 },
				look = { 0, 0, 0 },
				fov = { 40, 30 },
				ease = "Quint",
			},
		},
	},
	porte_ouvre = {
		sound = "grincement_porte",
		shots = {
			{
				t = 2.5,
				path = "travelling",
				from = { -6, 3, 8 },
				to = { -4, 3, 6 },
				look = { 0, 1.5, 0 },
				fov = { 62, 58 },
				ease = "Sine",
			},
			{
				t = 1.5,
				path = "dolly",
				from = { -4, 3, 6 },
				to = { -2.5, 2.5, 3.5 },
				look = { 0, 1.5, 0 },
				fov = { 58, 48 },
				ease = "Quad",
			},
		},
	},
	sortie_soussol = {
		sound = nil,
		shots = {
			{
				t = 3,
				path = "plongee",
				from = { 0, 2, 6 },
				to = { 0, 14, 16 },
				look = { 0, 3, 0 },
				fov = { 60, 70 },
				ease = "Quint",
			},
			{
				t = 4,
				path = "plongee",
				from = { 0, 14, 16 },
				to = { 0, 34, 26 },
				look = { 0, 0, 0 },
				fov = { 70, 78 },
				ease = "Sine",
				tint = { 255, 244, 220 },
			},
		},
	},
	enfant_retrouve = {
		sound = "chuchotement",
		vfx = { name = "aura_ailes", theme = "pale" },
		shots = {
			{
				t = 3,
				path = "orbite",
				radius = 3.2,
				sweep = 100,
				look = { 0, 1.2, 0 },
				fov = { 50, 46 },
				ease = "Sine",
				height = 1.6,
			},
			{
				t = 2,
				path = "dolly",
				from = { 2, 1.8, 3 },
				to = { 1, 1.5, 2 },
				look = { 0, 1.2, 0 },
				fov = { 46, 36 },
				ease = "Quint",
			},
		},
	},
	fuite_finale = {
		sound = "sting_monstre",
		shots = {
			{
				t = 3,
				path = "travelling",
				from = { 0, 1.8, -7 },
				to = { 0, 2.2, -2 },
				look = { 0, 1.5, 4 },
				fov = { 72, 82 },
				ease = "Quad",
				shake = 0.08,
			},
			{
				t = 3,
				path = "plongee",
				from = { 0, 4, 8 },
				to = { 0, 22, 18 },
				look = { 0, 2, 0 },
				fov = { 70, 76 },
				ease = "Sine",
				title = "Tu es sorti.",
			},
			{
				t = 2,
				path = "dolly",
				from = { 0, 22, 18 },
				to = { 0, 24, 22 },
				look = { 0, 2, 0 },
				fov = { 76, 60 },
				ease = "Quint",
				title = "Sortir Du Grenier",
				tint = { 220, 235, 255 },
			},
		},
	},
}

-- Durée totale d'une liste de prises
function CinematicKit.total(shots)
	local sum = 0
	for _, shot in ipairs(shots) do
		sum += shot.t
	end
	return sum
end

-- Plan tronqué à `limit` secondes (MAX_SECONDS par défaut) : la dernière prise est raccourcie
function CinematicKit.clamp(shots, limit)
	limit = math.min(limit or CinematicKit.MAX_SECONDS, CinematicKit.MAX_SECONDS)
	local out, used = {}, 0
	for _, shot in ipairs(shots) do
		if used >= limit then
			break
		end
		local copy = {}
		for k, v in pairs(shot) do
			copy[k] = v
		end
		copy.t = math.min(shot.t, limit - used)
		used += copy.t
		table.insert(out, copy)
	end
	return out
end

-- Erreurs de définition d'un plan (liste vide = valide)
function CinematicKit.validate(plan)
	local errors = {}
	if type(plan) ~= "table" or type(plan.shots) ~= "table" or #plan.shots == 0 then
		return { "aucune prise" }
	end
	for i, shot in ipairs(plan.shots) do
		if type(shot.t) ~= "number" or shot.t <= 0 then
			table.insert(errors, ("prise %d : durée invalide"):format(i))
		end
		if shot.ease and not CinematicKit.EASINGS[shot.ease] then
			table.insert(errors, ("prise %d : easing inconnu"):format(i))
		end
		if not shot.look then
			table.insert(errors, ("prise %d : sans cible"):format(i))
		end
	end
	if CinematicKit.total(plan.shots) > CinematicKit.MAX_SECONDS + 1e-9 then
		table.insert(errors, "durée totale supérieure à 8 s")
	end
	return errors
end

-- Aucune cinématique si le joueur est en danger : poursuite, monstre proche, mort, caché, ou autre cinématique.
function CinematicKit.allowed(state)
	if type(state) ~= "table" then
		return false
	end
	if state.chasing or state.hidden or state.busy then
		return false
	end
	if type(state.health) == "number" and state.health <= 0 then
		return false
	end
	if type(state.monsterDistance) == "number" and state.monsterDistance < (state.safeDistance or 25) then
		return false
	end
	return true
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerp3(a, b, t)
	return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) }
end

-- Position de la caméra, point regardé et champ de vision à l'instant `alpha` (0..1) d'une prise.
-- anchor, focus : { x, y, z } ; focus (optionnel) est le point regardé quand shot.focus est vrai.
function CinematicKit.sample(shot, alpha, anchor, focus)
	local a = CinematicKit.ease(shot.ease or "Sine", clamp01(alpha))
	if shot.slow and shot.slow > 0 and shot.slow < 1 then
		a = a ^ (1 + (1 - shot.slow) * 2) -- ralenti : démarre doucement
	end
	local eyeOffset
	if shot.path == "orbite" then
		local angle = math.rad((shot.sweep or 90) * a)
		local r = shot.radius or 3
		eyeOffset = { math.sin(angle) * r, shot.height or 1, math.cos(angle) * r }
	else
		eyeOffset = lerp3(shot.from or { 0, 1, 3 }, shot.to or shot.from or { 0, 1, 3 }, a)
	end
	local look = shot.look or { 0, 0, 0 }
	local base = (shot.focus and focus) or anchor
	local lookAt = { base[1] + look[1], base[2] + look[2], base[3] + look[3] }
	if shot.focus and focus then
		lookAt = { focus[1], focus[2] + look[2], focus[3] }
	end
	local fov = shot.fov and lerp(shot.fov[1], shot.fov[2], a) or 70
	return { anchor[1] + eyeOffset[1], anchor[2] + eyeOffset[2], anchor[3] + eyeOffset[3] }, lookAt, fov
end

-- Prise en cours au temps `elapsed` : index, alpha. nil une fois le plan fini.
function CinematicKit.locate(shots, elapsed)
	if elapsed < 0 then
		return nil
	end
	local start = 0
	for i, shot in ipairs(shots) do
		if elapsed < start + shot.t then
			return i, (elapsed - start) / shot.t
		end
		start += shot.t
	end
	return nil
end

-- Exécution (client) -------------------------------------------------------------------------------------------------

local current = nil

function CinematicKit.isPlaying()
	return current ~= nil
end

-- Termine immédiatement la cinématique en cours (bouton Passer, touche, nouvelle cinématique prioritaire)
function CinematicKit.skip()
	if current then
		current.finish("passée")
		return true
	end
	return false
end

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

-- ctx : { gui, anchor = Vector3 | function, focus = Vector3 | function, state = function -> table (voir allowed),
--         onDone = function, vfx = function(name, origin, theme), audio = function(key) }
-- Retourne true si la cinématique démarre. Toute erreur est absorbée : la caméra revient au personnage.
function CinematicKit.run(planName, ctx)
	local plan = CinematicKit.PLANS[planName]
	ctx = ctx or {}
	if not plan or current then
		return false
	end
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Lighting = game:GetService("Lighting")
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	if not (player and camera and ctx.gui) then
		return false
	end
	local state = ctx.state and ctx.state() or {}
	if plan.ignoreDanger then
		state = { busy = state.busy, health = state.health }
	end
	if not CinematicKit.allowed(state) then
		return false
	end
	local shots = CinematicKit.clamp(plan.shots)
	local total = CinematicKit.total(shots)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local saved = { fov = camera.FieldOfView, type = camera.CameraType, subject = camera.CameraSubject }
	local temp = {}
	local connections = {}
	local token = { finished = false }
	current = token

	local function resolve(v)
		if typeof(v) == "function" then
			return v()
		end
		return v
	end
	local anchorPos = resolve(ctx.anchor)
	if typeof(anchorPos) ~= "Vector3" then
		local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
		anchorPos = head and head.Position or Vector3.new(0, 5, 0)
	end
	local anchor = { anchorPos.X, anchorPos.Y, anchorPos.Z }

	-- Restauration : appelée une seule fois, quoi qu'il arrive
	local function finish(reason)
		if token.finished then
			return
		end
		token.finished = true
		for _, c in ipairs(connections) do
			pcall(function()
				c:Disconnect()
			end)
		end
		pcall(function()
			camera.CameraType = saved.type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.type
			camera.FieldOfView = saved.fov
			local nowChar = player.Character
			local nowHum = nowChar and nowChar:FindFirstChildOfClass("Humanoid")
			camera.CameraSubject = nowHum or saved.subject
		end)
		pcall(function()
			local nowChar = player.Character
			local nowHum = nowChar and nowChar:FindFirstChildOfClass("Humanoid")
			if nowHum then
				nowHum.PlatformStand = false
			end
		end)
		for _, inst in ipairs(temp) do
			pcall(function()
				inst:Destroy()
			end)
		end
		current = nil
		if ctx.onDone then
			pcall(ctx.onDone, reason)
		end
	end
	token.finish = finish

	local ok, err = pcall(function()
		-- Barres noires, titre, bouton « Passer »
		local function frame(name, size, position)
			local f = Instance.new("Frame")
			f.Name = name
			f.Size = size
			f.Position = position
			f.BackgroundColor3 = Color3.new(0, 0, 0)
			f.BorderSizePixel = 0
			f.ZIndex = 60
			f.Parent = ctx.gui
			table.insert(temp, f)
			return f
		end
		frame("BarreHaut", UDim2.new(1, 0, 0.1, 0), UDim2.new(0, 0, 0, 0))
		frame("BarreBas", UDim2.new(1, 0, 0.1, 0), UDim2.new(0, 0, 0.9, 0))
		local title = Instance.new("TextLabel")
		title.Name = "TitreCinematique"
		title.AnchorPoint = Vector2.new(0.5, 0.5)
		title.Position = UDim2.fromScale(0.5, 0.5)
		title.Size = UDim2.new(0.8, 0, 0, 60)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(235, 228, 205)
		title.TextStrokeTransparency = 0.4
		title.Font = Enum.Font.GothamBold
		title.TextSize = 36
		title.Text = ""
		title.ZIndex = 62
		title.Parent = ctx.gui
		table.insert(temp, title)
		local skipButton = Instance.new("TextButton")
		skipButton.Name = "PasserCinematique"
		skipButton.AnchorPoint = Vector2.new(1, 1)
		skipButton.Position = UDim2.new(1, -16, 1, -16)
		skipButton.Size = UDim2.fromOffset(120, 44)
		skipButton.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
		skipButton.BackgroundTransparency = 0.3
		skipButton.TextColor3 = Color3.fromRGB(230, 220, 190)
		skipButton.Font = Enum.Font.GothamMedium
		skipButton.TextSize = 18
		skipButton.Text = "Passer"
		skipButton.ZIndex = 70
		skipButton.Parent = ctx.gui
		table.insert(temp, skipButton)
		table.insert(
			connections,
			skipButton.Activated:Connect(function()
				finish("passée")
			end)
		)
		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input)
				local code = input.KeyCode
				if code == Enum.KeyCode.Space or code == Enum.KeyCode.Escape or code == Enum.KeyCode.Return then
					finish("passée")
				end
			end)
		)

		-- Effets d'image temporaires (flou, teinte) : détruits avec le reste
		local blur, tint = nil, nil
		for _, shot in ipairs(shots) do
			if shot.blur and not blur then
				blur = Instance.new("BlurEffect")
				blur.Size = 0
				blur.Parent = Lighting
				table.insert(temp, blur)
			end
			if shot.tint and not tint then
				tint = Instance.new("ColorCorrectionEffect")
				tint.Parent = Lighting
				table.insert(temp, tint)
			end
		end

		if humanoid then
			humanoid.PlatformStand = true
			table.insert(
				connections,
				humanoid.Died:Connect(function()
					finish("mort")
				end)
			)
		end
		table.insert(
			connections,
			player.CharacterRemoving:Connect(function()
				finish("personnage retiré")
			end)
		)
		camera.CameraType = Enum.CameraType.Scriptable
		if plan.sound and ctx.audio then
			pcall(ctx.audio, plan.sound)
		end
		if plan.vfx and ctx.vfx then
			pcall(ctx.vfx, plan.vfx.name, anchorPos, plan.vfx.theme)
		end

		local elapsed = 0
		local lastTitle = nil
		table.insert(
			connections,
			RunService.RenderStepped:Connect(function(dt)
				local okFrame, errFrame = pcall(function()
					if token.finished then
						return
					end
					elapsed += dt
					local index, alpha = CinematicKit.locate(shots, elapsed)
					if not index then
						finish("terminée")
						return
					end
					local shot = shots[index]
					local focus = resolve(ctx.focus)
					local focusT = typeof(focus) == "Vector3" and { focus.X, focus.Y, focus.Z } or nil
					local eye, look, fov = CinematicKit.sample(shot, alpha, anchor, focusT)
					local cf = CFrame.lookAt(v3(eye), v3(look))
					if shot.shake then
						local amp = shot.shake
						cf = cf * CFrame.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0)
					end
					camera.CFrame = cf
					camera.FieldOfView = fov
					if blur and shot.blur then
						blur.Size = shot.blur[1] + (shot.blur[2] - shot.blur[1]) * alpha
					end
					if tint and shot.tint then
						tint.TintColor = Color3.fromRGB(shot.tint[1], shot.tint[2], shot.tint[3])
					end
					local text = shot.title or ""
					if text ~= lastTitle then
						lastTitle = text
						title.Text = text
					end
				end)
				if not okFrame then
					warn("[Cinematic] plan " .. planName .. " : " .. tostring(errFrame))
					finish("erreur")
				end
			end)
		)
		-- Garde-fou : même si l'image ne se met plus à jour, la cinématique se termine
		task.delay(total + 0.5, function()
			finish("délai")
		end)
	end)
	if not ok then
		warn("[Cinematic] plan " .. planName .. " : " .. tostring(err))
		finish("erreur")
		return false
	end
	return true
end

return CinematicKit
