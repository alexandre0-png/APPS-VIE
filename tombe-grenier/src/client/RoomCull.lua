--[[
  RoomCull : masquage de pièces côté client (local seulement, le serveur n'est pas touché).
  Le décor et les meubles des pièces éloignées (au-delà des Config.Perf.CullRooms plus proches du joueur) quittent le
  Workspace local (rangés dans un dossier de ReplicatedStorage) et reviennent à l'approche. Murs, dalles et
  escaliers ne sont jamais masqués : le sol et les passages restent intacts, le joueur ne tombe jamais dans le vide.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MapData = require(Shared.MapData)
local PerfRules = require(Shared.PerfRules)

local RoomCull = {}

local FOLDERS = { "Meubles", "Décor", "Détails" }

local function pivotOf(instance)
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

function RoomCull.start()
	local perf = Config.Perf
	local holder = Instance.new("Folder")
	holder.Name = "DecorMasque"
	holder.Parent = ReplicatedStorage
	local rooms = {}
	for _, r in ipairs(MapData.rooms) do
		table.insert(rooms, { id = r.id, level = r.level, cx = (r.x0 + r.x1) / 2, cz = (r.z0 + r.z1) / 2 })
	end
	local known = {} -- [instance] = { room, parent }
	local list = {}
	local hidden = 0

	local function scan(house)
		for _, name in ipairs(FOLDERS) do
			local folder = house:FindFirstChild(name)
			if folder then
				for _, child in ipairs(folder:GetChildren()) do
					if known[child] == nil then
						local pos = pivotOf(child)
						local room = pos
							and PerfRules.roomIdAt(MapData.rooms, MapData.base, MapData.H, pos.X, pos.Y, pos.Z)
						known[child] = { room = room, parent = folder }
						if room then
							table.insert(list, child)
						end
					end
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(perf.CullInterval)
			pcall(function()
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local map = workspace:FindFirstChild("TombeMap")
				local house = map and map:FindFirstChild("Maison")
				if not (root and house) then
					return
				end
				scan(house)
				local here = PerfRules.roomIdAt(
					MapData.rooms,
					MapData.base,
					MapData.H,
					root.Position.X,
					root.Position.Y,
					root.Position.Z
				)
				local level = "ground"
				for _, r in ipairs(MapData.rooms) do
					if r.id == here then
						level = r.level
					end
				end
				local visible = PerfRules.visibleRooms(
					rooms,
					{ x = root.Position.X, z = root.Position.Z, level = level },
					perf.CullRooms
				)
				hidden = 0
				for i = #list, 1, -1 do
					local item = list[i]
					local info = known[item]
					if item.Parent == nil then
						table.remove(list, i)
					elseif visible[info.room] then
						if item.Parent == holder then
							item.Parent = info.parent
						end
					else
						if item.Parent == info.parent then
							item.Parent = holder
						end
						hidden += 1
					end
				end
			end)
		end
	end)
	return function()
		return hidden
	end
end

return RoomCull
