-- PlotService.luau : attribution des parcelles et synchronisation du monde physique avec les données du joueur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Economy = require(Shared.Economy)
local DinoFactory = require(Shared.DinoFactory)
local WorldBuilder = require(script.Parent.WorldBuilder)

local PlotService = {}

local plots = {}
local byPlayer = {}

-- Callbacks branchés par GameService
PlotService.handlers = {
	dig = function(_player) end,
	collect = function(_player) end,
	buy = function(_player, _id) end,
	stand = function(_player, _slot) end,
	bone = function(_player, _id) end,
}

local SLOT_OFFSETS = { Vector3.new(-9, 0, -6), Vector3.new(9, 0, -6), Vector3.new(-9, 0, 6), Vector3.new(9, 0, 6) }

local function playerFromHit(hit)
	local model = hit and hit.Parent
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

function PlotService.getPlot(player)
	return byPlayer[player]
end

function PlotService.getPlots()
	return plots
end

local function resetDynamic(plot)
	plot.dyn:ClearAllChildren()
	plot.padFolder:ClearAllChildren()
	plot.built = {}
	plot.pads = {}
	plot.stands = {}
	plot.locks = {}
	plot.dinoSlots = {}
	plot.dinoFolder = Instance.new("Folder")
	plot.dinoFolder.Name = "Dinos"
	plot.dinoFolder.Parent = plot.dyn
	plot.signature = ""
end

function PlotService.init()
	local built = WorldBuilder.build()
	for i, plot in ipairs(built) do
		plots[i] = plot
		resetDynamic(plot)

		for _, m in ipairs(plot.refs.mounds) do
			m.click.MouseClick:Connect(function(player)
				if plot.owner == player then
					PlotService.handlers.dig(player)
				end
			end)
			m.prompt.Triggered:Connect(function(player)
				if plot.owner == player then
					PlotService.handlers.dig(player)
				end
			end)
		end
		plot.refs.boothPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player and plot.owner == player then
				PlotService.handlers.collect(player)
			end
		end)
	end

	for j, pp in pairs(WorldBuilder.bones or {}) do
		pp.Triggered:Connect(function(player)
			PlotService.handlers.bone(player, j)
		end)
	end
end

function PlotService.claim(player)
	for _, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			resetDynamic(plot)
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotIndex", plot.index)
			plot.refs.gateText.Text = "PARC DE " .. string.upper(player.DisplayName)
			return plot
		end
	end
	return nil
end

function PlotService.release(player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.owner = nil
	resetDynamic(plot)
	plot.model:SetAttribute("OwnerUserId", nil)
	plot.refs.gateText.Text = "PARC LIBRE"
	plot.refs.boothLabel.Text = "💰 0"
end

function PlotService.teleport(player)
	local plot = byPlayer[player]
	local char = player.Character
	if not plot or not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		char:PivotTo(plot.refs.spawnCF)
	end
end

----------------------------------------------------------------------
-- Synchronisation des structures
----------------------------------------------------------------------
local function buildStructure(plot, def)
	if def.kind == "pen" then
		return WorldBuilder.buildPen(plot, def.index)
	elseif def.kind == "shop" then
		return WorldBuilder.buildShop(plot, def)
	elseif def.kind == "digger" then
		return WorldBuilder.buildDigger(plot, def.index)
	elseif def.kind == "helipad" then
		return WorldBuilder.buildHelipad(plot)
	end
	return nil
end

local function syncStructures(plot, data)
	if not plot.built.pen1 then
		plot.built.pen1 = WorldBuilder.buildPen(plot, 1)
	end
	for _, def in ipairs(Config.Buildables) do
		if def.kind ~= "incubator" then
			local owned = data.buildables[def.id] == true
			local existing = plot.built[def.id]
			if owned and not existing then
				plot.built[def.id] = buildStructure(plot, def)
			elseif not owned and existing then
				existing:Destroy()
				plot.built[def.id] = nil
			end
		end
	end
end

-- Enclos fermés : barrières rouges et panneau tant qu'ils ne sont pas achetés
local function syncLocks(plot, data)
	for _, def in ipairs(Config.Buildables) do
		if def.kind == "pen" then
			local owned = data.buildables[def.id] == true
			local lock = plot.locks[def.id]
			if not owned and not lock then
				local folder, label = WorldBuilder.buildLockedPen(plot, def)
				lock = { folder = folder, label = label }
				plot.locks[def.id] = lock
			elseif owned and lock then
				lock.folder:Destroy()
				plot.locks[def.id] = nil
				lock = nil
			end
			if lock then
				local unlocked = Economy.parkLevel(data) >= def.level
				local text = def.name .. (unlocked and "\nÀ acheter !" or ("\n🔒 Niveau " .. def.level))
				if lock.label.Text ~= text then
					lock.label.Text = text
				end
			end
		end
	end
end

local function syncStands(plot, data)
	local count = Economy.incubatorCount(data)
	for slot = 1, 4 do
		local existing = plot.stands[slot]
		if slot <= count and not existing then
			local folder, egg, pp, socle = WorldBuilder.buildStand(plot, slot)
			plot.stands[slot] = { folder = folder, egg = egg, prompt = pp, socle = socle, state = "" }
			local s = slot
			pp.Triggered:Connect(function(player)
				if plot.owner == player then
					PlotService.handlers.stand(player, s)
				end
			end)
		elseif slot > count and existing then
			existing.folder:Destroy()
			plot.stands[slot] = nil
		end
	end
end

local function syncPads(plot, data)
	for _, def in ipairs(Config.Buildables) do
		local show = not data.buildables[def.id] and (def.requires == nil or data.buildables[def.requires] == true)
		local pad = plot.pads[def.id]
		if show and not pad then
			pad = WorldBuilder.buildPad(plot, def)
			plot.pads[def.id] = pad
			pad.Label.Cost.Text = "💰 " .. Util.formatNumber(def.cost)
			local id = def.id
			pad.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player and plot.owner == player then
					PlotService.handlers.buy(player, id)
				end
			end)
		elseif not show and pad then
			pad:Destroy()
			plot.pads[def.id] = nil
			pad = nil
		end
		if pad then
			local locked = Economy.parkLevel(data) < def.level
			local text = locked and ("🔒 Niveau " .. def.level) or ("💰 " .. Util.formatNumber(def.cost))
			local color = Color3.fromRGB(255, 120, 110)
			if locked then
				color = Color3.fromRGB(255, 190, 80)
			elseif data.cash >= def.cost then
				color = Color3.fromRGB(110, 255, 130)
			end
			local label = pad.Label.Cost
			if label.Text ~= text then
				label.Text = text
			end
			if label.TextColor3 ~= color then
				label.TextColor3 = color
			end
		end
	end
