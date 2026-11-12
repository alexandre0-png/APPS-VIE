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
local AnimLogic = require("../.emit/ReplicatedStorage/Shared/AnimLogic")
local CL = require("../.emit/ReplicatedStorage/Shared/CinematicLogic")
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
	eq("6 chapitres", #Lore.Chapters, 6)
	eq("6 runes", #Lore.Runes, 6)
	local ids, unlocks = {}, {}
	for _, c in ipairs(Lore.Chapters) do
		check("chapitre unique " .. c.Id, not ids[c.Id]); ids[c.Id] = true
		check("stat connue " .. c.Id, ({ Level = 1, Kills = 1, Wins = 1, BestStreak = 1, Headshots = 1, Runes = 1 })[c.Stat] == 1)
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

section("AnimLogic")
do
	check("tout actif", AnimLogic.Enabled({ Enabled = true, Run = true }, "Run"))
	check("clé désactivée", not AnimLogic.Enabled({ Enabled = true, Run = false }, "Run"))
	check("interrupteur général", not AnimLogic.Enabled({ Enabled = false, Run = true }, "Run"))
	check("clé absente = active", AnimLogic.Enabled({ Enabled = true }, "Autre"))
	for key, value in pairs(Config.Animations) do
		check("Config.Animations." .. key .. " booléen", type(value) == "boolean")
	end
	eq("repos", AnimLogic.MoveState(0, true, false, false, false), "Idle")
	eq("course", AnimLogic.MoveState(16, true, false, false, false), "Run")
	eq("air", AnimLogic.MoveState(16, false, false, false, false), "Air")
	eq("garde", AnimLogic.MoveState(16, true, false, false, true), "Guard")
	eq("glissade > garde", AnimLogic.MoveState(16, true, true, false, true), "Slide")
	eq("esquive prioritaire", AnimLogic.MoveState(16, true, true, true, true), "Dodge")
	check("inclinaison nulle à l'arrêt", AnimLogic.LeanAngle(0, 16, 12) == 0)
	check("inclinaison max bornée", math.abs(AnimLogic.LeanAngle(99, 16, 12) - math.rad(12)) < 1e-9)
	check("inclinaison demi-vitesse", math.abs(AnimLogic.LeanAngle(8, 16, 12) - math.rad(6)) < 1e-9)
	eq("maxSpeed 0 sûr", AnimLogic.LeanAngle(5, 0, 12), 0)
	check("déclenchement possible", AnimLogic.CanTrigger(10, 8, 1.2, true, 12, 8))
	check("recharge non écoulée", not AnimLogic.CanTrigger(10, 9.5, 1.2, true, 12, 8))
	check("en l'air refusé", not AnimLogic.CanTrigger(10, 0, 1.2, false, 12, 8))
	check("trop lent refusé", not AnimLogic.CanTrigger(10, 0, 1.2, true, 3, 8))
	check("cloche 0 aux bords", AnimLogic.Bell(0) < 1e-9 and AnimLogic.Bell(1) < 1e-9)
	check("cloche 1 au milieu", math.abs(AnimLogic.Bell(0.5) - 1) < 1e-9)
	check("cloche bornée", AnimLogic.Bell(-3) < 1e-9 and AnimLogic.Bell(7) < 1e-9)
	eq("délai 1re ligne", AnimLogic.Stagger(1, 0.08, 0.5), 0)
	check("délai 3e ligne", math.abs(AnimLogic.Stagger(3, 0.08, 0.5) - 0.16) < 1e-9)
	eq("délai plafonné", AnimLogic.Stagger(50, 0.08, 0.5), 0.5)
	local a, b = AnimLogic.ConfettiPlan(30, 5, 42), AnimLogic.ConfettiPlan(30, 5, 42)
	eq("30 confettis", #a, 30)
	local same, valid = true, true
	for i, c in ipairs(a) do
		same = same and c.X == b[i].X and c.Delay == b[i].Delay
		valid = valid and c.X >= 0 and c.X <= 1 and c.Color >= 1 and c.Color <= 5 and c.Duration >= 1.4 and c.Size >= 6
	end
	check("confettis déterministes", same)
	check("confettis valides", valid)
	check("graines différentes", AnimLogic.ConfettiPlan(5, 5, 1)[1].X ~= AnimLogic.ConfettiPlan(5, 5, 2)[1].X)
end

section("CinematicLogic")
do
	for name, seq in pairs(CL.Sequences) do
		local total = CL.TotalDuration(seq)
		check("durée de " .. name .. " raisonnable", total >= 10 and total <= 40, total)
		eq("clé de " .. name, seq.Key, name)
		for i, shot in ipairs(seq.Shots) do
			check(("plan %s#%d valide"):format(name, i), shot.Duration > 0 and #shot.Caption > 0 and #shot.Sub > 0)
			if seq.Camera then check(("caméra %s#%d"):format(name, i), shot.From ~= nil and shot.To ~= nil and shot.Look ~= nil and #shot.From == 3)
			else check(("pas de caméra %s#%d"):format(name, i), shot.From == nil) end
			if shot.Hero then check("héros du plan connu", Lore.Hero(shot.Hero) ~= nil) end
		end
	end
	check("intro 20-40 s", CL.TotalDuration(CL.Sequences.intro) >= 20 and CL.TotalDuration(CL.Sequences.intro) <= 40)
	-- machine d'état
	local st = CL.New(CL.Sequences.tutorial)
	eq("départ plan 1", st.Index, 1)
	CL.Step(st, 5.9); check("encore plan 1", st.Index == 1 and not st.Done)
	CL.Step(st, 0.2); eq("plan 2", st.Index, 2)
	check("progression ~0.3", math.abs(CL.Progress(st) - 6.1 / 20) < 1e-9)
	CL.Step(st, 100)
	check("terminée", st.Done and st.Reason == "completed" and st.Index == 3)
	check("progression 1 à la fin", CL.Progress(st) == 1)
	local before = st.Elapsed
	CL.Step(st, 5); eq("figée après la fin", st.Elapsed, before)
	-- skip
	local sk = CL.New(CL.Sequences.intro)
	CL.Step(sk, 7)
	CL.Skip(sk)
	check("skip", sk.Done and sk.Reason == "skipped")
	CL.End(sk, "interrupted"); eq("raison conservée", sk.Reason, "skipped")
	check("skip = vu", CL.ShouldMarkSeen(sk.Reason))
	check("fin normale = vu", CL.ShouldMarkSeen("completed"))
	check("interruption = rejouera", not CL.ShouldMarkSeen("interrupted") and not CL.ShouldMarkSeen(nil))
	local it = CL.End(CL.New(CL.Sequences.hill), "interrupted")
	check("interrompue non marquée", it.Reason == "interrupted" and not CL.ShouldMarkSeen(it.Reason))
	-- plusieurs pas : même résultat qu'un grand pas
	local a, b = CL.New(CL.Sequences.season), CL.New(CL.Sequences.season)
	for _ = 1, 145 do CL.Step(a, 0.1) end
	CL.Step(b, 14.5)
	check("pas fins = grand pas", a.Done == b.Done and a.Index == b.Index)
	local half = CL.New(CL.Sequences.season); CL.Step(half, 3)
	check("alpha du plan", math.abs(CL.ShotAlpha(half) - 0.5) < 1e-9)
	local p0 = CL.Lerp({ 0, 0, 0 }, { 10, 20, 30 }, 0)
	local p1 = CL.Lerp({ 0, 0, 0 }, { 10, 20, 30 }, 1)
	local pm = CL.Lerp({ 0, 0, 0 }, { 10, 20, 30 }, 0.5)
	check("lerp bornes et milieu", p0[1] == 0 and p1[3] == 30 and pm[2] == 10)
	-- planification
	local cfg = { Enabled = true, Intro = true, Tutorial = true, Season = true, Hill = true }
	local order = { "intro", "tutorial", "season" }
	local ctx = { InArena = false, SeasonId = 1, NextMode = "FFA" }
	eq("intro d'abord", CL.NextToPlay(cfg, {}, order, ctx), "intro")
	eq("puis tutoriel", CL.NextToPlay(cfg, { intro = true }, order, ctx), "tutorial")
	eq("puis saison", CL.NextToPlay(cfg, { intro = true, tutorial = true }, order, ctx), "season")
	eq("tout vu", CL.NextToPlay(cfg, { intro = true, tutorial = true, season1 = true }, order, ctx), nil)
	eq("saison 2 rejoue", CL.NextToPlay(cfg, { intro = true, tutorial = true, season1 = true }, order, { InArena = false, SeasonId = 2, NextMode = "FFA" }), "season")
	eq("jamais en arène (intro)", CL.NextToPlay(cfg, {}, order, { InArena = true, SeasonId = 1, NextMode = "FFA" }), nil)
	eq("interrupteur général", CL.NextToPlay({ Enabled = false }, {}, order, ctx), nil)
	eq("intro désactivée", CL.NextToPlay({ Enabled = true, Intro = false }, {}, order, ctx), "tutorial")
	eq("hill en arène avant roi de la tour", CL.NextToPlay(cfg, {}, { "hill" }, { InArena = true, SeasonId = 1, NextMode = "HILL" }), "hill")
	eq("hill seulement si mode HILL", CL.NextToPlay(cfg, {}, { "hill" }, { InArena = true, SeasonId = 1, NextMode = "FFA" }), nil)
	eq("hill vu", CL.NextToPlay(cfg, { hill = true }, { "hill" }, { InArena = true, SeasonId = 1, NextMode = "HILL" }), nil)
	local keys = CL.SeenKeys(3)
	check("liste blanche", keys.intro and keys.tutorial and keys.hill and keys.season3 and not keys.season1 and not keys["../x"])
	for k, v in pairs(Config.Cinematics) do
		if k ~= "FadeSeconds" then check("Config.Cinematics." .. k .. " booléen", type(v) == "boolean") end
	end
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
