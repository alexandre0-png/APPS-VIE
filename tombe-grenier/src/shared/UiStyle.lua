--[[
  UiStyle : applique le style cartoon glossy (Theme) à un objet d'interface : dégradé, contour foncé épais,
  coins arrondis, reflet discret. Tout est dessiné par le code (aucun identifiant d'image). Chaque appel est
  idempotent et protégé : une erreur de style ne casse jamais l'interface, le bouton reste utilisable.
]]
local Theme = require(script.Parent.Theme)

local UiStyle = {}

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Change la couleur d'un objet déjà stylé (dégradé, contour, texte) : un même cadre sert à plusieurs fonctions.
function UiStyle.recolor(obj, role)
	local spec = Theme.role(role)
	pcall(function()
		obj.BackgroundColor3 = rgb(spec.top)
		if obj:IsA("TextButton") or obj:IsA("TextLabel") then
			obj.TextColor3 = rgb(spec.text)
			obj.TextStrokeColor3 = rgb(spec.stroke)
			obj.TextStrokeTransparency = spec.text[1] > 200 and 0.55 or 1
		end
		local stroke = obj:FindFirstChild("Contour")
		if stroke then
			stroke.Color = rgb(spec.stroke)
		end
		local gradient = obj:FindFirstChild("Degrade")
		if gradient then
			gradient.Color = ColorSequence.new(rgb(spec.top), rgb(spec.bottom))
		end
	end)
end

-- obj : TextButton, TextLabel ou Frame. role : "play" | "save" | "option" | "danger" | "neutral".
function UiStyle.apply(obj, role, opts)
	local ok, err = pcall(function()
		obj.BackgroundTransparency = (opts and opts.transparency) or 0.02
		obj.BorderSizePixel = 0
		if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and not (opts and opts.keepFont) then
			obj.Font = Enum.Font.GothamBold
		end
		if not obj:FindFirstChild("Contour") then
			local stroke = Instance.new("UIStroke")
			stroke.Name = "Contour"
			stroke.Thickness = Theme.STROKE
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = obj
		end
		if not obj:FindFirstChild("Coins") then
			local corner = Instance.new("UICorner")
			corner.Name = "Coins"
			corner.CornerRadius = UDim.new(0, Theme.CORNER)
			corner.Parent = obj
		end
		if not obj:FindFirstChild("Degrade") then
			local gradient = Instance.new("UIGradient")
			gradient.Name = "Degrade"
			gradient.Rotation = 90
			gradient.Parent = obj
		end
		if not obj:FindFirstChild("Reflet") then
			local gloss = Instance.new("Frame")
			gloss.Name = "Reflet"
			gloss.Active = false
			gloss.Size = UDim2.new(1, -10, Theme.GLOSS.height, 0)
			gloss.Position = UDim2.fromOffset(5, 3)
			gloss.BackgroundColor3 = Color3.new(1, 1, 1)
			gloss.BackgroundTransparency = Theme.GLOSS.transparency
			gloss.BorderSizePixel = 0
			gloss.ZIndex = obj.ZIndex
			local gcorner = Instance.new("UICorner")
			gcorner.CornerRadius = UDim.new(0, Theme.CORNER - 3)
			gcorner.Parent = gloss
			gloss.Parent = obj
		end
	end)
	if not ok then
		warn("[UiStyle] style non appliqué : " .. tostring(err))
	end
	UiStyle.recolor(obj, role)
	return obj
end

return UiStyle
