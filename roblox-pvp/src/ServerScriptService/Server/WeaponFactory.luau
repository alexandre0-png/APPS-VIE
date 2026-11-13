--!nonstrict
-- Fabrique les outils (Tool) à partir des définitions de Shared/Weapons.
-- Les armes sont construites uniquement avec des blocs Roblox standards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetLogic = require(ReplicatedStorage:WaitForChild("Shared").AssetLogic)
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local WeaponFactory = {}

-- Fournisseur de skin (renseigné par init.server : AssetService.GetSkin). nil = apparence d'origine.
WeaponFactory.SkinProvider = nil

-- Remplace l'apparence par un modèle importé (si disponible). Renvoie vrai si appliqué.
-- Le Handle (invisible) reste la référence : aucune règle de jeu ne change.
local function attachSkin(tool, handle, def, template)
	local clone = template:Clone()
	local _, size = clone:GetBoundingBox()
	local axis = AssetLogic.LongestAxis(size.X, size.Y, size.Z)
	clone:ScaleTo(clone:GetScale() * AssetLogic.ScaleFor(math.max(size.X, size.Y, size.Z), Config.Assets.SkinLength))
	-- oriente le grand axe le long de -Z (canon vers l'avant)
	local align = CFrame.new()
	if axis == 1 then
		align = CFrame.Angles(0, math.rad(90), 0)
	elseif axis == 2 then
		align = CFrame.Angles(math.rad(90), 0, 0)
	end
	local flip = CFrame.Angles(0, math.rad(Config.Assets.SkinRotationY[def.Id] or 0), 0)
	clone:PivotTo(handle.CFrame * flip * align)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local weld = Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = d
			weld.C0 = handle.CFrame:Inverse() * d.CFrame
			weld.Parent = d
		end
	end
	-- succès : on retire l'ancienne apparence
	for _, child in ipairs(tool:GetChildren()) do
		if child:IsA("BasePart") and child ~= handle then
			child:Destroy()
		end
	end
	handle.Transparency = 1
	clone.Name = "Skin"
	clone.Parent = tool
	return true
end

function WeaponFactory.Build(def)
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.ToolTip = def.Description
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", def.Id)

	local handle
	for i, spec in ipairs(def.Parts) do
		local part = Instance.new("Part")
		part.Size = Vector3.new(spec.Size[1], spec.Size[2], spec.Size[3])
		part.Color = Color3.fromHex(spec.Color)
		part.Material = Enum.Material[spec.Material] or Enum.Material.SmoothPlastic
		if spec.Shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth

		local rot = spec.Rot or { 0, 0, 0 }
		local relative = CFrame.new(spec.Offset[1], spec.Offset[2], spec.Offset[3])
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))

		if i == 1 then
			part.Name = "Handle"
			handle = part
		else
			part.Name = "Part" .. i
			part.CFrame = relative
			local weld = Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = part
			weld.C0 = relative
			weld.Parent = part
		end
		part.Parent = tool
	end
	-- apparence importée (optionnelle) : en cas d'erreur on garde l'apparence d'origine
	local template = WeaponFactory.SkinProvider and WeaponFactory.SkinProvider(def.Id)
	if template and handle then
		local ok, err = pcall(attachSkin, tool, handle, def, template)
		if not ok then
			warn(("[WeaponFactory] skin de %s ignoré : %s"):format(def.Id, tostring(err)))
		end
	end
	return tool
end

return WeaponFactory
