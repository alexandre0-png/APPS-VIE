--[[
  Cinematic : cinématiques par mouvements de caméra (sans texte, sans contrôle du joueur).
  Chaque plan : { from = position, look = point regardé, t = durée en secondes }.
  Une position peut être une fonction (ex. la tête du joueur ou le monstre, au moment du plan).
  Barres noires en haut et en bas. Espace ou Échap passe la cinématique.
  Le serveur déclenche les cinématiques par l'effet « Cine » (voir init.server).
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Timeline = require(Shared.CinematicTimeline)

local Cinematic = {}

-- Séquences longues (30 à 60 s) : chacune peut être passée (Espace, Échap, bouton « Passer »).
-- next : cinématique jouée ensuite (chaînage). Les plans de documents sont des gros plans fixes.
local SHOTS = {
	-- Arrivée devant la maison, de nuit : la route, la porte, puis l'entrée
	arrival = {
		next = "intro",
		fadeIn = true,
		plans = {
			{ from = { 60, 7, 215 }, look = { 60, 6, 150 }, t = 10 },
			{ from = { 72, 6, 172 }, look = { 60, 5, 128 }, t = 10 },
			{ from = { 54, 9, 140 }, look = { 60, 8, 92 }, t = 8 },
			{ from = { 60, 20, 70 }, look = { 60, 12, 40 }, t = 6 },
		},
	},
	-- Réveil dans le cercueil, dans le grenier : on fixe le couvercle, on regarde le grenier,
	-- puis les objets de la pièce (plaque, malle, trappe, miroir)
	intro = {
		fadeIn = true,
		plans = {
			{ from = { 90, 25.4, 45 }, look = { 90, 34, 45 }, t = 3 },
			{ from = { 90, 26.3, 45 }, look = { 78, 25.5, 26 }, t = 3.5 },
			{ from = { 88, 26.8, 30 }, look = { 60, 26, 12 }, t = 3 },
			{ from = { 90, 27, 36 }, look = { 90, 26.1, 42.5 }, t = 6 },
			{ from = { 70, 26, 58 }, look = { 70, 27, 62 }, t = 6 },
			{ from = { 54, 26, 14 }, look = { 54, 25.5, 9.5 }, t = 6 },
			{ from = { 100, 27, 60 }, look = { 119, 31, 30 }, t = 6 },
		},
	},
	-- Première apparition : la caméra du joueur tremble, face au monstre
	apparition = {
		plans = {
			{
				from = function()
					local char = Players.LocalPlayer.Character
					local head = char and char:FindFirstChild("Head")
					return head and head.Position or Vector3.new(60, 26, 40)
				end,
				look = function()
					local monster = workspace:FindFirstChild("Monster")
					local root = monster and monster:FindFirstChild("HumanoidRootPart")
					return root and root.Position or Vector3.new(30, 26, 40)
				end,
				t = 2.5,
				shake = true,
			},
		},
	},
	-- Courant rétabli : la caméra balaie le rez-de-chaussée pendant que les lampes s'allument
	courant = {
		plans = {
			{ from = { 60, 6, 20 }, look = { 60, 8, 42 }, t = 3 },
			{ from = { 30, 8, 70 }, look = { 30, 6, 22 }, t = 3 },
		},
	},
	-- Fin 1, la fuite : on quitte la maison, le jour se lève sur le grenier
	win = {
		plans = {
			{ from = { 60, 8, 165 }, look = { 60, 20, 60 }, t = 4 },
			{ from = { 105, 22, 170 }, look = { 60, 30, 30 }, t = 4 },
		},
	},
	-- Dans le jardin : on se retourne vers la porte, le monstre cogne et sort de la maison
	jardin = {
		plans = {
			{ from = { 60, 5, 128 }, look = { 60, 4, 90 }, t = 3 },
			{
				from = { 66, 4, 116 },
				look = function()
					local monster = workspace:FindFirstChild("Monster")
					local root = monster and monster:FindFirstChild("HumanoidRootPart")
					return root and root.Position or Vector3.new(60, 4, 90)
				end,
				t = 2.5,
				shake = true,
			},
		},
	},
	-- Fuite en voiture : on monte à bord au bout de l'allée, le monstre suit de loin
	voiture = {
		plans = {
			{ from = { 60, 6, 150 }, look = { 60, 3, 178 }, t = 4 },
			{
				from = { 66, 5, 200 },
				look = function()
					local monster = workspace:FindFirstChild("Monster")
					local root = monster and monster:FindFirstChild("HumanoidRootPart")
					return root and root.Position or Vector3.new(60, 3, 165)
				end,
				t = 6,
			},
		},
	},
	-- Le monstre descend l'escalier du sous-sol : la caméra le suit depuis le haut
	descente = {
		plans = {
			{
				from = { 103, 3, 112 },
				look = function()
					local monster = workspace:FindFirstChild("Monster")
					local root = monster and monster:FindFirstChild("HumanoidRootPart")
					return root and root.Position or Vector3.new(103, -6, 96)
				end,
				t = 6,
				shake = true,
			},
			{ from = { 100, -4, 84 }, look = { 103, -10, 84 }, t = 8 },
			{ from = { 112, -2, 70 }, look = { 103, -6, 90 }, t = 8 },
			{ from = { 80, -2, 50 }, look = { 90, -6, 90 }, t = 8 },
		},
	},
	-- Fin 3, la vérité : la lumière monte du cercueil vers le ciel
	truth = {
		plans = {
			{ from = { 90, 26, 45 }, look = { 90, 30, 44 }, t = 3 },
			{ from = { 90, 60, 45 }, look = { 90, 90, 45 }, t = 4 },
			{ from = { 90, 40, 45 }, look = { 90, 60, 45 }, t = 8 },
			{ from = { 60, 95, -20 }, look = { 60, 60, 45 }, t = 10 },
			{ from = { 60, 140, -60 }, look = { 60, 80, 45 }, t = 8 },
		},
	},
	-- Fin 4, le piège : l'enfant reste dans le cercueil, le couvercle se referme
	sealed = {
		fadeOut = true,
		plans = {
			{ from = { 90, 25.5, 45 }, look = { 90, 26, 43 }, t = 8 },
			{ from = { 90, 28, 36 }, look = { 90, 26.1, 42.5 }, t = 8 },
			{ from = { 90, 25.6, 45 }, look = { 90, 25.4, 44 }, t = 8 },
			{ from = { 90, 27, 36 }, look = { 90, 26, 42.5 }, t = 8 },
		},
	},
	-- Fin 2, la malédiction : le couvercle se referme, puis la plaque gravée
	lose = {
		fadeOut = true,
		plans = {
			{ from = { 90, 25.5, 45 }, look = { 90, 34, 45 }, t = 2.5 },
			{ from = { 90, 27, 36 }, look = { 90, 26, 42.5 }, t = 3 },
		},
	},
}

local current = nil

-- Réglage par cinématique (Config.Cinematics). Une cinématique désactivée est simplement sautée.
local FLAG = {
	arrival = "Arrival",
	intro = "Intro",
	descente = "Descent",
	sealed = "Sealed",
	truth = "Truth",
}

local function enabledShot(name)
	local cfg = Config.Cinematics
	if not cfg or cfg.Enabled ~= true then
		return false
	end
	local flag = FLAG[name]
	return flag == nil or cfg[flag] == true
end

-- Pendant une cinématique, le joueur ne bouge pas (caméra et personnage restent cohérents)
local function setFrozen(on)
	pcall(function()
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = on
		end
	end)
end

local function resolve(v)
	if typeof(v) == "function" then
		return v()
	end
	return Vector3.new(v[1], v[2], v[3])
end

local function makeBars(gui)
	local top = Instance.new("Frame")
	top.Size = UDim2.new(1, 0, 0.12, 0)
	top.Position = UDim2.new(0, 0, -0.12, 0)
	top.BackgroundColor3 = Color3.new(0, 0, 0)
	top.BorderSizePixel = 0
	top.ZIndex = 60
	top.Parent = gui
	local bottom = Instance.new("Frame")
	bottom.Size = UDim2.new(1, 0, 0.12, 0)
	bottom.Position = UDim2.new(0, 0, 1, 0)
	bottom.BackgroundColor3 = Color3.new(0, 0, 0)
	bottom.BorderSizePixel = 0
	bottom.ZIndex = 60
	bottom.Parent = gui
	local cover = Instance.new("Frame")
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.ZIndex = 59
	cover.Parent = gui
	return top, bottom, cover
end

-- Joue une cinématique. onDone est appelé à la fin (ou au passage), après la suite chaînée.
function Cinematic.play(name, gui, onDone)
	local spec = SHOTS[name]
	if not spec or not enabledShot(name) then
		-- Désactivée : on enchaîne directement avec la suite éventuelle
		if spec and spec.next then
			return Cinematic.play(spec.next, gui, onDone)
		end
		if onDone then
			onDone()
		end
		return
	end
	local okTotal, total = pcall(Timeline.total, spec.plans)
	if not okTotal then
		warn("[Cinematic] durée illisible pour " .. name)
		if onDone then
			onDone()
		end
		return
	end
	if current then
		current.done = true
		if current.tween then
			current.tween:Cancel()
		end
	end

	local cam = workspace.CurrentCamera
	local token = { done = false, tween = nil }
	current = token

	local top, bottom, cover = makeBars(gui)
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Sine)
	TweenService:Create(top, info, { Position = UDim2.new(0, 0, 0, 0) }):Play()
	TweenService:Create(bottom, info, { Position = UDim2.new(0, 0, 0.88, 0) }):Play()
	if spec.fadeIn then
		cover.BackgroundTransparency = 0
	end

	local function passShot()
		token.done = true
		if token.tween then
			token.tween:Cancel()
		end
	end

	local skip = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Escape then
			passShot()
		end
	end)

	-- Bouton « Passer », visible pendant toute la séquence (utile sur téléphone)
	local passButton = nil
	pcall(function()
		passButton = Instance.new("TextButton")
		passButton.Name = "PasserCinematique"
		passButton.Size = UDim2.fromOffset(120, 36)
		passButton.Position = UDim2.new(1, -20, 1, -20)
		passButton.AnchorPoint = Vector2.new(1, 1)
		passButton.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
		passButton.BackgroundTransparency = 0.3
		passButton.TextColor3 = Color3.fromRGB(230, 220, 190)
		passButton.Font = Enum.Font.GothamMedium
		passButton.TextSize = 16
		passButton.Text = "Passer"
		passButton.ZIndex = 70
		passButton.Visible = Config.Cinematics.SkipButton == true
		passButton.Parent = gui
		passButton.Activated:Connect(passShot)
	end)
	setFrozen(true)

	cam.CameraType = Enum.CameraType.Scriptable
	local firstLook = nil

	task.spawn(function()
		for _, plan in ipairs(spec.plans) do
			if token.done then
				break
			end
			local from = resolve(plan.from)
			local look = resolve(plan.look)
			local target = CFrame.lookAt(from, look)
			if not firstLook then
				cam.CFrame = target
				firstLook = true
				if spec.fadeIn then
					TweenService:Create(cover, TweenInfo.new(plan.t * 0.6), { BackgroundTransparency = 1 }):Play()
				end
			end

			if plan.shake then
				local elapsed = 0
				while elapsed < plan.t and not token.done do
					local dt = RunService.RenderStepped:Wait()
					elapsed += dt
					local jitter = CFrame.new(
						(math.random() - 0.5) * 0.4,
						(math.random() - 0.5) * 0.4,
						0
					)
					cam.CFrame = target * jitter
				end
			else
				local tween = TweenService:Create(cam, TweenInfo.new(plan.t, Enum.EasingStyle.Sine), { CFrame = target })
				token.tween = tween
				tween:Play()
				-- Attente par surveillance (un tween annulé ne déclenche pas Completed)
				local started = os.clock()
				while os.clock() - started < plan.t and not token.done do
					task.wait()
				end
				if token.done then
					tween:Cancel()
				end
				token.tween = nil
			end
		end

		skip:Disconnect()
		if spec.fadeOut then
			TweenService:Create(cover, TweenInfo.new(1.5), { BackgroundTransparency = 0 }):Play()
			task.wait(1.6)
		end
		TweenService:Create(top, info, { Position = UDim2.new(0, 0, -0.12, 0) }):Play()
		TweenService:Create(bottom, info, { Position = UDim2.new(0, 0, 1, 0) }):Play()
		cam.CameraType = Enum.CameraType.Custom
		setFrozen(false)
		if passButton then
			passButton:Destroy()
		end
		task.wait(0.8)
		top:Destroy()
		bottom:Destroy()
		if not spec.fadeOut then
			cover:Destroy()
		else
			task.delay(2, function()
				cover:Destroy()
			end)
		end
		token.done = true
		if current == token then
			current = nil
		end
		if spec.next then
			Cinematic.play(spec.next, gui, onDone)
		elseif onDone then
			onDone()
		end
	end)
end

function Cinematic.isPlaying()
	return current ~= nil and not current.done
end

return Cinematic
