--!nonstrict
-- Œufs et compagnons : tirage serveur (aléatoire non manipulable par le client), équipement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economy = require(Shared:WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerService = require(script.Parent.PlayerService)

local PetService = {}

local function hatch(player: Player, eggKind: string): string
	local data = PlayerService.get(player)
	local petId = Economy.rollPet(eggKind, math.random(), math.random())
	local isDuplicate = (data.pets[petId] or 0) > 0
	data.pets[petId] = (data.pets[petId] or 0) + 1
	local refund = 0
	if isDuplicate then
		refund = math.floor(Config.Eggs[eggKind].Price * Config.DuplicateRefundFraction)
		PlayerService.addCoins(player, refund)
	end
	Remotes.get("Reveal"):FireClient(player, petId, isDuplicate, refund, eggKind)
	PlayerService.markDirty(player)
	return petId
end

-- Ouvre un œuf. source = "free" (œuf gratuit du stock) ou "coins".
function PetService.openEgg(player: Player, eggKind: any, source: any): (boolean, string)
	local data = PlayerService.get(player)
	if not data then
		return false, "Données non chargées"
	end
	if type(eggKind) ~= "string" or Config.Eggs[eggKind] == nil then
		return false, "Œuf inconnu"
	end
	if source == "free" then
		if eggKind ~= "classic" or data.eggs < 1 then
			return false, "Aucun œuf gratuit"
		end
		data.eggs -= 1
	elseif source == "coins" then
		if not PlayerService.trySpend(player, Config.Eggs[eggKind].Price) then
			return false, "Pas assez de pièces"
		end
	else
		return false, "Requête invalide"
	end
	hatch(player, eggKind)
	return true, "Éclosion !"
end

function PetService.equip(player: Player, petId: any, on: any): (boolean, string)
	local data = PlayerService.get(player)
	if not data then
		return false, "Données non chargées"
	end
	if type(petId) ~= "string" or type(on) ~= "boolean" or not Economy.findPet(petId) then
		return false, "Requête invalide"
	end
	if (data.pets[petId] or 0) < 1 then
		return false, "Tu ne possèdes pas ce compagnon"
	end
	local idx = table.find(data.equipped, petId)
	if on then
		if idx then
			return true, "Déjà équipé"
		end
		if #data.equipped >= Economy.petSlots(data) then
			return false, "Emplacements pleins : déséquipe un compagnon d'abord"
		end
		table.insert(data.equipped, petId)
	else
		if idx then
			table.remove(data.equipped, idx)
		end
	end
	PlayerService.markDirty(player)
	return true, "OK"
end

return PetService
