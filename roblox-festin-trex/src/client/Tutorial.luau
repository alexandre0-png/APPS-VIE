--!nonstrict
-- Mini tutoriel interactif (premier lancement) : lancer, viser, récolter. Jamais bloquant : simple encart avec
-- bouton « Passer », flèche au-dessus de la bouche du T-Rex à l'étape « viser », pcall partout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TutorialLogic = require(Shared:WaitForChild("TutorialLogic"))

local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local Tutorial = {}

local STEPS = {
	{ title = "1/3 — LANCER", text = "Clique (ou touche l'écran / bouton LANCER) pour lancer la nourriture de ton panier." },
	{ title = "2/3 — VISER", text = "Vise la BOUCHE du T-Rex (la flèche te la montre). Plus tu enchaînes, plus ton combo grimpe !" },
	{ title = "3/3 — RÉCOLTER", text = "Panier presque vide ? Suis le rayon doré jusqu'à un stand et touche E (ou le bouton) pour le remplir." },
}

local logic = TutorialLogic.new()
local gui: ScreenGui? = nil
local title: TextLabel? = nil
local body: TextLabel? = nil
local arrow: BillboardGui? = nil
local started = false

local function close()
	if gui then
		gui:Destroy()
		gui = nil
	end
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
end

local function finish(markSeen: boolean)
	close()
	if markSeen then
		task.spawn(function()
			Store.request("cinematicSeen", { id = "tutorial" })
		end)
	end
end

local function showArrow(on: boolean)
	if not on then
		if arrow then
			arrow:Destroy()
			arrow = nil
		end
		return
	end
	if arrow then
		return
	end
	local dino = workspace:FindFirstChild("Dino")
	local mouth = dino and dino:FindFirstChild("MouthZone")
	if not mouth then
		return
	end
	arrow = Instance.new("BillboardGui")
	arrow.Adornee = mouth
	arrow.Size = UDim2.fromOffset(160, 70)
	arrow.StudsOffset = Vector3.new(0, 7, 0)
	arrow.AlwaysOnTop = true
	arrow.MaxDistance = 400
	UIKit.label(arrow, { Size = UDim2.fromScale(1, 1), Text = "⬇ VISE ICI", TextSize = 30, Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 210, 60), TextStrokeTransparency = 0 })
	arrow.Parent = mouth
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "FestinTutorial"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local f = UIKit.frame(gui, { Position = UDim2.new(0, 12, 0, 150), Size = UDim2.fromOffset(300, 150), BackgroundTransparency = 0.1 })
	UIKit.corner(f, 14)
	UIKit.gradient(f)
	UIKit.stroke(f, UIKit.Colors.gold, 3)
	title = UIKit.label(f, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Text = "", TextSize = 20, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.gold })
	body = UIKit.label(f, { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 78), Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	UIKit.button(f, {
		Position = UDim2.new(1, -150, 1, -36),
		Size = UDim2.fromOffset(140, 30),
		Text = "Passer le tutoriel",
		TextSize = 14,
		BackgroundColor3 = Color3.fromRGB(70, 72, 90),
		Callback = function()
			logic:skip()
			finish(true)
		end,
	})
end

local function onState(s: any)
	if not started or logic:isDone() then
		return
	end
	local ok = pcall(function()
		local step = logic:update({ ammo = s.ammo, totalFed = s.totalFed })
		if step >= TutorialLogic.DONE then
			finish(true)
			return
		end
		local info = STEPS[step]
		if title and body then
			title.Text = info.title
			body.Text = info.text
		end
		showArrow(step == 2)
	end)
	if not ok then
		logic:skip()
		pcall(close)
	end
end

function Tutorial.init()
	if not (Config.Cinematics.Enabled and Config.Cinematics.Flags.tutorial) then
		return
	end
	Store.onChange(function(s)
		if not started then
			-- Une seule fois par joueur (mémorisé côté serveur).
			if s.seen and s.seen.tutorial then
				return
			end
			started = true
			-- Laisse l'introduction se jouer d'abord ; l'encart n'est pas bloquant.
			task.delay(Config.Cinematics.TutorialDelay, function()
				pcall(build)
				onState(Store.state or s)
			end)
			return
		end
		onState(s)
	end)
end

return Tutorial
