--[[
	Panels.lua : fenêtres modales (garage / concessionnaire, boutique Robux, profil + succès + classement,
	grande carte, récompense quotidienne). Raccourcis clavier : G, B, P, M.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Ids = require(Shared:WaitForChild("MonetizationIds"))

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local MapView = require(script.Parent.MapView)

local Panels = {}
local T = UI.Theme
local player = Players.LocalPlayer

local gui, window, titleLabel, content, current, bigMap
local rebuild

local function clear()
	for _, c in ipairs(content:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	if bigMap then
		bigMap = nil
	end
end

local function scroll(parent)
	local s = UI.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent,
	})
	UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s })
	UI.new("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = s })
	return s
end

local function bar(parent, label, value, max, color, y)
	UI.label({ Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(70, 14), Text = label, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
	local b = UI.new("Frame", { Position = UDim2.fromOffset(72, y + 2), Size = UDim2.fromOffset(120, 10), BackgroundColor3 = T.PanelLight, BorderSizePixel = 0, Parent = parent })
	UI.corner(b, 5)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(math.clamp(value / max, 0.04, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = b })
	UI.corner(fill, 5)
end

-- ====================================================================
-- Véhicules (garage et concessionnaire)
-- ====================================================================
local function vehiclePanel(mode)
	local list = scroll(content)
	local d = State.data
	if not d then
		return
	end
	for order, v in ipairs(Config.Vehicles) do
		local owned = d.Owned[v.id] == true
		local row = UI.panel({ Size = UDim2.new(1, 0, 0, 116), BackgroundColor3 = T.PanelLight, LayoutOrder = order, Parent = list })
		UI.label({ Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(240, 24), Text = v.name, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local info = UI.new("Frame", { Position = UDim2.fromOffset(12, 40), Size = UDim2.fromOffset(200, 50), BackgroundTransparency = 1, Parent = row })
		bar(info, "Vitesse", v.maxSpeed, 180, T.Bad, 0)
		bar(info, "Accélération", v.accel, 90, T.Accent, 16)
		bar(info, "Maniabilité", v.turn, 2.3, T.Info, 32)
		local color = (d.Colors and d.Colors[v.id] and Config.VehicleColors[d.Colors[v.id]]) or v.color
		UI.new("Frame", { Position = UDim2.fromOffset(12, 96), Size = UDim2.fromOffset(100, 4), BackgroundColor3 = color, BorderSizePixel = 0, Parent = row })

		local right = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(190, 100), BackgroundTransparency = 1, Parent = row })
		if owned and (mode == "garage" or v.price <= 0 or true) then
			UI.button({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(190, 38), Text = "SORTIR", BackgroundColor3 = T.Good, TextSize = 18, Parent = right }, function()
				State.send("RequestSpawn", v.id)
				Panels.close()
			end)
			local sw = UI.new("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.fromOffset(190, 44), BackgroundTransparency = 1, Parent = right })
			UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(20, 20), CellPadding = UDim2.fromOffset(4, 4), Parent = sw })
			for idx, c in ipairs(Config.VehicleColors) do
				UI.button({ Size = UDim2.fromOffset(20, 20), Text = "", BackgroundColor3 = c, Parent = sw }, function()
					State.send("RequestColor", v.id, idx)
				end)
			end
		else
			local text, enabled
			if v.gamepass then
				text, enabled = "Réservé VIP", false
			elseif d.Level < v.level then
				text, enabled = string.format("Niveau %d requis", v.level), false
			else
				text, enabled = "ACHETER  " .. Util.formatCash(v.price), d.Cash >= v.price
			end
			local b = UI.button({ Size = UDim2.fromOffset(190, 44), Text = text, TextSize = 15, BackgroundColor3 = enabled and T.Accent or Color3.fromRGB(70, 70, 80), TextColor3 = enabled and Color3.new(0, 0, 0) or T.Muted, Parent = right }, function()
				if enabled then
					State.send("RequestBuy", v.id)
				end
			end)
			UI.label({ Position = UDim2.fromOffset(0, 52), Size = UDim2.fromOffset(190, 40), Text = v.gamepass and "Achète le pass VIP dans la boutique" or (enabled and "" or string.format("Prix %s - niveau %d", Util.formatCash(v.price), v.level)), TextSize = 12, TextColor3 = T.Muted, TextWrapped = true, Parent = right })
			b.Active = enabled
		end
	end
end

-- ====================================================================
-- Boutique Robux
-- ====================================================================
local function shopPanel()
	local list = scroll(content)
	UI.label({ Size = UDim2.new(1, 0, 0, 24), Text = "Argent", TextSize = 20, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = list })
	for i, p in ipairs(Config.Products) do
		local id = Ids.Products[p.key] or 0
		local row = UI.panel({ Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = T.PanelLight, LayoutOrder = 1 + i, Parent = list })
		UI.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(260, 24), Text = p.name, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.label({ Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(260, 22), Text = p.desc, TextSize = 14, TextColor3 = T.Good, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 40), Text = id ~= 0 and ("R$ " .. p.robux) or "Bientôt", BackgroundColor3 = id ~= 0 and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(70, 70, 80), Parent = row }, function()
			if id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
	UI.label({ Size = UDim2.new(1, 0, 0, 24), Text = "Passes", TextSize = 20, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 10, Parent = list })
	for i, p in ipairs(Config.GamePasses) do
		local id = Ids.GamePasses[p.key] or 0
		local has = State.data and ((p.key == "VIP" and State.data.Vip) or (p.key == "BOOST" and State.data.Boost))
		local row = UI.panel({ Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = T.PanelLight, LayoutOrder = 10 + i, Parent = list })
		UI.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(300, 24), Text = p.name, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.label({ Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -150, 0, 36), Text = p.desc, TextSize = 13, TextColor3 = T.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
		UI.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 40), Text = has and "Possédé" or (id ~= 0 and ("R$ " .. p.robux) or "Bientôt"), BackgroundColor3 = has and T.Good or (id ~= 0 and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(70, 70, 80)), Parent = row }, function()
			if id ~= 0 and not has then
				MarketplaceService:PromptGamePassPurchase(player, id)
			end
		end)
	end