end

-- Dinos exposés : un modèle par emplacement, reconstruit seulement si la clé change.
local function syncDinos(plot, displayed)
	local maxN = math.max(#displayed, #plot.dinoSlots)
	for k = 1, maxN do
		local want = displayed[k]
		local cur = plot.dinoSlots[k]
		if (cur and cur.key) ~= want then
			if cur and cur.model then
				cur.model:Destroy()
			end
			plot.dinoSlots[k] = nil
			if want then
				local penIdx = math.floor((k - 1) / Config.SlotsPerPen) + 1
				local slotIdx = ((k - 1) % Config.SlotsPerPen) + 1
				local pen = Config.Pens[penIdx]
				if pen then
					local model = DinoFactory.build(want)
					if model then
						local local_ = Vector3.new(pen.center.X, 0.45, pen.center.Z) + SLOT_OFFSETS[slotIdx]
						local worldPos = plot.cf:PointToWorldSpace(local_)
						local yaw = math.rad(math.random(0, 359))
						model:PivotTo(CFrame.new(worldPos) * CFrame.Angles(0, yaw, 0))
						model:SetAttribute("Home", worldPos)
						model:SetAttribute("Slot", k)
						model.Parent = plot.dinoFolder
						plot.dinoSlots[k] = { key = want, model = model }
					end
				end
			end
		end
	end
end

-- Appelé à chaque changement structurel (achat, éclosion, renaissance…)
function PlotService.refresh(player, data)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	syncStructures(plot, data)
	syncLocks(plot, data)
	syncStands(plot, data)
	syncPads(plot, data)
	local displayed = Economy.displayAndReserve(data)
	syncDinos(plot, displayed)
end

-- Appelé chaque seconde : textes dynamiques (kiosque, incubateurs, couleur des boutons)
function PlotService.tick(player, data, now, pending, cap)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	local text = "💰 " .. Util.formatNumber(pending)
	if cap > 0 and pending >= cap * 0.999 then
		text = text .. " (plein)"
	end
	if plot.refs.boothLabel.Text ~= text then
		plot.refs.boothLabel.Text = text
	end
	syncPads(plot, data)
	syncLocks(plot, data)
	for slot, st in pairs(plot.stands) do
		local info = data.eggSlots[tostring(slot)]
		local egg = st.egg
		local newState, action
		if not info then
			newState = "empty"
			action = "Placer un œuf"
			if egg.Transparency ~= 1 then
				egg.Transparency = 1
			end
		else
			local def = Config.Eggs[info.egg]
			egg.Color = def.color
			egg.Transparency = 0
			if now >= info.finish then
				newState = "ready"
				action = "Récupérer l'œuf !"
				egg.Material = Enum.Material.Neon
			else
				newState = "hatching"
				action = "Éclosion " .. Util.formatTime(info.finish - now)
				egg.Material = Enum.Material.SmoothPlastic
			end
		end
		if st.prompt.ActionText ~= action then
			st.prompt.ActionText = action
		end
		if st.state ~= newState then
			st.state = newState
			egg:SetAttribute("State", newState)
		end
	end
end

return PlotService
