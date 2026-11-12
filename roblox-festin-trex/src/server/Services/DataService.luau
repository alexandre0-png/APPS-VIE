--!nonstrict
-- Chargement / sauvegarde des profils avec verrou de session (anti-duplication entre serveurs).
-- Le DataStore est injectable (_setStore) pour pouvoir tester la logique hors Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = {}

local store: any = nil
local clock: () -> number = os.time
local jobId: string = ""
local sleep: (number) -> () = function(s)
	task.wait(s)
end

local function getStore()
	if store == nil then
		store = game:GetService("DataStoreService"):GetDataStore(Config.Data.StoreName)
		jobId = game.JobId
		if jobId == "" then
			jobId = "studio"
		end
	end
	return store
end

-- Pour les tests : remplace le magasin, l'horloge, l'identifiant de serveur et l'attente.
function DataService._setStore(fakeStore: any, fakeClock: (() -> number)?, fakeJobId: string?, fakeSleep: ((number) -> ())?)
	store = fakeStore
	if fakeClock then
		clock = fakeClock
	end
	jobId = fakeJobId or "test"
	if fakeSleep then
		sleep = fakeSleep
	end
end

-- Migrations : Migrations[n] convertit un profil de la version n vers n+1.
-- Les ajouts de clés sont gérés par Util.reconcile (pas besoin de migration).
DataService.Migrations = {} :: { [number]: (any) -> () }

function DataService.migrate(data: any)
	local current = Config.DataVersion
	if type(data.version) ~= "number" then
		data.version = 1
	end
	-- Un profil plus récent que ce serveur n'est jamais « rétrogradé ».
	while data.version < current do
		local step = DataService.Migrations[data.version]
		if step then
			step(data)
		end
		data.version += 1
	end
end

local function keyFor(userId: number): string
	return "P_" .. tostring(userId)
end

local function lockIsForeign(record: any): boolean
	local lock = record and record.lock
	if not lock then
		return false
	end
	if lock.job == jobId then
		return false
	end
	return (clock() - (lock.t or 0)) < Config.Data.LockSeconds
end

-- Retourne (data, nil) ou (nil, raison). Prend le verrou de session.
function DataService.load(userId: number): (any?, string?)
	local s = getStore()
	local lastError = "inconnu"
	for attempt = 1, Config.Data.LoadRetries do
		local captured: any = nil
		local blocked = false
		local ok, err = pcall(function()
			s:UpdateAsync(keyFor(userId), function(old)
				captured = nil
				blocked = false
				old = old or {}
				if lockIsForeign(old) then
					blocked = true
					return nil -- annule l'écriture
				end
				captured = old.data
				old.lock = { job = jobId, t = clock() }
				return old
			end)
		end)
		if ok and not blocked then
			local data = if captured ~= nil then Util.deepCopy(captured) else {}
			Util.reconcile(data, Config.Defaults)
			DataService.migrate(data)
			return data, nil
		end
		lastError = if blocked then "session déjà ouverte sur un autre serveur" else tostring(err)
		if attempt < Config.Data.LoadRetries then
			sleep(Config.Data.LoadRetryDelay)
		end
	end
	return nil, lastError
end

-- Sauvegarde. release=true libère le verrou (départ du joueur). Retourne true si écrit.
-- Réessaie jusqu'à 3 fois en cas d'erreur DataStore ; un verrou étranger n'est jamais écrasé (pas de réessai).
function DataService.save(userId: number, data: any, release: boolean): boolean
	local s = getStore()
	for attempt = 1, 3 do
		local written = false
		local ok = pcall(function()
			s:UpdateAsync(keyFor(userId), function(old)
				written = false
				old = old or {}
				if lockIsForeign(old) then
					return nil -- un autre serveur détient le profil : on n'écrase rien
				end
				old.data = data
				old.lock = if release then nil else { job = jobId, t = clock() }
				written = true
				return old
			end)
		end)
		if ok then
			return written
		end
		if attempt < 3 then
			sleep(attempt)
		end
	end
	return false
end

return DataService
