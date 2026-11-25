-- ModuleScript : StarterPlayer/StarterPlayerScripts/BaseUpgradeFx
-- Montée de niveau de la maison (REFONTE lot 5, D.4), côté client : échafaudage de bois (Parts temporaires locales), nuage de poussière + onde (VfxKit),
-- l'ancienne maison s'enfonce, la nouvelle monte avec squash & stretch. Le calendrier vient du module pur Upgrade (4,5 s) ; la bannière, la fanfare et les
-- confettis viennent de la notification serveur « levelup » (au début de la fête). Le serveur garde la nouvelle maison sous le sol puis la remet en place
-- après 4,5 s quoi qu'il arrive : si cet effet échoue ou est passé, la maison apparaît quand même. Tout sous pcall, tout est nettoyé, aucune cinématique ici
-- (la caméra large est celle de Cinematics). Les Parts de l'échafaudage sont locales : aucun autre joueur ne les voit comme des objets du serveur.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local BaseUpgradeFx = {}

-- env = { Config, Upgrade (instance du module Upgrade), vfx = function(names, tier, cframe), skipEvent (BindableEvent facultatif) }
-- Retourne { run = function(p, from, to), skip = function(), active = function() }
-- Nuage de poussière : une salve de fumée (Part invisible locale, supprimée par Debris).
local function puff(position)
	pcall(function()
		local anchor = Instance.new("Part")
		anchor.Name = "UpgradeDust"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = position
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(214, 200, 176), Color3.fromRGB(176, 164, 146))
		e.Rate = 0
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(8, 22)
		e.SpreadAngle = Vector2.new(180, 60)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = anchor
		anchor.Parent = workspace
		e:Emit(40)
		Debris:AddItem(anchor, 3)
	end)
end

