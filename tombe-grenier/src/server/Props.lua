--[[
  Props : objets de scène fixes avec une action (miroirs, télévision, cheval à bascule, photo d'intro).
  Remis à zéro à chaque partie (Props.setup) : chaque effet ne joue qu'une fois par partie.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local Noise = require(script.Parent.Noise)
local Locks = require(script.Parent.Locks)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerState = require(script.Parent.PlayerState)

local Props = {}

local used = {}          -- [part] = true : effet déjà joué cette partie
local tvRunning = false

local function prompt(part, action, object, onTriggered)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") and child.Name == "PropPrompt" then
			child:Destroy()
		end
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "PropPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.4
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p.Parent = part
	p.Triggered:Connect(onTriggered)
	return p
end

-- Le reflet : un sursaut, sans sang
local function reflectionScare(player, part, delay, text)
	task.delay(delay, function()
		Remotes.fire("Effect", player, { kind = "Scare" })
		Audio.play("porte", part, { lifetime = 4 })
		Noise.emit(part.Position, 0.5)
		PlayerState.addSanity(player, -15)
	end)
	Remotes.fire("Message", player, { text = text })
end

local function setupMirrors()
	for _, part in ipairs(CollectionService:GetTagged("Mirror")) do
		if part:IsA("BasePart") then
			if part.Name == "miroir fissuré" then
				prompt(part, "Regarder", part.Name, function(player)
					if used[part] then
						return
					end
					used[part] = true
					part.Transparency = 0.2
					part.Color = Color3.fromRGB(120, 130, 140)
					reflectionScare(player, part, 1,
						"Le miroir est fissuré. Ton reflet met une seconde à te suivre.")
				end)
			else
				prompt(part, "Regarder", part.Name, function(player)
					if used[part] then
						return
					end
					used[part] = true
					reflectionScare(player, part, 2,
						"Ton reflet tarde à bouger. Il regarde derrière toi.")
				end)
			end
		end
	end
end

-- Texte de la télévision : l'image montre la pièce vue de haut, et là où se trouve la créature
local function tvText(player)
	local at = workspace:GetAttribute("MonsterAt")
	local rid = at and MapBuilder.roomAt(at, true)
	local where = rid and MapBuilder.roomName(rid) or "une pièce vide"
	local st = player and PlayerState.get(player)
	local last = st and #st.log > 0 and st.log[#st.log] or nil
	local detail = last and (" Il y a un instant, tu étais en train de : " .. last .. ".") or ""
	return "Une image granuleuse : la pièce vue de haut. Tu y es, au milieu. La créature est dans " .. where .. "." .. detail
end

local function setupTV()
	for _, part in ipairs(CollectionService:GetTagged("TV")) do
		if part:IsA("BasePart") then
			prompt(part, "Allumer la télé", "Télévision", function(player)
				if used[part] or tvRunning then
					return
				end
				used[part] = true
				tvRunning = true
				Audio.play("statique_tv", part, { lifetime = 11 })
				Remotes.fire("Message", player, { text = tvText(player) })
				task.spawn(function()
					for _ = 1, 40 do
						local g = math.random(20, 150)
						part.Color = Color3.fromRGB(g, g, g)
						task.wait(0.25)
					end
					part.Color = Color3.fromRGB(25, 25, 28)
					tvRunning = false
				end)
			end)
		end
	end
end

-- Modèle visuel posé par DecorKit sur ce meuble (même nom), sinon la partie elle-même
local function visualOf(part)
	local root = workspace:FindFirstChild("TombeMap")
	local maison = root and root:FindFirstChild("Maison")
	local decor = maison and maison:FindFirstChild("Décor")
	return (decor and decor:FindFirstChild(part.Name)) or part
end

local function setPivot(visual, cf)
	if visual:IsA("Model") then
		visual:PivotTo(cf)
	else
		visual.CFrame = cf
	end
end

local function setupRocking()
	for _, part in ipairs(CollectionService:GetTagged("Rocking")) do
		if part:IsA("BasePart") then
			prompt(part, "Faire balancer", "Cheval à bascule", function(player)
				if used[part] then
					return
				end
				used[part] = true
				Remotes.fire("Message", player, { text = "Le cheval se met à balancer, seul." })
				Noise.emit(part.Position, 0.5)
				Audio.play("chaise_grince", part, { lifetime = 4 })
				local visual = visualOf(part)
				local origin = visual:IsA("Model") and visual:GetPivot() or visual.CFrame
				task.spawn(function()
					-- Trois balancements, angle maximal de 6 degrés, sans tween (le modèle est animé image par image)
					for _ = 1, 3 do
						for k = 0, 40 do
							local angle = math.rad(6) * math.sin(k / 40 * math.pi * 2)
							setPivot(visual, origin * CFrame.Angles(0, 0, angle))
							task.wait(0.05)
						end
					end
					setPivot(visual, origin)
				end)
			end)
		end
	end
end

-- Photo de l'introduction : tombe depuis le cercueil. Lue, elle déclenche le premier flashback.
local introPart = nil
local introStart = nil -- position de départ de la chute (au-dessus du cercueil)
local function setupIntroPhoto()
	for _, part in ipairs(CollectionService:GetTagged("IntroPhoto")) do
		if part:IsA("BasePart") then
			introPart = part
			introStart = introStart or part.Position
			prompt(part, "Ramasser", "Photo jaunie", function(player)
				if used[part] then
					return
				end
				used[part] = true
				part.Transparency = 1
				Remotes.fire("Flashback", player, { kind = "intro" })
				Remotes.fire("Message", player, {
					text = "Une photo jaunie : une famille, devant cette maison.",
				})
			end)
		end
	end
end

-- Jouet musical : une mélodie se déclenche seule quand on le remonte
local function setupMusicBox()
	for _, part in ipairs(CollectionService:GetTagged("MusicBox")) do
		if part:IsA("BasePart") then
			prompt(part, "Remonter le jouet", "Coffre à jouets", function(player)
				if used[part] then
					return
				end
				used[part] = true
				Remotes.fire("Message", player, { text = "Une mélodie douce se met en route, toute seule." })
				Noise.emit(part.Position, 0.4)
				Audio.play("chaise_grince", part, { lifetime = 3 })
			end)
		end
	end
end

-- Portes intérieures : ouvrir ou fermer (tween de transparence, collision suivie)
local function setDoor(panel, open)
	panel:SetAttribute("Open", open)
	TweenService:Create(panel, TweenInfo.new(0.6), { Transparency = open and 0.9 or 0 }):Play()
	panel.CanCollide = not open
	panel.CanQuery = not open -- une porte fermée bloque aussi la vue et les raycasts
end

local function setupDoors()
	for _, panel in ipairs(CollectionService:GetTagged("Door")) do
		if panel:IsA("BasePart") then
			local lock = panel:GetAttribute("Lock")
			-- Ouvertes au début de chaque partie, sauf celles dont le verrou n'est pas levé
			setDoor(panel, lock == nil or Locks.isOpen(lock))
			local p = prompt(panel, "Ouvrir", "Porte", function(player)
				local name = panel:GetAttribute("Lock")
				if name and not Locks.isOpen(name) then
					Remotes.fire("Message", player, { text = Locks.hint(name) })
					return
				end
				setDoor(panel, not panel:GetAttribute("Open"))
			end)
			-- Le texte suit l'état. Connexion unique par panneau (la carte peut être reconstruite)
			if not panel:GetAttribute("TextWired") then
				panel:SetAttribute("TextWired", true)
				panel:GetAttributeChangedSignal("Open"):Connect(function()
					local current = panel:FindFirstChild("PropPrompt")
					if current then
						current.ActionText = panel:GetAttribute("Open") and "Fermer" or "Ouvrir"
					end
				end)
			end
			p.ActionText = panel:GetAttribute("Open") and "Fermer" or "Ouvrir"
		end
	end
end

-- Remise à zéro pour une nouvelle partie
function Props.setup()
	used = {}
	tvRunning = false
	setupMirrors()
	setupTV()
	setupRocking()
	setupIntroPhoto()
	setupMusicBox()
	setupDoors()
	-- La photo tombe du cercueil au début de la partie
	if introPart and introStart then
		introPart.Transparency = 0
		introPart.Anchored = true
		introPart.CFrame = CFrame.new(introStart)
		TweenService:Create(introPart, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(introStart - Vector3.new(0, 3.8, 0)) }):Play()
	end
end

Props.setDoor = setDoor

return Props
