--!nonstrict
-- Simulation serveur avec un faux environnement Roblox : exécute les VRAIS modules
-- DataService / PlayerService / QuestService / CombatService et vérifie le flux
-- dégâts -> mort -> récompenses -> série -> prime -> assistance -> quêtes.
-- Usage : python3 tools/check.py --emit .emit && luau tests/sim.luau

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("  ÉCHEC : " .. name .. (detail and (" -> " .. tostring(detail)) or ""))
	end
end
local function eq(name, a, b)
	check(name, a == b, ("attendu %s, obtenu %s"):format(tostring(b), tostring(a)))
end

-- ===== Faux Roblox (tests/mock.luau) =====
local M = require("./mock")
local Signal, newInstance, remoteLog = M.Signal, M.newInstance, M.remoteLog
local Vector3, workspace = M.Vector3, M.workspace
local PlayersService, allPlayers = M.PlayersService, M.allPlayers

-- ===== Chargement des vrais modules =====
local E = "../.emit/ServerScriptService/Server/"
local DataService = require(E .. "DataService")
local PlayerService = require(E .. "PlayerService")
local QuestService = require(E .. "QuestService")
local CombatService = require(E .. "CombatService")
local Weapons = require("../.emit/ReplicatedStorage/Shared/Weapons")
local Config = require("../.emit/ReplicatedStorage/Shared/Config")
local QuestLogic = require("../.emit/ReplicatedStorage/Shared/QuestLogic")
local Progression = require("../.emit/ReplicatedStorage/Shared/Progression")

local nextId = 100
local function makePlayer(name)
	nextId += 1
	local p = newInstance("Player")
	p.Name, p.DisplayName, p.UserId = name, name, nextId
	p.Parent = PlayersService
	table.insert(allPlayers, p)
	DataService.Load(p)
	PlayerService.Setup(p, DataService.Get(p))
	p:SetAttribute("InArena", true)
	-- personnage factice
	local model = newInstance("Model")
	model.Name = name
	local hum = newInstance("Humanoid")
	hum.Health, hum.MaxHealth = 100, 100
	hum.Died = Signal()
	function hum:TakeDamage(d)
		if self.Health <= 0 then return end
		self.Health = math.max(0, self.Health - d)
		if self.Health <= 0 then self.Died:Fire() end
	end
	hum.Parent = model
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Position = Vector3.new(0, 0, 0)
	root.Parent = model
	p.Character = model
	CombatService.Track(hum)
	p._hum = hum
	return p
end
local function revive(p)
	p._hum.Health = 100
end
local function feed()
	local n = 0
	for _, r in ipairs(remoteLog) do if r.remote == "Feed" then n += 1 end end
	return n
end
local function lastNotify(player, kind)
	for i = #remoteLog, 1, -1 do
		local r = remoteLog[i]
		if r.remote == "Notify" and r.to == player and r.data.Kind == kind then return r.data end
	end
end

local sword, katana, pistol = Weapons.Get("sword"), Weapons.Get("katana"), Weapons.Get("pistol")
local killsSeen = {}
CombatService.OnKill(function(k, v, info) table.insert(killsSeen, { k, v, info }) end)

workspace:SetAttribute("MatchState", "Playing")
workspace:SetAttribute("MatchMode", "FFA")

local A, B, C = makePlayer("Alice"), makePlayer("Bob"), makePlayer("Cleo")
-- forcer des quêtes connues
DataService.Get(A).Quests = { Day = QuestLogic.DayKey(os.time()), List = {
	{ Id = "kills10", Progress = 0, Claimed = false },
	{ Id = "head3", Progress = 0, Claimed = false },
	{ Id = "streak4", Progress = 0, Claimed = false },
} }

print("• Règles de dégâts")
do
	local dealt = CombatService.DealDamage(A, A.Character, 50, { Weapon = sword })
	eq("pas d'auto-dégâts", dealt, 0)
	workspace:SetAttribute("MatchState", "Intermission")
	eq("pas de dégâts hors manche", (CombatService.DealDamage(A, B.Character, 26, { Weapon = sword })), 0)
	workspace:SetAttribute("MatchState", "Playing")
	B:SetAttribute("InArena", false)
	eq("pas de dégâts sur un joueur du hub", (CombatService.DealDamage(A, B.Character, 26, { Weapon = sword })), 0)
	B:SetAttribute("InArena", true)
	workspace:SetAttribute("MatchMode", "TEAM")
	A:SetAttribute("Team", "Red"); B:SetAttribute("Team", "Red"); C:SetAttribute("Team", "Blue")
	eq("pas de tir allié", (CombatService.DealDamage(A, B.Character, 26, { Weapon = sword })), 0)
	eq("ennemi touché", (CombatService.DealDamage(A, C.Character, 26, { Weapon = sword })), 26)
	revive(C)
	workspace:SetAttribute("MatchMode", "FFA")
	local ff = newInstance("ForceField"); ff.Parent = B.Character
	eq("ForceField protège", (CombatService.DealDamage(A, B.Character, 26, { Weapon = sword })), 0)
	ff:Destroy()
	eq("hors protection : dégâts", (CombatService.DealDamage(A, B.Character, 10, { Weapon = sword })), 10)
	revive(B)
