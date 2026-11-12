-- Tests unitaires de la logique pure (Luau CLI, sans Roblox).
-- Lancer avec : ./tests/run.sh   (voir README)

local failures = 0
local total = 0

local function check(cond, msg)
	total += 1
	if not cond then
		failures += 1
		print("ÉCHEC : " .. msg)
	end
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-- Doublures minimales de l'API Roblox utilisée par DataService.
local stub
stub = setmetatable({}, {
	__index = function(_, k)
		if k == "WaitForChild" then
			return function()
				return stub
			end
		end
		return nil
	end,
})
game = {
	JobId = "",
	GetService = function()
		return stub
	end,
}

local Util = require("./Util")
local Config = require("./Config")
local Economy = require("./Economy")
local QuestLogic = require("./QuestLogic")
local DinoCore = require("./DinoCore")
local Ballistics = require("./Ballistics")
local DataService = require("./DataService")

-- ------------------------------------------------------------ Util
check(Util.formatNumber(0) == "0", "format 0")
check(Util.formatNumber(999) == "999", "format 999")
check(Util.formatNumber(1000) == "1K", "format 1000")
check(Util.formatNumber(1500) == "1.5K", "format 1500")
check(Util.formatNumber(999999) == "999.9K", "format 999999")
check(Util.formatNumber(1e6) == "1M", "format 1e6")
check(Util.formatNumber(12345678) == "12.3M", "format 12345678")
check(Util.clamp(5, 0, 3) == 3 and Util.clamp(-1, 0, 3) == 0 and Util.clamp(2, 0, 3) == 2, "clamp")
local r1, r2 = Util.lcg(42), Util.lcg(42)
check(r1() == r2() and r1() == r2(), "lcg déterministe")
local v = Util.lcg(7)()
check(v >= 0 and v < 1, "lcg dans [0,1)")
local items = { { id = "a", weight = 1 }, { id = "b", weight = 3 } }
check(Util.weightedPick(items, 0) == "a" and Util.weightedPick(items, 0.24) == "a" and Util.weightedPick(items, 0.26) == "b" and Util.weightedPick(items, 0.999) == "b", "weightedPick")
local target = { a = 1, nested = { x = 1 } }
Util.reconcile(target, { a = 9, b = 2, nested = { x = 5, y = 6 } })
check(target.a == 1 and target.b == 2 and target.nested.x == 1 and target.nested.y == 6, "reconcile")
local d1 = { t = { 1, 2 } }
local d2 = Util.deepCopy(d1)
d2.t[1] = 99
check(d1.t[1] == 1, "deepCopy indépendant")
check(Util.formatTime(125) == "2:05", "formatTime")

-- ------------------------------------------------------------ Economy
local function newData()
	return Util.deepCopy(Config.Defaults)
end
local d = newData()
local st = Economy.stats(d)
check(st.range == 60 and st.capacity == 6 and near(st.cooldown, 1.0) and near(st.coinMult, 1), "stats par défaut")
d.upgrades.power = 10
d.upgrades.rate = 10
d.upgrades.basket = 10
d.upgrades.greed = 15
st = Economy.stats(d)
check(st.range == 130 and st.capacity == 26 and near(st.cooldown, 0.3, 1e-9) and near(st.coinMult, 2.5), "stats niveaux max")
check(Economy.upgradeCost(Economy.findUpgrade("power"), 0) == 120, "coût niveau 0")
check(Economy.upgradeCost(Economy.findUpgrade("power"), 1) == 204, "coût niveau 1")
check(Economy.rebirthCost(0) == 20000 and Economy.rebirthCost(1) == 60000, "coût renaissance")
check(Economy.hitReward(10, 1, false, false, 1, 1) == 11, "récompense simple")
check(Economy.hitReward(10, 1, true, false, 1, 1) == 32, "récompense favori")
check(Economy.hitReward(10, 100, false, false, 1, 1) == 25, "combo plafonné")
check(Economy.hitReward(1, 0, false, false, 1, 0.01) == 1, "récompense minimale 1")
local lvl = Economy.level(0)
check(lvl == 1 and Economy.level(12) == 2, "niveaux")
local dp = newData()
dp.pets.poussin = 1
dp.equipped = { "poussin", "poussin", "inconnu", "raptor" }
check(near(Economy.petBonus(dp), 0.05), "bonus compagnon : doublons, inconnus et non possédés ignorés")
dp.pets.raptor = 1
check(near(Economy.petBonus(dp), 0.05 + 0.06), "bonus compagnon cumulé")
check(Economy.rollPet("classic", 0, 0) == "poussin", "tirage commun")
local top = Economy.rollPet("classic", 0.9999, 0)
check(Economy.findPet(top).Rarity == "mythique", "tirage mythique")
for i = 1, 50 do
	local rng = Util.lcg(i)
	check(Economy.findPet(Economy.rollPet("gold", rng(), rng())) ~= nil, "tirage toujours valide")
