-- ModuleScript : ServerScriptService/HenQuest
-- REFONTE lot 6 : énigme de la Mère Poule côté SERVEUR (étapes guidées : plumes, runes, berceuse). Toutes les règles sont dans ReplicatedStorage/Riddle (pur,
-- testé) ; ici : l'état par joueur, les prompts, les 4 plumes du jour, la récompense, l'effet collectif et le journal.
-- Principe : le client n'envoie que des INTENTIONS (« Parler », « Ramasser », toucher une pierre, 4 boutons du dialogue) ; chaque distance, chaque étape,
-- chaque cadence et la récompense (une fois par jour) sont revalidées ici. Les distances sont calculées sur les coordonnées de Config (jamais sur une
-- valeur fournie par le client). Les textes viennent de Config.HEN_LINES : le serveur n'envoie que l'identifiant de la réplique et ses paramètres.
local HenQuest = {}

function HenQuest.new(ctx)
	local Config, Riddle, Builder = ctx.Config, ctx.Riddle, ctx.Builder
	local notify, sync = ctx.notify, ctx.sync
	local RHen = ctx.RHen
	local H = Config.HEN
	local M = {}
	local day0 = function()
		return os.time() // 86400
	end
	local feathers = {} -- [dir] = Part (4 plumes, déplacées chaque jour)
	local spots, spotsDay = nil, -1
	local riddleDay, riddleToday = -1, nil -- énigme du jour mise en cache (Config.riddleFor est pure mais appelée à chaque synchronisation)
	local function riddle(day)
		if riddleDay ~= day then
			riddleDay, riddleToday = day, Config.riddleFor(day)
		end
		return riddleToday
	end
	local collective = { day = -1, count = 0, fired = false }
	local folder = ctx.world.folder
	local geo = ctx.world.geo

	local function say(s, id, params)
		if s.player and s.player.Parent then
			RHen:FireClient(s.player, "say", id, params)
		end
	end

	function M.newState()
		return { stepAt = os.clock(), startT = os.clock(), fails = 0, lullFails = 0, pos = 1, listenUntil = 0, lastPick = -99, lastTap = -99, lastAct = -99, lastTalk = -99, lastDay = -1 }
	end

	-- Journal : un relevé à chaque étape (abandon par étape, temps passé, indices) lisible dans la sortie du serveur.
	local function log(s, step)
		print(string.format("[Riddle] step=%d t=%d hints=%d", step, math.floor(os.clock() - s.hen.startT), s.data.puzzle.hints))
	end

	-- Passe à l'étape suivante : remet à zéro le chronomètre de l'étape (indice gratuit après 5 min DANS l'étape) et les échecs de l'étape.
	local function enter(s, step)
		s.hen.stepAt = os.clock()
		s.hen.fails = 0
		s.hen.pos = 1
		log(s, step)
	end

	---------------------------------------------------------------- Les 4 plumes du jour
	local function placeFeathers(day)
		spots, spotsDay = Riddle.featherSpots(Config, day), day
		for dir = 1, 4 do
			local sp = spots[dir]
			sp.y = geo.groundY(sp.x, sp.z) + 2.4
			local f = feathers[dir]
			if not f then
				f = Builder.feather(folder, dir)
				feathers[dir] = f
			end
			f.CFrame = CFrame.new(sp.x, sp.y, sp.z) * CFrame.Angles(0, dir * 1.3, 0.35)
		end
	end
	placeFeathers(day0())

	-- Remise à jour de ce joueur pour le jour courant. Retourne true si une progression d'un autre jour a été remise à zéro.
	local function refresh(s, day)
		if not s.hen then
			s.hen = M.newState()
		end
		if day ~= spotsDay then
			placeFeathers(day)
		end
		local reset, lost = Riddle.normalize(s.data.puzzle, day)
		if reset then
			s.runes = { 1, 1, 1, 1 }
			s.runeLock = 0
			s.hen.stepAt, s.hen.fails, s.hen.lullFails, s.hen.pos, s.hen.listenUntil = os.clock(), 0, 0, 1, 0
			if lost then
				log(s, 0)
				notify(s.player, "🌙 Le Grand Œuf s'est rendormi : nouvelle berceuse aujourd'hui !") -- l'avancement d'hier est remis à zéro
			end
		end
		return reset and lost
	end

	local function stepNow(s, day)
		return Riddle.stepOf(s.data.puzzle, day)
	end

	local function henDist(root)
		local h = Config.Map2.hen
		return math.sqrt((root.Position.X - h.x) ^ 2 + (root.Position.Z - h.z) ^ 2)
	end

	local function sayStep(s)
		local day = day0()
		local p = s.data.puzzle
		local step = stepNow(s, day)
		if not Riddle.available(s.data.story.ch) then
			say(s, "locked")
		elseif step == 4 then
			say(s, "done", Riddle.doneParams(os.time()))
		elseif step == 0 then
			if not p.met then
				p.met = true
				say(s, "first")
			else
				say(s, "again")
			end
		elseif step == 1 then
			say(s, "missing", Riddle.missingParams(p.feathers))
		elseif step == 2 then
			say(s, "allFeathers")
		else
			say(s, "runesRight")
			M.play(s)
		end
	end

	---------------------------------------------------------------- Dialogue
	function M.talk(s, root)
		if henDist(root) > H.talkDistance then
			return
		end
		local now = os.clock()
		if now - s.hen.lastTalk < 0.4 then
			return
		end
		s.hen.lastTalk = now
		refresh(s, day0())
		sayStep(s)
		sync(s)
	end

	local function near(s, maxDist)
		local root = ctx.getRoot(s.player)
		return root ~= nil and henDist(root) <= maxDist
	end

	local function throttle(s)
		local now = os.clock()
		if now - s.hen.lastAct < 0.5 then
			return false
		end
		s.hen.lastAct = now
		return true
	end

	-- « J'y vais ! » : accepte l'énigme du jour (étape 0 -> 1).
	function M.go(s)
		if not throttle(s) or not near(s, H.talkDistance + 16) then
			return
		end
		local day = day0()
		refresh(s, day)
		local ok, why = Riddle.start(s.data.puzzle, day, Riddle.available(s.data.story.ch))
		if ok then
			s.hen.startT = os.clock()
			s.data.puzzle.met = true
			enter(s, 1)
			notify(s.player, "📜 Berceuse du jour : étape 1/3 — trouve les 4 plumes dorées (suis la flèche jaune).", "claim")
			sync(s)
		elseif why == "started" then
			sayStep(s)
		elseif why == "locked" then
			say(s, "locked")
		else
			say(s, "done", Riddle.doneParams(os.time()))
		end
	end

	function M.explain(s)
		if not throttle(s) or not near(s, H.talkDistance + 16) then
			return
		end
		say(s, "explain")
	end

	-- « 💡 Un coup de bec » : 2 indices par jour (voir Riddle.hintStatus), jamais payants.
	function M.hint(s)
		if not throttle(s) or not near(s, H.talkDistance + 16) then
			return
		end
		local day = day0()
		refresh(s, day)
		local p = s.data.puzzle
		local ok, why, extra = Riddle.hintStatus(Config, p, day, os.clock() - s.hen.stepAt, s.hen.fails)
		if not ok then
			if why == "wait" then
				say(s, "hintWait", { mm = math.floor(extra / 60), ss = string.format("%02d", extra % 60) })
			elseif why == "fails" then
				say(s, "hintFails", { n = extra or H.failsForHint })
			elseif why == "max" then
				say(s, "hintMax")
			end
			return
		end
		local id, params = Riddle.hintFor(Config, p, day, s.runes)
		if not id then
			return
		end
		p.hints = p.hints + 1
		say(s, id, params)
		print(string.format("[Riddle] step=%d t=%d hints=%d (indice)", Riddle.stepOf(p, day), math.floor(os.clock() - s.hen.startT), p.hints))
		sync(s)
	end

	---------------------------------------------------------------- Plumes
	function M.pickFeather(s, root, prompt)
		local dir = prompt:GetAttribute("Dir")
		if type(dir) ~= "number" or dir % 1 ~= 0 or dir < 1 or dir > 4 or prompt.Parent ~= feathers[dir] then
			return
		end
		local day = day0()
		refresh(s, day)
		local p = s.data.puzzle
		if not Riddle.available(s.data.story.ch) then
			return
		end
		local sp = spots[dir]
		local dist = math.sqrt((root.Position.X - sp.x) ^ 2 + (root.Position.Z - sp.z) ^ 2)
		local now = os.clock()
		if not Riddle.pickupAllowed(Config, dist, now, s.hen.lastPick) then
			return
		end
		local step = stepNow(s, day)
		if step == 0 then
			say(s, "again") -- il faut d'abord parler à la Mère Poule
			return
		end
		local ok, n = Riddle.collect(p, day, dir)
		if not ok then
			return
		end
		s.hen.lastPick = now
		local line, clue = Riddle.featherLine(Config, day, dir)
		RHen:FireClient(s.player, "feather", dir, clue)
		notify(s.player, line, "claim")
		if n == 4 then
			local moved = Riddle.toRunes(p, day)
			if moved then
				enter(s, 2)
				say(s, "allFeathers")
			end
		end
		sync(s)
	end

	---------------------------------------------------------------- Runes
	local function runeDistance(root, idx)
		local st = Config.Map2.runeStones[idx]
		return math.sqrt((root.Position.X - st.x) ^ 2 + (root.Position.Z - st.z) ^ 2)
	end

	function M.rotateRune(s, root, prompt)
		local idx = prompt:GetAttribute("Idx")
		if type(idx) ~= "number" or idx % 1 ~= 0 or idx < 1 or idx > #Config.RUNES then
			return
		end
		if runeDistance(root, idx) > H.singDistance then
			return
		end
		local day = day0()
		refresh(s, day)
		local now = os.clock()
		if now - s.lastRune < 0.12 then
			return
		end
		s.lastRune = now
		if not Riddle.runeUnlocked(s.data.puzzle, day, idx) then
			if Riddle.available(s.data.story.ch) and stepNow(s, day) ~= 4 and now - (s.hen.lastWait or -99) > 1.5 then
				s.hen.lastWait = now
				notify(s.player, Riddle.format(Config.HEN_LINES.runeWaits, { dir = Riddle.DIR_OF[idx] }))
			end
			return
		end
		s.runes[idx] = s.runes[idx] % #Config.RUNES + 1
		sync(s)
	end

	-- Écoute de la berceuse : les 4 pierres s'allument dans l'ordre (le client joue les notes et les lueurs). Le serveur refuse les touches pendant l'écoute.
	function M.play(s)
		local day = day0()
		local seq = Riddle.lullaby(Config, day)
		s.hen.pos = 1
		s.hen.listenUntil = os.clock() + Riddle.lullabyDuration(Config) + 0.2
		RHen:FireClient(s.player, "lullaby", seq, H.lullabyNote, H.lullabyGap)
	end

	function M.replay(s)
		if not throttle(s) then
			return
		end
		local root = ctx.getRoot(s.player)
		if not root then
			return
		end
		local e = Config.Map2.bigEgg
		if henDist(root) > 40 and math.sqrt((root.Position.X - e.x) ^ 2 + (root.Position.Z - e.z) ^ 2) > 40 then
			return
		end
		local day = day0()
		refresh(s, day)
		if stepNow(s, day) == 3 and os.clock() >= s.hen.listenUntil then
			M.play(s)
		end
	end

	-- Validation des runes sur le Grand Œuf : on ne dit QUE le nombre de runes justes. Pause RUNE_LOCK_SECONDS après une erreur (existante).
	function M.confirmRunes(s, root)
		local e = Config.Map2.bigEgg
		if math.sqrt((root.Position.X - e.x) ^ 2 + (root.Position.Z - e.z) ^ 2) > 20 then
			return
		end
		local day = day0()
		refresh(s, day)
		local p = s.data.puzzle
		local step = stepNow(s, day)
		if not Riddle.available(s.data.story.ch) then
			say(s, "locked")
			return
		elseif step == 4 then
			notify(s.player, "🔮 Tu as déjà chanté aujourd'hui. Reviens demain !")
			return
		elseif step == 0 then
			say(s, "again")
			return
		elseif step == 1 then
			say(s, "needFeathers", { dirs = Riddle.missingDirs(p.feathers) })
			return
		elseif step == 3 then
			M.play(s)
			return
		end
		local now = os.clock()
		if now < s.runeLock then
			notify(s.player, Config.HEN_LINES.runesLocked)
			return
		end
		local k = Riddle.runesCorrect(s.runes, riddle(day).answer)
		if k < 4 then
			s.runeLock = now + Config.RUNE_LOCK_SECONDS
			s.hen.fails = s.hen.fails + 1
			say(s, "runesWrong", { k = k })
			notify(s.player, Riddle.format(Config.HEN_LINES.runesWrong, { k = k }), "caught")
			return
		end
		if Riddle.toLullaby(p, day, k) then
			enter(s, 3)
			say(s, "runesRight")
			M.play(s)
			sync(s)
		end
	end

	---------------------------------------------------------------- Berceuse
	local function grant(s, tier)
		local i = ctx.freeSlot(s)
		if i then
			s.data.slots[i] = { k = "e", t = tier, ends = os.time() + ctx.hatchTime(s, tier), shield = os.time() + ctx.shieldTime(s) }
			ctx.refreshPad(s, i)
			return true
		end
		s.data.coins = s.data.coins + Config.EGG_PRICE[tier] -- base pleine : l'œuf est converti en pièces (prix plein)
		return false
	end

	local function reward(s, day)
		local p = s.data.puzzle
		local ok, r = Riddle.complete(Config, p, day, true)
		if not ok then
			return
		end
		local d = s.data
		local coins = Config.puzzleCoins(ctx.income(s))
		local placed = grant(s, r.eggTier)
		d.coins = d.coins + coins
		local msg = "🔮 Le Grand Œuf s'éveille ! +" .. Config.fmt(coins) .. " 🪙 et " .. (placed and ("un œuf " .. Config.TIERS[r.eggTier].name .. " dans ta base") or "la valeur d'un œuf (base pleine)")
		msg = msg .. " · 🥚 Fragment du Grand Œuf " .. (r.fragments % H.fragmentsForEgg == 0 and H.fragmentsForEgg or r.fragments % H.fragmentsForEgg) .. "/" .. H.fragmentsForEgg
		notify(s.player, msg, "rare")
		if r.legendary > 0 then
			for _ = 1, r.legendary do
				local placedL = grant(s, 4)
				notify(s.player, "🌟 " .. H.fragmentsForEgg .. " fragments réunis : un œuf Légendaire" .. (placedL and " t'attend dans ta base !" or " (base pleine : converti en pièces)."), "legendary")
			end
		end
		if r.titleNew then
			notify(s.player, "🏷 Nouveau titre : " .. Config.TITLE_HEN.name, "claim")
		end
		s.runes = { 1, 1, 1, 1 }
		s.hen.pos = 1
		Builder.burst(ctx.world.monumentCenter, Color3.fromRGB(255, 214, 120), 140, true)
		say(s, "success")
		log(s, 4)
		ctx.story(s, "puzzle", 1)
		-- effet collectif : 3 énigmes résolues sur ce serveur aujourd'hui -> « Pluie de chance » gratuite pour tous (une fois par jour et par serveur)
		if Riddle.collectiveAdd(Config, collective, day) then
			for _, e in ipairs(Config.EVENTS) do
				if e.key == "luck" then
					ctx.setEvent(e, H.collectiveSeconds)
				end
			end
			for _, o in pairs(ctx.sessions) do
				notify(o.player, "🍀 " .. H.collectiveSolves .. " berceuses chantées aujourd'hui : Pluie de chance offerte à tout le serveur pendant " .. math.floor(H.collectiveSeconds / 60) .. " min !", "event")
			end
		end
		sync(s)
	end

	function M.sing(s, root, prompt)
		local idx = prompt:GetAttribute("Idx")
		if type(idx) ~= "number" or idx % 1 ~= 0 or idx < 1 or idx > 4 or runeDistance(root, idx) > H.singDistance then
			return
		end
		local day = day0()
		refresh(s, day)
		local now = os.clock()
		if now < s.hen.listenUntil then
			return -- écoute en cours : les touches sont ignorées
		end
		if not Riddle.tapAllowed(Config, now, s.hen.lastTap) then
			return -- trop rapide (< 0,25 s) : refusée, sans compter comme une erreur
		end
		s.hen.lastTap = now
		local seq = Riddle.lullaby(Config, day)
		local res, pos = Riddle.tap(seq, s.hen.pos, idx)
		s.hen.pos = pos
		if res == "wrong" then
			s.hen.lullFails = s.hen.lullFails + 1
			RHen:FireClient(s.player, "tap", idx, false)
			say(s, "lullabyWrong")
			M.play(s) -- la suite est rejouée, sans pause
			sync(s)
		else
			RHen:FireClient(s.player, "tap", idx, true)
			if res == "done" then
				reward(s, day)
			else
				sync(s)
			end
		end
	end

	-- Prompt d'une pierre runique : selon l'étape, tourner la rune (1 et 2) ou chanter (3).
	function M.stoneTap(s, root, prompt)
		local day = day0()
		refresh(s, day)
		if stepNow(s, day) == 3 then
			M.sing(s, root, prompt)
		else
			M.rotateRune(s, root, prompt)
		end
	end

	---------------------------------------------------------------- État publié au client
	function M.snapshot(s)
		local day = day0()
		refresh(s, day)
		local p = s.data.puzzle
		local avail = Riddle.available(s.data.story.ch)
		local step = stepNow(s, day)
		local out = {
			avail = avail, step = step, feathers = p.feathers, count = Riddle.featherCount(p.feathers), hints = p.hints, hintMax = H.hintsPerDay,
			fragments = p.fragments, nextAt = (day + 1) * 86400, alert = avail and step < 4, lullabyPos = step == 3 and (s.hen.pos - 1) or 0,
			spots = {}, clues = {}, solved = p.solved,
		}
		if step == 1 then
			for dir = 1, 4 do
				if not Riddle.hasFeather(p.feathers, dir) then
					out.spots[#out.spots + 1] = { dir = dir, x = spots[dir].x, z = spots[dir].z }
				end
			end
		end
		if step >= 1 and step <= 3 then
			for dir = 1, 4 do
				if Riddle.hasFeather(p.feathers, dir) then
					out.clues[dir] = riddle(day).clues[dir]
				end
			end
		end
		return out
	end

	-- Toutes les 5 s : changement de jour (plumes déplacées, progression de chacun remise à zéro et publiée).
	function M.tick()
		local day = day0()
		if day ~= spotsDay then
			placeFeathers(day)
		end
		for _, s in pairs(ctx.sessions) do
			if refresh(s, day) then
				sync(s)
			end
		end
	end

	M.feathers = feathers
	M.collective = collective
	task.spawn(function()
		while true do
			task.wait(5)
			local ok, err = pcall(M.tick)
			if not ok then
				warn("[HenQuest] " .. tostring(err))
			end
		end
	end)
	return M
end

return HenQuest
