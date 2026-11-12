-- Chapeaux : construits en blocs et soudés à la tête du personnage.

local Cosmetics = {}

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Décalages relatifs au centre de la tête (le dessus de la tête est à y = +0.5).
-- shape : "Block" (défaut), "Ball" ou "Cyl" ; rot en degrés.
local HATS = {
	beanie = {
		{ s = V(2.3, 1.6, 2.3), o = V(0, 0.55, 0), c = C(214, 60, 60), shape = "Ball" },
		{ s = V(2.2, 0.35, 2.2), o = V(0, 0.15, 0), c = C(255, 255, 255) },
		{ s = V(0.9, 0.9, 0.9), o = V(0, 1.5, 0), c = C(255, 255, 255), shape = "Ball" },
	},
	cowboy = {
		{ s = V(0.2, 4.4, 4.4), o = V(0, 0.6, 0), c = C(150, 96, 56), shape = "Cyl", rot = V(0, 0, 90) },
		{ s = V(2.2, 1.3, 2.2), o = V(0, 1.2, 0), c = C(150, 96, 56) },
		{ s = V(2.3, 0.3, 2.3), o = V(0, 0.85, 0), c = C(80, 50, 30) },
	},
	viking = {
		{ s = V(2.4, 2.0, 2.4), o = V(0, 0.5, 0), c = C(150, 152, 160), mat = Enum.Material.Metal, shape = "Ball" },
		{ s = V(0.5, 1.4, 0.5), o = V(-1.3, 1.0, 0), c = C(240, 232, 205), rot = V(0, 0, 20) },
		{ s = V(0.5, 1.4, 0.5), o = V(1.3, 1.0, 0), c = C(240, 232, 205), rot = V(0, 0, -20) },
		{ s = V(0.5, 0.8, 0.5), o = V(-1.75, 1.9, 0), c = C(240, 232, 205), rot = V(0, 0, 40) },
		{ s = V(0.5, 0.8, 0.5), o = V(1.75, 1.9, 0), c = C(240, 232, 205), rot = V(0, 0, -40) },
	},
	wizard = {
		{ s = V(3.2, 0.2, 3.2), o = V(0, 0.6, 0), c = C(90, 50, 150) },
		{ s = V(2.2, 1.2, 2.2), o = V(0, 1.2, 0), c = C(90, 50, 150) },
		{ s = V(1.6, 1.2, 1.6), o = V(0, 2.4, 0), c = C(90, 50, 150) },
		{ s = V(1.0, 1.2, 1.0), o = V(0, 3.6, 0), c = C(90, 50, 150) },
		{ s = V(0.5, 0.8, 0.5), o = V(0, 4.5, 0), c = C(90, 50, 150) },
		{ s = V(0.7, 0.7, 0.7), o = V(0, 5.1, 0), c = C(255, 225, 80), mat = Enum.Material.Neon, shape = "Ball" },
	},
	dino = {
		{ s = V(2.3, 1.2, 2.3), o = V(0, 0.7, 0), c = C(96, 166, 98) },
		{ s = V(0.4, 0.8, 0.8), o = V(0, 1.6, 0.6), c = C(230, 120, 60) },
		{ s = V(0.4, 0.8, 0.8), o = V(0, 1.6, 0), c = C(230, 120, 60) },
		{ s = V(0.4, 0.8, 0.8), o = V(0, 1.6, -0.6), c = C(230, 120, 60) },
		{ s = V(0.6, 0.6, 0.6), o = V(-0.6, 1.3, -0.9), c = C(255, 255, 255), shape = "Ball" },
		{ s = V(0.6, 0.6, 0.6), o = V(0.6, 1.3, -0.9), c = C(255, 255, 255), shape = "Ball" },
	},
	vip = {
		{ s = V(2.2, 0.5, 2.2), o = V(0, 0.75, 0), c = C(255, 205, 60), mat = Enum.Material.Metal },
		{ s = V(0.6, 1.8, 0.6), o = V(-1.3, 1.5, 0), c = C(255, 214, 90), mat = Enum.Material.Metal, rot = V(0, 0, 25) },
		{ s = V(0.6, 1.8, 0.6), o = V(1.3, 1.5, 0), c = C(255, 214, 90), mat = Enum.Material.Metal, rot = V(0, 0, -25) },
		{ s = V(0.5, 1.0, 0.5), o = V(-1.9, 2.5, 0), c = C(255, 245, 180), mat = Enum.Material.Neon, rot = V(0, 0, 45) },
		{ s = V(0.5, 1.0, 0.5), o = V(1.9, 2.5, 0), c = C(255, 245, 180), mat = Enum.Material.Neon, rot = V(0, 0, -45) },
	},
	crown = {
		{ s = V(2.2, 0.8, 2.2), o = V(0, 0.9, 0), c = C(255, 205, 60), mat = Enum.Material.Metal },
		{ s = V(0.5, 0.9, 0.5), o = V(-0.8, 1.7, -0.8), c = C(255, 205, 60), mat = Enum.Material.Metal },
		{ s = V(0.5, 0.9, 0.5), o = V(0.8, 1.7, -0.8), c = C(255, 205, 60), mat = Enum.Material.Metal },
		{ s = V(0.5, 0.9, 0.5), o = V(-0.8, 1.7, 0.8), c = C(255, 205, 60), mat = Enum.Material.Metal },
		{ s = V(0.5, 0.9, 0.5), o = V(0.8, 1.7, 0.8), c = C(255, 205, 60), mat = Enum.Material.Metal },
		{ s = V(0.5, 0.5, 0.3), o = V(0, 0.9, -1.15), c = C(255, 60, 90), mat = Enum.Material.Neon },
	},
}

function Cosmetics.remove(character)
	local old = character:FindFirstChild("HHHat")
	if old then
		old:Destroy()
	end
end

function Cosmetics.applyHat(character, hatId)
	Cosmetics.remove(character)
	local spec = HATS[hatId]
	if not spec then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local model = Instance.new("Model")
	model.Name = "HHHat"
	for index, def in ipairs(spec) do
		local part = Instance.new("Part")
		part.Name = "HatPart" .. index
		part.Size = def.s
		part.Color = def.c
		part.Material = def.mat or Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
		if def.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif def.shape == "Cyl" then
			part.Shape = Enum.PartType.Cylinder
		end
		local rot = def.rot or Vector3.new(0, 0, 0)
		part.CFrame = head.CFrame
			* CFrame.new(def.o)
			* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	model.Parent = character
end

return Cosmetics
