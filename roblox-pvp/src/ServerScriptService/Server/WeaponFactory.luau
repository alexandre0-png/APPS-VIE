--!nonstrict
-- Fabrique les outils (Tool) à partir des définitions de Shared/Weapons.
-- Les armes sont construites uniquement avec des blocs Roblox standards.
local WeaponFactory = {}

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
	return tool
end

return WeaponFactory
