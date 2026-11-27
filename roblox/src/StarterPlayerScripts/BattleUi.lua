-- ModuleScript : StarterPlayerScripts/BattleUi
-- Arène des pets (PvE) : écran d'équipe (3 pets de la collection, type affiché), choix de l'étage de la tour, écran de combat (barres de PV, icônes de type,
-- flèche d'avantage, journal court, minuteur de tour), écran de résultat avec récompenses. 100 % code. Le client N'ENVOIE QU'UNE INTENTION par tour
-- (« attack », « skill », « swapN ») : tout le résultat vient du serveur (événements rejoués ici). Aucune erreur ne sort d'ici.
local BattleUi = {}

local TweenService = game:GetService("TweenService")
local FONT = Enum.Font.GothamBold

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function label(parent, props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextSize = props.TextSize or 14
	return make("TextLabel", props, parent)
end

local function button(parent, props)
	props.Font = FONT
	props.TextSize = props.TextSize or 14
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(10, 30, 15)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(91, 227, 125)
	props.AutoButtonColor = true
	local b = make("TextButton", props, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
	make("UIStroke", { Color = Color3.fromRGB(20, 80, 40), Thickness = 2 }, b)
	return b
end

-- Avantage de type de MON pet actif sur l'adversaire : « ⬆ » (x1,5), « ⬇ » (x0,67) ou « ➡ ».
function BattleUi.advantage(Battle, myType, foeType)
	local m = Battle.typeMul(myType, foeType)
	return m > 1 and "⬆ avantage" or (m < 1 and "⬇ désavantage" or "➡ neutre")
end

-- LOT 12 B : état du bouton Spécial et pastilles de charge. `u.charge` (0..max) vient du moteur du lot 12 (Battle.CHARGE_MAX, 5 par défaut) ; si le moteur est
-- encore celui du lot 8 (pas de `charge`), on retombe sur la recharge `cd` : l'écran reste correct dans les deux cas. Pur (testé).
function BattleUi.specialState(Config, Battle, u)
	local sk = Battle.SKILLS and Battle.SKILLS[u.skill] or { name = "Spécial" }
	local name = (Config.TYPE_SPECIAL_NAME and Config.TYPE_SPECIAL_NAME[u.type]) or (Battle.SPECIAL_NAME and Battle.SPECIAL_NAME[u.type]) or sk.name or "Spécial" -- FUSION 12A : nom du spécial par type (Battle.SPECIAL_NAME)
	if type(u.charge) == "number" then
		local max = Battle.CHARGE_MAX or 5
		local c = math.max(0, math.min(max, math.floor(u.charge)))
		local ready = c >= max and not (type(u.stun) == "number" and u.stun > 0)
		return { charge = c, max = max, ready = ready, text = (c >= max) and ("✨ " .. name) or ("Spécial " .. c .. "/" .. max) }
	end
	local cd = type(u.cd) == "number" and u.cd or 0
	return { charge = nil, max = 0, ready = cd == 0, text = cd > 0 and (name .. " (" .. cd .. ")") or ("✨ " .. name) }
end

-- Texte d'efficacité (B.6), repli local si le module TypeFx de données n'est pas fourni : texte, couleur RGB ; nil si neutre.
BattleUi.EFFICACY = {
	{ min = 1.5, text = "Super efficace !", rgb = { 70, 220, 90 } },
	{ min = 1.2, text = "Efficace", rgb = { 150, 230, 120 } },
	{ max = 0.7, text = "Pas très efficace…", rgb = { 230, 70, 70 } },
	{ max = 0.95, text = "Peu efficace", rgb = { 255, 160, 50 } },
}
function BattleUi.efficacy(mult)
	if type(mult) ~= "number" or mult ~= mult or mult <= 0 then
		return nil
	end
	for _, e in ipairs(BattleUi.EFFICACY) do
		if (e.min ~= nil and mult >= e.min - 1e-9) or (e.max ~= nil and mult <= e.max + 1e-9) then
			return e.text, e.rgb
		end
	end
	return nil
end

-- REFONTE DU COMBAT (vue face à face) : si `fx.BattleScene` et `fx.BattleLayout` sont fournis (et `Config.BATTLE_FX.scene ~= false`), le combat s'affiche dans une scène
-- plein écran (BattleScene : créatures sur socles lumineux, carte adverse en haut à droite, carte du joueur en bas à gauche, journal et boutons en bas) ; sinon, ou si la
-- construction échoue, l'ancien panneau compact (lot 8) est utilisé tel quel. Remotes, payloads et protocole inchangés : ce module n'envoie que les mêmes intentions.
-- Lot 10 : `fx` (optionnel) = { Odds, IntroPlan, BattleIntro, TypeFx (client), TypeFxData (données), sound = fn(clé), reduced = mobile, iconUrl = fn(clé) -> url|nil }.
-- Intro avant le premier tour (BattleIntro, passable), effet par type à chaque attaque (spécial pour une compétence ou tous les `specialEvery` coups), texte
-- d'efficacité flottant, sons battle_start / atk_<type> / special_hit / special_ready / battle_win / battle_lose. Sans `fx` : écran du lot 8 inchangé.
function BattleUi.start(Config, Battle, player, gui, getState, fire, RBattle, fx)
	local TW = Config.TOWER
	local ok, ui = pcall(function()
		local open = button(gui, { Name = "ArenaButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0.3, -42), Size = UDim2.fromOffset(34, 34), Text = "⚔️", BackgroundColor3 = Color3.fromRGB(255, 159, 28) })
		local panel = make("Frame", { Name = "ArenaPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 0, 330), BackgroundColor3 = Color3.fromRGB(28, 26, 44), Visible = false, ZIndex = 30 }, gui)
		make("UISizeConstraint", { MaxSize = Vector2.new(360, 330) }, panel) -- 360 px au plus, jamais plus large que l'écran (téléphone de 360 px : 8 px de marge de chaque côté)
		make("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
		make("UIStroke", { Color = Color3.fromRGB(255, 210, 63), Thickness = 3 }, panel)
		local title = label(panel, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -60, 0, 26), TextSize = 18, Text = "⚔️ Arène des pets", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31 })
		local close = button(panel, { Position = UDim2.new(1, -40, 0, 6), Size = UDim2.fromOffset(30, 26), Text = "✕", BackgroundColor3 = Color3.fromRGB(255, 99, 99), ZIndex = 32 })
		local info = label(panel, { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 36), TextSize = 14, TextWrapped = true, Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31 })
		local body = make("Frame", { Position = UDim2.fromOffset(10, 74), Size = UDim2.new(1, -20, 1, -84), BackgroundTransparency = 1, ZIndex = 31 }, panel)
		return { open = open, panel = panel, title = title, close = close, info = info, body = body }
	end)
	if not ok then
		return nil
	end
	local floor, team, mode = 1, {}, "team"
	local FX = { on = type(fx) == "table" and Config.BATTLE_FX ~= nil and Config.BATTLE_FX.Enabled == true, hits = { 0, 0 } }
	function FX.sound(key)
		if type(fx) == "table" and type(fx.sound) == "function" and key then
			pcall(fx.sound, key)
		end
	end
	function FX.icon(parent, key, x, y, size)
		local url = type(fx) == "table" and type(fx.iconUrl) == "function" and fx.iconUrl(key) or nil
		if url then
			return make("ImageLabel", { BackgroundTransparency = 1, Image = url, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), ZIndex = 34 }, parent)
		end
		return nil
	end
	local view, seconds, deadline, foeName, lastFloor = nil, 0, 0, "", 1
	local pick, pickDeadline, pickSent, lastReady = nil, 0, false, false -- lot 12 B : écran de choix des 3 cartes (D.5)
	local logLines = {}
	local widgets = {}
	local DU = { on = false, cam = nil, ask = nil, watch = nil, watchAt = 0, chosen = false } -- lot 13 : duel local (caméra, demande reçue, bandeau des spectateurs)
	local LV = { queued = false, note = nil } -- lot 14 : classé en direct (file d'attente ; fermée = le serveur lance directement le classé enregistré)
	-- Réglages locaux du combat (durée de la session : vitesse 1x / 2x / 3x, nombre de combats déjà vus pour proposer « Passer l'animation » dès le 2e). `fx.prefs`
	-- (table facultative fournie par le client) les conserve entre deux écrans ; rien n'est envoyé au serveur.
	local PREFS = type(fx) == "table" and type(fx.prefs) == "table" and fx.prefs or {}
	PREFS.speed, PREFS.seen = PREFS.speed or 1, PREFS.seen or 0
	local SC = { scene = nil, delay = 0, events = nil } -- refonte : scène face à face (nil = ancien panneau compact)
	local function clear()
		for _, w in ipairs(widgets) do
			pcall(function()
				w:Destroy()
			end)
		end
		widgets = {}
	end
	local function add(w)
		widgets[#widgets + 1] = w
		return w
	end
	local render

	local function unitText(u)
		local def = Config.PETS[u.p]
		return (Battle.TYPE_EMOJI[u.type] or "") .. " " .. def.emoji .. " " .. def.name
	end

	-- Lot 10 : intro de combat (plan pur IntroPlan, exécuté par BattleIntro) ; sans module : son de début seulement.
	function FX.intro(p)
		if not (FX.on and Config.BATTLE_FX.intro and fx.IntroPlan and fx.BattleIntro and type(p.view) == "table") then
			FX.sound("battle_start")
			return
		end
		local st = getState()
		local pv = (st and st.battle and st.battle.pvp) or {}
		local function pets(sd)
			local out = {}
			for _, u in ipairs(sd.units or {}) do
				local def = Config.PETS[u.p]
				out[#out + 1] = { type = u.type, odds = fx.Odds and fx.Odds.forPet(Config, u.p, u.s, u.m) or nil, tier = def and def.tier or nil }
			end
			return out
		end
		local me, foe = p.view.sides[1], p.view.sides[2]
		local mu, fu = me.units[me.active], foe.units[foe.active]
		local meInfo = { name = player.DisplayName, userId = player.UserId, wins = pv.wins, losses = pv.losses, trophies = pv.trophies, league = st and st.battle and st.battle.league or nil, pets = pets(me) }
		local foeInfo = { name = p.foe, pets = pets(foe) }
		if p.duel and type(p.intro) == "table" and type(p.intro.me) == "table" and type(p.intro.foe) == "table" then -- lot 13 (B.4) : ratios de duel, ligues et trophées envoyés par le serveur
			meInfo = { name = p.intro.me.name, userId = p.intro.me.userId, wins = p.intro.me.wins, losses = p.intro.me.losses, trophies = p.intro.me.trophies, league = p.intro.me.league, pets = pets(me) }
			foeInfo = { name = p.intro.foe.name, userId = p.intro.foe.userId, wins = p.intro.foe.wins, losses = p.intro.foe.losses, trophies = p.intro.foe.trophies, league = p.intro.foe.league, pets = pets(foe) }
		end
		local plan = fx.IntroPlan.plan({
			mode = p.duel and "duel" or (p.pvp and "pvp" or (p.npc and "npc" or "tower")), countdown = false, advantage = (mu and fu) and Battle.typeMul(mu.type, fu.type) or 1,
			me = meInfo, foe = foeInfo,
		}, { fmtOdds = fx.Odds and fx.Odds.label or nil })
		fx.BattleIntro.play(gui, plan, {
			thumbnail = function(uid)
				return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(uid) .. "&w=150&h=150"
			end,
			sound = function()
				FX.sound("battle_start")
			end,
		})
	end

	-- Lot 10 : effets d'attaque par type pour les coups d'un tour (décalés de 0,6 s), texte d'efficacité sur la cible.
	function FX.hits(events)
		if not (FX.on and Config.BATTLE_FX.typeFx and fx.TypeFx and fx.TypeFxData) then
			return
		end
		local k = 0
		for _, ev in ipairs(events or {}) do
			if type(ev) == "table" and ev.t == "hit" and (ev.side == 1 or ev.side == 2) then
				FX.hits[ev.side] = FX.hits[ev.side] + 1
				local special = ev.special == true -- FUSION 12A : le spécial est porté par l'événement du moteur (charge 5/5), plus un coup sur 5
				local typ = Battle.SPECIES_TYPE[ev.p]
				local data = fx.TypeFxData.get(typ)
				local readySoon = ev.side == 1 and ev.charge == 4 -- FUSION 12A : prêt au prochain coup
				local mul = ev.mul
				task.delay(0.6 * k, function()
					pcall(function()
						local mine, theirs, shakeFrame
						if SC.scene then -- scène face à face : positions projetées au-dessus des deux créatures
							local mx, my = SC.scene.anchor(1)
							local tx, ty = SC.scene.anchor(2)
							mine, theirs, shakeFrame = Vector2.new(mx, my), Vector2.new(tx, ty), SC.scene.shake
						else
							local ap, sz = ui.panel.AbsolutePosition, ui.panel.AbsoluteSize
							local bodyY = ap.Y + 74
							mine = Vector2.new(ap.X + sz.X * 0.25, bodyY + 50)
							theirs = Vector2.new(ap.X + sz.X * 0.75, bodyY + 10)
							shakeFrame = ui.panel
						end
						local from, to = mine, theirs
						if ev.side == 2 then
							from, to = theirs, mine
						end
						fx.TypeFx.play(gui, data, special, {
							from = from, to = to, reduced = fx.reduced == true, shakeFrame = shakeFrame,
							sound = function(key)
								FX.sound(key == "special" and "special_hit" or Config.ATK_SOUND[typ])
							end,
						})
						local text, rgb = fx.TypeFxData.efficacy(mul)
						if text and not SC.scene then -- en scène face à face, le message de type est affiché par la scène (avant le nombre)
							fx.TypeFx.floatText(gui, text, rgb, to.X, to.Y - 28)
						end
						if readySoon then
							FX.sound("special_ready")
						end
					end)
				end)
				k = k + 1
			end
		end
	end

	local function renderTeam()
		local st = getState()
		local b = st and st.battle or { team = {}, best = 0, fightsLeft = TW.dailyFights, repeatsLeft = TW.dailyRepeats }
		if #team == 0 then
			for _, v in ipairs(b.team or {}) do
				team[#team + 1] = v
			end
		end
		floor = math.min(math.max(1, floor), math.min(TW.floors, b.best + 1))
		ui.title.Text = "⚔️ Tour des Dresseurs"
		ui.info.Text = "Meilleur étage : " .. b.best .. "/" .. TW.floors .. " · combats restants aujourd'hui : " .. b.fightsLeft .. "\nChoisis jusqu'à " .. TW.teamSize .. " pets (touche pour ajouter / retirer)."
		local y = 0
		local n = 0
		for i = 1, Config.SLOTS_MAX do
			local sl = st and st.slots and st.slots[i]
			if sl and sl.k == "p" then
				n = n + 1
				local col = (n - 1) % 2
				local row = (n - 1) // 2
				local selected = false
				for _, v in ipairs(team) do
					if v == i then
						selected = true
					end
				end
				local def = Config.PETS[sl.p]
				local btn = add(button(ui.body, { Position = UDim2.new(col * 0.5, col * 4, 0, row * 28), Size = UDim2.new(0.5, -4, 0, 26), Text = (selected and "✅ " or "") .. Battle.TYPE_EMOJI[Battle.SPECIES_TYPE[sl.p]] .. " " .. def.emoji .. " " .. def.name, TextSize = 14, BackgroundColor3 = selected and Color3.fromRGB(255, 210, 63) or Color3.fromRGB(70, 74, 110), TextColor3 = selected and Color3.fromRGB(40, 30, 0) or Color3.new(1, 1, 1), ZIndex = 32 }))
				btn.Activated:Connect(function()
					local at
					for k, v in ipairs(team) do
						if v == i then
							at = k
						end
					end
					if at then
						table.remove(team, at)
					elseif #team < TW.teamSize then
						team[#team + 1] = i
					end
					fire("setTeam", team)
					render()
				end)
				y = math.max(y, row * 28 + 28)
			end
		end
		if n == 0 then
			add(label(ui.body, { Size = UDim2.new(1, 0, 0, 40), Text = "Fais d'abord éclore des pets !", ZIndex = 32 }))
		end
		local prev = add(button(ui.body, { Position = UDim2.new(0, 0, 1, -34), Size = UDim2.fromOffset(34, 30), Text = "‹", ZIndex = 32 }))
		local nxt = add(button(ui.body, { Position = UDim2.new(0, 130, 1, -34), Size = UDim2.fromOffset(34, 30), Text = "›", ZIndex = 32 }))
		add(label(ui.body, { Position = UDim2.new(0, 36, 1, -34), Size = UDim2.fromOffset(94, 30), Text = "Étage " .. floor .. (TW.bosses[floor] and " 👑" or ""), ZIndex = 32 }))
		prev.Activated:Connect(function()
			floor = math.max(1, floor - 1)
			render()
		end)
		nxt.Activated:Connect(function()
			floor = math.min(math.min(TW.floors, b.best + 1), floor + 1)
			render()
		end)
		local pv = b.pvp or { trophies = 0, wins = 0, losses = 0, fightsLeft = Config.PVP.dailyFights, hasDefense = false }
		add(label(ui.body, { Position = UDim2.new(0, 0, 1, -68), Size = UDim2.new(1, 0, 0, 14), TextSize = 12, Text = "🏆 " .. pv.trophies .. " trophées · " .. pv.wins .. " V / " .. pv.losses .. " D · classés restants : " .. pv.fightsLeft, ZIndex = 32 }))
		local def = add(button(ui.body, { Position = UDim2.new(0, 0, 1, -106), Size = UDim2.new(0.5, -3, 0, 28), Text = pv.hasDefense and "🛡 Défense ✔" or "🛡 Défense", BackgroundColor3 = Color3.fromRGB(74, 163, 255), ZIndex = 32 }))
		def.Activated:Connect(function()
			fire("setTeam", team)
			fire("pvpDefense")
		end)
		local rk = add(button(ui.body, { Position = UDim2.new(0.5, 3, 1, -106), Size = UDim2.new(0.5, -3, 0, 28), Text = LV.queued and "✖ Annuler la recherche" or "🏆 Combat classé", BackgroundColor3 = LV.queued and Color3.fromRGB(255, 99, 99) or Color3.fromRGB(184, 120, 255), ZIndex = 32 }))
		rk.Activated:Connect(function()
			if LV.queued then -- lot 14 : annulation pendant l'attente (refusée par le serveur une fois la téléportation lancée)
				fire("liveCancel")
				return
			end
			fire("setTeam", team)
			fire("liveQueue") -- lot 14 : file en direct si elle est ouverte, sinon le serveur lance le classé enregistré (pvpStart)
		end)
		if LV.note then
			ui.info.Text = LV.note
		end
		local go = add(button(ui.body, { Position = UDim2.new(1, -150, 1, -34), Size = UDim2.fromOffset(150, 30), Text = "⚔️ Combattre", ZIndex = 32 }))
		go.Activated:Connect(function()
			lastFloor = floor
			fire("setTeam", team)
			fire("towerStart", floor)
		end)
	end

	local function renderBattle()
		if not view then
			return
		end
		ui.title.Text = "⚔️ " .. foeName .. ((lastFloor or 0) > 0 and (" · étage " .. lastFloor) or "")
		local me, foe = view.sides[1], view.sides[2]
		local mu, fu = me.units[me.active], foe.units[foe.active]
		ui.info.Text = BattleUi.advantage(Battle, mu.type, fu.type) .. " · tour " .. view.turn .. "/" .. Battle.MAX_TURNS .. (DU.on and (DU.chosen and " · ✅ choix envoyé, attente de l'adversaire" or " · duel : choisis ton action") or "")
		local function bar(y, u, left)
			add(label(ui.body, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 20), Text = unitText(u) .. "   " .. u.hp .. "/" .. u.maxHp .. (u.guard and " 🛡" or "") .. (u.stun > 0 and " 💫" or "") .. (u.focus > 0 and " ⚡" or ""), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32 }))
			local bg = add(make("Frame", { Position = UDim2.fromOffset(0, y + 22), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Color3.fromRGB(50, 30, 40), ZIndex = 32 }, ui.body))
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, bg)
			local frac = u.maxHp > 0 and math.max(0, u.hp / u.maxHp) or 0
			make("Frame", { Size = UDim2.fromScale(frac, 1), BackgroundColor3 = frac > 0.5 and Color3.fromRGB(91, 227, 125) or (frac > 0.25 and Color3.fromRGB(255, 210, 63) or Color3.fromRGB(255, 99, 99)), ZIndex = 33 }, bg)
		end
		-- lot 12 B : 5 pastilles de charge sous la barre de vie (la dernière pulse quand le spécial est prêt)
		local function pips(y, u)
			local st = BattleUi.specialState(Config, Battle, u)
			if not st.charge then
				return st
			end
			for i = 1, st.max do
				local on = i <= st.charge
				local pip = add(make("Frame", { Position = UDim2.fromOffset((i - 1) * 14, y + 35), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = on and Color3.fromRGB(255, 210, 63) or Color3.fromRGB(60, 56, 80), ZIndex = 33 }, ui.body))
				make("UICorner", { CornerRadius = UDim.new(1, 0) }, pip)
				make("UIStroke", { Color = Color3.fromRGB(20, 20, 30), Thickness = 1 }, pip)
				if on and st.ready and i == st.max then
					pcall(function()
						TweenService:Create(pip, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(14, 14) }):Play()
					end)
				end
			end
			return st
		end
		bar(0, fu, false)
		pips(0, fu)
		bar(48, mu, true)
		local myState = pips(48, mu)
		if myState.ready and not lastReady then
			FX.sound("special_ready")
		end
		lastReady = myState.ready
		for _, e in ipairs({ { fu, 0 }, { mu, 48 } }) do -- lot 10 : icône de type (Decal) à droite de la barre, si elle est chargée
			local w = FX.icon(ui.body, Config.TYPE_ICON[e[1].type], 0, e[2], 20)
			if w then
				w.AnchorPoint = Vector2.new(1, 0)
				w.Position = UDim2.new(1, 0, 0, e[2])
				add(w)
			end
		end
		local log = add(label(ui.body, { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 52), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = table.concat(logLines, "\n"), ZIndex = 32 }))
		local b1 = add(button(ui.body, { Position = UDim2.new(0, 0, 1, -66), Size = UDim2.new(0.5, -3, 0, 28), Text = "⚔ Attaque", ZIndex = 32 }))
		b1.Activated:Connect(function()
			fire("battleAct", "attack")
			DU.picked()
		end)
		local b2 = add(button(ui.body, { Position = UDim2.new(0.5, 3, 1, -66), Size = UDim2.new(0.5, -3, 0, 28), Text = myState.text, AutoButtonColor = myState.ready, BackgroundColor3 = myState.ready and Color3.fromRGB(74, 163, 255) or Color3.fromRGB(110, 110, 120), TextColor3 = myState.ready and Color3.fromRGB(10, 30, 15) or Color3.fromRGB(200, 200, 210), ZIndex = 32 }))
		b2.Activated:Connect(function()
			if myState.ready then -- le serveur revalide (« spécial pas prêt (x/5) ») : ce test n'est que du confort
				fire("battleAct", "skill")
				DU.picked()
			end
		end)
		local k = 0
		for i, u in ipairs(me.units) do
			if i ~= me.active then
				k = k + 1
				local alive = u.hp > 0
				local sb = add(button(ui.body, { Position = UDim2.new((k - 1) * 0.34, 0, 1, -34), Size = UDim2.new(0.33, -2, 0, 28), Text = alive and ("🔁 " .. Config.PETS[u.p].emoji .. " " .. u.hp) or ("💀 " .. Config.PETS[u.p].emoji), BackgroundColor3 = alive and Color3.fromRGB(255, 159, 28) or Color3.fromRGB(70, 70, 80), ZIndex = 32 }))
				sb.Activated:Connect(function()
					if alive then
						fire("battleAct", "swap" .. i)
						DU.picked()
					end
				end)
			end
		end
		local quit = add(button(ui.body, { Position = UDim2.new(1, -60, 0, 96), Size = UDim2.fromOffset(60, 22), Text = "Abandon", TextSize = 12, BackgroundColor3 = Color3.fromRGB(255, 99, 99), ZIndex = 33 }))
		quit.Activated:Connect(function()
			fire("battleQuit")
		end)
		return log
	end

	-- Refonte : scène de combat face à face. Le serveur n'envoie rien de plus : tout vient de la vue (Battle.view) et du message « start ».
	local function sceneOn()
		return type(fx) == "table" and fx.BattleScene ~= nil and fx.BattleLayout ~= nil and not (Config.BATTLE_FX and Config.BATTLE_FX.scene == false)
	end
	function SC.close()
		if SC.scene then
			pcall(SC.scene.destroy)
			SC.scene = nil
		end
		pcall(function()
			ui.open.Visible = true
		end)
	end
	function SC.statusText()
		if not view then
			return ""
		end
		local me, foe = view.sides[1], view.sides[2]
		local mu, fu = me.units[me.active], foe.units[foe.active]
		local left = math.max(0, math.ceil(deadline - os.clock()))
		return (mu and fu and (BattleUi.advantage(Battle, mu.type, fu.type) .. " · ") or "") .. "tour " .. tostring(view.turn) .. "/" .. Battle.MAX_TURNS .. (view.over and "" or (" · ⏱ " .. left .. " s")) .. (DU.on and (DU.chosen and " · ✅ choix envoyé, attente de l'adversaire" or " · duel : choisis ton action") or "")
	end
	function SC.refresh()
		if not (SC.scene and view) then
			return
		end
		local d = SC.delay
		SC.delay = 0
		SC.scene.update(view, { delay = d, events = SC.events })
		SC.events = nil
		SC.scene.setContext(tostring(foeName or "") .. ((lastFloor or 0) > 0 and (" · étage " .. lastFloor) or ""))
		SC.scene.setLog(logLines)
		SC.scene.setStatus(SC.statusText())
	end
	function SC.open(p)
		SC.close()
		if not sceneOn() then
			return false
		end
		local ok, sc = pcall(fx.BattleScene.create, {
			gui = gui, Config = Config, Battle = Battle, Layout = fx.BattleLayout, player = player, payload = p, view = view, foeName = foeName, floor = lastFloor,
			reduced = fx.reduced == true, iconUrl = fx.iconUrl, sound = FX.sound,
			speed = PREFS.speed, canSkip = fx.BattleLayout.skipAvailable(PREFS.seen),
			onSpeed = function(v)
				PREFS.speed = v
			end,
			specialState = function(u)
				return BattleUi.specialState(Config, Battle, u)
			end,
			fire = fire,
			onChosen = function()
				DU.picked()
			end,
		})
		if ok and sc then
			SC.scene = sc
			ui.panel.Visible = false
			pcall(function()
				ui.open.Visible = false
			end)
			return true
		end
		return false
	end

	function render()
		clear()
		if mode == "battle" then
			if SC.scene then
				SC.refresh()
			else
				renderBattle()
			end
		elseif mode == "end" then
			-- l'écran de résultat est construit par `finish`
		else
			renderTeam()
		end
	end

	local function pushLog(events)
		for _, ev in ipairs(events or {}) do
			local t = Battle.describe(Config, ev)
			if t ~= "" and ev.t == "hit" then -- lot 12 B : texte d'efficacité aussi dans le journal (utile sans effets visuels), sans doublon
				local eff = BattleUi.efficacy(ev.mul)
				if eff and not string.find(t, eff, 1, true) then
					t = t .. " (" .. eff .. ")"
				end
			end
			if t ~= "" and ev.t ~= "turn" then
				logLines[#logLines + 1] = t
			end
		end
		while #logLines > 4 do
			table.remove(logLines, 1)
		end
	end

	local function showResult(msg, waitPick)
		mode = "end"
		clear()
		ui.panel.Visible = true
		ui.info.Text = ""
		add(label(ui.body, { Size = UDim2.new(1, 0, 1, -52), TextSize = 16, TextWrapped = true, Text = msg, ZIndex = 32 }))
		if waitPick then
			return -- le serveur envoie ensuite { k = "pick" } ; « Continuer » n'apparaît qu'après le choix
		end
		local ok2 = add(button(ui.body, { Position = UDim2.new(0.5, -70, 1, -46), Size = UDim2.fromOffset(140, 44), Text = "Continuer", ZIndex = 32 }))
		ok2.Activated:Connect(function()
			SC.close() -- refonte : la scène de combat est détruite (aucune instance ne reste)
			mode = "team"
			team = {}
			logLines = {}
			render()
		end)
	end

	-- LOT 12 B (D.5) : écran de choix. `p` = { id, cards = { { kind, icon, title, desc, boss } x3 }, seconds } reçu du serveur (BattleRewards.view). Le client n'envoie
	-- que { id, i } ; le serveur valide l'id et l'index, tire au sort rien, et donne la première carte si le délai est écoulé. Reconnexion : le serveur renvoie la même vue.
	local function showPick(p)
		mode = "pick"
		pick, pickSent = p, false
		pickDeadline = os.clock() + (tonumber(p.seconds) or 15)
		clear()
		ui.panel.Visible = true
		ui.title.Text = "🎁 Choisis ta récompense"
		ui.info.Text = "Une seule carte ! (sinon la première te sera donnée)"
		local n = #p.cards
		for i, c in ipairs(p.cards) do
			local w = 1 / n
			local btn = add(button(ui.body, { Position = UDim2.new((i - 1) * w, 3, 0, 0), Size = UDim2.new(w, -6, 1, -50), Text = "", BackgroundColor3 = c.boss and Color3.fromRGB(255, 210, 63) or Color3.fromRGB(70, 74, 110), ZIndex = 32 }))
			label(btn, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 40), Text = tostring(c.icon or "?"), TextSize = 32, TextColor3 = Color3.new(1, 1, 1), ZIndex = 33 })
			label(btn, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 20), Text = tostring(c.title or ""), TextSize = 15, TextColor3 = c.boss and Color3.fromRGB(40, 30, 0) or Color3.new(1, 1, 1), ZIndex = 33 })
			label(btn, { Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 1, -84), Text = tostring(c.desc or ""), TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = c.boss and Color3.fromRGB(40, 30, 0) or Color3.fromRGB(220, 220, 235), ZIndex = 33 })
			btn.Activated:Connect(function()
				if pickSent or mode ~= "pick" then
					return
				end
				pickSent = true
				btn.Text = "✅"
				fire("battlePick", { id = p.id, i = i })
			end)
		end
		add(label(ui.body, { Name = "PickTimer", Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(1, 0, 0, 36), Text = "", TextSize = 14, ZIndex = 32 }))
	end

	local function showPicked(p)
		mode = "end"
		pick = nil
		local lines = { "🎁 Récompense reçue !" }
		if type(p.text) == "string" then
			lines[#lines + 1] = p.text
		end
		if p.auto then
			lines[#lines + 1] = "(choix automatique : première carte)"
		end
		showResult(table.concat(lines, "\n"))
	end

	-- LOT 13 : duel local. Demande reçue (Accepter / Refuser, 20 s), caméra de duel sur le sable, bandeau des spectateurs. Le serveur revalide tout.
	function DU.picked()
		if DU.on and not DU.chosen then
			DU.chosen = true
			if mode == "battle" then
				render()
			end
		end
	end
	function DU.camera(p)
		local cam = workspace.CurrentCamera
		if not cam or type(p.arena) ~= "table" or type(p.arena.x) ~= "number" or type(p.arena.z) ~= "number" then
			return
		end
		DU.cam = { type = cam.CameraType, subject = cam.CameraSubject }
		local dir = p.arena.side == 2 and -1 or 1
		local center = Vector3.new(p.arena.x, 4, p.arena.z)
		local eye = center + Vector3.new(-dir * 6, 16, 30)
		cam.CameraType = Enum.CameraType.Scriptable
		local goal = { CFrame = CFrame.lookAt(eye, center) }
		pcall(function()
			TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), goal):Play()
		end)
	end
	function DU.restore()
		local cam = workspace.CurrentCamera
		if DU.cam and cam then
			cam.CameraType = Enum.CameraType.Custom
			local ch = player.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			cam.CameraSubject = hum or DU.cam.subject
		end
		DU.cam, DU.on, DU.chosen = nil, false, false
	end
	function DU.closeAsk()
		if DU.ask then
			pcall(function()
				DU.ask.frame:Destroy()
			end)
			DU.ask = nil
		end
	end
	function DU.showAsk(p)
		if type(p.fromId) ~= "number" or type(p.from) ~= "string" then
			return
		end
		DU.closeAsk()
		local fr = make("Frame", { Name = "DuelAsk", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(300, 104), BackgroundColor3 = Color3.fromRGB(28, 26, 44), ZIndex = 40 }, gui)
		make("UICorner", { CornerRadius = UDim.new(0, 14) }, fr)
		make("UIStroke", { Color = Color3.fromRGB(255, 159, 28), Thickness = 3 }, fr)
		label(fr, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 40), TextSize = 16, TextWrapped = true, Text = "⚔️ " .. p.from:sub(1, 20) .. " te défie en duel !\nAmical : aucun trophée en jeu.", ZIndex = 41 })
		local timer = label(fr, { Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = Color3.fromRGB(220, 220, 235), Text = "", ZIndex = 41 })
		local yes = button(fr, { Position = UDim2.new(0, 10, 1, -36), Size = UDim2.new(0.5, -15, 0, 28), Text = "✅ Accepter", ZIndex = 41 })
		local no = button(fr, { Position = UDim2.new(0.5, 5, 1, -36), Size = UDim2.new(0.5, -15, 0, 28), Text = "✖ Refuser", BackgroundColor3 = Color3.fromRGB(255, 99, 99), ZIndex = 41 })
		DU.ask = { frame = fr, fromId = p.fromId, deadline = os.clock() + (tonumber(p.seconds) or 20), timer = timer }
		yes.Activated:Connect(function()
			fire("duelAnswer", { from = p.fromId, accept = true })
			DU.closeAsk()
		end)
		no.Activated:Connect(function()
			fire("duelAnswer", { from = p.fromId, accept = false })
			DU.closeAsk()
		end)
		pcall(function()
			fr.Position = UDim2.new(0.5, 0, 0, 60)
			TweenService:Create(fr, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 90) }):Play()
		end)
		FX.sound("battle_start")
	end
	function DU.showWatch(p) -- bandeau des spectateurs : noms, PV restants des deux équipes, tour, vainqueur
		if type(p.view) ~= "table" or type(p.view.sides) ~= "table" then
			return
		end
		if not DU.watch then
			local fr = make("Frame", { Name = "DuelWatch", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(320, 50), BackgroundColor3 = Color3.fromRGB(28, 26, 44), BackgroundTransparency = 0.15, ZIndex = 25 }, gui)
			make("UICorner", { CornerRadius = UDim.new(0, 12) }, fr)
			make("UIStroke", { Color = Color3.fromRGB(255, 210, 63), Thickness = 2 }, fr)
			local title = label(fr, { Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 20), TextSize = 14, Text = "", ZIndex = 26 })
			local bars = {}
			for i = 1, 2 do
				local bg = make("Frame", { Position = UDim2.new((i - 1) * 0.5, 8, 0, 28), Size = UDim2.new(0.5, -16, 0, 12), BackgroundColor3 = Color3.fromRGB(50, 30, 40), ZIndex = 26 }, fr)
				make("UICorner", { CornerRadius = UDim.new(0, 6) }, bg)
				bars[i] = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = i == 1 and Color3.fromRGB(74, 163, 255) or Color3.fromRGB(255, 99, 99), ZIndex = 27 }, bg)
			end
			DU.watch = { frame = fr, title = title, bars = bars }
		end
		local w = DU.watch
		for i = 1, 2 do
			local hp, max = 0, 0
			for _, u in ipairs(p.view.sides[i] and p.view.sides[i].units or {}) do
				hp, max = hp + math.max(0, tonumber(u.hp) or 0), max + math.max(0, tonumber(u.maxHp) or 0)
			end
			w.bars[i].Size = UDim2.fromScale(max > 0 and hp / max or 0, 1)
		end
		local a, b = tostring(p.a or "?"):sub(1, 16), tostring(p.b or "?"):sub(1, 16)
		w.title.Text = p.over and ("🏆 " .. (p.winner and tostring(p.winner):sub(1, 16) .. " gagne le duel !" or "Duel terminé")) or ("⚔️ Duel au colisée : " .. a .. " 🆚 " .. b .. " · tour " .. tostring(p.view.turn or 0))
		DU.watchAt = os.clock() + (p.over and 5 or 25)
	end

	RBattle.OnClientEvent:Connect(function(p)
		pcall(function()
			if type(p) ~= "table" then
				return
			end
			if p.k == "duelAsk" then
				DU.showAsk(p)
				return
			elseif p.k == "duelAskEnd" then
				if DU.ask and DU.ask.fromId == p.fromId then
					DU.closeAsk()
				end
				return
			elseif p.k == "duelWatch" then
				DU.showWatch(p)
				return
			elseif p.k == "liveQueued" then -- lot 14 : classé en direct
				LV.queued, LV.note = true, "🔎 Recherche d'un adversaire en ligne de ton niveau…" .. (tonumber(p.seconds) and (" (au plus " .. math.floor(p.seconds) .. " s)") or "")
				if mode == "team" then
					render()
				end
				return
			elseif p.k == "liveCancel" then
				LV.queued, LV.note = false, nil
				if mode == "team" then
					render()
				end
				return
			elseif p.k == "liveFound" then
				LV.queued, LV.note = false, "⚔️ Adversaire trouvé : " .. tostring(p.opp or "?"):sub(1, 20) .. " ! Téléportation vers l'arène…"
				ui.panel.Visible = true
				if mode == "team" then
					render()
				end
				FX.sound("battle_start")
				return
			elseif p.k == "liveFallback" then
				LV.queued, LV.note = false, nil
				mode = "end"
				clear()
				ui.panel.Visible = true
				ui.title.Text = "🏆 Combat classé"
				ui.info.Text = ""
				add(label(ui.body, { Size = UDim2.new(1, 0, 1, -52), TextSize = 16, TextWrapped = true, Text = "Aucun adversaire en ligne de ton niveau.\nCombattre une équipe enregistrée ?", ZIndex = 32 }))
				local yes = add(button(ui.body, { Position = UDim2.new(0, 0, 1, -46), Size = UDim2.new(0.5, -3, 0, 44), Text = "🏆 Oui", ZIndex = 32 }))
				local no = add(button(ui.body, { Position = UDim2.new(0.5, 3, 1, -46), Size = UDim2.new(0.5, -3, 0, 44), Text = "Non", BackgroundColor3 = Color3.fromRGB(255, 99, 99), ZIndex = 32 }))
				yes.Activated:Connect(function()
					fire("pvpStart")
				end)
				no.Activated:Connect(function()
					mode = "team"
					render()
				end)
				return
			elseif p.k == "liveArena" then
				LV.queued, LV.note = false, nil
				mode = "end"
				clear()
				ui.panel.Visible = true
				ui.title.Text = "🏆 Arène classée"
				ui.info.Text = ""
				add(label(ui.body, { Size = UDim2.new(1, 0, 1, 0), TextSize = 16, TextWrapped = true, Text = "En attente de ton adversaire…" .. (tonumber(p.seconds) and ("\n(au plus " .. math.floor(p.seconds) .. " s ; s'il n'arrive pas, aucun trophée ne bouge)") or ""), ZIndex = 32 }))
				return
			elseif p.k == "liveVoid" then
				LV.queued, LV.note = false, nil
				ui.panel.Visible = true
				showResult("⚔️ Combat annulé : aucun trophée gagné ni perdu.\nRetour à ta partie…")
				return
			end
			if p.k == "start" then
				DU.on, DU.chosen = p.duel == true, false
				LV.queued, LV.note = false, nil
				if p.duel then
					DU.closeAsk()
					pcall(DU.camera, p)
				end
				mode, view, foeName, lastFloor, logLines, pick, lastReady = "battle", p.view, p.foe, p.floor, {}, nil, false
				deadline = os.clock() + (p.seconds or TW.turnSeconds)
				if SC.open(p) then -- refonte : scène face à face plein écran (le panneau compact reste caché)
					SC.refresh()
				else
					ui.panel.Visible = true
					render()
				end
				FX.hits = { 0, 0 }
				pcall(FX.intro, p)
			elseif p.k == "turn" then
				DU.chosen = false
				view = p.view
				deadline = os.clock() + (p.seconds or TW.turnSeconds)
				pushLog(p.events)
				SC.events = p.events
				if SC.scene then -- animations de la scène (élan, recul, nombres flottants) ; le remplacement d'une créature attend la fin des coups
					local okc, d = pcall(SC.scene.cues, p.events)
					SC.delay = okc and tonumber(d) or 0
				end
				pcall(FX.hits, p.events)
				if mode == "battle" then
					render()
				end
			elseif p.k == "pick" then
				if type(p.cards) == "table" and #p.cards >= 1 and #p.cards <= 5 then
					showPick(p)
				end
			elseif p.k == "picked" then
				showPicked(p)
			elseif p.k == "end" then
				PREFS.seen = PREFS.seen + 1 -- un combat de plus vu : « Passer l'animation » est proposé dès le suivant
				local r = p.rewards or {}
				local lines = { p.win and "🏆 Victoire !" or "💀 Défaite…" }
				if p.duel then -- lot 13 : texte du serveur (forfait, quotas, pièces), caméra rendue
					pcall(DU.restore)
					lines = { r.cancelled and "⚔️ Duel annulé" or (p.win and "🏆 Duel gagné !" or "💀 Duel perdu…"), type(r.duelText) == "string" and r.duelText or "" }
					r = {}
				end
				if p.win and r.coins then
					lines[#lines + 1] = "+" .. Config.fmt(r.coins) .. " 🪙" .. (r.first and " (première victoire de l'étage)" or "")
				end
				if p.pvp and r.trophies then
					lines[#lines + 1] = (r.trophies >= 0 and "+" or "") .. r.trophies .. " 🏆 trophées (total " .. r.total .. ")"
					if type(fx) == "table" and fx.BattleLayout and type(Config.LEAGUES) == "table" then -- récap : progression vers le palier suivant (calculée ici d'après le total envoyé)
						local pr = fx.BattleLayout.leagueProgress(r.total, Config.LEAGUES)
						if pr.name ~= "" then
							lines[#lines + 1] = "🏅 " .. pr.name .. (pr.next and (" · prochain palier : " .. tostring(pr.nextName) .. " à " .. pr.next .. " 🏆 (" .. pr.percent .. " %)") or " · palier maximal")
						end
					end
				end
				if p.live then -- lot 14 : classé en direct
					if r.forfeit then
						lines[#lines + 1] = p.win and "(forfait de l'adversaire)" or "(forfait)"
					end
					if r.capped then
						lines[#lines + 1] = "Plafond de trophées du jour atteint en direct."
					end
				end
				if r.egg then
					lines[#lines + 1] = "🥚 Œuf " .. Config.TIERS[r.egg].name
				end
				if r.potion then
					lines[#lines + 1] = "🧪 Potion de chance"
				end
				if p.pick then
					lines[#lines + 1] = "🎁 Choisis ta récompense…"
				end
				if r.limited then
					lines[#lines + 1] = "Limite de récompenses de répétition atteinte aujourd'hui."
				end
				if SC.scene then -- la scène reste en fond, assombrie, derrière l'écran de résultat et les cartes de récompense
					if type(p.view) == "table" and type(p.view.sides) == "table" then
						pcall(SC.scene.update, p.view, { delay = 0.8 })
					end
					pcall(SC.scene.setDim, true)
				end
				showResult(table.concat(lines, "\n"), p.pick == true)
				FX.sound(p.win and "battle_win" or "battle_lose")
				local trophy = FX.icon(ui.body, p.win and "ui_trophee" or "ui_victoire_defaite", 4, 4, 40)
				if trophy then
					add(trophy)
				end
			end
		end)
	end)
	ui.open.Activated:Connect(function()
		ui.panel.Visible = not ui.panel.Visible
		if ui.panel.Visible and mode ~= "battle" and mode ~= "end" and mode ~= "pick" then
			mode = "team"
			render()
		end
	end)
	ui.close.Activated:Connect(function()
		ui.panel.Visible = false
		if SC.scene and (mode == "end" or mode == "team") then -- refonte : fermer le résultat libère la scène (jamais d'écran de combat orphelin)
			SC.close()
			mode = "team"
		end
	end)
	task.spawn(function() -- minuteur du tour
		while true do
			task.wait(0.5)
			pcall(function()
				if mode == "pick" and pick and ui.panel.Visible then
					local left = math.max(0, math.ceil(pickDeadline - os.clock()))
					for _, w in ipairs(widgets) do
						if w.Name == "PickTimer" then
							w.Text = left > 0 and ("⏱ " .. left .. " s") or "Choix automatique…"
						end
					end
					if left <= 0 and os.clock() > pickDeadline + 20 then -- le serveur n'a rien renvoyé : on rend la main (la carte reste attribuée côté serveur)
						mode, pick = "team", nil
						render()
					end
				end
				if DU.ask then
					local left = math.ceil(DU.ask.deadline - os.clock())
					DU.ask.timer.Text = "⏱ " .. math.max(0, left) .. " s pour répondre"
					if left < -1 then
						DU.closeAsk()
					end
				end
				if DU.watch and os.clock() > DU.watchAt then
					DU.watch.frame:Destroy()
					DU.watch = nil
				end
				if DU.on and mode ~= "battle" then
					DU.restore()
				end
				if mode == "battle" and SC.scene and view then
					SC.scene.setStatus(SC.statusText())
				elseif SC.scene and mode ~= "battle" and mode ~= "end" and mode ~= "pick" then -- plus de combat : la scène ne reste jamais seule à l'écran
					SC.close()
				end
				if mode == "battle" and ui.panel.Visible and view and not view.over then
					local left = math.max(0, math.ceil(deadline - os.clock()))
					ui.title.Text = "⚔️ " .. foeName .. ((lastFloor or 0) > 0 and (" · étage " .. lastFloor) or "") .. " · ⏱ " .. left .. " s"
				end
			end)
		end
	end)
	return ui
end

return BattleUi
