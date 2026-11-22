-- ModuleScript : StarterPlayerScripts/BattleUi
-- Arène des pets (PvE) : écran d'équipe (3 pets de la collection, type affiché), choix de l'étage de la tour, écran de combat (barres de PV, icônes de type,
-- flèche d'avantage, journal court, minuteur de tour), écran de résultat avec récompenses. 100 % code. Le client N'ENVOIE QU'UNE INTENTION par tour
-- (« attack », « skill », « swapN ») : tout le résultat vient du serveur (événements rejoués ici). Aucune erreur ne sort d'ici.
local BattleUi = {}

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

function BattleUi.start(Config, Battle, player, gui, getState, fire, RBattle)
	local TW = Config.TOWER
	local ok, ui = pcall(function()
		local open = button(gui, { Name = "ArenaButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0.3, -42), Size = UDim2.fromOffset(34, 34), Text = "⚔️", BackgroundColor3 = Color3.fromRGB(255, 159, 28) })
		local panel = make("Frame", { Name = "ArenaPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 330), BackgroundColor3 = Color3.fromRGB(28, 26, 44), Visible = false, ZIndex = 30 }, gui)
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
	local view, seconds, deadline, foeName, lastFloor = nil, 0, 0, "", 1
	local logLines = {}
	local widgets = {}
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
		return Battle.TYPE_EMOJI[u.type] .. " " .. def.emoji .. " " .. def.name
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
		for i = 1, 12 do
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
		ui.title.Text = "⚔️ " .. foeName .. " · étage " .. lastFloor
		local me, foe = view.sides[1], view.sides[2]
		local mu, fu = me.units[me.active], foe.units[foe.active]
		ui.info.Text = BattleUi.advantage(Battle, mu.type, fu.type) .. " · tour " .. view.turn .. "/" .. Battle.MAX_TURNS
		local function bar(y, u, left)
			add(label(ui.body, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 20), Text = unitText(u) .. "   " .. u.hp .. "/" .. u.maxHp .. (u.guard and " 🛡" or "") .. (u.stun > 0 and " 💫" or "") .. (u.focus > 0 and " ⚡" or ""), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32 }))
			local bg = add(make("Frame", { Position = UDim2.fromOffset(0, y + 22), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Color3.fromRGB(50, 30, 40), ZIndex = 32 }, ui.body))
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, bg)
			local frac = u.maxHp > 0 and math.max(0, u.hp / u.maxHp) or 0
			make("Frame", { Size = UDim2.fromScale(frac, 1), BackgroundColor3 = frac > 0.5 and Color3.fromRGB(91, 227, 125) or (frac > 0.25 and Color3.fromRGB(255, 210, 63) or Color3.fromRGB(255, 99, 99)), ZIndex = 33 }, bg)
		end
		bar(0, fu, false)
		bar(40, mu, true)
		local log = add(label(ui.body, { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 56), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = table.concat(logLines, "\n"), ZIndex = 32 }))
		local b1 = add(button(ui.body, { Position = UDim2.new(0, 0, 1, -66), Size = UDim2.new(0.5, -3, 0, 28), Text = "⚔ Attaque", ZIndex = 32 }))
		b1.Activated:Connect(function()
			fire("battleAct", "attack")
		end)
		local sk = Battle.SKILLS[mu.skill]
		local b2 = add(button(ui.body, { Position = UDim2.new(0.5, 3, 1, -66), Size = UDim2.new(0.5, -3, 0, 28), Text = mu.cd > 0 and (sk.name .. " (" .. mu.cd .. ")") or ("✨ " .. sk.name), BackgroundColor3 = mu.cd > 0 and Color3.fromRGB(110, 110, 120) or Color3.fromRGB(74, 163, 255), ZIndex = 32 }))
		b2.Activated:Connect(function()
			if mu.cd == 0 then
				fire("battleAct", "skill")
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
					end
				end)
			end
		end
		local quit = add(button(ui.body, { Position = UDim2.new(1, -60, 0, 86), Size = UDim2.fromOffset(60, 22), Text = "Abandon", TextSize = 12, BackgroundColor3 = Color3.fromRGB(255, 99, 99), ZIndex = 33 }))
		quit.Activated:Connect(function()
			fire("battleQuit")
		end)
		return log
	end

	function render()
		clear()
		if mode == "battle" then
			renderBattle()
		elseif mode == "end" then
			-- l'écran de résultat est construit par `finish`
		else
			renderTeam()
		end
	end

	local function pushLog(events)
		for _, ev in ipairs(events or {}) do
			local t = Battle.describe(Config, ev)
			if t ~= "" and ev.t ~= "turn" then
				logLines[#logLines + 1] = t
			end
		end
		while #logLines > 4 do
			table.remove(logLines, 1)
		end
	end

	local function showResult(msg)
		mode = "end"
		clear()
		ui.info.Text = ""
		add(label(ui.body, { Size = UDim2.new(1, 0, 1, -44), TextSize = 16, TextWrapped = true, Text = msg, ZIndex = 32 }))
		local ok2 = add(button(ui.body, { Position = UDim2.new(0.5, -70, 1, -34), Size = UDim2.fromOffset(140, 30), Text = "Continuer", ZIndex = 32 }))
		ok2.Activated:Connect(function()
			mode = "team"
			team = {}
			logLines = {}
			render()
		end)
	end

	RBattle.OnClientEvent:Connect(function(p)
		pcall(function()
			if type(p) ~= "table" then
				return
			end
			if p.k == "start" then
				mode, view, foeName, lastFloor, logLines = "battle", p.view, p.foe, p.floor, {}
				deadline = os.clock() + (p.seconds or TW.turnSeconds)
				ui.panel.Visible = true
				render()
			elseif p.k == "turn" then
				view = p.view
				deadline = os.clock() + (p.seconds or TW.turnSeconds)
				pushLog(p.events)
				if mode == "battle" then
					render()
				end
			elseif p.k == "end" then
				local r = p.rewards or {}
				local lines = { p.win and "🏆 Victoire !" or "💀 Défaite…" }
				if p.win and r.coins then
					lines[#lines + 1] = "+" .. Config.fmt(r.coins) .. " 🪙" .. (r.first and " (première victoire de l'étage)" or "")
				end
				if r.egg then
					lines[#lines + 1] = "🥚 Œuf " .. Config.TIERS[r.egg].name
				end
				if r.potion then
					lines[#lines + 1] = "🧪 Potion de chance"
				end
				if r.limited then
					lines[#lines + 1] = "Limite de récompenses de répétition atteinte aujourd'hui."
				end
				showResult(table.concat(lines, "\n"))
			end
		end)
	end)
	ui.open.Activated:Connect(function()
		ui.panel.Visible = not ui.panel.Visible
		if ui.panel.Visible and mode ~= "battle" and mode ~= "end" then
			mode = "team"
			render()
		end
	end)
	ui.close.Activated:Connect(function()
		ui.panel.Visible = false
	end)
	task.spawn(function() -- minuteur du tour
		while true do
			task.wait(0.5)
			pcall(function()
				if mode == "battle" and ui.panel.Visible and view and not view.over then
					local left = math.max(0, math.ceil(deadline - os.clock()))
					ui.title.Text = "⚔️ " .. foeName .. " · étage " .. lastFloor .. " · ⏱ " .. left .. " s"
				end
			end)
		end
	end)
	return ui
end

return BattleUi
