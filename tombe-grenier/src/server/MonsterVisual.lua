--[[
  MonsterVisual : apparence « Ombre rampante » du monstre (modèle Blender chargé dans ServerStorage/Decor).
  La logique, la hitbox et les animations du rig actuel ne changent pas : le rig devient invisible, la silhouette est
  soudée à sa racine par un Weld dont le décalage (C0) est animé par code (MonsterSway : balancement et inclinaison).
  Sans modèle chargé, ou en cas d'erreur, le rig reste visible comme avant.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelFit = require(Shared.ModelFit)
local MonsterSway = require(Shared.MonsterSway)
local ModelPlace = require(script.Parent.ModelPlace)

local MonsterVisual = {}

MonsterVisual.MODEL = "ombre rampante"

-- model : le rig du monstre (déjà posé dans le monde) ; root : sa HumanoidRootPart. Retourne { weld, base, model } ou nil.
function MonsterVisual.attach(model, root)
	local template = ModelPlace.template(MonsterVisual.MODEL)
	if not template then
		return nil
	end
	local ok, visual = pcall(function()
		local rigCF, rigSize = model:GetBoundingBox()
		local clone = template:Clone()
		local ext = clone:GetExtentsSize()
		-- Hauteur du rig : la silhouette (~2,5 studs au départ) est ramenée à la taille du monstre
		local scale = ModelFit.scaleFor({ ext.X, ext.Y, ext.Z }, { 0, rigSize.Y, 0 }, "height")
		clone:ScaleTo(clone:GetScale() * scale)
		local parts = {}
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		local primary = clone.PrimaryPart or parts[1]
		if not primary then
			error("modèle sans pièce")
		end
		clone.PrimaryPart = primary
		local cf, size = clone:GetBoundingBox()
		local feet = rigCF.Position.Y - rigSize.Y / 2
		clone:PivotTo(CFrame.new(root.Position.X, feet + size.Y / 2, root.Position.Z) * root.CFrame.Rotation)
		for _, d in ipairs(parts) do
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= primary then
				local glue = Instance.new("WeldConstraint")
				glue.Part0 = primary
				glue.Part1 = d
				glue.Parent = d
			end
		end
		-- Le rig devient invisible (sa hitbox et sa logique restent) avant l'arrivée de la silhouette
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d ~= root then
				d.Transparency = 1
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			end
		end
		local base = root.CFrame:Inverse() * primary.CFrame
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = primary
		weld.C0 = base
		weld.Parent = primary
		clone.Parent = model
		return { weld = weld, base = base, model = clone }
	end)
	if not ok then
		warn("[MonsterVisual] silhouette non posée, rig conservé : " .. tostring(visual))
		return nil
	end
	return visual
end

-- Balancement et inclinaison selon l'allure du monstre (m.locoKey : immobile, marche, course), tant qu'il est en vie
function MonsterVisual.loop(m)
	local visual = m.visual
	while visual and m.alive do
		local pose = MonsterSway.pose(m.locoKey or "immobile", os.clock())
		pcall(function()
			visual.weld.C0 = visual.base * CFrame.new(0, pose.bob, 0) * CFrame.Angles(pose.pitch, 0, pose.roll)
		end)
		task.wait(0.05)
	end
end

return MonsterVisual