end

print("• Élimination, récompenses, série")
do
	local pa = DataService.Get(A)
	local coins0, xp0 = pa.Coins, pa.XP
	local total = 0
	for _ = 1, 4 do
		local d = CombatService.DealDamage(A, B.Character, sword.Damage, { Weapon = sword })
		total += d
	end
	eq("Bob mort après 4 coups d'épée", B._hum.Health, 0)
	eq("dégâts cumulés plafonnés aux PV (100)", total, 26 * 3 + 22)
	eq("Alice : +1 kill", pa.Kills, 1)
	eq("Bob : +1 mort", DataService.Get(B).Deaths, 1)
	eq("série d'Alice", A:GetAttribute("Streak"), 1)
	eq("série de Bob remise à 0", B:GetAttribute("Streak"), 0)
	eq("pièces gagnées", pa.Coins - coins0, Config.Rewards.KillCoins)
	eq("XP gagnée", (pa.XP - xp0), Config.Rewards.KillXP)
	eq("feed publié", feed(), 1)
	eq("callback d'élimination", #killsSeen, 1)
	eq("callback : bon tueur", killsSeen[1][1], A)
	local n = lastNotify(A, "Kill")
	check("notification de kill", n ~= nil and n.Extra.Coins == Config.Rewards.KillCoins)
	check("notification de mort envoyée à Bob", lastNotify(B, "Death") ~= nil)
	eq("quête kills10 +1", pa.Quests.List[1].Progress, 1)
	eq("attribut Coins répliqué", A:GetAttribute("Coins"), pa.Coins)
	eq("leaderstats Kills", A:FindFirstChild("leaderstats").Kills.Value, 1)
end

print("• Tir à la tête, séries, primes")
do
	local pa = DataService.Get(A)
	revive(B)
	-- 3 kills consécutifs en alternant les victimes (sinon l'anti-farm réduit les gains)
	local victims = { C, B, C }
	for i = 1, 3 do
		local victim = victims[i]
		revive(victim)
		local before, levelBefore = pa.Coins, pa.Level
		for _ = 1, 4 do
			CombatService.DealDamage(A, victim.Character, pistol.Damage, { Weapon = pistol, Headshot = true })
		end
		local levelUpCoins = 0
		for lv = levelBefore + 1, pa.Level do
			levelUpCoins += Progression.LevelUpReward(lv)
		end
		eq("kill #" .. (i + 1) .. " : série", A:GetAttribute("Streak"), i + 1)
		local expected = Config.Rewards.KillCoins + math.min(Config.Rewards.StreakCoinCap, i * Config.Rewards.StreakCoinStep) + Config.Rewards.HeadshotCoins
		eq("pièces kill #" .. (i + 1) .. " (hors bonus de niveau)", pa.Coins - before - levelUpCoins, expected)
	end
	eq("têtes comptées", pa.Headshots, 3)
	eq("quête head3 terminée", pa.Quests.List[2].Progress, 3)
	eq("quête streak4 = 4", pa.Quests.List[3].Progress, 4)
	check("meilleure série", pa.BestStreak == 4)
	check("quête signalée terminée", lastNotify(A, "Quest") ~= nil)
	-- claim
	local ok, msg = QuestService.Claim(A, "head3")
	check("récupération de quête", ok, msg)
	local ok2 = QuestService.Claim(A, "head3")
	check("double récupération refusée", not ok2)
	local ok3 = QuestService.Claim(A, "kills10")
	check("quête incomplète refusée", not ok3)
	check("id invalide refusé", not QuestService.Claim(A, 42))

	-- prime : Alice (série 4) puis 5
	revive(B)
	for _ = 1, 4 do CombatService.DealDamage(A, B.Character, pistol.Damage, { Weapon = pistol, Headshot = true }) end
	eq("série 5", A:GetAttribute("Streak"), 5)
	-- Bob tue Alice : prime
	local pb = DataService.Get(B)
	revive(B); revive(A)
	local before = pb.Coins
	for _ = 1, 5 do CombatService.DealDamage(B, A.Character, sword.Damage, { Weapon = sword }) end
	eq("Alice morte", A._hum.Health, 0)
	local bounty = math.min(Config.Rewards.BountyCap, 5 * Config.Rewards.BountyPerStreak)
	eq("Bob touche la prime", pb.Coins - before, Config.Rewards.KillCoins + bounty)
	eq("série d'Alice remise à 0", A:GetAttribute("Streak"), 0)
	local n = lastNotify(B, "Kill")
	eq("prime dans la notification", n.Extra.Bounty, bounty)
end

print("• Assistances, rage, vol de vie, cibles d'entraînement")
do
	revive(A); revive(B); revive(C)
	local pc = DataService.Get(C)
	local before = pc.Coins
	CombatService.DealDamage(C, A.Character, 10, { Weapon = sword }) -- assistance
	for _ = 1, 4 do CombatService.DealDamage(B, A.Character, 26, { Weapon = sword }) end
	eq("Alice morte (assist)", A._hum.Health, 0)
	eq("assistance payée à Cleo", pc.Coins - before, Config.Rewards.AssistCoins)
	check("notification d'assistance", lastNotify(C, "Assist") ~= nil)

	revive(A); revive(C)
	B:SetAttribute("BoostUntil", workspace:GetServerTimeNow() + 10)
	eq("rage x1.5 (40 -> 60)", (CombatService.DealDamage(B, C.Character, 40, { Weapon = sword })), 60)
	B:SetAttribute("BoostUntil", 0)
	revive(C)
	eq("rage expirée", (CombatService.DealDamage(B, C.Character, 40, { Weapon = sword })), 40)

	-- vol de vie
	local sov = Weapons.Get("sovereign")
	B._hum.Health = 50
	CombatService.DealDamage(A, B.Character, 1, { Weapon = katana }) -- touche B pour avoir une cible vivante
	revive(C)
	A._hum.Health = 40
	CombatService.DealDamage(A, C.Character, sov.Damage, { Weapon = sov })
	eq("vol de vie +30% de 34 (=10.2)", math.floor(A._hum.Health * 10 + 0.5) / 10, 50.2)

	-- cible d'entraînement : pas de récompense, pas de feed
	local dummy = newInstance("Model")
	dummy:SetAttribute("Dummy", true)
	local dh = newInstance("Humanoid"); dh.Health, dh.MaxHealth = 150, 150; dh.Died = Signal()
	function dh:TakeDamage(d) self.Health = math.max(0, self.Health - d) if self.Health <= 0 then self.Died:Fire() end end
	dh.Parent = dummy
	local feedBefore, coinsBefore = feed(), DataService.Get(A).Coins
	revive(A)
	for _ = 1, 6 do CombatService.DealDamage(A, dummy, 30, { Weapon = sword }) end
	eq("dummy détruit", dh.Health, 0)
	eq("aucun feed pour un dummy", feed(), feedBefore)
	eq("aucune pièce pour un dummy", DataService.Get(A).Coins, coinsBefore)
	-- modèle quelconque : non blessable
	local rock = newInstance("Model")
	eq("modèle sans humanoïde ignoré", (CombatService.DealDamage(A, rock, 30, { Weapon = sword })), 0)
end

print("• Anti-farm (même victime en boucle)")
do
	local D, F = makePlayer("Dan"), makePlayer("Fay")
	local pd = DataService.Get(D)
	local gains = {}
	for i = 1, 5 do
		revive(F)
		local before, lv = pd.Coins, pd.Level
		for _ = 1, 4 do CombatService.DealDamage(D, F.Character, 26, { Weapon = sword }) end
		local bonus = 0
		for l = lv + 1, pd.Level do bonus += Progression.LevelUpReward(l) end
		gains[i] = pd.Coins - before - bonus
	end
	local R = Config.Rewards
	eq("kill 1 normal", gains[1], R.KillCoins)
	eq("kill 3 normal", gains[3], R.KillCoins + 2 * R.StreakCoinStep)
	eq("kill 4 réduit", gains[4], math.floor((R.KillCoins + 3 * R.StreakCoinStep) * R.FarmMultiplier))
	check("kill 5 réduit", gains[5] < gains[3] / 2)
	-- une autre victime remet le compteur à zéro
	local G = makePlayer("Gus")
	for _ = 1, 4 do CombatService.DealDamage(D, G.Character, 26, { Weapon = sword }) end
	local before, lv = pd.Coins, pd.Level
	revive(G)
	for _ = 1, 4 do CombatService.DealDamage(D, G.Character, 26, { Weapon = sword }) end
	local bonus = 0
	for l = lv + 1, pd.Level do bonus += Progression.LevelUpReward(l) end
	check("nouvelle victime : gain plein", pd.Coins - before - bonus >= R.KillCoins)
end

print("• Achats intégrés")
do
	local Enum = nil
	local Monetization = require(E .. "MonetizationService")
	Config.Monetization.Products[1].Id = 777
	local H = makePlayer("Hana")
	local ph = DataService.Get(H)
	local before = ph.Coins
	eq("reçu crédité", Monetization.HandleReceipt({ PlayerId = H.UserId, PurchaseId = "abc", ProductId = 777 }), "Granted")
	eq("pièces du pack", ph.Coins - before, 500)
	eq("reçu rejoué : pas de double crédit", Monetization.HandleReceipt({ PlayerId = H.UserId, PurchaseId = "abc", ProductId = 777 }), "Granted")
	eq("solde inchangé", ph.Coins - before, 500)
	eq("produit inconnu refusé", Monetization.HandleReceipt({ PlayerId = H.UserId, PurchaseId = "x", ProductId = 1 }), "NotYet")
	eq("joueur absent : réessayer", Monetization.HandleReceipt({ PlayerId = 424242, PurchaseId = "y", ProductId = 777 }), "NotYet")
	ph.Ephemeral = true
	eq("profil éphémère : réessayer", Monetization.HandleReceipt({ PlayerId = H.UserId, PurchaseId = "z", ProductId = 777 }), "NotYet")
	ph.Ephemeral = nil
	check("achat bloqué si Id = 0", not Monetization.Prompt(H, "Pass", "VIP"))
	check("clé inconnue refusée", not Monetization.Prompt(H, "Pass", "hack"))
	-- multiplicateurs
	H:SetAttribute("HasDoubleCoins", true); H:SetAttribute("HasDoubleXP", true)
	local c0, x0, l0 = ph.Coins, ph.XP, ph.Level
	PlayerService.AddCoins(H, 10)
	eq("pièces x2", ph.Coins - c0, 20)
	PlayerService.AddCoins(H, 10, true)
	eq("montant brut sans multiplicateur", ph.Coins - c0, 30)
	PlayerService.AddXP(H, 10)
	eq("XP x2", ph.XP - x0 + (ph.Level - l0) * 120, 20)
	H:SetAttribute("HasVIP", true)
	local ok = QuestService.ClaimDaily(H)
	check("cadeau VIP +50%", ok and ph.DailyStreak == 1)
end

print("• Profils (DataService.Reconcile)")
do
	local d = DataService.Reconcile({ Coins = 0 / 0, Level = 999, Owned = { sword = true, hack = true }, Loadout = { "hack", "sword", "sword", "bow", "katana" } })
	eq("NaN corrigé", d.Coins, 100)
	eq("niveau plafonné", d.Level, Config.MaxLevel)
	check("arme inconnue retirée", d.Owned.hack == nil)
	check("armes de départ garanties", d.Owned.sword and d.Owned.bow)
	eq("loadout : doublons et armes non possédées retirés", table.concat(d.Loadout, ","), "sword,bow")
	local fresh = DataService.Reconcile("corrompu")
	eq("profil neuf si donnée invalide", fresh.Level, 1)
	local neg = DataService.Reconcile({ Coins = -50 })
	eq("pièces négatives -> 0", neg.Coins, 0)
	local view = PlayerService.BuildClientProfile(A)
	check("vue client", view and view.Level and view.Owned and view.Quests and view.DailyNext == 1 and view.DailyAvailable == true)
	-- cadeau quotidien
	local ok1 = QuestService.ClaimDaily(A)
	local ok2 = QuestService.ClaimDaily(A)
	check("cadeau quotidien 1x/jour", ok1 and not ok2)
	eq("série cadeau", DataService.Get(A).DailyStreak, 1)
	-- niveau
	local pa = DataService.Get(A)
	local lvl = pa.Level
	PlayerService.AddXP(A, 1000)
	check("montée de niveau", pa.Level > lvl)
	check("notification de niveau", lastNotify(A, "LevelUp") ~= nil)
	check("dépense refusée si fonds insuffisants", not PlayerService.SpendCoins(A, 1e9))
	local c0 = pa.Coins
	check("dépense acceptée", PlayerService.SpendCoins(A, 10) and pa.Coins == c0 - 10)
	check("dépense négative refusée", not PlayerService.SpendCoins(A, -10))
end

print(("\nRésultat : %d tests réussis, %d échecs"):format(passed, failed))
if failed > 0 then
	error("des tests ont échoué")
end
