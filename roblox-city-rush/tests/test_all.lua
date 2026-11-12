local H = dofile(ROOT_DIR .. "/tests/harness.lua")
local V3, CF = H.V3, H.env.CFrame

local passed, failed, failures = 0, 0, {}
local function test(name, fn)
	if ONLY then
		local hit = false
		for pat in ONLY:gmatch("[^|]+") do if name:find(pat, 1, true) then hit = true end end
		if not hit then return end
	end
	H.reset()
	local ok, err = pcall(fn)
	if ok and #H.errors > 0 then ok, err = false, "erreur dans une coroutine: " .. H.errors[1] end
	if ok then passed = passed + 1; print("  OK   " .. name)
	else failed = failed + 1; failures[#failures + 1] = name .. " -> " .. tostring(err); print("  FAIL " .. name .. "\n       " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "eq") .. ": attendu " .. tostring(b) .. ", obtenu " .. tostring(a), 2) end end
local function near(a, b, tol, msg) if math.abs(a - b) > (tol or 1e-6) then error((msg or "near") .. ": attendu " .. tostring(b) .. ", obtenu " .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or "attendu vrai", 2) end end

local function client(player, name, ...) H.remote(name)._props.OnServerEvent:Fire(player, ...) end

local function boot()
	local M = {}
	M.Remote = H.mod("RemoteService"); M.Remote.init()
	M.Data = H.mod("DataService"); M.Data.init()
	M.Econ = H.mod("EconomyService"); M.Econ.init()
	M.Config = H.mod("Config")
	M.Util = H.mod("Util")
	return M
end
local function join(M, name, withChar)
	local p = H.addPlayer(name)
	H.advance(0.2)
	if withChar ~= false then H.spawnCharacter(p, V3.new(0, 3, 0)) end
	return p
end
local function lastFired(name, player)
	local list = H.remote(name)._fired
	for i = #list, 1, -1 do if not player or list[i].player == player then return list[i] end end
end
local function notifications(player)
	local out = {}
	for _, f in ipairs(H.remote("Notify")._fired) do if f.player == player then out[#out + 1] = f.args[1] end end
	return out
end

local function mockWorld()
	local root = H.Instance.new("Folder"); root.Name = "City"
	return {
		Root = root, PolicePoint = CF.new(0, 3, 372), Hideout = V3.new(-30, 0.5, -345),
		DeliveryPoints = { V3.new(300, 0.5, 0), V3.new(0, 0.5, 300) },
		TaxiStops = { V3.new(100, 0.5, 0), V3.new(500, 0.5, 0), V3.new(-300, 0.5, 100) },
		RaceCircuit = { V3.new(500, 0, -500), V3.new(0, 0, -500), V3.new(0, 0, 500) },
		StarSpots = { V3.new(50, 3, 50), V3.new(-50, 3, 50), V3.new(80, 3, -80) },
		RoadNodes = (function() local r = {}; for ix = 0, 5 do r[ix] = {}; for iz = 0, 5 do r[ix][iz] = V3.new(-500 + 200 * ix, 0, -500 + 200 * iz) end end; return r end)(), ParkingSpots = {}, BreakFolder = H.Instance.new("Folder"),
	}
end

print("== Util / Config")
test("Util.formatCash", function()
	local U = boot().Util
	eq(U.formatCash(0), "0 $"); eq(U.formatCash(999), "999 $"); eq(U.formatCash(1000), "1 000 $")
	eq(U.formatCash(1234567), "1 234 567 $"); eq(U.formatCash(-2500), "-2 500 $"); eq(U.formatCash(nil), "0 $")
end)
test("Util.formatTime / reconcile / weightedPick", function()
	local U = boot().Util
	eq(U.formatTime(65), "1:05"); eq(U.formatTime(-5), "0:00"); eq(U.formatTime(0), "0:00")
	local t = U.reconcile({ a = 1, n = { x = 1 } }, { a = 9, b = 2, n = { x = 5, y = 6 } })
	eq(t.a, 1); eq(t.b, 2); eq(t.n.x, 1); eq(t.n.y, 6)
	local pick = U.weightedPick({ { id = "a", weight = 1 }, { id = "b", weight = 3 } }, { NextNumber = function() return 0.99 end })
	eq(pick.id, "b")
end)
test("Config cohérente (véhicules, XP, succès)", function()
	local M = boot(); local C = M.Config
	local ids, lastPrice = {}, -1
	for _, v in ipairs(C.Vehicles) do
		truthy(not ids[v.id], "id dupliqué " .. v.id); ids[v.id] = true
		truthy(v.maxSpeed > 0 and v.accel > 0 and v.turn > 0, "stats invalides " .. v.id)
		if v.price > 0 then truthy(v.price > lastPrice, "prix non croissants " .. v.id); lastPrice = v.price end
	end
	for lvl = 1, C.MaxLevel - 1 do truthy(C.xpForNext(lvl + 1) > C.xpForNext(lvl), "xp non croissant") end
	local aid = {}
	local join1 = join(M, "A")
	local stats = M.Data.get(join1).Stats
	for _, a in ipairs(C.Achievements) do
		truthy(not aid[a.id], "succès dupliqué"); aid[a.id] = true
		truthy(stats[a.stat] ~= nil, "stat inconnue pour le succès " .. a.id .. ": " .. a.stat)
		truthy(a.goal > 0 and a.reward > 0)
	end
	for k, m in pairs(C.Missions) do truthy(m.minLevel >= 1 and m.baseReward > 0 and m.xp > 0, "mission " .. k) end
end)

print("== RemoteService")
test("RemoteService : rate limit, validateur, handlers multiples", function()
	local R = H.mod("RemoteService"); R.init()
	local p = H.addPlayer("R")
	local calls, calls2 = 0, 0
	R.on("RequestBuy", 1, function(a) return type(a) == "string" end, function() calls = calls + 1 end)
	R.on("RequestBuy", 0, nil, function() calls2 = calls2 + 1 end)
	client(p, "RequestBuy", "x"); client(p, "RequestBuy", "x")
	eq(calls, 1, "rate limit"); eq(calls2, 2, "deuxième handler indépendant du cooldown du premier")
	H.advance(1.1); client(p, "RequestBuy", 42); eq(calls, 1, "validateur rejette un nombre")
	client(p, "RequestBuy"); eq(calls, 1, "validateur rejette nil")
	local ok = pcall(function() R.on("Inconnu", 1, nil, function() end) end)
	eq(ok, false, "remote inconnu doit lever une erreur")
end)

print("== DataService")
test("nouveau joueur : profil par défaut + leaderstats + sauvegarde à la sortie", function()
	local M = boot(); local p = join(M, "Nouveau")
	local d = M.Data.get(p)
	eq(d.Cash, M.Config.StartCash); eq(d.Level, 1); eq(d.Owned.citadine, true); eq(d.Stats.joins, 1)
	eq(p.leaderstats.Argent.Value, M.Config.StartCash)
	d.Cash = 4321; M.Data.markDirty(p)
	H.removePlayer(p); H.advance(0.1)
	eq(H.ds.data["Player_" .. p.UserId].data.Cash, 4321, "données sauvegardées")
	eq(H.ds.data["Player_" .. p.UserId].job, nil, "verrou de session libéré")
	eq(M.Data.get(p), nil, "profil retiré de la mémoire")
end)
test("retour du joueur : progression conservée, joins incrémenté", function()
	local M = boot(); local p = join(M, "Retour")
	M.Data.get(p).Cash = 999; M.Data.get(p).Owned.sport = true; M.Data.markDirty(p)
	H.removePlayer(p); H.advance(0.1)
	local uid = p.UserId
	H.nextUserId = uid - 1
	local p2 = join(M, "Retour"); eq(p2.UserId, uid)
	eq(M.Data.get(p2).Cash, 999); eq(M.Data.get(p2).Owned.sport, true); eq(M.Data.get(p2).Stats.joins, 2)
end)
test("chargement impossible hors Studio : joueur expulsé, aucune écriture", function()
	local M = boot(); H.ds.failLoad = true
	local p = H.addPlayer("Panne"); H.advance(120)
	eq(M.Data.get(p), nil, "pas de profil")
	truthy(p._props.Kicked ~= nil, "expulsion")
	eq(H.ds.saves, 0, "rien écrit")
end)
test("chargement impossible en Studio : profil temporaire, jamais sauvegardé", function()
	local M = boot(); H.services.RunService.IsStudioValue = true; H.ds.failLoad = true
	local p = H.addPlayer("Studio"); H.advance(5)
	truthy(M.Data.get(p) ~= nil, "profil temporaire")
	eq(M.Data.isTemp(p), true)
	H.ds.failLoad = false
	H.removePlayer(p); H.advance(0.1)
	eq(H.ds.saves, 0, "un profil temporaire n'écrase jamais le vrai")
	H.services.RunService.IsStudioValue = false
end)
test("verrou de session détenu par un autre serveur : pas de chargement concurrent", function()
	local M = boot(); H.osTime = 1700000000
	local uid = H.nextUserId + 1
	H.ds.data["Player_" .. uid] = { data = { Cash = 777, Level = 1, XP = 0 }, job = "job-B", lockTime = H.osTime }
	local p = H.addPlayer("Verrou"); H.advance(10)
	eq(M.Data.get(p), nil, "pas de profil tant que le verrou est valide")
	H.advance(40); truthy(p._props.Kicked ~= nil, "expulsé après échecs répétés (sécurité anti-duplication)")
	eq(H.ds.data["Player_" .. uid].data.Cash, 777, "données de l'autre serveur intactes")
end)
test("verrou expiré : le profil est repris", function()
	local M = boot(); H.osTime = 1700000000
	local uid = H.nextUserId + 1
	H.ds.data["Player_" .. uid] = { data = { Cash = 777, Level = 3, XP = 0 }, job = "job-B", lockTime = H.osTime - 500 }
	local p = H.addPlayer("Expire"); H.advance(1)
	eq(M.Data.get(p).Cash, 777); eq(M.Data.get(p).Level, 3)
end)
test("échec de sauvegarde : profil reste sale, pas de crash", function()
	local M = boot(); local p = join(M, "Save")
	H.ds.failSave = true; H.ds.mode = "save"
	M.Data.get(p).Cash = 5; M.Data.markDirty(p)
	H.advance(65)
	eq(H.errors[1], nil, "aucune erreur non gérée")
	truthy(#H.warnings > 0, "avertissement de sauvegarde")
	H.ds.failSave = false; H.advance(65)
	eq(H.ds.data["Player_" .. p.UserId].data.Cash, 5, "sauvegardé après rétablissement")
end)

print("== EconomyService")
test("addCash : valeurs invalides rejetées, VIP x2", function()
	local M = boot(); local p = join(M, "E1"); local start = M.Econ.getCash(p)
	eq(M.Econ.addCash(p, -50), 0); eq(M.Econ.addCash(p, 0), 0); eq(M.Econ.addCash(p, 0 / 0), 0)
	eq(M.Econ.addCash(p, "100"), 0); eq(M.Econ.addCash(p, nil), 0); eq(M.Econ.addCash(p, {}), 0)
	eq(M.Econ.getCash(p), start, "aucun changement")
	eq(M.Econ.addCash(p, 100.9), 100, "arrondi inférieur")
	M.Econ.setPass(p, "VIP", true); eq(M.Econ.addCash(p, 100), 200, "VIP x2")
	M.Econ.grantCashRaw(p, 50); eq(M.Econ.getCash(p), start + 100 + 200 + 50, "crédit brut sans multiplicateur")
end)
test("spendCash / loseCash bornés", function()
	local M = boot(); local p = join(M, "E2"); local c = M.Econ.getCash(p)
	eq(M.Econ.spendCash(p, c + 1), false); eq(M.Econ.spendCash(p, -5), false); eq(M.Econ.getCash(p), c)
	eq(M.Econ.spendCash(p, c), true); eq(M.Econ.getCash(p), 0)
	M.Econ.grantCashRaw(p, 100)
	eq(M.Econ.loseCash(p, 1e9), 100, "perte plafonnée au solde"); eq(M.Econ.getCash(p), 0)
	eq(M.Econ.loseCash(p, -10), 0, "perte négative ignorée")
end)
test("XP : montée de niveaux multiple, report, plafond, double XP", function()
	local M = boot(); local p = join(M, "E3"); local d = M.Data.get(p)
	M.Econ.addXP(p, -10); M.Econ.addXP(p, 0); eq(d.Level, 1)
	local need1 = M.Config.xpForNext(1)
	M.Econ.addXP(p, need1 + 5); eq(d.Level, 2); eq(d.XP, 5, "report de l'XP")
	M.Econ.addXP(p, 100000); truthy(d.Level > 5, "plusieurs niveaux d'un coup")
	M.Econ.addXP(p, 1e9); eq(d.Level, M.Config.MaxLevel); eq(d.XP, 0, "XP remise à 0 au niveau max")
	local before = M.Data.get(p).Level
	M.Econ.addXP(p, 5); eq(d.Level, before)
	d.Level = 1; d.XP = 0; M.Econ.DoubleXP = true; M.Econ.addXP(p, 10); eq(d.XP, 20, "double XP")
end)
test("succès : une seule récompense, stats utilisées", function()
	local M = boot(); local p = join(M, "E4"); local d = M.Data.get(p)
	local c0 = d.Cash
	M.Econ.addStat(p, "missions", 1)
	eq(d.Achv.first, true); eq(d.Cash, c0 + 300)
	M.Econ.addStat(p, "missions", 1); eq(d.Cash, c0 + 300, "pas de double récompense")
	M.Econ.addDistance(p, 3571 * 21); truthy(d.Achv.km, "succès distance (21 km)")
	M.Econ.setStatMax(p, "bestRace", 50); eq(d.Stats.bestRace, 50); M.Econ.setStatMax(p, "bestRace", 10); eq(d.Stats.bestRace, 50)
end)
test("achat de véhicule : validations serveur", function()
	local M = boot(); local p = join(M, "E5"); local d = M.Data.get(p)
	for _, bad in ipairs({ "nil", "" }) do client(p, "RequestBuy", bad == "nil" and "inconnu" or bad) end
	client(p, "RequestBuy", ("x"):rep(40)); client(p, "RequestBuy", 123); client(p, "RequestBuy", {}); client(p, "RequestBuy", nil); client(p, "RequestBuy", 0 / 0)
	eq(d.Owned.berline, nil); eq(d.Cash, M.Config.StartCash)
	H.advance(1); client(p, "RequestBuy", "berline")   -- niveau 1 < 2
	eq(d.Owned.berline, nil, "niveau insuffisant")
	d.Level = 2; H.advance(1); client(p, "RequestBuy", "berline")   -- cash 500 < 2500
	eq(d.Owned.berline, nil, "argent insuffisant"); eq(d.Cash, M.Config.StartCash)
	d.Cash = 3000; H.advance(1); client(p, "RequestBuy", "berline")
	eq(d.Owned.berline, true); eq(d.Cash, 500, "prix déduit une seule fois")
	H.advance(1); client(p, "RequestBuy", "berline"); eq(d.Cash, 500, "pas de double achat")
	H.advance(1); client(p, "RequestBuy", "citadine"); eq(d.Cash, 500, "gratuit : non achetable")
	d.Cash = 9e9; d.Level = 50; H.advance(1); client(p, "RequestBuy", "gold"); eq(d.Owned.gold, nil, "véhicule gamepass non achetable")
	H.advance(1); client(p, "RequestBuy", "police"); eq(d.Owned.police, nil, "voiture de police non achetable")
end)
test("achat : cooldown anti-spam", function()
	local M = boot(); local p = join(M, "E6"); local d = M.Data.get(p); d.Level = 12; d.Cash = 100000
	client(p, "RequestBuy", "berline"); client(p, "RequestBuy", "pickup"); client(p, "RequestBuy", "muscle")
	eq(d.Owned.pickup, nil, "requêtes rapprochées ignorées"); eq(d.Owned.muscle, nil)
end)
test("couleur : index invalides ignorés", function()
	local M = boot(); local p = join(M, "E7"); local d = M.Data.get(p); local n = #M.Config.VehicleColors
	local bad = { 0, n + 1, 1.5, -1, 1e12, 0 / 0, "2", nil }
	for _, b in ipairs(bad) do H.advance(0.5); client(p, "RequestColor", "citadine", b) end
	eq(d.Colors.citadine, nil, "aucune couleur invalide enregistrée")
	H.advance(0.5); client(p, "RequestColor", "super", 2); eq(d.Colors.super, nil, "véhicule non possédé")
	H.advance(0.5); client(p, "RequestColor", "citadine", 3); eq(d.Colors.citadine, 3)
end)
test("récompense quotidienne : une fois par jour, série, remise à zéro", function()
	local M = boot(); H.osTime = 86400 * 100 + 50
	local p = join(M, "E8"); local d = M.Data.get(p); local c0 = d.Cash
	client(p, "ClaimDaily"); eq(d.Daily.streak, 1); eq(d.Cash, c0 + M.Config.Daily.Base)
	H.advance(2); client(p, "ClaimDaily"); eq(d.Cash, c0 + M.Config.Daily.Base, "pas deux fois le même jour")
	H.osTime = 86400 * 101 + 10; H.advance(2); client(p, "ClaimDaily"); eq(d.Daily.streak, 2)
	eq(d.Cash, c0 + M.Config.Daily.Base * 2 + M.Config.Daily.PerStreak)
	H.osTime = 86400 * 105; H.advance(2); client(p, "ClaimDaily"); eq(d.Daily.streak, 1, "série brisée")
end)
test("état envoyé au client : possède Owned, pas de fuite de données internes", function()
	local M = boot(); local p = join(M, "E9"); H.advance(0.5)
	local st = lastFired("State", p).args[1]
	eq(st.Owned.citadine, true); eq(st.Owned.gold, nil); eq(st.Cash, M.Config.StartCash); eq(st.DailyAvailable, true)
	eq(st.Receipts, nil)
	M.Econ.setPass(p, "VIP", true); H.advance(0.5)
	eq(lastFired("State", p).args[1].Owned.gold, true, "Phantom doré débloqué par VIP")
end)

print("== MonetizationService")
test("reçus : idempotence, produit inconnu, joueur absent, profil non chargé", function()
	local M = boot(); local Mon = H.mod("MonetizationService"); Mon.init()
	local Ids = H.mod("MonetizationIds"); Ids.Products.cash_s = 111
	local p = join(M, "M1"); local c0 = M.Econ.getCash(p)
	local MPS = H.services.MarketplaceService
	eq(MPS.ProcessReceipt({ PlayerId = p.UserId, ProductId = 999, PurchaseId = "a" }), "Enum.ProductPurchaseDecision.NotProcessedYet")
	eq(MPS.ProcessReceipt({ PlayerId = 424242, ProductId = 111, PurchaseId = "a" }), "Enum.ProductPurchaseDecision.NotProcessedYet")
	local r = { PlayerId = p.UserId, ProductId = 111, PurchaseId = "p1" }
	eq(MPS.ProcessReceipt(r), "Enum.ProductPurchaseDecision.PurchaseGranted"); eq(M.Econ.getCash(p), c0 + 5000)
	eq(MPS.ProcessReceipt(r), "Enum.ProductPurchaseDecision.PurchaseGranted"); eq(M.Econ.getCash(p), c0 + 5000, "pas de double crédit")
	H.advance(1); truthy(H.ds.data["Player_" .. p.UserId] ~= nil, "sauvegarde immédiate")
	M.Econ.setPass(p, "VIP", true)
	MPS.ProcessReceipt({ PlayerId = p.UserId, ProductId = 111, PurchaseId = "p2" }); eq(M.Econ.getCash(p), c0 + 10000, "achat Robux non doublé par le VIP")
	Ids.Products.cash_s = 0
	eq(MPS.ProcessReceipt({ PlayerId = p.UserId, ProductId = 0, PurchaseId = "p3" }), "Enum.ProductPurchaseDecision.NotProcessedYet", "ID 0 non configuré ne doit rien créditer")
end)
test("game pass : VIP détecté à l'arrivée", function()
	local M = boot(); local Mon = H.mod("MonetizationService"); Mon.init()
	local Ids = H.mod("MonetizationIds"); Ids.GamePasses.VIP = 55
	local uid = H.nextUserId + 1; H.services.MarketplaceService.owned[uid .. ":55"] = true
	local p = join(M, "M2"); H.advance(1)
	eq(M.Econ.hasPass(p, "VIP"), true); eq(M.Econ.canUseVehicle(p, "gold"), true)
	Ids.GamePasses.BOOST = 66
	H.services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(p, 66, true); eq(M.Econ.hasPass(p, "BOOST"), true)
	H.services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(p, 66, false)
end)

local function bootGame(world)
	local M = boot()
	M.World = world or mockWorld()
	M.Ped = H.mod("PedestrianService"); M.Ped.init()
	M.Veh = H.mod("VehicleService"); M.Veh.init(); M.Veh.setDependencies(M.World, M.Ped, nil)
	M.Wanted = H.mod("WantedService"); M.Wanted.init(M.World)
	return M
end

print("== WantedService")
test("niveau de recherche : paliers, plafond, succès 5 étoiles", function()
	local M = bootGame(); local p = join(M, "W1")
	local function stars() return lastFired("Wanted", p).args[1] end
	M.Wanted.addHeat(p, 1); eq(stars(), 1); eq(M.Wanted.getStars(p), 1)
	M.Wanted.addHeat(p, 20); eq(stars(), 2); M.Wanted.addHeat(p, 20); eq(stars(), 3)
	M.Wanted.addHeat(p, 1e6); eq(stars(), 5, "plafond 5 étoiles"); eq(M.Data.get(p).Stats.fiveStars, 1)
	M.Wanted.addHeat(p, 50); eq(M.Data.get(p).Stats.fiveStars, 1, "succès compté une seule fois")
	M.Wanted.clear(p); eq(M.Wanted.getStars(p), 0); eq(stars(), 0)
end)
test("chaleur : valeurs non numériques n'altèrent pas l'état", function()
	local M = bootGame(); local p = join(M, "W2")
	M.Wanted.addHeat(p, 10); local s = M.Wanted.getStars(p)
	local ok = pcall(M.Wanted.addHeat, p, nil); -- ne doit pas casser durablement
	truthy(M.Wanted.getStars(p) >= s or not ok)
end)
test("sans profil chargé : aucune chaleur ajoutée", function()
	local M = bootGame(); H.ds.failLoad = true
	local p = H.addPlayer("W3"); H.advance(0.2)
	M.Wanted.addHeat(p, 90); eq(M.Wanted.getStars(p), 0)
end)
test("décrochage : la chaleur retombe si aucun policier ne voit le joueur", function()
	local M = bootGame(); H.rayHit = false
	M.Wanted.start()
	local p = join(M, "W4"); M.Wanted.addHeat(p, 30); eq(M.Wanted.getStars(p), 2)
	H.advance(10); truthy(M.Wanted.getStars(p) <= 1, "étoiles en baisse")
	H.advance(30); eq(M.Wanted.getStars(p), 0)
	local n = notifications(p); truthy(n[#n]:find("semé"), "message de réussite")
	H.rayHit = true
end)
test("police : effectifs selon étoiles, arrestation, amende plafonnée, mission annulée", function()
	local M = bootGame(); M.Wanted.start()
	local p = join(M, "W5"); local d = M.Data.get(p); d.Cash = 100000
	local cops = H.Workspace:FindFirstChild("Cops")
	M.Wanted.addHeat(p, 50)   -- 3 étoiles
	H.advance(2)
	eq(#cops:GetChildren(), 3, "3 policiers pour 3 étoiles")
	local busted = 0
	M.Wanted.Busted:Connect(function() busted = busted + 1 end)
	H.move(p, V3.new(0, 3, 0))
	local c = cops:GetChildren()[1]; c.HumanoidRootPart.Position = V3.new(2, 3, 0)
	H.advance(0.6)
	eq(busted, 1, "arrêté une fois"); eq(M.Wanted.getStars(p), 0); eq(d.Cash, 100000 - 2500 + 250, "amende plafonnée à 2500 (+250 du succès Pris la main dans le sac)")
	eq(d.Stats.busted, 1); truthy(lastFired("Busted", p) ~= nil)
	eq(#cops:GetChildren(), 0, "policiers retirés")
	M.Wanted.addHeat(p, 50); eq(M.Wanted.getStars(p), 0, "immunité courte après arrestation")
end)
test("arrestation : amende = 10 % si petit solde, jamais négative", function()
	local M = bootGame(); M.Wanted.start()
	local p = join(M, "W6"); local d = M.Data.get(p); d.Cash = 1000
	M.Wanted.addHeat(p, 20); H.advance(1)
	local cops = H.Workspace:FindFirstChild("Cops")
	H.move(p, V3.new(0, 3, 0)); cops:GetChildren()[1].HumanoidRootPart.Position = V3.new(1, 3, 0); H.advance(0.6)
	eq(d.Cash, 900 + 250, "10 % d'amende + succès"); local p2 = join(M, "W6b"); M.Data.get(p2).Cash = 0
	H.advance(8); M.Wanted.addHeat(p2, 20); H.advance(1)
	for _, c in ipairs(cops:GetChildren()) do if c:GetAttribute("Target") == p2.UserId then c.HumanoidRootPart.Position = V3.new(0, 3, 0) end end
	H.advance(0.6); eq(M.Data.get(p2).Cash, 250, "rien à perdre (0), seul le succès est crédité")
end)
test("Pay'n'Spray : coût par étoile, refus si pauvre", function()
	local M = bootGame()
	local pad = H.Instance.new("Part"); H.services.CollectionService:AddTag(pad, "SprayHub")
	M.Wanted.init(M.World)
	local prompt = pad:FindFirstChildOfClass("ProximityPrompt"); truthy(prompt, "prompt créé")
	local p = join(M, "W7"); local d = M.Data.get(p)
	prompt.Triggered:Fire(p); eq(d.Cash, M.Config.StartCash, "pas recherché : rien à payer")
	M.Wanted.addHeat(p, 50); eq(M.Wanted.getStars(p), 3)
	d.Cash = 100; prompt.Triggered:Fire(p); eq(M.Wanted.getStars(p), 3, "pas assez d'argent"); eq(d.Cash, 100)
	d.Cash = 1000; prompt.Triggered:Fire(p); eq(M.Wanted.getStars(p), 0); eq(d.Cash, 1000 - 3 * M.Config.Wanted.SprayCostPerStar)
end)

print("== MissionService")
local function bootMissions(opts)
	local M = bootGame()
	M.Mission = H.mod("MissionService")
	local pads = {}
	for _, kind in ipairs({ "delivery", "taxi", "race", "heist" }) do
		local pad = H.Instance.new("Part"); pad:SetAttribute("Mission", kind); pad:SetAttribute("Label", kind)
		H.services.CollectionService:AddTag(pad, "MissionHub"); pads[kind] = pad
	end
	M.Mission.init(M.World); M.Mission.start()
	function M.trigger(kind, player) pads[kind]:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player) end
	function M.mission(player) local f = lastFired("Mission", player); return f and f.args[1] end
	return M
end
test("livraison : démarrage, validation de position, récompense, succès, cooldown", function()
	local M = bootMissions(); local p = join(M, "L1"); local d = M.Data.get(p); local c0 = d.Cash
	M.trigger("delivery", p); local m = M.mission(p); truthy(m and m.type == "delivery", "mission envoyée")
	truthy(m.target.X == 300 or m.target.Z == 300, "cible issue du monde serveur")
	H.advance(1); eq(d.Stats.deliveries, 0, "pas validée loin de la cible")
	M.trigger("delivery", p); eq(M.mission(p).type, "delivery", "une seule mission à la fois")
	H.move(p, m.target + V3.new(0, 2.5, 0)); H.advance(0.6)
	eq(d.Stats.deliveries, 1); eq(d.Stats.missions, 1); truthy(d.Achv.first); eq(M.mission(p), nil, "HUD mission effacé")
	local gain = d.Cash - c0 - 300 -- moins le bonus du succès
	truthy(gain >= m.reward and gain <= m.reward + 2 * 70, "gain " .. gain .. " entre " .. m.reward .. " et bonus temps")
	M.trigger("delivery", p); eq(M.mission(p), nil, "cooldown actif")
	H.advance(10); M.trigger("delivery", p); truthy(M.mission(p), "relançable après cooldown")
end)
test("livraison : temps écoulé = échec sans gain ; abandon ; mort", function()
	local M = bootMissions(); local p = join(M, "L2"); local d = M.Data.get(p); local c0 = d.Cash
	M.trigger("delivery", p); H.advance(200); eq(M.mission(p), nil); eq(d.Cash, c0); eq(d.Stats.missions, 0)
	H.advance(10); M.trigger("delivery", p); truthy(M.mission(p)); client(p, "AbandonMission"); eq(M.mission(p), nil)
	H.advance(10); M.trigger("delivery", p); local _, _, hum = p.Character, nil, p.Character.Humanoid
	hum.Health = 0; H.advance(0.6); eq(M.mission(p), nil, "mission échouée à la mort"); eq(d.Cash, c0)
end)
test("mission impossible : niveau, recherche, hors-personnage", function()
	local M = bootMissions(); local p = join(M, "L3"); local d = M.Data.get(p)
	M.trigger("taxi", p); eq(M.mission(p), nil, "taxi niveau 2")
	M.trigger("race", p); eq(M.mission(p), nil, "course niveau 3")
	M.trigger("heist", p); eq(M.mission(p), nil, "braquage niveau 6")
	M.Wanted.addHeat(p, 30); M.trigger("delivery", p); eq(M.mission(p), nil, "recherché : missions bloquées")
	M.Wanted.clear(p)
	local ghost = join(M, "L3b", false); M.trigger("delivery", ghost); eq(M.mission(ghost), nil, "sans personnage")
end)
test("taxi : client pris seulement en véhicule, trajet validé", function()
	local M = bootMissions(); local p = join(M, "L4"); local d = M.Data.get(p); d.Level = 2
	M.trigger("taxi", p); eq(M.mission(p), nil, "doit être en véhicule")
	p.Character.Humanoid.SeatPart = H.Instance.new("Seat")
	M.trigger("taxi", p); local m = M.mission(p); truthy(m and m.type == "taxi")
	local pickup = m.target
	p.Character.Humanoid.SeatPart = nil; H.move(p, pickup + V3.new(0, 2.5, 0)); H.advance(0.6)
	eq(M.mission(p).step, 1, "à pied : pas de prise en charge")
	p.Character.Humanoid.SeatPart = H.Instance.new("Seat"); H.advance(0.6)
	m = M.mission(p); eq(m.step, 2, "client à bord"); truthy(m.target ~= pickup)
	local c0 = d.Cash; H.move(p, m.target + V3.new(0, 2.5, 0)); H.advance(0.6)
	eq(d.Stats.taxis, 1); truthy(d.Cash > c0)
end)
test("course : ordre des points imposé, véhicule obligatoire, record", function()
	local M = bootMissions(); local p = join(M, "L5"); local d = M.Data.get(p); d.Level = 3
	local cs = M.World.RaceCircuit
	M.trigger("race", p); eq(M.mission(p), nil, "à pied refusé")
	p.Character.Humanoid.SeatPart = H.Instance.new("Seat")
	M.trigger("race", p); eq(M.mission(p).step, 1)
	H.move(p, cs[3]); H.advance(0.6); eq(M.mission(p).step, 1, "sauter au dernier point ne valide rien")
	H.move(p, cs[1]); H.advance(0.6); eq(M.mission(p).step, 2)
	p.Character.Humanoid.SeatPart = nil; H.move(p, cs[2]); H.advance(0.6); eq(M.mission(p).step, 2, "à pied pas de validation")
	p.Character.Humanoid.SeatPart = H.Instance.new("Seat"); H.advance(0.6); eq(M.mission(p).step, 3)
	local c0 = d.Cash; H.move(p, cs[3]); H.advance(0.6)
	eq(d.Stats.races, 1); truthy(d.Cash - c0 >= M.Config.Missions.race.baseReward, "récompense de course"); truthy(d.Stats.bestRace > 0)
end)
test("braquage : étoiles, arrestation = butin perdu, réussite = gros gain", function()
	local M = bootMissions(); local p = join(M, "L6"); local d = M.Data.get(p); d.Level = 6
	M.trigger("heist", p); truthy(M.mission(p) and M.mission(p).type == "heist"); eq(M.Wanted.getStars(p), 4, "70 de chaleur = 4 étoiles")
	local c0 = d.Cash; M.Wanted.Busted:Fire(p); H.advance(0.1)
	eq(M.mission(p), nil, "mission annulée à l'arrestation"); eq(d.Cash, c0); eq(d.Stats.heists, 0)
	H.advance(300)
	M.Wanted.clear(p); M.trigger("heist", p); truthy(M.mission(p))
	H.move(p, M.World.Hideout + V3.new(0, 2.5, 0)); H.advance(0.6)
	eq(d.Stats.heists, 1); eq(d.Cash - c0, M.Config.Missions.heist.baseReward + 5000 + 300, "2600 + succès braquage 5000 + premier contrat 300")
	M.trigger("heist", p); eq(M.mission(p), nil, "cooldown du braquage")
end)
test("VIP double les gains de mission", function()
	local M = bootMissions(); local p = join(M, "L7"); local d = M.Data.get(p); M.Econ.setPass(p, "VIP", true)
	M.trigger("delivery", p); local m = M.mission(p); local c0 = d.Cash
	H.move(p, m.target + V3.new(0, 2.5, 0)); H.advance(0.6)
	truthy(d.Cash - c0 >= 2 * m.reward, "gain doublé")
end)
test("joueur qui quitte pendant une mission : pas d'erreur", function()
	local M = bootMissions(); local p = join(M, "L8"); M.trigger("delivery", p); H.removePlayer(p); H.advance(2)
end)

print("== CollectibleService")
test("étoiles : une fois par joueur, jalons, proximité, joueurs indépendants", function()
	local M = bootGame(); local C = H.mod("CollectibleService"); C.init(M.World); C.start()
	local p = join(M, "C1"); local d = M.Data.get(p); local c0 = d.Cash
	H.move(p, V3.new(1000, 3, 1000)); H.advance(1); eq(d.Stats.collected, 0)
	H.move(p, V3.new(50, 3, 50)); H.advance(1); eq(d.Stats.collected, 1); eq(d.Cash, c0 + 400)
	H.advance(2); eq(d.Stats.collected, 1, "même étoile pas recomptée")
	local q = join(M, "C2"); H.move(q, V3.new(50, 3, 50)); H.advance(1); eq(M.Data.get(q).Stats.collected, 1, "autre joueur peut la prendre")
	local list = lastFired("Collected", p).args[1]; eq(#list, 1); eq(list[1], 1)
	H.move(p, V3.new(-50, 3, 50)); H.advance(1); H.move(p, V3.new(80, 3, -80)); H.advance(1); eq(d.Stats.collected, 3)
end)
test("étoiles : jalon de 10 étoiles", function()
	local world = mockWorld(); world.StarSpots = {}
	for i = 1, 10 do world.StarSpots[i] = V3.new(i * 100, 3, 0) end
	local M = bootGame(world); local C = H.mod("CollectibleService"); C.init(world); C.start()
	local p = join(M, "C3"); local d = M.Data.get(p); local c0 = d.Cash
	for i = 1, 10 do H.move(p, V3.new(i * 100, 3, 0)); H.advance(0.5) end
	eq(d.Stats.collected, 10); eq(d.Cash - c0, 10 * 400 + 2500 + 100 * d.Level, "10 x 400 + palier 2500 + bonus de niveau (150 XP => niveau 2)"); eq(d.Level, 2)
end)

print("== StoryService")
local function bootStory()
	local M = bootGame(); M.Story = H.mod("StoryService"); M.Story.init(); M.Story.start(); return M
end
test("histoire : Config cohérente (chiffres = code)", function()
	local C = boot().Config
	local digits = {}
	for _, ch in ipairs(C.Story.Chapters) do digits[#digits + 1] = ch.digit; truthy(ch.radius > 0 and ch.reward > 0) end
	eq(table.concat(digits), C.Story.Code, "les chiffres des chapitres forment le code")
	eq(#C.Story.Code, 4)
end)
test("histoire : énigmes dans l'ordre, pas de saut, récompense unique", function()
	local M = bootStory(); local p = join(M, "S1"); local d = M.Data.get(p); local ch = M.Config.Story.Chapters
	eq(d.Story.chapter, 0)
	H.move(p, V3.new(ch[2].x, 3, ch[2].z)); H.advance(1); eq(d.Story.chapter, 0, "chapitre 2 ne compte pas avant le 1")
	local c0 = d.Cash
	H.move(p, V3.new(ch[1].x, 3, ch[1].z)); H.advance(1); eq(d.Story.chapter, 1); eq(d.Cash, c0 + ch[1].reward)
	H.advance(3); eq(d.Cash, c0 + ch[1].reward, "pas de double récompense")
	local st = lastFired("State", p).args[1].Story
	eq(st.chapter, 1); eq(st.digits[1], "7"); eq(st.digits[2], nil, "les chiffres suivants ne fuitent pas"); truthy(st.riddle:find("taxi"), "énigme suivante")
	for i = 2, 4 do H.move(p, V3.new(ch[i].x, 3, ch[i].z)); H.advance(1) end
	eq(d.Story.chapter, 4); eq(lastFired("State", p).args[1].Story.riddle, nil)
end)
test("histoire : code validé côté serveur (types, longueur, essais, unique)", function()
	local M = bootStory(); local p = join(M, "S2"); local d = M.Data.get(p); local ch = M.Config.Story.Chapters
	client(p, "SubmitCode", "7391"); eq(d.Story.done, false, "refusé tant que les énigmes ne sont pas résolues")
	for i = 1, 4 do H.move(p, V3.new(ch[i].x, 3, ch[i].z)); H.advance(1) end
	for _, bad in ipairs({ 7391, "abcd", "739", "73910", "7 91", "", "7391\n" }) do H.advance(3); client(p, "SubmitCode", bad) end
	H.advance(3); client(p, "SubmitCode", nil); client(p, "SubmitCode", {}); client(p, "SubmitCode", 0 / 0)
	eq(d.Story.done, false, "entrées invalides rejetées")
	H.advance(3); client(p, "SubmitCode", "0000"); eq(d.Story.done, false, "mauvais code")
	local n = notifications(p); truthy(n[#n]:find("erroné"))
	client(p, "SubmitCode", "7391"); eq(d.Story.done, false, "2 s entre deux essais")
	local c0 = d.Cash; H.advance(3); client(p, "SubmitCode", "7391")
	eq(d.Story.done, true); eq(d.Stats.storyDone, 1); truthy(d.Achv.detective)
	truthy(d.Cash >= c0 + M.Config.Story.FinalReward, "récompense finale")
	local c1 = d.Cash; H.advance(3); client(p, "SubmitCode", "7391"); eq(d.Cash, c1, "une seule fois")
end)
test("histoire : progression sauvegardée", function()
	local M = bootStory(); local p = join(M, "S3"); local ch = M.Config.Story.Chapters
	H.move(p, V3.new(ch[1].x, 3, ch[1].z)); H.advance(1)
	local uid = p.UserId; H.removePlayer(p); H.advance(0.1)
	H.nextUserId = uid - 1; local q = join(M, "S3"); eq(M.Data.get(q).Story.chapter, 1)
end)

print("== VehicleService")
test("sortie de véhicule : propriété, cooldown, remplacement, arguments aberrants", function()
	local M = bootGame(); M.Veh.start()
	local p = join(M, "V1"); local d = M.Data.get(p)
	local folder = H.Workspace:FindFirstChild("Vehicles")
	for _, bad in ipairs({ 1, {}, ("x"):rep(50), "inconnu" }) do H.advance(1); client(p, "RequestSpawn", bad) end
	H.advance(1); client(p, "RequestSpawn", nil)
	eq(#folder:GetChildren(), 0, "rien ne spawn pour des entrées invalides")
	H.advance(1); client(p, "RequestSpawn", "super"); eq(#folder:GetChildren(), 0, "véhicule non possédé")
	H.advance(1); client(p, "RequestSpawn", "citadine"); eq(#folder:GetChildren(), 1)
	local car = folder:GetChildren()[1]
	eq(car:GetAttribute("OwnerUserId"), p.UserId); eq(car:GetAttribute("CRVehicle"), true)
	truthy(car.PrimaryPart.DriveVelocity and car.PrimaryPart.TurnVelocity, "contraintes de conduite")
	H.advance(0.5); client(p, "RequestSpawn", "citadine"); eq(#folder:GetChildren(), 1, "cooldown")
	d.Owned.berline = true; H.advance(5); client(p, "RequestSpawn", "berline")
	local n = 0; for _, c in ipairs(folder:GetChildren()) do if c:GetAttribute("OwnerUserId") == p.UserId then n = n + 1 end end
	eq(n, 1, "un seul véhicule personnel à la fois")
	H.removePlayer(p); H.advance(0.2)
	n = 0; for _, c in ipairs(folder:GetChildren()) do if c:GetAttribute("OwnerUserId") == p.UserId then n = n + 1 end end
	eq(n, 0, "véhicule retiré au départ du joueur")
end)
test("siège conducteur verrouillé pour les autres, ouvert pour les voitures publiques", function()
	local M = bootGame(); local p = join(M, "V2"); local q = join(M, "V3")
	H.advance(1); client(p, "RequestSpawn", "citadine")
	local car = H.Workspace:FindFirstChild("Vehicles"):GetChildren()[1]
	local seat = car:FindFirstChild("DriverSeat")
	local hum = q.Character.Humanoid; hum.Sit = true; seat.Occupant = hum; H.advance(0.2)
	eq(hum.Sit, false, "intrus éjecté"); truthy(notifications(q)[1] and notifications(q)[1]:find("verrouill"))
end)
test("voitures publiques : une par place de parking", function()
	local world = mockWorld(); world.ParkingSpots = { CF.new(10, 0.3, 0), CF.new(20, 0.3, 0), CF.new(30, 0.3, 0) }
	local M = bootGame(world); M.Veh.start(); H.advance(0.5)
	local folder = H.Workspace:FindFirstChild("Vehicles"); eq(#folder:GetChildren(), 3)
	for _, c in ipairs(folder:GetChildren()) do eq(c:GetAttribute("OwnerUserId"), nil); eq(c:GetAttribute("Public"), true) end
	H.advance(30)
end)
test("voiture de police : sièges désactivés", function()
	local M = bootGame(); local car = M.Veh.spawnCruiser(CF.new(0, 3, 0))
	eq(car:FindFirstChild("DriverSeat").Disabled, true); eq(car:GetAttribute("Police"), true)
end)

print("== Pedestrians")
test("piétons : population, billets lâchés ramassés", function()
	local M = bootGame(); M.Ped.start(); H.advance(10)
	local folder = H.Workspace:FindFirstChild("Pedestrians"); truthy(#folder:GetChildren() >= 20, "population de piétons")
	local p = join(M, "P1"); local c0 = M.Econ.getCash(p)
	M.Ped.dropCash(V3.new(0, 0, 0)); H.advance(1); truthy(M.Econ.getCash(p) > c0, "billet ramassé")
	local c1 = M.Econ.getCash(p); H.advance(30); eq(M.Econ.getCash(p), c1, "un billet ne se ramasse qu'une fois")
end)

print("== Événements, classement")
test("EventService : largage de caisses et double XP", function()
	local M = bootGame(); local E = H.mod("EventService"); E.start(M.World)
	local p = join(M, "EV"); H.advance(155)
	local banner = lastFired("Banner"); truthy(banner and banner.args[1].kind == "airdrop", "annonce de largage")
	local pos = banner.args[1].positions[1]; local c0 = M.Econ.getCash(p)
	H.move(p, pos); H.advance(1); truthy(M.Econ.getCash(p) > c0, "caisse récupérée")
	H.advance(300); local last = lastFired("Banner"); truthy(last ~= nil)
	H.advance(500); eq(M.Econ.DoubleXP == true or M.Econ.DoubleXP == false, true)
end)

print("== Monde & démarrage complet")
test("WorldService.build : ville générée, points d'intérêt cohérents", function()
	local C = H.mod("Config"); local World = H.mod("WorldService")
	local done = false
	task_ = H.env.task
	H.env.task.spawn(function() World.build(); done = true end)
	H.advance(2000)
	truthy(done, "génération terminée"); truthy(World.Ready)
	eq(#World.StarSpots, C.Collectibles.Count, "30 étoiles")
	eq(#World.RaceCircuit, C.Missions.race.checkpoints, "8 points de contrôle")
	truthy(#World.DeliveryPoints >= 25, "points de livraison: " .. #World.DeliveryPoints)
	truthy(#World.TaxiStops >= 10); truthy(#World.ParkingSpots >= 25)
	local tags = H.services.CollectionService.tags
	eq(#(tags.MissionHub or {}), 4, "4 hubs de mission"); eq(#(tags.DealerHub or {}), 1); eq(#(tags.SprayHub or {}), 1)
	truthy(#(tags.Lit or {}) > 300, "fenêtres allumables"); local nparts = #World.Root:GetDescendants(); print("       parts générées : " .. nparts); truthy(nparts > 1500, "nombre de parts: " .. nparts)
	local kinds = {}
	for _, pad in ipairs(tags.MissionHub) do kinds[pad:GetAttribute("Mission")] = true end
	truthy(kinds.delivery and kinds.taxi and kinds.race and kinds.heist, "4 types de mission")
	-- une étoile ne doit pas être sous la ville
	for _, s in ipairs(World.StarSpots) do truthy(s.Y > 0, "étoile sous le sol") end
	-- briser un prop
	local prop = World.BreakFolder:GetChildren()[1]; truthy(prop, "props destructibles"); eq(World.breakProp(prop), true)
	eq(World.breakProp(prop), false, "pas de double casse")
end)
test("démarrage complet (Main) sans erreur, joueur apparu avec sa Citadine", function()
	H.rayHit = true
	local MainInst
	for _, c in ipairs(H.SSS:GetChildren()) do if c.Name == "Main" then MainInst = c end end
	truthy(MainInst, "Main.server.lua")
	H.Players.CharacterAutoLoads = true
	local p = H.addPlayer("Main1")
	local loaded = false
	p.LoadCharacter = function(self) loaded = true; H.spawnCharacter(self, V3.new(0, 3, 0)) end
	H.env.task.spawn(function() H.require(MainInst) end)
	H.advance(3000)
	eq(H.Workspace:GetAttribute("WorldReady"), true, "monde prêt")
	eq(H.Players.CharacterAutoLoads, false, "apparition gérée manuellement")
	truthy(loaded, "personnage chargé"); 
	local vehicles = H.Workspace:FindFirstChild("Vehicles")
	local mine = 0
	for _, c in ipairs(vehicles:GetChildren()) do if c:GetAttribute("OwnerUserId") == p.UserId then mine = mine + 1 end end
	eq(mine, 1, "Citadine de bienvenue")
	H.advance(600)
end)

print("== Animations (logique pure)")
test("AnimMath : roulis, suspension, dérapage, démarrage", function()
	local A = H.mod("AnimMath")
	eq(A.leanDegrees(1, 0, 100, 4.5), 0, "pas de roulis à l'arrêt"); eq(A.leanDegrees(1, 5, 100, 4.5), 0, "pas de roulis à très basse vitesse")
	truthy(A.leanDegrees(1, 90, 100, 4.5) > 3 and A.leanDegrees(1, 90, 100, 4.5) <= 4.5, "roulis borné")
	eq(A.leanDegrees(-1, 90, 100, 4.5), -A.leanDegrees(1, 90, 100, 4.5), "symétrique")
	eq(A.leanDegrees(5, 90, 100, 4.5), A.leanDegrees(1, 90, 100, 4.5), "braquage borné à 1"); eq(A.leanDegrees(1, 50, 0, 4), 0, "maxSpeed nul sans division par 0")
	truthy(A.pitchDegrees(-200, 2.5) ~= A.pitchDegrees(200, 2.5), "freinage et accélération différents"); truthy(math.abs(A.pitchDegrees(1e9, 2.5)) <= 2.5, "tangage borné")
	local ok, i = A.drift(1, 90, 100, 0.6, 0.55); eq(ok, true); truthy(i > 0 and i <= 1)
	eq((A.drift(0.2, 90, 100, 0.6, 0.55)), false, "pas de dérapage sans braquage"); eq((A.drift(1, 20, 100, 0.6, 0.55)), false, "pas de dérapage trop lent"); eq((A.drift(1, 50, 0, 0.6, 0.55)), false)
	eq(A.launch(0, 5, 1), true); eq(A.launch(40, 50, 1), false, "pas un démarrage si déjà en mouvement"); eq(A.launch(0, 5, 0), false, "sans accélérateur")
end)
test("AnimMath : pop, machine à écrire UTF-8, lissage, porte", function()
	local A = H.mod("AnimMath")
	near(A.popScale(0), 0, 1e-6); near(A.popScale(1), 1, 1e-6); truthy(A.popScale(0.7) > 1, "dépassement (rebond)"); near(A.popScale(5), 1, 1e-6, "borné")
	eq(A.typewriter("Bonjour", 0, 10), ""); eq(A.typewriter("Bonjour", 0.3, 10), "Bon"); eq(A.typewriter("Bonjour", 99, 10), "Bonjour")
	eq(A.typewriter("é à", 0.2, 10), "é ", "UTF-8 : jamais de caractère coupé"); eq(A.typewriter("", 1, 10), "")
	local v = A.smooth(0, 10, 0.1, 5); truthy(v > 0 and v < 10); near(A.smooth(0, 10, 1000, 5), 10, 1e-6); eq(A.smooth(3, 3, 0.1, 5), 3)
	eq(A.doorAngle(0, 1, 60), 0); eq(A.doorAngle(0.5, 1, 60), 60, "porte ouverte au milieu"); near(A.doorAngle(1, 1, 60), 0, 1e-6); eq(A.doorAngle(0.5, 0, 60), 0, "durée nulle sûre")
end)
test("Config.Animations : interrupteurs complets et voiture avec porte animable", function()
	local M = boot(); local C = M.Config
	truthy(C.Animations.Enabled ~= nil)
	for _, k in ipairs({ "Lean", "Suspension", "Launch", "Drift", "Door", "Horn" }) do eq(type(C.Animations.Vehicle[k]), "boolean", "Vehicle." .. k) end
	for _, k in ipairs({ "MenuTransitions", "RewardPop", "MissionSlide", "Journal" }) do eq(type(C.Animations.UI[k]), "boolean", "UI." .. k) end
	eq(type(C.Animations.Police.Cuffs), "boolean")
	local B = H.mod("VehicleBuilder"); local car = B.build(C.Vehicles[1], C.Vehicles[1].color)
	local door = car:FindFirstChild("DoorL"); truthy(door, "porte conducteur"); truthy(door:FindFirstChild("DoorHinge"), "charnière")
	local static = B.build(C.Vehicles[1], C.Vehicles[1].color, { static = true }); eq(static:FindFirstChild("DoorL"), nil, "pas de porte sur les voitures de vitrine")
end)

test("Animations.on : interrupteur général et par animation", function()
	local C = H.mod("Config"); local Anim = H.mod("Animations")
	eq(Anim.on("UI", "RewardPop"), true); eq(Anim.on("UI", "Inconnue"), false); eq(Anim.on("Inexistant", "x"), false)
	C.Animations.UI.RewardPop = false; eq(Anim.on("UI", "RewardPop"), false)
	C.Animations.UI.RewardPop = true; C.Animations.Enabled = false; eq(Anim.on("UI", "RewardPop"), false, "coupure générale")
	C.Animations.Enabled = true
end)

print("== Cinématiques")
test("CinematicLogic : toutes les séquences valides, 20 à 40 s, skippables", function()
	local C = H.mod("Config"); local L = H.mod("CinematicLogic"); local n = 0
	for id, seq in pairs(C.Cinematics.Sequences) do
		local ok, msg = L.validate(seq); truthy(ok, id .. ": " .. tostring(msg))
		local d = L.totalDuration(seq); truthy(d >= 20 and d <= 40, id .. " dure " .. d .. " s"); n = n + 1
	end
	for _, id in ipairs({ "intro", "tutorial", "chase" }) do truthy(C.Cinematics.Sequences[id], "séquence " .. id) end
	eq(n, 3, "3 moments clés seulement")
end)
test("CinematicLogic : validation rejette les séquences invalides", function()
	local L = H.mod("CinematicLogic")
	eq((L.validate(nil)), false); eq((L.validate({})), false); eq((L.validate({ shots = {} })), false)
	local base = function(over) local shot = { dur = 25, kind = "orbit", radius = 10, a0 = 0, a1 = 1, caption = "x" }; for k, v in pairs(over or {}) do shot[k] = v end; return { shots = { shot } } end
	eq((L.validate(base())), true)
	eq((L.validate(base({ dur = 0 }))), false); eq((L.validate(base({ dur = -5 }))), false); eq((L.validate(base({ kind = "zoom" }))), false)
	eq((L.validate(base({ radius = 0 }))), false); eq((L.validate(base({ caption = "" }))), false); eq((L.validate(base({ dur = 5 }))), false, "trop court")
	eq((L.validate(base({ dur = 41 }))), false, "trop long"); eq((L.validate(base({ kind = "fly" }))), false, "fly sans from/to")
end)
test("CinematicLogic : lecteur (temps, plans, skip, fin, reprise)", function()
	local L = H.mod("CinematicLogic")
	local seq = { shots = { { dur = 10, kind = "orbit", radius = 5, a0 = 0, a1 = 1, caption = "A" }, { dur = 12, kind = "orbit", radius = 5, a0 = 0, a1 = 1, caption = "B" } } }
	local p = L.newPlayer(seq); eq(p.total, 22); eq(p.finished, false); eq(p:caption(), "A")
	p:step(4); local shot, prog, idx = p:current(); eq(idx, 1); near(prog, 0.4, 1e-9)
	p:step(7); shot, prog, idx = p:current(); eq(idx, 2); eq(p:caption(), "B"); near(prog, 1 / 12, 1e-9)
	p:step(-5); near(p.time, 11, 1e-9, "dt négatif ignoré")
	p:step(100); eq(p.finished, true); eq(p.skipped, false); eq(p.time, 22)
	eq(p:skip(), false, "skip après la fin sans effet"); local before = p.time; p:step(5); eq(p.time, before, "plus d'avancement une fois fini")
	local q = L.newPlayer(seq); q:step(3); eq(q:skip(), true); eq(q.finished, true); eq(q.skipped, true); eq(q:skip(), false, "double skip")
	local r = L.newPlayer(seq); r:step(1e9); local s2, p2, i2 = r:current(); eq(i2, 2); eq(p2, 1, "avancement borné")
end)
test("CinematicLogic : poses caméra (orbite, survol) et file d'attente", function()
	local L = H.mod("CinematicLogic")
	local orbit = { kind = "orbit", radius = 10, height = 5, a0 = 0, a1 = math.pi, lookY = 2 }
	local pos, look = L.pose(orbit, 0, { 100, 0, 50 }); near(pos.x, 110, 1e-9); near(pos.y, 5, 1e-9); near(pos.z, 50, 1e-9); eq(look.y, 2); eq(look.x, 100)
	pos = L.pose(orbit, 1, { 100, 0, 50 }); near(pos.x, 90, 1e-9); near(pos.z, 50, 1e-6)
	pos = L.pose(orbit, 2, { 0, 0, 0 }); near(pos.x, -10, 1e-9, "avancement borné à 1"); 
	local fly = { kind = "fly", from = { 0, 10, 0 }, to = { 100, 10, 0 } }
	pos = L.pose(fly, 0, { 0, 0, 0 }); eq(pos.x, 0); pos = L.pose(fly, 1, { 0, 0, 0 }); eq(pos.x, 100)
	local rel = { kind = "fly", relative = true, from = { 0, 10, 0 }, to = { 100, 10, 0 } }
	pos = L.pose(rel, 0, { 500, 0, 500 }); eq(pos.x, 500); eq(pos.z, 500)
	local q = {}
	eq(L.enqueue(q, "a", 2), true); eq(L.enqueue(q, "a", 2), false, "pas de doublon"); eq(L.enqueue(q, "b", 2), true); eq(L.enqueue(q, "c", 2), false, "file bornée"); eq(#q, 2)
end)
test("CinematicService : une seule fois, réglages, inconnues, sans profil", function()
	local M = boot(); local Cin = H.mod("CinematicService"); local p = join(M, "CI1"); local C = M.Config
	eq(Cin.play(p, "intro"), true); eq(lastFired("Cinematic", p).args[1], "intro"); eq(M.Data.get(p).Seen.intro, true)
	eq(Cin.play(p, "intro"), false, "déjà vue")
	eq(#H.remote("Cinematic")._fired, 1)
	for _, bad in ipairs({ "inconnue", "", "__index" }) do eq(Cin.play(p, bad), false) end
	C.Cinematics.Sequences.tutorial.enabled = false; eq(Cin.play(p, "tutorial"), false, "séquence désactivée"); C.Cinematics.Sequences.tutorial.enabled = true
	C.Cinematics.Enabled = false; eq(Cin.play(p, "chase"), false, "coupure générale"); eq(M.Data.get(p).Seen.chase, nil, "non marquée vue si désactivée"); C.Cinematics.Enabled = true
	C.Cinematics.PlayOnce = false; eq(Cin.play(p, "intro"), true, "rejouable si PlayOnce = false"); C.Cinematics.PlayOnce = true
	local ghost = join(M, "CI2", false); H.ds.failLoad = true; local nop = H.addPlayer("CI3"); H.advance(0.2); eq(Cin.play(nop, "intro"), false, "sans profil")
end)
test("cinématiques : seule la première poursuite déclenche une cinématique en jeu", function()
	local M = bootGame(); M.Story = H.mod("StoryService"); M.Story.init(); M.Story.start()
	local p = join(M, "CI4"); local ids = function() local out = {}; for _, f in ipairs(H.remote("Cinematic")._fired) do out[#out + 1] = f.args[1] end; return table.concat(out, ",") end
	M.Wanted.addHeat(p, 25); eq(ids(), "chase", "première poursuite")
	M.Wanted.clear(p); M.Wanted.addHeat(p, 25); eq(ids(), "chase", "une seule fois")
	local ch = M.Config.Story.Chapters
	for i = 1, 4 do H.move(p, V3.new(ch[i].x, 3, ch[i].z)); H.advance(1) end
	H.advance(3); client(p, "SubmitCode", "7391"); eq(M.Data.get(p).Story.done, true)
	eq(ids(), "chase", "l'histoire se joue en gameplay, sans cinématique")
end)
test("cinématiques : intro puis mini tutoriel au premier lancement (Main)", function()
	H.rayHit = true
	local MainInst
	for _, c in ipairs(H.SSS:GetChildren()) do if c.Name == "Main" then MainInst = c end end
	local p = H.addPlayer("Main2"); p.LoadCharacter = function(self) H.spawnCharacter(self, V3.new(0, 3, 0)) end
	H.env.task.spawn(function() H.require(MainInst) end); H.advance(3000)
	local ids = {}; for _, f in ipairs(H.remote("Cinematic")._fired) do ids[#ids + 1] = f.args[1] end
	eq(table.concat(ids, ","), "intro,tutorial"); H.advance(600)
end)

print("== Client (chargement des modules)")
test("modules client : syntaxe et chargement", function()
	local spsC
	for _, c in ipairs(H.SPS:GetChildren()) do if c.Name == "Controllers" then spsC = c end end
	for _, c in ipairs(spsC:GetChildren()) do
		local ok, err = pcall(H.require, c)
		if not ok then error("chargement de " .. c.Name .. ": " .. tostring(err)) end
	end
end)

print(string.format("\nRésultat : %d réussis, %d échoués", passed, failed))
for _, f in ipairs(failures) do print("  - " .. f) end
return failed
