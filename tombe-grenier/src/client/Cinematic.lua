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

local Cinematic = {}

local SHOTS = {
	-- Réveil dans le cercueil : on fixe le couvercle, puis on se redresse et on regarde le grenier
	intro = {
		fadeIn = true,
		plans = {
			{ from = { 90, 25.4, 45 }, look = { 90, 34, 45 }, t = 3 },
			{ from = { 90, 26.3, 45 }, look = { 78, 25.5, 26 }, t = 3.5 },
			{ from = { 88, 26.8, 30 }, look = { 60, 26, 12 }, t = 3 },
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
	-- Fin 3, la vérité : la lumière monte du cercueil vers le ciel
	truth = {
		plans = {
			{ from = { 90, 26, 45 }, look = { 90, 30, 44 }, t = 3 },
			{ from = { 90, 60, 45 }, look = { 90, 90, 45 }, t = 4 },
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

-- Joue une cinématique. onDone est appelé à la fin (ou au passage).
function Cinematic.play(name, gui, onDone)
	local spec = SHOTS[name]
	if not spec then
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

	local skip = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Escape then
			token.done = true
			if token.tween then
				token.tween:Cancel()
			end
		end
	end)

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
		if onDone then
			onDone()
		end
	end)
end

function Cinematic.isPlaying()
	return current ~= nil and not current.done
end

return Cinematic
