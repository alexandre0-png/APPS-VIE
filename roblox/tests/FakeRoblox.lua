-- Roblox factice minimal pour exécuter le code de construction du monde hors de Roblox (tests/run.luau) : détecte les erreurs d'exécution
-- (champ nil, mauvais ordre d'arguments, méthode oubliée) et compte les instances. Ne simule AUCUN comportement de jeu ni de rendu.
local Fake = {}

function Fake.new()
	local F = { created = {}, tags = {} }
	local function vec(x, y, z)
		local v = { X = x, Y = y, Z = z }
		return setmetatable(v, {
			__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
			__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
			__mul = function(a, b)
				if type(b) == "number" then
					return vec(a.X * b, a.Y * b, a.Z * b)
				end
				return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
			end,
			__index = function(_, k)
				if k == "Magnitude" then
					return math.sqrt(x * x + y * y + z * z)
				end
			end,
		})
	end
	local function cf(x, y, z)
		local c = { Position = vec(x or 0, y or 0, z or 0), X = x or 0, Y = y or 0, Z = z or 0 }
		return setmetatable(c, {
			__mul = function(a, b)
				if b.Position then
					return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
				end
				return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
			end,
			__add = function(a, b) return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
		})
	end
	local color
	color = function(r, g, b)
		local c = { R = r, G = g, B = b }
		function c:Lerp(o, t) return color(r + (o.R - r) * t, g + (o.G - g) * t, b + (o.B - b) * t) end
		return c
	end
	local enumMeta = { __index = function(t, k)
		local sub = setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end })
		rawset(t, k, sub)
		return sub
	end }
	local function newInstance(class)
		local o = { ClassName = class, children = {}, attrs = {} }
		function o:SetAttribute(k, v) self.attrs[k] = v end
		function o:GetAttribute(k) return self.attrs[k] end
		function o:GetDescendants() return {} end
		function o:FindFirstChild() return nil end
		function o:FindFirstChildOfClass() return nil end
		function o:Destroy() end
		F.created[#F.created + 1] = o
		F.counts = F.counts or {}
		F.counts[class] = (F.counts[class] or 0) + 1
		return o
	end
	F.counts = {}
	local lighting = newInstance("Lighting")
	local services = {
		CollectionService = { AddTag = function(_, inst, tag) F.tags[tag] = (F.tags[tag] or 0) + 1 end },
		Lighting = lighting,
	}
	F.env = {
		Color3 = { fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end, new = function(r, g, b) return color(r, g, b) end },
		Vector3 = { new = function(x, y, z) return vec(x or 0, y or 0, z or 0) end, zero = vec(0, 0, 0) },
		Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		CFrame = {
			new = function(x, y, z)
				if type(x) == "table" and x.X then return cf(x.X, x.Y, x.Z) end
				return cf(x, y, z)
			end,
			Angles = function() return cf(0, 0, 0) end,
			lookAt = function(from) return cf(from.X, from.Y, from.Z) end,
		},
		UDim2 = { fromOffset = function() return {} end, fromScale = function() return {} end, new = function() return {} end },
		Enum = setmetatable({}, enumMeta),
		Instance = { new = newInstance },
		ColorSequence = { new = function() return {} end },
		NumberRange = { new = function() return {} end },
		NumberSequence = { new = function() return {} end },
		NumberSequenceKeypoint = { new = function() return {} end },
		Random = { new = function(seed)
			local s = seed or 1
			local r = {}
			function r:NextNumber(a, b)
				s = (s * 16807) % 2147483647
				return (a or 0) + (s / 2147483647) * ((b or 1) - (a or 0))
			end
			function r:NextInteger(a, b) return math.floor(self:NextNumber(a, b + 1)) end
			return r
		end },
		typeof = function(v) return type(v) end,
		workspace = newInstance("Workspace"),
		game = { GetService = function(_, name) return services[name] or newInstance(name) end },
	}
	-- `game:GetService(...)` : appelé avec deux arguments (self, nom) comme dans Roblox ; les modules l'appellent avec « : »
	F.env.game.GetService = function(self, name)
		return services[name] or newInstance(name)
	end
	F.lighting = lighting
	return F
end

return Fake
