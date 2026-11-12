--!nonstrict
-- Tests unitaires exécutés avec le runtime Luau (hors Roblox).
-- Usage : python3 tools/check.py --emit .emit && luau tests/run.luau

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
local function section(title)
	print("• " .. title)
end

local Progression = require("../.emit/ReplicatedStorage/Shared/Progression")
local Combat = require("../.emit/ReplicatedStorage/Shared/Combat")
local QuestLogic = require("../.emit/ReplicatedStorage/Shared/QuestLogic")
local MatchLogic = require("../.emit/ReplicatedStorage/Shared/MatchLogic")
local Weapons = require("../.emit/ReplicatedStorage/Shared/Weapons")
local Config = require("../.emit/ReplicatedStorage/Shared/Config")
local Lore = require("../.emit/ReplicatedStorage/Shared/Lore")
local SeasonLogic = require("../.emit/ReplicatedStorage/Shared/SeasonLogic")
local BotLogic = require("../.emit/ReplicatedStorage/Shared/BotLogic")

section("Progression")
eq("XpToNext(1)", Progression.XpToNext(1), 120)
do
	local lv, xp, g = Progression.AddXp(1, 0, 100, 50)
	eq("pas de niveau", lv, 1); eq("xp conservée", xp, 100); eq("gain 0", g, 0)
	lv, xp, g = Progression.AddXp(1, 100, 30, 50)
	eq("niveau 2", lv, 2); eq("reste xp", xp, 10); eq("gain 1", g, 1)
	lv, xp, g = Progression.AddXp(1, 0, 120 + 160 + 200 + 5, 50)
	eq("3 niveaux d'un coup", lv, 4); eq("reste", xp, 5); eq("gagnés", g, 3)
	lv, xp, g = Progression.AddXp(49, 0, 1e9, 50)
	eq("plafond niveau", lv, 50); eq("xp remise à 0 au max", xp, 0); eq("un seul niveau", g, 1)
	lv, xp = Progression.AddXp(3, 10, -50, 50)
	eq("xp négative ignorée", xp, 10)
end
eq("titre niv 1", Progression.TitleFor(1, Config.Titles), "Recrue")
eq("titre niv 10", Progression.TitleFor(10, Config.Titles), "Gladiateur")
eq("titre niv 29", Progression.TitleFor(29, Config.Titles), "Champion")
eq("titre niv 50", Progression.TitleFor(50, Config.Titles), "Mythe")
eq("récompense niveau", Progression.LevelUpReward(5), 200)

section("Combat")
eq("dégâts de base", Combat.ComputeDamage(26, nil), 26)
eq("tête x1.7", Combat.ComputeDamage(17, { Headshot = true, HeadshotMult = 1.7 }), 29)
eq("tête défaut x1.5", Combat.ComputeDamage(20, { Headshot = true }), 30)
eq("dos x2.2", Combat.ComputeDamage(13, { Backstab = true, BackstabMult = 2.2 }), 29)
eq("rage x1.5", Combat.ComputeDamage(40, { Boost = 1.5 }), 60)
eq("minimum 1", Combat.ComputeDamage(0.1, { Falloff = 0.35 }), 1)
eq("rail à la tête tue (68x2=136)", Combat.ComputeDamage(68, { Headshot = true, HeadshotMult = 2.0 }), 136)
eq("splash centre", Combat.SplashFalloff(0, 9), 1)
check("splash bord >= 0.35", Combat.SplashFalloff(9, 9) >= 0.35 and Combat.SplashFalloff(9, 9) < 0.36)
eq("splash hors rayon borné", Combat.SplashFalloff(100, 9), 0.35)
check("cône devant", Combat.InCone(0, -1, 0, -5, 110))
check("cône derrière refusé", not Combat.InCone(0, -1, 0, 5, 110))
check("cône 45° dans 110°", Combat.InCone(0, -1, 3, -3, 110))
check("cône 80° hors 110° (arc/2=55)", not Combat.InCone(0, -1, 5, -0.9, 110))
check("cible superposée", Combat.InCone(0, -1, 0, 0, 90))
check("backstab : victime regarde -Z, attaquant au +Z", Combat.IsBackstab(0, -1, 0, -1) == true)
check("pas backstab de face", Combat.IsBackstab(0, -1, 0, 1) == false)
do
	local y, p = Combat.SpreadAngles(6, 1, 0)
	check("spread max = 6°", math.abs(y - math.rad(6)) < 1e-9 and math.abs(p) < 1e-9)
	y, p = Combat.SpreadAngles(6, 0, 0.3)
	check("spread nul", y == 0 and p == 0)
