--!nonstrict
-- Chronique (chapitres) et choix du héros. Tout est validé côté serveur : progression lue dans le profil,
-- récompense unique par chapitre, héros utilisable seulement s'il est débloqué.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Lore = require(Shared.Lore)
local DataService = require(Server.DataService)
local PlayerService = require(Server.PlayerService)

local StoryService = {}

local function countRunes(profile)
	local n = 0
	for _, r in ipairs(Lore.Runes) do
		if profile.Runes[r.Id] then
			n += 1
		end
	end
	return n
end

local function stats(profile)
	return {
		Runes = countRunes(profile),
		Level = profile.Level,
		Kills = profile.Kills,
		Wins = profile.Wins,
		BestStreak = profile.BestStreak,
		Headshots = profile.Headshots,
	}
end

function StoryService.ClaimChapter(player, chapterId)
	local profile = DataService.Get(player)
	local chapter = type(chapterId) == "string" and Lore.Chapter(chapterId)
	if not profile or not chapter then
		return false, "Chapitre inconnu"
	end
	if profile.Chapters[chapter.Id] then
		return false, "Déjà lu"
	end
	if Lore.Progress(chapter, stats(profile)) < chapter.Target then
		return false, "Chapitre verrouillé"
	end
	profile.Chapters[chapter.Id] = true
	PlayerService.AddCoins(player, chapter.Coins, true)
	PlayerService.AddXP(player, chapter.XP)
	local extra = ""
	if chapter.Unlock then
		local hero = Lore.Hero(chapter.Unlock)
		extra = hero and ("  ·  héros débloqué : " .. hero.Name) or ""
	end
	PlayerService.Notify(player, "Reward", ("Chapitre terminé : %s%s"):format(chapter.Title, extra))
	PlayerService.Sync(player)
	return true, "Chapitre terminé"
end

-- Ramassage d'une rune : validé ici (id connu, une seule fois par joueur).
function StoryService.CollectRune(player, runeId)
	local profile = DataService.Get(player)
	if not profile or type(runeId) ~= "string" then
		return false
	end
	local known = false
	for _, r in ipairs(Lore.Runes) do
		known = known or r.Id == runeId
	end
	if not known or profile.Runes[runeId] then
		return false
	end
	profile.Runes[runeId] = true
	PlayerService.AddCoins(player, 25, true)
	local n = countRunes(profile)
	PlayerService.Notify(player, "Reward", ("Rune trouvée ! (%d / %d)  +25 🪙"):format(n, #Lore.Runes))
	PlayerService.Sync(player)
	return true
end

function StoryService.Init(map)
	local Players = game:GetService("Players")
	for _, rune in ipairs(map.Runes) do
		rune.Part.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			if player then
				StoryService.CollectRune(player, rune.Id)
			end
		end)
	end
end

function StoryService.SetHero(player, key)
	local profile = DataService.Get(player)
	if not profile or type(key) ~= "string" or not Lore.Hero(key) then
		return false, "Héros inconnu"
	end
	if not Lore.IsHeroUnlocked(key, profile.Chapters) then
		return false, "Héros verrouillé : terminez son chapitre"
	end
	profile.Hero = key
	player:SetAttribute("Hero", key)
	PlayerService.Sync(player)
	if player.Character then
		PlayerService.ApplyHero(player, player.Character)
	end
	return true, "Héros sélectionné"
end

return StoryService
