-- ModuleScript : StarterPlayerScripts/MiniMapUi
-- Mini-carte ronde dessinée par le code : un cadre, des pastilles réutilisées (au plus Config.MINIMAP.maxDots, jamais créées en cours de route), mise à jour
-- Config.MINIMAP.hz fois par seconde. Points : toi (centre), ta base, les zones (grisées si verrouillées), les portails de voyage rapide, les gardiens proches.
-- Bouton 🗺 pour l'afficher ou la masquer. Tout sous pcall.
local MiniMapUi = {}

function MiniMapUi.start(Config, MiniMap, player, gui, getState, UserInputService, RunService)
	local C = Config.MINIMAP
	if not C.enabled then
		return nil
	end
	local ok, objs = pcall(function()
		local cam = workspace.CurrentCamera
		local small = cam ~= nil and cam.ViewportSize.X < 500
		local size = small and C.sizeSmall or C.size
		local half = size / 2
		local btn = Instance.new("TextButton")
		btn.Name = "MiniMapToggle"
		btn.AnchorPoint = Vector2.new(1, 0)
		btn.Position = UDim2.new(1, -8, 0.3, 0)
		btn.Size = UDim2.fromOffset(34, 34)
		btn.Text = "🗺"
		btn.TextSize = 18
		btn.Font = Enum.Font.GothamBold
		btn.BackgroundColor3 = Color3.fromRGB(30, 36, 48)
		btn.BackgroundTransparency = 0.2
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Parent = gui
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0.5, 0)
		bc.Parent = btn
		local frame = Instance.new("Frame")
		frame.Name = "MiniMap"
		frame.AnchorPoint = Vector2.new(1, 0)
		frame.Position = UDim2.new(1, -8, 0.3, 40)
		frame.Size = UDim2.fromOffset(size, size)
		frame.BackgroundColor3 = Color3.fromRGB(34, 60, 44)
		frame.BackgroundTransparency = 0.25
		frame.ClipsDescendants = true
		frame.Parent = gui
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0.5, 0)
		fc.Parent = frame
		local fs = Instance.new("UIStroke")
		fs.Color = Color3.fromRGB(255, 232, 150)
		fs.Thickness = 2
		fs.Parent = frame
		local dots = {}
		for i = 1, C.maxDots do
			local d = Instance.new("TextLabel")
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.BackgroundTransparency = 1
			d.Size = UDim2.fromOffset(16, 16)
			d.TextSize = 14
			d.Font = Enum.Font.GothamBold
			d.Text = ""
			d.Visible = false
			d.Parent = frame
			dots[i] = d
		end
		local me = Instance.new("TextLabel")
		me.AnchorPoint = Vector2.new(0.5, 0.5)
		me.Position = UDim2.fromOffset(half, half)
		me.BackgroundTransparency = 1
		me.Size = UDim2.fromOffset(18, 18)
		me.TextSize = 16
		me.Text = "🔹"
		me.Parent = frame
		return { btn = btn, frame = frame, dots = dots, half = half }
	end)
	if not ok then
		return nil
	end
	local visible = true
	objs.btn.Activated:Connect(function()
		visible = not visible
		objs.frame.Visible = visible
	end)
	pcall(function()
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.M then
				visible = not visible
				objs.frame.Visible = visible
			end
		end)
	end)
	local guardCache, cacheAt = {}, -99
	task.spawn(function()
		while true do
			task.wait(1 / math.max(1, C.hz))
			pcall(function()
				if not visible then
					return
				end
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local state = getState()
				if not root or not state then
					return
				end
				local px, pz = root.Position.X, root.Position.Z
				local plot = player:GetAttribute("PlotCF")
				local pts = MiniMap.landmarks(Config, typeof(plot) == "CFrame" and plot.Position.X or nil, typeof(plot) == "CFrame" and plot.Position.Z or nil, state.story and state.story.ch)
				if os.clock() - cacheAt > 2 then -- gardiens : liste relue toutes les 2 s seulement
					cacheAt = os.clock()
					guardCache = {}
					local w = workspace:FindFirstChild("World")
					if w then
						for _, d in ipairs(w:GetDescendants()) do
							if d:IsA("Model") and d.Name:match("^Guard%d+_%d+$") then
								guardCache[#guardCache + 1] = d
							end
						end
					end
				end
				for _, g in ipairs(guardCache) do
					local ok2, cf = pcall(function()
						return g:GetPivot()
					end)
					if ok2 and cf then
						local dx, dz = cf.Position.X - px, cf.Position.Z - pz
						if dx * dx + dz * dz <= C.guardRange * C.guardRange then
							pts[#pts + 1] = { kind = "guard", x = cf.Position.X, z = cf.Position.Z, label = "🔴" }
						end
					end
				end
				local used = 0
				for _, p in ipairs(pts) do
					if used >= #objs.dots then
						break
					end
					local u, v = MiniMap.place(px, pz, p.x, p.z, C.radius, objs.half - 8, p.kind ~= "guard")
					if u then
						used = used + 1
						local d = objs.dots[used]
						d.Visible = true
						d.Position = UDim2.fromOffset(objs.half + u, objs.half + v)
						d.Text = p.label
						d.TextTransparency = p.locked and 0.6 or 0
					end
				end
				for i = used + 1, #objs.dots do
					objs.dots[i].Visible = false
				end
			end)
		end
	end)
	return objs
end

return MiniMapUi