end

section("QuestLogic")
do
	local a, b = QuestLogic.Pick(20000, 3), QuestLogic.Pick(20000, 3)
	eq("3 quêtes", #a, 3)
	check("déterministe", a[1] == b[1] and a[2] == b[2] and a[3] == b[3])
	check("distinctes", a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3])
	local seen = {}
	for day = 20000, 20060 do
		for _, id in ipairs(QuestLogic.Pick(day, 3)) do
			seen[id] = true
			check("quête valide " .. id, QuestLogic.Get(id) ~= nil)
		end
	end
	local n = 0
	for _ in pairs(seen) do n += 1 end
	check("toutes les quêtes apparaissent sur 60 jours", n == #QuestLogic.Pool, n)

	local state = { Day = 1, List = {
		{ Id = "kills10", Progress = 0, Claimed = false },
		{ Id = "melee5", Progress = 0, Claimed = false },
		{ Id = "streak4", Progress = 0, Claimed = false },
	} }
	check("Kill melee change", QuestLogic.Apply(state, "Kill", 1, "Melee"))
	eq("kills10 +1", state.List[1].Progress, 1); eq("melee5 +1", state.List[2].Progress, 1)
	QuestLogic.Apply(state, "Kill", 1, "Ranged")
	eq("kills10 +1 (ranged)", state.List[1].Progress, 2); eq("melee5 inchangé", state.List[2].Progress, 1)
	QuestLogic.Apply(state, "Streak", 2)
	QuestLogic.Apply(state, "Streak", 1)
	eq("série = maximum", state.List[3].Progress, 2)
	QuestLogic.Apply(state, "Streak", 9)
	eq("série plafonnée à la cible", state.List[3].Progress, 4)
	check("streak4 terminée", state.List[3].Progress >= QuestLogic.Get("streak4").Target)
	check("pas de changement après complétion", not QuestLogic.Apply(state, "Streak", 9))
	check("évènement sans quête", not QuestLogic.Apply(state, "Win", 1))
	eq("DayKey", QuestLogic.DayKey(86400 * 3 + 5), 3)
	local fresh = QuestLogic.NewState(5)
	eq("NewState 3", #fresh.List, 3); eq("jour", fresh.Day, 5)
end

section("MatchLogic")
do
	local spawns = { { X = 0, Z = 0 }, { X = 100, Z = 0 }, { X = 50, Z = 80 }, { X = -100, Z = 10 } }
	local idx = MatchLogic.PickSpawn(spawns, { { X = 0, Z = 0 } }, 0)
	eq("spawn le plus loin de l'ennemi (rand=0)", idx, 4)
	eq("3e meilleur (rand=0.99)", MatchLogic.PickSpawn(spawns, { { X = 0, Z = 0 } }, 0.99), 3)
	check("jamais le spawn sur l'ennemi", MatchLogic.PickSpawn(spawns, { { X = 0, Z = 0 } }, 0.99) ~= 1)
	check("sans ennemi : index valide", MatchLogic.PickSpawn(spawns, {}, 0.5) >= 1)
	eq("aucun spawn", MatchLogic.PickSpawn({}, {}, 0.5), 0)
	eq("équipe moins peuplée (rouge)", MatchLogic.BalanceTeam(1, 3, 10, 0, 0.9), "Red")
	eq("équipe moins peuplée (bleu)", MatchLogic.BalanceTeam(3, 1, 0, 10, 0.1), "Blue")
	eq("égalité -> moins de points", MatchLogic.BalanceTeam(2, 2, 5, 9, 0.9), "Red")
	eq("égalité totale rand<0.5", MatchLogic.BalanceTeam(2, 2, 5, 5, 0.2), "Red")
	eq("égalité totale rand>=0.5", MatchLogic.BalanceTeam(2, 2, 5, 5, 0.7), "Blue")
	local w = MatchLogic.FFAWinners({ { Id = 1, Score = 5 }, { Id = 2, Score = 9 }, { Id = 3, Score = 9 } })
	eq("2 ex æquo", #w, 2)
	eq("aucun vainqueur à 0", #MatchLogic.FFAWinners({ { Id = 1, Score = 0 } }), 0)
	eq("vainqueur d'équipe", MatchLogic.TeamWinner(10, 4), "Red")
	eq("égalité d'équipes", MatchLogic.TeamWinner(7, 7), "Draw")
	local m, i = MatchLogic.NextMode({ "FFA", "TEAM" }, 0)
	eq("mode 1", m, "FFA"); eq("idx 1", i, 1)
	m, i = MatchLogic.NextMode({ "FFA", "TEAM" }, 2)
	eq("rotation", m, "FFA"); eq("idx", i, 1)
	check("sur le plateau", MatchLogic.OnHill(5, 8, 5, 0, 0, 17, 7.5))
	check("au sol : pas de point", not MatchLogic.OnHill(5, 1, 5, 0, 0, 17, 7.5))
	check("hors du rayon", not MatchLogic.OnHill(30, 8, 0, 0, 0, 17, 7.5))
	eq("prime sous le seuil", MatchLogic.Bounty(4, 5, 10, 200), 0)
	eq("prime série 5", MatchLogic.Bounty(5, 5, 10, 200), 50)
	eq("prime plafonnée", MatchLogic.Bounty(50, 5, 10, 200), 200)
	eq("label x3", MatchLogic.StreakLabel(3), "Triple élimination !")
	eq("pas de label x4", MatchLogic.StreakLabel(4), nil)
end

section("Weapons & Config (cohérence des données)")
do
	local ids, kinds = {}, { Melee = true, Slam = true, Hitscan = true, Shotgun = true, Projectile = true }
	eq("10 armes", #Weapons.List, 10)
	local lastLevel = 0
	for _, def in ipairs(Weapons.List) do
		check(def.Id .. " id unique", not ids[def.Id]); ids[def.Id] = true
		check(def.Id .. " genre valide", kinds[def.Kind])
		check(def.Id .. " classe", def.Class == "Melee" or def.Class == "Ranged")
		check(def.Id .. " rareté connue", Config.Rarities[def.Rarity] ~= nil)
		check(def.Id .. " cadence > 0", def.Cooldown > 0.1)
		check(def.Id .. " dégâts > 0", def.Damage > 0)
		check(def.Id .. " couleur", #def.Accent == 6 and tonumber(def.Accent, 16) ~= nil)
		check(def.Id .. " Handle en premier", def.Parts[1] ~= nil and #def.Parts <= 6)
		for _, part in ipairs(def.Parts) do
			check(def.Id .. " bloc valide", #part.Size == 3 and #part.Offset == 3 and #part.Color == 6 and part.Material ~= nil)
		end
		check(def.Id .. " niveau croissant", def.LevelReq >= lastLevel); lastLevel = def.LevelReq
		check(def.Id .. " niveau max atteignable", def.LevelReq <= Config.MaxLevel)
		if def.Kind == "Melee" then check(def.Id .. " arc+portée", def.Arc and def.Range > 0) end
		if def.Kind == "Slam" then check(def.Id .. " rayon", def.Radius and def.Radius > 0) end
		if def.Kind == "Shotgun" then check(def.Id .. " plombs", def.Pellets and def.Spread) end
		if def.Kind == "Projectile" then check(def.Id .. " vitesse", def.Speed and def.Speed > 0 and def.Range / def.Speed < 6) end
		if def.Kind == "Hitscan" or def.Kind == "Shotgun" then check(def.Id .. " portée", def.Range >= 50) end
		check(def.Id .. " Get/IsValid", Weapons.Get(def.Id) == def and Weapons.IsValid(def.Id))
		-- temps pour tuer un joueur de 100 PV (corps) : jamais instantané sauf rail à la tête
		local hits = math.ceil(100 / def.Damage / (def.Pellets and 1 or 1))
		check(def.Id .. " TTK raisonnable", hits >= 1)
	end
	for _, id in ipairs(Weapons.StarterOwned) do
		eq("arme de départ gratuite " .. id, Weapons.Get(id).Price, 0)
		eq("arme de départ niveau 1 " .. id, Weapons.Get(id).LevelReq, 1)
	end
	check("IsValid refuse l'inconnu", not Weapons.IsValid("hack") and not Weapons.IsValid(42) and not Weapons.IsValid(nil))
	eq("7 récompenses quotidiennes", #Config.DailyRewards, 7)
	for i = 2, 7 do check("récompense croissante " .. i, Config.DailyRewards[i] > Config.DailyRewards[i - 1]) end
	check("rail tue en un tir à la tête", Combat.ComputeDamage(Weapons.Get("rail").Damage, { Headshot = true, HeadshotMult = Weapons.Get("rail").HeadshotMult }) >= Config.Player.MaxHealth)
	for _, mode in ipairs(Config.Match.Modes) do check("mode connu " .. mode, Config.ModeNames[mode] ~= nil) end
end

section("Lore")
do
	eq("4 héros", #Lore.Heroes, 4)
	eq("5 chapitres", #Lore.Chapters, 5)
	local ids, unlocks = {}, {}
	for _, c in ipairs(Lore.Chapters) do
		check("chapitre unique " .. c.Id, not ids[c.Id]); ids[c.Id] = true
		check("stat connue " .. c.Id, ({ Level = 1, Kills = 1, Wins = 1, BestStreak = 1, Headshots = 1 })[c.Stat] == 1)
		check("cible > 0 " .. c.Id, c.Target > 0 and c.Coins > 0)
		if c.Unlock then check("héros débloqué existe", Lore.Hero(c.Unlock) ~= nil); unlocks[c.Unlock] = true end
	end
	for _, h in ipairs(Lore.Heroes) do
		check("couleur héros " .. h.Key, #h.Color == 6 and tonumber(h.Color, 16) ~= nil)
	end
	check("kael et mira libres", Lore.IsHeroUnlocked("kael", {}) and Lore.IsHeroUnlocked("mira", {}))
	check("orin verrouillé", not Lore.IsHeroUnlocked("orin", {}))
	check("orin après c2", Lore.IsHeroUnlocked("orin", { c2 = true }))
	check("héros inconnu refusé", not Lore.IsHeroUnlocked("nope", {}))
	eq("progression plafonnée", Lore.Progress(Lore.Chapter("c2"), { Kills = 99 }), 10)
	eq("progression partielle", Lore.Progress(Lore.Chapter("c2"), { Kills = 4 }), 4)
	eq("stat absente", Lore.Progress(Lore.Chapter("c3"), {}), 0)
end

section("SeasonLogic")
do
	eq("palier 0", SeasonLogic.Tier(99, 100, 10), 0)
	eq("palier 1", SeasonLogic.Tier(100, 100, 10), 1)
	eq("palier plafonné", SeasonLogic.Tier(99999, 100, 10), 10)
	eq("points négatifs", SeasonLogic.Tier(-5, 100, 10), 0)
	eq("pièces du palier", SeasonLogic.TierCoins(4, 60), 240)
	local st = { Id = 1, Points = 250, Claimed = { ["1"] = true } }
	check("même saison : conservé", not SeasonLogic.Rollover(st, 1) and st.Points == 250)
	check("nouvelle saison : remise à zéro", SeasonLogic.Rollover(st, 2) and st.Points == 0 and st.Id == 2 and next(st.Claimed) == nil)
	local S = Config.Season
	check("config saison cohérente", S.Tiers > 0 and S.TierPoints > 0 and S.Points.Kill > 0 and S.Points.Win > S.Points.Kill)
end

section("BotLogic")
do
	eq("aucun humain : aucun bot", BotLogic.DesiredCount(0, 4, 3), 0)
	eq("1 humain : 3 bots", BotLogic.DesiredCount(1, 4, 3), 3)
	eq("2 humains : 2 bots", BotLogic.DesiredCount(2, 4, 3), 2)
	eq("4 humains : 0 bot", BotLogic.DesiredCount(4, 4, 3), 0)
	eq("bots plafonnés", BotLogic.DesiredCount(1, 10, 3), 3)
	local i, d = BotLogic.NearestTarget(0, 0, { { Id = 1, X = 30, Z = 0 }, { Id = 2, X = 5, Z = 5 }, { Id = 3, X = 200, Z = 0 } }, 100)
	eq("cible la plus proche", i, 2); check("distance", math.abs(d - math.sqrt(50)) < 1e-9)
	eq("hors vision", (BotLogic.NearestTarget(0, 0, { { Id = 1, X = 300, Z = 0 } }, 100)), nil)
	local ux, uz = BotLogic.Steer(10, 0, function() return false end, 1)
	check("tout droit", math.abs(ux - 1) < 1e-9 and math.abs(uz) < 1e-9)
	ux, uz = BotLogic.Steer(10, 0, function(x, z) return x > 0.9 end, 1)
	check("contourne un obstacle devant", ux ~= nil and ux < 0.9 and ux > 0)
	eq("entouré : pas de direction", (BotLogic.Steer(10, 0, function() return true end, 1)), nil)
	eq("sur la cible : rien", (BotLogic.Steer(0, 0, function() return false end, 1)), nil)
	check("attaque à portée et prête", BotLogic.CanAttack(5, 6, 10, 8, 1.1))
	check("pas d'attaque en recharge", not BotLogic.CanAttack(5, 6, 10, 9.5, 1.1))
	check("pas d'attaque hors portée", not BotLogic.CanAttack(9, 6, 10, 0, 1.1))
	eq("config bots : noms", #Config.Bots.Names >= 3, true)
end

print(("\nRésultat : %d tests réussis, %d échecs"):format(passed, failed))
if failed > 0 then
	error("des tests ont échoué")
end
