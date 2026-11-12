--[[
	StoryService : "L'Affaire du Coffre". Quatre énigmes à résoudre dans l'ordre en se rendant sur place
	(détection côté serveur), chacune révèle un chiffre ; le code à 4 chiffres ouvre le coffre final.
	Le client ne peut ni sauter de chapitre ni deviner le code sans les chiffres : 2 s entre deux essais,
	et seuls les chaînes de 4 chiffres sont acceptées.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local RemoteService = require(script.Parent.RemoteService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)

local StoryService = {}

local story = Config.Story

local function step()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.get(player)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if profile and hrp and not profile.Story.done then
			local nextCh = story.Chapters[profile.Story.chapter + 1]
			if nextCh and Util.flatDistance(hrp.Position, Vector3.new(nextCh.x, 0, nextCh.z)) <= nextCh.radius then
				profile.Story.chapter += 1
				local paid = EconomyService.addCash(player, nextCh.reward, "story")
				EconomyService.addXP(player, nextCh.xp)
				local msg = string.format("Énigme %d/%d résolue : %s. Chiffre trouvé : %s  (+%s)", profile.Story.chapter, #story.Chapters, nextCh.name, nextCh.digit, Util.formatCash(paid))
				if profile.Story.chapter >= #story.Chapters then
					msg ..= " - Ouvre ton journal (J) pour entrer le code !"
				end
				RemoteService.notify(player, msg, "star")
				DataService.markDirty(player)
				EconomyService.pushState(player)
			end
		end
	end
end

local function onSubmit(player, code)
	local profile = DataService.get(player)
	if not profile or profile.Story.done then
		return
	end
	if profile.Story.chapter < #story.Chapters then
		RemoteService.notify(player, "Le coffre reste hors de portée : résous d'abord toutes les énigmes.", "bad")
		return
	end
	if code == story.Code then
		profile.Story.done = true
		local paid = EconomyService.addCash(player, story.FinalReward, "story")
		EconomyService.addXP(player, story.FinalXP)
		EconomyService.addStat(player, "storyDone", 1)
		RemoteService.notify(player, string.format("COFFRE OUVERT ! +%s - Tu es le Détective de la ville !", Util.formatCash(paid)), "levelup")
		DataService.markDirty(player)
		EconomyService.pushState(player)
	else
		RemoteService.notify(player, "Code erroné. Relis les chiffres de ton journal.", "bad")
	end
end

function StoryService.init()
	RemoteService.on("SubmitCode", 2, function(code)
		return type(code) == "string" and #code == 4 and code:match("^%d%d%d%d$") ~= nil
	end, onSubmit)
end

function StoryService.start()
	Util.supervise("StoryService", function()
		while true do
			task.wait(0.5)
			step()
		end
	end)
end

return StoryService
