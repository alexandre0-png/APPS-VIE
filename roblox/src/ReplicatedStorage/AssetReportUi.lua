-- ModuleScript : ReplicatedStorage/Shared/AssetReportUi
-- Diagnostic visible des modèles Blender (Config.Debug.AssetReport) : petite étiquette « Blender N/M » en bas à gauche (hub et partie) ; un clic ou F4 ouvre le
-- rapport complet (catégories et échecs : nom, ID, message). Le rapport vient du serveur (StringValue « AssetReport » dans ReplicatedStorage), imprimé aussi
-- dans la console client par lignes « [Assets] ». Tout sous pcall, jamais d'erreur.
local AssetReportUi = {}

-- Texte de l'étiquette : « Blender N/M » (ou « Blender … » tant que le rapport n'est pas arrivé).
function AssetReportUi.label(loaded, requested)
	if type(loaded) ~= "number" or type(requested) ~= "number" then
		return "Blender …"
	end
	return ("Blender %d/%d"):format(loaded, requested)
end

function AssetReportUi.start(Config, player, ReplicatedStorage, UserInputService)
	if not (Config.Debug and Config.Debug.AssetReport) then
		return nil
	end
	local ok, gui = pcall(function()
		local g = Instance.new("ScreenGui")
		g.Name = "AssetReport"
		g.ResetOnSpawn = false
		g.DisplayOrder = 90
		local lbl = Instance.new("TextButton")
		lbl.Name = "Label"
		lbl.AnchorPoint = Vector2.new(0, 1)
		lbl.Position = UDim2.new(0, 8, 1, -8)
		lbl.Size = UDim2.fromOffset(130, 22)
		lbl.BackgroundColor3 = Color3.new(0, 0, 0)
		lbl.BackgroundTransparency = 0.5
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 13
		lbl.TextColor3 = Color3.fromRGB(190, 255, 190)
		lbl.Text = AssetReportUi.label(nil, nil)
		lbl.AutoButtonColor = false
		lbl.Parent = g
		local box = Instance.new("TextLabel")
		box.Name = "Details"
		box.AnchorPoint = Vector2.new(0, 1)
		box.Position = UDim2.new(0, 8, 1, -34)
		box.Size = UDim2.new(0.8, 0, 0.6, 0)
		box.BackgroundColor3 = Color3.new(0, 0, 0)
		box.BackgroundTransparency = 0.25
		box.Font = Enum.Font.Code
		box.TextSize = 12
		box.TextColor3 = Color3.new(1, 1, 1)
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top
		box.TextWrapped = true
		box.Visible = false
		box.Text = ""
		box.Parent = g
		lbl.Activated:Connect(function()
			box.Visible = not box.Visible
		end)
		g.Parent = player:WaitForChild("PlayerGui")
		return g
	end)
	if not ok then
		return nil
	end
	task.spawn(function()
		local rv = ReplicatedStorage:WaitForChild("AssetReport", 120)
		if not rv then
			pcall(function()
				gui.Label.Text = "Blender : pas de rapport"
			end)
			return
		end
		pcall(function()
			gui.Label.Text = AssetReportUi.label(rv:GetAttribute("Loaded"), rv:GetAttribute("Requested"))
			gui.Details.Text = rv.Value
			for line in rv.Value:gmatch("[^\n]+") do
				print(line) -- rapport dans la console client
			end
		end)
	end)
	pcall(function()
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.F4 then
				gui.Details.Visible = not gui.Details.Visible
			end
		end)
	end)
	return gui
end

return AssetReportUi