function BaseUpgradeFx.start(env)
	local Config, U = env.Config, env.Upgrade
	local F = Config.UPGRADE_FX
	local current = nil -- animation en cours (une seule à la fois, la plus récente remplace la précédente)
	local api = {}

	local function cleanup(run)
		if run.conn then
			pcall(function()
				run.conn:Disconnect()
			end)
			run.conn = nil
		end
		for _, part in ipairs(run.scaffold) do
			pcall(function()
				part:Destroy()
			end)
		end
		run.scaffold = {}
		-- l'état local est restitué exactement : la nouvelle maison à sa place et à l'échelle 1, la dalle de nouveau solide
		pcall(function()
			if run.new and run.new.Parent and run.final then
				run.new:ScaleTo(1)
				run.new:PivotTo(run.final)
			end
		end)
		for _, plate in ipairs(run.plates) do
			pcall(function()
				if plate.Parent then
					plate.CanCollide = true
				end
			end)
		end
		run.plates = {}
		if current == run then
			current = nil
		end
	end

	local function findHouse(cf)
		local world = workspace:FindFirstChild("World")
		if not world then
			return nil
		end
		for _, m in ipairs(world:GetChildren()) do
			local nu = m:FindFirstChild("BaseUpgrade")
			local final = nu and nu:GetAttribute("FinalPivot")
			if nu and typeof(final) == "CFrame" and (final.Position - cf.Position).Magnitude < 4 then
				return m, nu, final
			end
		end
		return nil
	end

	-- Une animation pour le joueur p dont le niveau passe de `from` à `to`.
	function api.run(p, from, to)
		local ok, err = pcall(function()
			if current then
				cleanup(current)
			end
			local cf = p:GetAttribute("PlotCF")
			if typeof(cf) ~= "CFrame" then
				return
			end
			local cam = workspace.CurrentCamera
			if cam and (cam.CFrame.Position - cf.Position).Magnitude > 260 then
				return -- trop loin pour voir : le serveur remet la maison en place seul
			end
			local run = { scaffold = {}, plates = {}, t0 = os.clock(), p = p, dust1 = false, dust2 = false }
			current = run
			local halfX, backZ = Config.baseExtent(to)
			local wait0 = os.clock()
			local waited = false
			run.conn = RunService.Heartbeat:Connect(function()
				local okStep, errStep = pcall(function()
					if current ~= run then
						return
					end
					if not run.new then -- la nouvelle maison peut arriver un peu après l'attribut : on réessaie ~1 s
						local _, nu, final = findHouse(cf)
						if nu then
							local plotModel = nu.Parent
							run.new, run.final, run.old = nu, final, plotModel:FindFirstChild("BaseUpgradeOld")
							run.oldFinal = run.old and run.old:GetPivot() or nil
							run.t0 = os.clock()
							for _, d in ipairs(nu:GetChildren()) do
								if d.Name == "BasePlate" then
									d.CanCollide = false
									run.plates[#run.plates + 1] = d
								end
							end
							if run.old then
								for _, d in ipairs(run.old:GetChildren()) do
									if d.Name == "BasePlate" then
										d.CanCollide = false
									end
								end
							end
							-- échafaudage : 4 poteaux et 2 niveaux de traverses autour de l'emprise de la maison (à l'arrière de la plateforme)
							local x0, x1, z0, z1 = -halfX * 0.62, halfX * 0.62, backZ - 24, backZ - 3
							local function plank(name, material)
								local part = Instance.new("Part")
								part.Name = name
								part.Anchored = true
								part.CanCollide = false
								part.CanQuery = false
								part.Material = material or Enum.Material.WoodPlanks
								part.Color = Color3.fromRGB(150, 104, 62)
								part.Size = Vector3.new(0.6, 0.6, 0.6)
								part.Parent = workspace
								run.scaffold[#run.scaffold + 1] = part
								return part
							end
							run.posts, run.rails = {}, {}
							for _, c in ipairs({ { x0, z0 }, { x1, z0 }, { x0, z1 }, { x1, z1 } }) do
								run.posts[#run.posts + 1] = { part = plank("ScaffoldPost"), x = c[1], z = c[2] }
							end
							for level = 1, 2 do
								for _, e in ipairs({ { 0, z0, x1 - x0, true }, { 0, z1, x1 - x0, true }, { x0, 0, z1 - z0, false }, { x1, 0, z1 - z0, false } }) do
									run.rails[#run.rails + 1] = { part = plank("ScaffoldRail"), level = level, cx = e[1], cz = e[2], len = e[3], alongX = e[4], mid = (z0 + z1) / 2 }
								end
							end
						elseif os.clock() - wait0 > 1 then
							waited = true
						end
						if waited or not run.new then
							if waited then
								cleanup(run)
							end
							return
						end
					end
					local st = U.state(os.clock() - run.t0)
					-- échafaudage
					local height = 12 * st.scaffold * (1 - st.strip)
					for _, e in ipairs(run.posts) do
						e.part.Size = Vector3.new(0.6, math.max(0.05, height), 0.6)
						e.part.CFrame = cf * CFrame.new(e.x, 1 + height / 2, e.z)
					end
					for _, e in ipairs(run.rails) do
						local y = 1 + height * (e.level == 1 and 0.5 or 1)
						local cx, cz = e.cx, e.cz
						if e.alongX then
							e.part.Size = Vector3.new(e.len, 0.5, 0.5)
						else
							e.part.Size = Vector3.new(0.5, 0.5, e.len)
							cz = e.mid
						end
						e.part.CFrame = cf * CFrame.new(cx, y, cz)
						e.part.Transparency = height < 0.5 and 1 or 0
					end
					-- poussière et onde
					if st.t >= U.dustAt and not run.dust1 then
						run.dust1 = true
						local at = cf * CFrame.new(0, 2, backZ - 12)
						if env.vfx then
							env.vfx({ "onde_de_choc" }, math.min(6, math.max(2, to - 1)), at)
						end
						puff(at.Position)
					end
					-- échange : l'ancienne maison s'enfonce, la nouvelle monte avec squash & stretch
					if st.t >= U.swapAt then
						if run.old and run.old.Parent and run.oldFinal then
							run.old:PivotTo(run.oldFinal * CFrame.new(0, -30 * st.drop, 0))
						end
						if run.new.Parent then
							run.new:PivotTo(run.final * CFrame.new(0, -F.hide * (1 - math.min(st.rise, 1.02)), 0))
							run.new:ScaleTo(1 + (st.sy - 1) * 0.4)
						end
						if not run.dust2 then
							run.dust2 = true
							puff((cf * CFrame.new(0, 2, backZ - 12)).Position)
						end
					end
					if st.done then
						cleanup(run)
					end
				end)
				if not okStep then
					warn("[BaseUpgradeFx] " .. tostring(errStep))
					cleanup(run)
				end
			end)
		end)
		if not ok then
			warn("[BaseUpgradeFx] " .. tostring(err))
			if current then
				cleanup(current)
			end
		end
	end

	-- Passer : la nouvelle maison reprend sa place tout de suite (le serveur fait de même à 4,5 s).
	function api.skip()
		if current then
			cleanup(current)
		end
	end
	function api.active()
		return current ~= nil
	end

	-- Écoute des montées de niveau de tous les joueurs (chacun voit la transformation des autres bases, sans caméra).
	local last = {}
	local function hook(p)
		local lv = p:GetAttribute("BaseLevel")
		last[p] = type(lv) == "number" and lv or nil
		p:GetAttributeChangedSignal("BaseLevel"):Connect(function()
			local now = p:GetAttribute("BaseLevel")
			if type(now) ~= "number" then
				return
			end
			local before = last[p]
			last[p] = now
			if before and now > before then
				api.run(p, before, now)
			end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
	if env.skipEvent then
		env.skipEvent.Event:Connect(api.skip)
	end
	return api
end

return BaseUpgradeFx
