--!nonstrict
-- Armes : distribution du loadout et résolution des attaques côté serveur.
-- Le client n'envoie QUE la direction de visée ; origine, portée, cadence,
-- dégâts et cibles sont décidés ici.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Combat = require(Shared.Combat)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local DataService = require(Server.DataService)
local PlayerService = require(Server.PlayerService)
local CombatService = require(Server.CombatService)
local RateLimiter = require(Server.RateLimiter)
local WeaponFactory = require(Server.WeaponFactory)

local WeaponService = {}

local lastUse = setmetatable({}, { __mode = "k" })
local lastAny = setmetatable({}, { __mode = "k" }) -- dernier tir de n'importe quelle arme, par joueur
local projectiles = {}
local nextProjectileId = 0

-- ===== Loadout =====
local function clearWeapons(container)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			child:Destroy()
		end
	end
end

function WeaponService.GiveLoadout(player)
	local profile = DataService.Get(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack or player.Character ~= character then
		return
	end
	clearWeapons(backpack)
	clearWeapons(character)
	local first
	for _, id in ipairs(profile.Loadout) do
		local def = Weapons.Get(id)
		if def and profile.Owned[id] then
			local tool = WeaponFactory.Build(def)
			tool.Parent = backpack
			first = first or tool
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if first and humanoid then
		humanoid:EquipTool(first)
	end
end

-- ===== Cibles =====
local function listTargets(excludeModel)
	local out = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local ch = pl.Character
		if ch and ch ~= excludeModel then
			local hum = ch:FindFirstChildOfClass("Humanoid")
			local root = ch:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and root then
				table.insert(out, { Model = ch, Humanoid = hum, Root = root, Player = pl })
			end
		end
	end
	for _, dummy in ipairs(CollectionService:GetTagged("Dummy")) do
		local hum = dummy:FindFirstChildOfClass("Humanoid")
		local root = dummy:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and root then
			table.insert(out, { Model = dummy, Humanoid = hum, Root = root, Player = nil })
		end
	end
	return out
end

local function rayParams(...)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ... }
	params.IgnoreWater = true
	return params
end

local function hasLineOfSight(from, target, attackerChar)
	local to = target.Root.Position
	local result = workspace:Raycast(from, to - from, rayParams(attackerChar, target.Model))
	return result == nil
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function knockback(target, dir, power)
	if target.Player and power and power > 0 then
		local v = flat(dir)
		if v.Magnitude > 0.01 then
			v = v.Unit
		end
		Remotes.Fx:FireClient(target.Player, "Knockback", v * power + Vector3.new(0, power * 0.35, 0))
	end
end

-- ===== Types d'attaque =====
local function fireMelee(player, def, char, root, head, aim)
	local aimFlat = flat(aim)
	if aimFlat.Magnitude < 0.05 then
		aimFlat = flat(root.CFrame.LookVector)
	end
	Remotes.Fx:FireAllClients("Swing", player, def.Kind, def.Accent)

	for _, t in ipairs(listTargets(char)) do
		local delta = t.Root.Position - root.Position
		if flat(delta).Magnitude <= def.Range + 1.5 and math.abs(delta.Y) <= def.Range * 0.8 + 2 then
			if Combat.InCone(aimFlat.X, aimFlat.Z, delta.X, delta.Z, def.Arc or 90) and hasLineOfSight(head.Position, t, char) then
				local look = t.Root.CFrame.LookVector
				local backstab = def.BackstabMult ~= nil and Combat.IsBackstab(look.X, look.Z, delta.X, delta.Z)
				local dealt, killed = CombatService.DealDamage(player, t.Model, def.Damage, {
					Weapon = def,
					Backstab = backstab,
					Origin = root.Position,
				})
				if dealt > 0 and not killed then
					knockback(t, delta, def.Knockback)
				end
			end
		end
	end
end

local function fireSlam(player, def, char, root, aim)
	local aimFlat = flat(aim)
	if aimFlat.Magnitude < 0.05 then
		aimFlat = flat(root.CFrame.LookVector)
	end
	aimFlat = aimFlat.Unit
	local center = root.Position + aimFlat * (def.Range * 0.7) - Vector3.new(0, 2.5, 0)
	Remotes.Fx:FireAllClients("Swing", player, def.Kind, def.Accent)
	Remotes.Fx:FireAllClients("Slam", center, def.Radius, def.Accent)

	for _, t in ipairs(listTargets(char)) do
		local delta = t.Root.Position - center
		local dist = flat(delta).Magnitude
		if dist <= def.Radius and math.abs(delta.Y) <= 7 then
			local dealt, killed = CombatService.DealDamage(player, t.Model, def.Damage, {
				Weapon = def,
				Falloff = Combat.SplashFalloff(dist, def.Radius),
				Origin = center,
			})
			if dealt > 0 and not killed then
				knockback(t, delta, def.Knockback)
			end
		end
	end
end

-- Un tir instantané ; renvoie le point d'arrivée.
local function hitscan(player, def, char, origin, dir, range)
	local result = workspace:Raycast(origin, dir * range, rayParams(char))
	if not result then
		return origin + dir * range
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		CombatService.DealDamage(player, model, def.Damage, {
			Weapon = def,
			Headshot = result.Instance.Name == "Head",
			Origin = origin,
		})
	end
	return result.Position
end