end

-- ====================================================================
-- Profil : statistiques, succès, classement
-- ====================================================================
local function profilePanel()
	local list = scroll(content)
	local d = State.data
	if not d then
		return
	end
	local function line(order, a, b)
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
		UI.label({ Size = UDim2.fromScale(0.6, 1), Text = a, TextSize = 16, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.4, 1), Text = b, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	end
	local s = d.Stats
	line(1, "Niveau", tostring(d.Level))
	line(2, "Argent", Util.formatCash(d.Cash))
	line(3, "Distance parcourue", string.format("%.1f km", s.km or 0))
	line(4, "Missions réussies", tostring(s.missions or 0))
	line(5, "Livraisons / Taxis / Courses", string.format("%d / %d / %d", s.deliveries or 0, s.taxis or 0, s.races or 0))
	line(6, "Braquages réussis", tostring(s.heists or 0))
	line(7, "Étoiles dorées", string.format("%d / %d", s.collected or 0, State.totalStars))
	line(8, "Arrestations", tostring(s.busted or 0))
	line(9, "Meilleure course", (s.bestRace or 0) > 0 and Util.formatTime(s.bestRace) or "-")
	UI.label({ Size = UDim2.new(1, 0, 0, 28), Text = "Succès", TextSize = 20, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 20, Parent = list })
	for i, a in ipairs(Config.Achievements) do
		local done = d.Achv and d.Achv[a.id]
		local row = UI.panel({ Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = done and Color3.fromRGB(36, 70, 50) or T.PanelLight, LayoutOrder = 20 + i, Parent = list })
		UI.label({ Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -120, 0, 22), Text = (done and "✔ " or "") .. a.name, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.label({ Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -120, 0, 20), Text = a.desc, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		UI.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 24), Text = "+" .. Util.formatCash(a.reward), TextSize = 14, TextColor3 = T.Good, Parent = row })
	end
	UI.label({ Size = UDim2.new(1, 0, 0, 28), Text = "Classement des fortunes", TextSize = 20, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 50, Parent = list })
	if #State.leaderboard == 0 then
		UI.label({ Size = UDim2.new(1, 0, 0, 24), Text = "Chargement du classement...", TextSize = 14, TextColor3 = T.Muted, LayoutOrder = 51, Parent = list })
	end
	for i, r in ipairs(State.leaderboard) do
		line(50 + i, string.format("%d. %s", i, r.name), Util.formatCash(r.cash))
	end
end

-- ====================================================================
-- Carte
-- ====================================================================
local function mapPanel()
	local size = window.AbsoluteSize
	local side = math.max(260, math.min(size.X - 40, size.Y - 90))
	local holder = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	bigMap = MapView.new(holder, Vector2.new(side, side), side / (Config.Map.GroundHalf * 2) * 1.0, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- carte centrée sur la ville, le marqueur est repositionné au joueur
	local scale = side / (Config.Map.GroundHalf * 2)
	bigMap:update(Vector3.zero, nil)
	if hrp then
		bigMap.me.Position = UDim2.fromOffset((hrp.Position.X + Config.Map.GroundHalf) * scale, (hrp.Position.Z + Config.Map.GroundHalf) * scale)
		bigMap.me.Parent = bigMap.canvas
		local look = workspace.CurrentCamera.CFrame.LookVector
		bigMap.me.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end
	bigMap.canvas.Position = UDim2.fromOffset(0, 0)
	local legend = UI.label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -2), Size = UDim2.new(1, -8, 0, 36), Text = "P Pizzeria · T Taxi · $ Banque · C Course · V Concession · S Pay'n'Spray · ! Police · H Planque", TextSize = 12, TextColor3 = T.Muted, TextWrapped = true, Parent = holder })
	legend.ZIndex = 20
