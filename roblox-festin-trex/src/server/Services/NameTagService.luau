--!nonstrict
-- Étiquette au-dessus des joueurs : niveau gourmet + couronne VIP (progression visible, statut social).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)

local NameTagService = {}

local function render(label: TextLabel, player: Player)
	local level = player:GetAttribute("Level") or 1
	local vip = player:GetAttribute("Vip") == true
	label.Text = (if vip then "👑 " else "") .. "Niv. " .. tostring(level)
	label.TextColor3 = if vip then Color3.fromRGB(255, 210, 60) else Color3.new(1, 1, 1)
end

local function attach(player: Player, char: Model)
	local head = char:WaitForChild("Head", 5)
	if not head then
		return
	end
	local old = head:FindFirstChild("NameTag")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(150, 30)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	render(label, player)
	gui.Parent = head

	local c1 = player:GetAttributeChangedSignal("Level"):Connect(function()
		render(label, player)
	end)
	local c2 = player:GetAttributeChangedSignal("Vip"):Connect(function()
		render(label, player)
	end)
	gui.Destroying:Connect(function()
		c1:Disconnect()
		c2:Disconnect()
	end)
end

function NameTagService.init()
	PlayerService.onCharacter(attach)
end

return NameTagService