end
check(Economy.feastCoins(1, 1, 0) == 800 and Economy.feastCoins(1, 0, 0) == 160, "récompense festin")

-- ------------------------------------------------------------ QuestLogic
local qa = QuestLogic.generate(20000, 12345)
local qb = QuestLogic.generate(20000, 12345)
check(#qa == 3 and qa[1].kind == qb[1].kind and qa[2].target == qb[2].target, "quêtes déterministes")
local kinds = {}
for _, q in ipairs(qa) do
	check(kinds[q.kind] == nil, "types de quête distincts")
	kinds[q.kind] = true
end
local qd = newData()
qd.quests = { day = 0, list = {} }
check(QuestLogic.ensure(qd, 100, 1) == true and #qd.quests.list == 3, "ensure génère")
check(QuestLogic.ensure(qd, 100, 1) == false, "ensure idempotent le même jour")
qd.quests.list = { { kind = "feed", target = 10, coins = 500, eggs = 1, progress = 0, claimed = false }, { kind = "combo", target = 8, coins = 700, eggs = 0, progress = 0, claimed = false } }
check(QuestLogic.progress(qd, "feed", 4) and qd.quests.list[1].progress == 4, "progression additive")
QuestLogic.progress(qd, "feed", 100)
check(qd.quests.list[1].progress == 10, "progression plafonnée")
QuestLogic.progress(qd, "combo", 5)
QuestLogic.progress(qd, "combo", 3)
check(qd.quests.list[2].progress == 5, "progression max (ne diminue pas)")
local coins, eggs = QuestLogic.claim(qd, 1)
check(coins == 500 and eggs == 1, "claim récompense")
check(QuestLogic.claim(qd, 1) == nil, "claim double refusé")
check(QuestLogic.claim(qd, 2) == nil, "claim incomplet refusé")
check(QuestLogic.claim(qd, 9) == nil, "claim hors index refusé")
local ds = newData()
local can, nextDay = QuestLogic.dailyStatus(ds, 500)
check(can and nextDay == 1, "série : premier jour")
local c1 = QuestLogic.claimDaily(ds, 500)
check(c1 == 200, "série : jour 1 = 200")
check(QuestLogic.claimDaily(ds, 500) == nil, "série : double réclamation refusée")
local c2 = QuestLogic.claimDaily(ds, 501)
check(c2 == 400 and ds.streak.count == 2, "série : jour consécutif")
QuestLogic.claimDaily(ds, 505)
check(ds.streak.count == 1, "série : réinitialisée après une absence")

-- ------------------------------------------------------------ DinoCore
local dino = DinoCore.new()
check(dino:need() == 600 and dino:isHungry(), "dino initial affamé")
check(dino:add(1, 300) == false and dino:add(2, 299) == false, "pas de festin avant le seuil")
check(dino:add(1, 1) == true, "festin au seuil")
local contrib, total2, finished = dino:completeFeast()
check(contrib[1] == 301 and contrib[2] == 299 and total2 == 600 and finished == 1, "contributions du festin")
check(dino.stage == 2 and dino.satiety == 0 and dino.feasts == 1, "stade suivant")
dino.satiety = 100
dino:decay(10)
check(near(dino.satiety, 100 - 1500 * 0.003 * 10), "décroissance")
dino.satiety = 0
dino:decay(100)
check(dino.satiety == 0, "satiété jamais négative")
dino.stage = #Config.Dino.Stages
dino:completeFeast()
check(dino.stage == #Config.Dino.Stages, "stade plafonné")

-- ------------------------------------------------------------ Ballistics
for _, T in ipairs({ 0.35, 0.8, 1.8 }) do
	local ox, oy, oz, tx, ty, tz = 3, 5, 100, -10, 21, 20
	local vx, vy, vz = Ballistics.launchVelocity(ox, oy, oz, tx, ty, tz, T, 196.2)
	local x, y, z = Ballistics.position(ox, oy, oz, vx, vy, vz, T, 196.2)
	check(near(x, tx) and near(y, ty, 1e-6) and near(z, tz), "la balistique atteint la cible à T=" .. T)
end
check(Ballistics.flightTime(1, 70, 0.35, 1.8) == 0.35 and Ballistics.flightTime(1000, 70, 0.35, 1.8) == 1.8, "temps de vol borné")

-- ------------------------------------------------------------ DataService (verrou de session)
local function newFakeStore()
	local store = { rows = {}, fail = false, calls = 0 }
	function store:UpdateAsync(key, fn)
		self.calls += 1
		if self.fail then
			error("DataStore indisponible")
		end
		local old = Util.deepCopy(self.rows[key])
		local new = fn(old)
		if new ~= nil then
			self.rows[key] = Util.deepCopy(new)
		end
		return new
	end
	return store
end

local now = 1000
local function clock()
	return now
end
local sleeps = 0
local function sleep()
	sleeps += 1
end

local store = newFakeStore()
DataService._setStore(store, clock, "serveurA", sleep)
local data, err = DataService.load(1)
check(data ~= nil and err == nil, "chargement d'un nouveau joueur")
check(data.coins == 0 and data.foods.pomme == true, "profil par défaut complété")
check(store.rows["P_1"].lock.job == "serveurA", "verrou posé")
data.coins = 777
check(DataService.save(1, data, false) == true, "sauvegarde")
check(store.rows["P_1"].data.coins == 777, "données écrites")

DataService._setStore(store, clock, "serveurB", sleep)
local blocked, why = DataService.load(1)
check(blocked == nil and why ~= nil and string.find(why, "session", 1, true) ~= nil, "second serveur bloqué par le verrou")
check(sleeps == Config.Data.LoadRetries - 1, "tentatives avec attente")
check(DataService.save(1, { coins = 0 }, true) == false, "le second serveur ne peut pas écraser")
check(store.rows["P_1"].data.coins == 777, "données intactes")

now += Config.Data.LockSeconds + 1
local taken = DataService.load(1)
check(taken ~= nil and taken.coins == 777, "verrou périmé : reprise possible")

DataService._setStore(store, clock, "serveurB", sleep)
check(DataService.save(1, taken, true) == true and store.rows["P_1"].lock == nil, "libération du verrou au départ")
DataService._setStore(store, clock, "serveurA", sleep)
local again = DataService.load(1)
check(again ~= nil and again.coins == 777, "rechargement après libération")

store.fail = true
local failed, ferr = DataService.load(2)
check(failed == nil and ferr ~= nil, "erreur DataStore : pas de profil")
check(DataService.save(2, newData(), false) == false, "erreur DataStore : sauvegarde échoue proprement")

-- ------------------------------------------------------------ Game Passes
local dpass = newData()
dpass.passes = { vip = true, nest = true, aim = true }
local sp = Economy.stats(dpass)
check(near(sp.coinMult, 1.5) and sp.petSlots == 4 and near(sp.assist, 8), "effets des Game Passes")
check(Economy.petSlots(newData()) == 3, "emplacements sans pass")

print(string.format("%d vérifications, %d échec(s).", total, failures))
if failures > 0 then
	error("des tests ont échoué")
end
