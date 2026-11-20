--[[
  ModelPlace : pose un modèle chargé (ServerStorage/Decor) à la place d'un objet de la carte. Taille mesurée par
  GetExtentsSize, échelle et orientation calculées par ModelFit (pur, testé), sans collision.
  Le modèle garde le nom de son modèle source (Props lit le visuel d'un meuble par son nom).
  En cas d'erreur ou de modèle absent, ne fait rien et retourne nil : l'objet procédural reste visible.
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ModelFit = require(Shared.ModelFit)
local MapData = require(Shared.MapData)

local ModelPlace = {}

function ModelPlace.template(name)
	local folder = ServerStorage:FindFirstChild("Decor")
	local template = folder and folder:FindFirstChild(name)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

-- Centre de la pièce qui contient ce point (la face avant du modèle regarde vers l'intérieur de la pièce)
function ModelPlace.roomCentre(pos)
	for _, r in ipairs(MapData.rooms) do
		local base = MapData.base[r.level]
		if pos.X >= r.x0 and pos.X <= r.x1 and pos.Z >= r.z0 and pos.Z <= r.z1 and pos.Y >= base - 0.5 then
			if pos.Y < base + MapData.H + 1 then
				return { (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2 }
			end
		end
	end
	return { pos.X, pos.Z + 1 }
end

-- Hauteur du sol de l'étage qui contient ce point
function ModelPlace.floorOf(pos)
	local best = 0
	for _, base in pairs(MapData.base) do
		if pos.Y >= base - 0.5 and base >= best then
			best = base
		end
	end
	return best
end

-- opts : { name, centre = Vector3 (x et z du centre, y ignoré), bottomY, target = { x, y, z }, parent,
--          weldTo = BasePart (le modèle y est soudé), room = centre de pièce { x, z } (sinon déduit) }
-- Retourne le modèle posé, ou nil.
function ModelPlace.fit(opts)
	local template = ModelPlace.template(opts.name)
	if not template then
		return nil
	end
	local ok, result = pcall(function()
		local clone = template:Clone()
		local ext = clone:GetExtentsSize()
		local facing =
			ModelFit.faceToward({ opts.centre.X, opts.centre.Z }, opts.roomCentre or ModelPlace.roomCentre(opts.centre))
		local sol = ModelFit.solve(
			opts.name,
			{ ext.X, ext.Y, ext.Z },
			opts.target,
			facing,
			Config.Assets.Front and Config.Assets.Front[opts.name]
		)
		clone:ScaleTo(clone:GetScale() * sol.scale)
		clone:PivotTo(CFrame.new(opts.centre) * CFrame.Angles(0, sol.yaw, 0))
		local cf, size = clone:GetBoundingBox()
		clone:TranslateBy(
			Vector3.new(
				opts.centre.X - cf.Position.X,
				opts.bottomY - (cf.Position.Y - size.Y / 2),
				opts.centre.Z - cf.Position.Z
			)
		)
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				if opts.weldTo then
					d.Anchored = false
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = opts.weldTo
					weld.Part1 = d
					weld.Parent = d
				else
					d.Anchored = true
				end
			end
		end
		clone.Parent = opts.parent or opts.weldTo
		return clone
	end)
	if not ok then
		warn(("[ModelPlace] modèle « %s » non posé : %s"):format(opts.name, tostring(result)))
		return nil
	end
	return result
end

return ModelPlace