local function fireHitscan(player, def, char, head, aim)
	local origin = head.Position
	local endPos = hitscan(player, def, char, origin, aim, def.Range)
	Remotes.Fx:FireAllClients("Tracer", { origin + aim * 2 - Vector3.new(0, 0.7, 0) }, { endPos }, def.Accent, def.Id == "rail")
end

local function fireShotgun(player, def, char, head, aim)
	local origin = head.Position
	local ends = {}
	local starts = {}
	local basis = CFrame.lookAt(Vector3.zero, aim)
	for _ = 1, def.Pellets do
		local yaw, pitch = Combat.SpreadAngles(def.Spread, math.random(), math.random())
		local dir = (basis * CFrame.Angles(pitch, yaw, 0)).LookVector
		table.insert(ends, hitscan(player, def, char, origin, dir, def.Range))
		table.insert(starts, origin + dir * 2 - Vector3.new(0, 0.7, 0))
	end
	Remotes.Fx:FireAllClients("Tracer", starts, ends, def.Accent, false)
end

local function fireProjectile(player, def, char, head, aim)
	nextProjectileId += 1
	local id = nextProjectileId
	local origin = head.Position + aim * 2.2
	local velocity = aim * def.Speed
	table.insert(projectiles, {
		Id = id,
		Owner = player,
		Char = char,
		Def = def,
		Pos = origin,
		Vel = velocity,
		Gravity = def.Gravity or 0,
		Age = 0,
		Max = def.Range / def.Speed + 0.5,
		Params = rayParams(char),
	})
	Remotes.Fx:FireAllClients("Projectile", id, origin, velocity, def.Gravity or 0, def.Accent, def.Splash ~= nil, def.Range / def.Speed + 0.5)
end

local function explode(pr, position)
	local def = pr.Def
	Remotes.Fx:FireAllClients("Explosion", position, def.Splash, def.Accent)
	for _, t in ipairs(listTargets(pr.Char)) do
		local dist = (t.Root.Position - position).Magnitude
		if dist <= def.Splash + 2 then
			local dealt, killed = CombatService.DealDamage(pr.Owner, t.Model, def.Damage, {
				Weapon = def,
				Falloff = Combat.SplashFalloff(dist, def.Splash),
				Origin = position,
			})
			if dealt > 0 and not killed then
				knockback(t, t.Root.Position - position, 22)
			end
		end
	end
end

local function stepProjectiles(dt)
	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		if pr.Owner.Parent ~= Players then
			table.remove(projectiles, i)
		else
			pr.Vel += Vector3.new(0, -pr.Gravity * dt, 0)
			local step = pr.Vel * dt
			local result = workspace:Raycast(pr.Pos, step, pr.Params)
			if result then
				local def = pr.Def
				if def.Splash then
					explode(pr, result.Position + result.Normal * 0.5)
				else
					local model = result.Instance:FindFirstAncestorOfClass("Model")
					if model and model:FindFirstChildOfClass("Humanoid") then
						CombatService.DealDamage(pr.Owner, model, def.Damage, {
							Weapon = def,
							Headshot = result.Instance.Name == "Head",
							Origin = pr.Pos,
						})
					end
				end
				table.remove(projectiles, i)
			else
				pr.Pos += step
				pr.Age += dt
				if pr.Age > pr.Max or pr.Pos.Y < -100 then
					table.remove(projectiles, i)
				end
			end
		end
	end
end

-- ===== Entrée réseau =====
local function validAim(aim)
	if typeof(aim) ~= "Vector3" then
		return nil
	end
	local m = aim.Magnitude
	if m ~= m or m < 0.01 or m > 1e4 then
		return nil
	end
	return aim.Unit
end

local function onAttack(player, rawAim)
	if not RateLimiter.Check(player, "Attack", 12, 6) then
		return
	end
	local aim = validAim(rawAim)
	if not aim then
		return
	end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local head = char and char:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not root or not head then
		return
	end
	local tool = char:FindFirstChildOfClass("Tool")
	local def = tool and Weapons.Get(tool:GetAttribute("WeaponId"))
	if not def then
		return
	end
	local now = os.clock()
	if now - (lastUse[tool] or 0) < def.Cooldown * 0.85 or now - (lastAny[player] or 0) < 0.12 then
		return -- cadence de l'arme, et pas d'enchaînement par changement d'arme
	end
	lastUse[tool] = now
	lastAny[player] = now

	-- attaquer met fin à la protection d'apparition
	local shield = char:FindFirstChildOfClass("ForceField")
	if shield then
		shield:Destroy()
	end

	local kind = def.Kind
	if kind == "Melee" then
		fireMelee(player, def, char, root, head, aim)
	elseif kind == "Slam" then
		fireSlam(player, def, char, root, aim)
	elseif kind == "Hitscan" then
		fireHitscan(player, def, char, head, aim)
	elseif kind == "Shotgun" then
		fireShotgun(player, def, char, head, aim)
	elseif kind == "Projectile" then
		fireProjectile(player, def, char, head, aim)
	end
end

function WeaponService.Init()
	Remotes.Attack.OnServerEvent:Connect(onAttack)
	RunService.Heartbeat:Connect(stepProjectiles)
	PlayerService.CharacterCallbacks[#PlayerService.CharacterCallbacks + 1] = function(player)
		WeaponService.GiveLoadout(player)
	end
end

return WeaponService
