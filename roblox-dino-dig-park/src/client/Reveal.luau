-- Reveal.luau : animation d'éclosion (œuf qui tremble -> flash -> dino en rotation avec sa rareté).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Economy = require(Shared.Economy)

local Ui = require(script.Parent.Ui)

local Reveal = {}
local C = Ui.colors

local queue = {}
local playing = false
local overlay

local function build()
	overlay = Ui.new("Frame", { Name = "RevealOverlay", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, Visible = false, ZIndex = 50, Active = true, Parent = Ui.root })
end

local function play(item)
	playing = true
	for _, c in ipairs(overlay:GetChildren()) do
		c:Destroy()
	end
	overlay.Visible = true
	Ui.closePanels()

	local id, golden = Economy.parseKey(item.key)
	local def = Config.DinoById[id]
	local rar = Config.RarityById[def.rarity]
	local egg = Config.Eggs[item.egg] or Config.Eggs.basic

	-- 1. œuf qui tremble
	local eggFrame = Ui.new("Frame", { Size = UDim2.fromOffset(150, 200), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = egg.color, ZIndex = 51, Parent = overlay })
	Ui.corner(eggFrame, 75)
	Ui.stroke(eggFrame, egg.spot, 5)
	for i = 1, 5 do
		local s = Ui.new("Frame", { Size = UDim2.fromOffset(22 + i * 3, 22 + i * 3), Position = UDim2.fromScale(0.15 + (i * 0.37) % 0.6, 0.15 + (i * 0.23) % 0.65), BackgroundColor3 = egg.spot, ZIndex = 52, Parent = eggFrame })
		Ui.corner(s, 20)
	end
	Ui.playSound("click", 0.5)
	local t0 = os.clock()
	local dur = 1.5
	while os.clock() - t0 < dur do
		local a = (os.clock() - t0) / dur
		eggFrame.Rotation = math.sin(os.clock() * (10 + a * 30)) * (6 + a * 14)
		eggFrame.Size = UDim2.fromOffset(150 + a * 40, 200 + a * 50)
		RunService.RenderStepped:Wait()
	end
	eggFrame:Destroy()

	-- 2. flash
	local flash = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 60, Parent = overlay })
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	local order = rar.order
	Ui.playSound("hatch", 0.5 + order * 0.07, 0.8 + order * 0.07)
	if order >= 5 then
		task.delay(0.35, function()
			Ui.playSound("buy", 0.8, 1.4)
		end)
	end

	-- 3. révélation
	local rays = {}
	for i = 1, 2 do
		local r = Ui.new("Frame", { Size = UDim2.fromOffset(380, 380), Position = UDim2.fromScale(0.5, 0.44), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = i * 45, BackgroundColor3 = rar.color, BackgroundTransparency = 0.6, ZIndex = 51, Parent = overlay })
		Ui.corner(r, 30)
		rays[i] = r
	end
	local vp, model = Ui.dinoViewport(overlay, item.key, { size = UDim2.fromOffset(440, 330), pos = UDim2.fromScale(0.5, 0.44), z = 53 })
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	local nameText = def.name
	if golden then
		nameText = "✨ " .. nameText .. " DORÉ ✨"
	end
	Ui.label(overlay, { text = nameText, size = 44, color = rar.color, sizeUdim = UDim2.fromOffset(640, 56), pos = UDim2.fromScale(0.5, 0.72), anchor = Vector2.new(0.5, 0.5), stroke = true, z = 55, name = "Name" })
	Ui.label(overlay, { text = rar.name:upper() .. "   •   💰 " .. Util.formatNumber(Economy.dinoIncome(item.key)) .. "/s", size = 24, sizeUdim = UDim2.fromOffset(640, 34), pos = UDim2.fromScale(0.5, 0.78), anchor = Vector2.new(0.5, 0.5), stroke = true, z = 55 })
	if item.new then
		Ui.label(overlay, { text = "NOUVEAU DINO !", size = 28, color = C.gold, sizeUdim = UDim2.fromOffset(400, 40), pos = UDim2.fromScale(0.5, 0.2), anchor = Vector2.new(0.5, 0.5), stroke = true, z = 55 })
	end
	local done = false
	local ok = Ui.button(overlay, { text = "Super !", size = UDim2.fromOffset(220, 56), pos = UDim2.fromScale(0.5, 0.88), anchor = Vector2.new(0.5, 0.5), color = C.green, z = 56, textSize = 26, onClick = function()
		done = true
	end })

	-- apparition + rotation
	vp.Size = UDim2.fromOffset(10, 8)
	TweenService:Create(vp, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(440, 330) }):Play()
	local conn = RunService.RenderStepped:Connect(function(dt)
		for i, r in ipairs(rays) do
			r.Rotation = r.Rotation + dt * (i == 1 and 25 or -18)
		end
		if model then
			local center = vp:GetAttribute("Center")
			if center then
				model:PivotTo(CFrame.new(center) * CFrame.Angles(0, os.clock() * 1.1, 0) * CFrame.new(-center))
			end
		end
	end)
	while not done and overlay.Visible do
		RunService.RenderStepped:Wait()
	end
	conn:Disconnect()
	overlay.Visible = false
	playing = false
end

function Reveal.show(key, isNew, eggId)
	table.insert(queue, { key = key, new = isNew, egg = eggId })
	if playing then
		return
	end
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1)
			play(item)
		end
	end)
end

function Reveal.build()
	build()
end

return Reveal