end

-- ====================================================================
-- Quotidien
-- ====================================================================
local function dailyPanel()
	local d = State.data
	local box = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	UI.label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 40), Text = "Récompense quotidienne", TextSize = 28, TextColor3 = T.Accent, Parent = box })
	if not d then
		return
	end
	UI.label({ Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 30), Text = string.format("Série en cours : %d jour(s) (max %d)", d.DailyStreak, Config.Daily.MaxStreak), TextSize = 18, Parent = box })
	local row = UI.new("Frame", { Position = UDim2.new(0.5, 0, 0, 105), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(7 * 54, 50), BackgroundTransparency = 1, Parent = box })
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = row })
	for i = 1, Config.Daily.MaxStreak do
		local reached = i < d.DailyStreak or (i == d.DailyStreak and not d.DailyAvailable)
		local cell = UI.panel({ Size = UDim2.fromOffset(50, 50), BackgroundColor3 = reached and T.Good or T.PanelLight, Parent = row })
		UI.label({ Size = UDim2.fromScale(1, 1), Text = tostring(i), TextSize = 22, TextColor3 = reached and Color3.new(0, 0, 0) or T.Text, Parent = cell })
	end
	UI.label({ Position = UDim2.fromOffset(0, 170), Size = UDim2.new(1, 0, 0, 30), Text = d.DailyAvailable and ("Aujourd'hui : " .. Util.formatCash(d.DailyReward)) or "Reviens demain pour la suite !", TextSize = 22, TextColor3 = T.Good, Parent = box })
	if d.DailyAvailable then
		UI.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 215), Size = UDim2.fromOffset(240, 50), Text = "RÉCUPÉRER", TextSize = 22, BackgroundColor3 = T.Accent, TextColor3 = Color3.new(0, 0, 0), Parent = box }, function()
			State.send("ClaimDaily")
		end)
	end
end

local BUILDERS = {
	garage = { "Garage", function() vehiclePanel("garage") end },
	dealer = { "Concessionnaire", function() vehiclePanel("dealer") end },
	shop = { "Boutique", shopPanel },
	profile = { "Profil", profilePanel },
	map = { "Carte de la ville", mapPanel },
	daily = { "Cadeau quotidien", dailyPanel },
}

rebuild = function()
	if not current then
		return
	end
	clear()
	titleLabel.Text = BUILDERS[current][1]
	BUILDERS[current][2]()
end

function Panels.close()
	current = nil
	window.Visible = false
end

function Panels.open(name)
	if not BUILDERS[name] then
		return
	end
	if current == name then
		Panels.close()
		return
	end
	current = name
	window.Visible = true
	rebuild()
end

function Panels.init(screenGui)
	gui = screenGui
	window = UI.panel({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.8, 0, 0.8, 0),
		Visible = false, ZIndex = 20, Parent = gui,
	})
	local lim = UI.new("UISizeConstraint", { MaxSize = Vector2.new(680, 520), MinSize = Vector2.new(300, 240), Parent = window })
	UI.stroke(window, T.Accent, 2)
	titleLabel = UI.label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 34), Text = "", TextSize = 24, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = window })
	UI.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(40, 34), Text = "✕", TextSize = 20, BackgroundColor3 = T.Bad, Parent = window }, Panels.close)
	content = UI.new("Frame", { Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 1, -64), BackgroundTransparency = 1, Parent = window })

	State.Changed:Connect(function()
		if current and current ~= "map" then
			rebuild()
		end
	end)
	State.LeaderboardChanged:Connect(function()
		if current == "profile" then
			rebuild()
		end
	end)
	State.PanelRequested:Connect(function(name)
		if name == "dealer" and current == "dealer" then
			return
		end
		Panels.open(name)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.G then
			Panels.open("garage")
		elseif k == Enum.KeyCode.B then
			Panels.open("shop")
		elseif k == Enum.KeyCode.P then
			Panels.open("profile")
		elseif k == Enum.KeyCode.M then
			Panels.open("map")
		end
	end)

	-- cadeau quotidien proposé une fois par session
	local shown = false
	State.Changed:Connect(function(d)
		if d.DailyAvailable and not shown then
			shown = true
			task.delay(6, function()
				if not current then
					Panels.open("daily")
				end
			end)
		end
	end)
end

return Panels
