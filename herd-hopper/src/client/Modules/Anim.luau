-- Animations côté client (caméra, écran, bras du joueur). Chacune est derrière Config.Animations et encapsulée
-- en pcall via Anim.run : une animation qui échoue est signalée une fois puis ignorée, le jeu continue.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local AnimMath = require(Shared.AnimMath)

local CameraRig = require(script.Parent.CameraRig)
local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)

local Anim = {}

local player = Players.LocalPlayer
local warned = {}
Anim.failures = 0

-- Exécute fn si l'animation `flag` est activée. Renvoie true si elle s'est bien déroulée.
function Anim.run(flag, fn, ...)
	local cfg = Config.Animations
	if not cfg.Enabled or not cfg[flag] then
		return false
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		Anim.failures = Anim.failures + 1
		if not warned[flag] then
			warned[flag] = true
			warn("[Animation " .. flag .. "] " .. tostring(err))
		end
	end
	return ok
end

local function hrpOf()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- Survol de la zone au départ : la caméra arrive d'en avant et en hauteur, puis se place derrière le cavalier.
function Anim.zoneIntro()
	return Anim.run("ZoneIntro", function()
		local hrp = hrpOf()
		if not hrp or CameraRig.isCinematic() then
			return
		end
		local origin = hrp.Position
		CameraRig.cinematic(function(t)
			local e, height = AnimMath.flyover(t / 3.2)
			local start = origin + Vector3.new(60, 60, 230)
			local goal = origin + Vector3.new(0, 14, -30)
			local eye = start:Lerp(goal, e) + Vector3.new(0, height - AnimMath.lerp(60, 14, e), 0)
			return CFrame.lookAt(eye, origin + Vector3.new(0, 4, 40 * (1 - e)))
		end, 3.2)
	end)
end

-- Balayage de couleur entre deux zones (la bannière de zone est affichée par le HUD).
function Anim.zoneTransition(zone)
	return Anim.run("ZoneTransition", function()
		local gui = player:WaitForChild("PlayerGui"):FindFirstChild("HerdHopperWipe")
		if not gui then
			gui = UI.make(
				"ScreenGui",
				{ Name = "HerdHopperWipe", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40 },
				player.PlayerGui
			)
		end
		local band = UI.frame(gui, {
			Size = UDim2.new(0.6, 0, 1, 0),
			BackgroundColor3 = zone.tint,
			BackgroundTransparency = 1,
			Active = false,
		})
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.9 and band.Parent do
				local p = (os.clock() - t0) / 0.9
				local x, alpha = AnimMath.wipe(p)
				band.Position = UDim2.new(x * 0.8 - 0.3, 0, 0, 0)
				band.BackgroundTransparency = 1 - alpha
				task.wait()
			end
			band:Destroy()
		end)
	end)
end

-- Bras du joueur qui lance le lasso (local : seul le joueur le voit).
function Anim.throw()
	return Anim.run("Lasso", function()
		local char = player.Character
		local shoulder = char
			and (char:FindFirstChild("RightShoulder", true) or char:FindFirstChild("Right Shoulder", true))
		if not shoulder or not shoulder:IsA("Motor6D") then
			return
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.3 and shoulder.Parent do
				shoulder.Transform = CFrame.Angles(0, 0, AnimMath.throwArm(os.clock() - t0))
				RunService.Heartbeat:Wait()
			end
			if shoulder.Parent then
				shoulder.Transform = CFrame.new()
			end
		end)
	end)
end

-- Échec : l'écran se grise un instant (puis revient). `on` = true à la chute, false ensuite.
function Anim.deathTint(on)
	return Anim.run("Death", function()
		local color = Lighting:FindFirstChild("HHColor")
		if not color then
			return
		end
		UI.tween(color, 0.6, { Saturation = on and -0.75 or 0.12 })
	end)
end

-- Arrivée d'un boss : coup de zoom et secousse.
function Anim.bossPunch()
	return Anim.run("Boss", function()
		CameraRig.fovPunch(14, 1.4)
		CameraRig.shake(1.6, 0.6)
	end)
end

-- Branchements sur l'état du jeu (statut du joueur, zone atteinte).
function Anim.init()
	local lastStatus = ClientState.Status
	ClientState.connect("Status", function(status)
		if status == "Dead" then
			Anim.deathTint(true)
		elseif lastStatus == "Dead" then
			Anim.deathTint(false)
		end
		lastStatus = status
	end)

	local lastZone = player:GetAttribute("ZoneIdx") or 0
	player:GetAttributeChangedSignal("ZoneIdx"):Connect(function()
		local idx = player:GetAttribute("ZoneIdx") or 0
		if idx > lastZone and lastZone > 0 and Config.Zones[idx] then
			Anim.zoneTransition(Config.Zones[idx])
		end
		lastZone = idx
	end)
end

return Anim
