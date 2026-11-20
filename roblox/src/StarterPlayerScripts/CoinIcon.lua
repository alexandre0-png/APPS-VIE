-- ModuleScript : StarterPlayerScripts/CoinIcon
-- Icônes de richesse dessinées par le code (Frames, UICorner, UIStroke, UIGradient) : 1 pièce, petite pile, grosse pile, coffre.
-- Aucune image ni identifiant. Retourne le conteneur ; aucune erreur ne sort d'ici (pcall) : nil si la construction échoue.
local CoinIcon = {}

local GOLD_TOP, GOLD_BOTTOM, DARK = Color3.fromRGB(255, 232, 120), Color3.fromRGB(224, 150, 20), Color3.fromRGB(78, 46, 6)

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function disc(parent, cx, cy, d)
	local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(d, d), BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	make("UIStroke", { Color = DARK, Thickness = math.max(2, d * 0.1) }, f)
	make("UIGradient", { Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM), Rotation = 90 }, f)
	return f
end

-- tier : 1 pièce, 2 petite pile, 3 grosse pile, 4 coffre. size : côté du conteneur en pixels.
function CoinIcon.build(parent, tier, size)
	local ok, root = pcall(function()
		local box = make("Frame", { Name = "CoinIcon", Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
		local d = size * 0.34
		if tier <= 1 then
			disc(box, size / 2, size / 2, size * 0.62)
		elseif tier == 2 then
			for i = 0, 2 do
				disc(box, size * 0.22 + i * d * 0.9, size * 0.72, d)
			end
			for i = 0, 1 do
				disc(box, size * 0.34 + i * d * 0.9, size * 0.72 - d * 0.62, d)
			end
		elseif tier == 3 then
			local rows = { 4, 3, 2, 1 }
			for r, n in ipairs(rows) do
				for i = 0, n - 1 do
					disc(box, size / 2 + (i - (n - 1) / 2) * d * 0.88, size * 0.8 - (r - 1) * d * 0.62, d)
				end
			end
		else
			local body = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(size / 2, size * 0.42), Size = UDim2.fromOffset(size * 0.8, size * 0.46), BackgroundColor3 = Color3.fromRGB(150, 92, 44) }, box)
			make("UICorner", { CornerRadius = UDim.new(0.12, 0) }, body)
			make("UIStroke", { Color = DARK, Thickness = math.max(2, size * 0.05) }, body)
			make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Rotation = 90 }, body)
			local lid = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(size / 2, size * 0.46), Size = UDim2.fromOffset(size * 0.84, size * 0.24), BackgroundColor3 = Color3.fromRGB(190, 122, 56) }, box)
			make("UICorner", { CornerRadius = UDim.new(0.45, 0) }, lid)
			make("UIStroke", { Color = DARK, Thickness = math.max(2, size * 0.05) }, lid)
			make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(size / 2, size * 0.42), Size = UDim2.fromOffset(size * 0.1, size * 0.46), BackgroundColor3 = GOLD_BOTTOM, BorderSizePixel = 0 }, box)
			disc(box, size / 2, size * 0.62, size * 0.2)
			disc(box, size * 0.3, size * 0.3, d * 0.5)
			disc(box, size * 0.7, size * 0.26, d * 0.45)
		end
		return box
	end)
	return ok and root or nil
end

return CoinIcon
