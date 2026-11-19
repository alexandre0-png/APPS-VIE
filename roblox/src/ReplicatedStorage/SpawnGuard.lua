-- ModuleScript : ReplicatedStorage/Shared/SpawnGuard
-- Garantit qu'un joueur a toujours un personnage dans la zone de jeu : (1) si aucun personnage n'apparaît dans les `noCharTimeout`
-- secondes (script d'arrivée planté, CharacterAutoLoads coupé), il est chargé ici ; (2) un joueur sous le sol, hors zone, trop haut ou en
-- chute libre est replacé au point de départ ; (3) chaque événement est tracé dans la console serveur avec le préfixe [Spawn].
-- Les décisions sont dans Spawn (pur, testé) ; ce module n'applique que du Roblox. Aucune erreur ne sort d'ici (tout sous pcall).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spawn = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Spawn"))

local SpawnGuard = {}

-- opts = { role = "game" | "hub", safeCFrame = function(player) -> CFrame, interval = 0.5 }
function SpawnGuard.attach(opts)
	local cfg = Spawn.PRESETS[opts.role] or Spawn.PRESETS.game
	local tally = Spawn.newTally()
	local noChar = {} -- Player -> secondes sans personnage
	local loading = {} -- Player -> true pendant un LoadCharacterAsync lancé ici
	local function log(msg)
		print("[Spawn] (" .. opts.role .. ") " .. msg)
	end

	local function safeCF(player)
		local ok, cf = pcall(opts.safeCFrame, player)
		if ok and typeof(cf) == "CFrame" then
			return cf
		end
		return CFrame.new(0, 10, 0)
	end

	local function place(player, root, reason)
		local n = tally.add(reason, os.clock())
		local cf = safeCF(player)
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.CFrame = cf
		end)
		log(player.Name .. " replacé (" .. reason .. ") vers " .. string.format("%.0f, %.0f, %.0f", cf.X, cf.Y, cf.Z) .. " [" .. tally.total .. " au total]")
		if n > 6 then
			warn("[Spawn] (" .. opts.role .. ") plus de 6 sauvetages en une minute : un joueur retombe en boucle, vérifie le point de départ")
		end
	end

	Players.PlayerAdded:Connect(function(player)
		log(player.Name .. " arrivé (" .. #Players:GetPlayers() .. " joueur(s), CharacterAutoLoads = " .. tostring(Players.CharacterAutoLoads) .. ")")
		player.CharacterAdded:Connect(function(char)
			log(player.Name .. " : personnage apparu")
			task.defer(function()
				local root = char:WaitForChild("HumanoidRootPart", 5)
				if root and player.Parent then
					local st = { hasChar = true, alive = true, x = root.Position.X, y = root.Position.Y, z = root.Position.Z, vy = 0 }
					local reason = Spawn.rescueReason(st, cfg)
					if reason then
						place(player, root, reason)
					end
				end
			end)
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(opts.interval or 0.5)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(function()
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if not root then
						noChar[player] = (noChar[player] or 0) + (opts.interval or 0.5)
					else
						noChar[player] = 0
					end
					local pos = root and root.Position
					local st = {
						hasChar = root ~= nil, alive = hum == nil or hum.Health > 0, waited = noChar[player] or 0,
						x = pos and pos.X, y = pos and pos.Y, z = pos and pos.Z, vy = root and root.AssemblyLinearVelocity.Y or 0,
					}
					local reason = Spawn.rescueReason(st, cfg)
					if reason == "nochar" then
						if not loading[player] and player.Parent then
							loading[player] = true
							noChar[player] = 0
							tally.add("nochar", os.clock())
							log(player.Name .. " sans personnage depuis " .. cfg.noCharTimeout .. " s : chargement forcé")
							task.spawn(function()
								local ok, err = pcall(function()
									player:LoadCharacterAsync()
								end)
								if not ok then
									warn("[Spawn] (" .. opts.role .. ") LoadCharacterAsync a échoué pour " .. player.Name .. " : " .. tostring(err))
								end
								loading[player] = nil
							end)
						end
					elseif reason and root then
						place(player, root, reason)
					end
				end)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		noChar[player] = nil
		loading[player] = nil
	end)
	log("filet de sécurité actif (sol " .. cfg.floorY .. ", demi-zone " .. cfg.half .. ")")
	return tally
end

return SpawnGuard
