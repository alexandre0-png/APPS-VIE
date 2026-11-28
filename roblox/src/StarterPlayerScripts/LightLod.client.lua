-- LocalScript : StarterPlayer/StarterPlayerScripts/LightLod
-- Niveau de détail des effets (lot graphismes, budget mobile) : au plus Config.GRAPHICS.perf.maxPointLights PointLight de la carte sont allumées (les plus proches de la
-- caméra, à moins de lightRange studs, choix de Graphics.selectLights) ; les émetteurs de particules, faisceaux, feux, fumées et étincelles au-delà de fxCullAt studs sont
-- coupés et rallumés sous fxShowAt (hystérésis de Culling.decide). Rien n'est détruit ni déplacé ; seules les propriétés Enabled changent, et SEULEMENT pour les objets que ce
-- script a lui-même coupés (un effet éteint par le jeu n'est jamais rallumé). Local au joueur. Coupé par Config.GRAPHICS.enabled = false ; une erreur le désactive.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Graphics = require(Shared:WaitForChild("Graphics"))
local Culling = require(Shared:WaitForChild("Culling"))
if not Config.GRAPHICS.enabled then
	return
end
local perf = Config.GRAPHICS.perf

local FX = { ParticleEmitter = true, Beam = true, Fire = true, Smoke = true, Sparkles = true, Trail = true }
local lights, fx = {}, {} -- instances suivies (au plus quelques centaines)
local heldOff = {} -- instance -> true : coupée par ce script
local culled = {} -- instance d'effet -> true : au-delà de fxCullAt
local lastScan = -math.huge

local function position(inst)
	local par = inst.Parent
	while par and not par:IsA("BasePart") and not par:IsA("Attachment") do
		par = par.Parent
	end
	if par and par:IsA("Attachment") then
		return par.WorldPosition
	end
	return par and par.Position or nil
end

local function rescan()
	lastScan = os.clock()
	local world = workspace:FindFirstChild("World")
	lights, fx = {}, {}
	if not world then
		return
	end
	for _, d in ipairs(world:GetDescendants()) do
		if d:IsA("PointLight") then
			lights[#lights + 1] = d
		elseif FX[d.ClassName] then
			fx[#fx + 1] = d
		end
	end
	for inst in pairs(heldOff) do -- objets disparus : on les oublie (pas de fuite)
		if not inst.Parent then
			heldOff[inst] = nil
			culled[inst] = nil
		end
	end
end

local function setEnabled(inst, on)
	if on then
		if heldOff[inst] then
			heldOff[inst] = nil
			inst.Enabled = true
		end
	elseif inst.Enabled then
		heldOff[inst] = true
		inst.Enabled = false
	end
end

task.spawn(function()
	while true do
		task.wait(perf.interval)
		local ok = pcall(function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			if os.clock() - lastScan > perf.rescan then
				rescan()
			end
			local cp = cam.CFrame.Position
			-- lumières : les plus proches seulement (celles coupées par le jeu sont ignorées, sauf si c'est ce script qui les a coupées)
			local pool, poolPos = {}, {}
			for _, l in ipairs(lights) do
				if l.Parent and (l.Enabled or heldOff[l]) then
					local pos = position(l)
					if pos then
						pool[#pool + 1] = l
						poolPos[#poolPos + 1] = { x = pos.X, y = pos.Y, z = pos.Z }
					end
				end
			end
			local on = Graphics.selectLights(poolPos, { x = cp.X, y = cp.Y, z = cp.Z }, perf.maxPointLights, perf.lightRange)
			for i, l in ipairs(pool) do
				setEnabled(l, on[i])
			end
			-- effets lointains
			for _, e in ipairs(fx) do
				if e.Parent and (e.Enabled or heldOff[e]) then
					local pos = position(e)
					if pos then
						local d = (pos - cp).Magnitude
						local hide = Culling.decide(d, culled[e] == true, perf.fxCullAt, perf.fxShowAt)
						culled[e] = hide or nil
						setEnabled(e, not hide)
					end
				end
			end
		end)
		if not ok then
			warn("[LightLod] désactivé pour cette session après une erreur")
			break
		end
	end
end)
