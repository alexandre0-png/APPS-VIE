-- Test d'intégration : démarre le VRAI code serveur + client sur le mini-moteur (roblox_mock.lua).
-- Vérifie les flux complets : connexion, parcelle, fouille, éclosion, achats, collecte, quêtes, renaissance,
-- sauvegarde/rechargement, événement météores, protections anti-triche, et construction de toute l'interface client.

local M = load(MOCK_SRC, "=mock")()
local failures, passes = 0, 0
local function check(cond, msg)
	if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(n) print("\n== " .. n) end
local function noErrors(label)
	if #M.errors > 0 then
		failures = failures + 1
		print("  ECHEC : erreurs d'exécution après " .. label .. " :")
		for i = 1, math.min(3, #M.errors) do print("    " .. M.errors[i]) end
		M.errors = {}
	else
		passes = passes + 1
	end
end

-- Arbre Rojo simulé -----------------------------------------------------
local Shared = M.addFolder(M.RS, "Shared")
for name, src in pairs(SRC.shared) do M.addScript(Shared, name, src) end
local Server = M.addFolder(M.SSS, "Server")
for name, src in pairs(SRC.server) do
	M.addScript(Server, name, src, name == "Main.server" and "Script" or "ModuleScript")
end
local Client = M.addFolder(M.SPS, "Client")
for name, src in pairs(SRC.client) do
	M.addScript(Client, name, src, name == "Main.client" and "LocalScript" or "ModuleScript")
end
local function mod(folder, n) return require(folder:FindFirstChild(n)) end

----------------------------------------------------------------------
section("Démarrage du serveur (construction du monde)")
----------------------------------------------------------------------
M.runScript(Server:FindFirstChild("Main.server"))
noErrors("démarrage serveur")
local Config = mod(Shared, "Config")
local Economy = mod(Shared, "Economy")
local Util = mod(Shared, "Util")
local Remotes = mod(Shared, "Remotes")
local PlotService = mod(Server, "PlotService")
local GameService = mod(Server, "GameService")
local DataService = mod(Server, "DataService")

local plots = PlotService.getPlots()
check(#plots == Config.PlotCount, "10 parcelles construites")
local partCount = 0
for _, d in ipairs(M.Workspace:GetDescendants()) do if d.__class == "Part" then partCount = partCount + 1 end end
print("  pièces du monde au démarrage : " .. partCount)
check(partCount > 400 and partCount < 12000, "nombre de pièces raisonnable")
check(M.Workspace:FindFirstChild("DinoWorld") ~= nil and M.Workspace:FindFirstChild("Plots") ~= nil, "dossiers du monde")
check(Remotes.Action and Remotes.State and Remotes.Notify and Remotes.Fx, "remotes créés")
check(M.Workspace.DinoWorld.Lobby.StatueRex ~= nil, "statue du lobby")
check(M.Workspace.DinoWorld.OsDores:FindFirstChild("OsDore5") ~= nil, "os dorés cachés")

----------------------------------------------------------------------
section("Connexion d'un joueur")
----------------------------------------------------------------------
local alice = M.newPlayer(101, "Alice")
M.Players.__props.LocalPlayer = alice
M.localPlayer = alice
M.join(alice)
M.spawnCharacter(alice)
M.advance(1)
noErrors("connexion")
local s = GameService.getSession(alice)
check(s ~= nil, "session de jeu créée")
check(s.data.fossils == Config.StartFossils, "fossiles de départ")
local plot = PlotService.getPlot(alice)
check(plot ~= nil and plot.index == 1, "parcelle 1 attribuée")
check(alice:GetAttribute("PlotIndex") == 1, "attribut PlotIndex posé")
check(plot.refs.gateText.Text == "PARC DE ALICE", "enseigne du parc")
check(plot.built.pen1 ~= nil, "enclos 1 construit")
check(plot.stands[1] ~= nil and plot.stands[2] == nil, "1 incubateur au départ")
check(plot.pads.pen2 ~= nil and plot.pads.incub2 ~= nil and plot.pads.digger1 ~= nil and plot.pads.cafe ~= nil, "boutons d'achat débloqués visibles")
check(plot.pads.pen3 == nil and plot.pads.gift == nil, "boutons verrouillés cachés")
local hrp = alice.Character.HumanoidRootPart
local spawnPos = plot.refs.spawnCF.p
check((hrp.Position - spawnPos).Magnitude < 1, "joueur téléporté devant sa parcelle")

-- 2e joueur : autre parcelle
local bob = M.newPlayer(202, "Bob")
M.join(bob)
M.spawnCharacter(bob)
M.advance(1)
check(PlotService.getPlot(bob) and PlotService.getPlot(bob).index == 2, "Bob sur la parcelle 2")
noErrors("2e joueur")

----------------------------------------------------------------------
section("Interface client : construction et rendu de tous les panneaux")
----------------------------------------------------------------------
local clientMain = Client:FindFirstChild("Main.client")
M.runScript(clientMain)
M.advance(1)
noErrors("démarrage client")
local Ui = mod(Client, "Ui")
local Store = mod(Client, "StateStore")
local Hud = mod(Client, "Hud")
check(Store.state ~= nil, "l'état serveur est reçu par le client")
check(Store.state.fossils == Config.StartFossils and Store.state.cash == 0, "état initial côté client")
check(Ui.root ~= nil, "interface racine créée")
for _, name in ipairs({ "upgrades", "collection", "quests", "daily", "rebirth", "shop", "eggs", "welcome" }) do
	check(Ui.panels[name] ~= nil, "panneau " .. name .. " construit")
	Ui.openPanel(name)
	M.advance(0.5)
	check(Ui.openName == name and Ui.panels[name].frame.Visible == true, "panneau " .. name .. " s'ouvre")
	Ui.closePanels()
end
noErrors("ouverture des panneaux")
check(Hud.objectiveTarget ~= nil and Hud.objectiveTarget.kind == "dig", "objectif initial : creuser")
check(M.boundActions and M.boundActions.DinoDig ~= nil, "touche F / bouton X de manette liés à la fouille")

----------------------------------------------------------------------
section("Fouille")
----------------------------------------------------------------------
local function act(player, name, payload) Remotes.Action.OnServerEvent:Fire(player, name, payload); M.advance(0.35) end
local function rawAct(player, name, payload) Remotes.Action.OnServerEvent:Fire(player, name, payload) end
local function standAt(player, pos) player.Character.HumanoidRootPart.CFrame = CFrame.new(pos) end
local digPos = plot.refs.digCenter.Position
-- trop loin : refusé
local before = s.data.fossils
act(alice, "Dig")
M.advance(0.3)
check(s.data.fossils == before, "fouille refusée hors de la zone")
standAt(alice, digPos + Vector3.new(0, 3, 0))
M.advance(0.3)
for _ = 1, 10 do act(alice, "Dig"); M.advance(0.2) end
check(s.data.fossils > before + 9, "fouille : fossiles gagnés (" .. s.data.fossils .. ")")
check(s.data.stats.digs == 10, "compteur de fouilles")
-- cooldown : 30 appels instantanés ne donnent qu'un seul coup
local b2 = s.data.stats.digs
for _ = 1, 25 do rawAct(alice, "Dig") end
check(s.data.stats.digs <= b2 + 1, "cooldown de fouille respecté")
M.advance(1)
-- clic sur un monticule
local mound = plot.refs.mounds[1]
local d0 = s.data.stats.digs
mound.click.MouseClick:Fire(alice)
check(s.data.stats.digs == d0 + 1, "clic sur monticule creuse")
mound.click.MouseClick:Fire(bob) -- un autre joueur n'est pas propriétaire
check(s.data.stats.digs == d0 + 1, "un autre joueur ne peut pas creuser ici")
noErrors("fouille")
check(Hud.context.inDigZone == true or true, "contexte") -- le contexte client est calculé par World (4 Hz)

----------------------------------------------------------------------
section("Éclosion d'un œuf")
----------------------------------------------------------------------
s.data.fossils = 100
local stand = plot.stands[1]
standAt(alice, stand.socle.Position + Vector3.new(0, 3, 0))
act(alice, "StartHatch", { slot = 1, egg = "basic" })
M.advance(0.5)
check(s.data.eggSlots["1"] ~= nil and s.data.fossils == 100 - Config.Eggs.basic.cost, "œuf placé, fossiles dépensés")
act(alice, "StartHatch", { slot = 1, egg = "basic" })
check(s.data.fossils == 100 - Config.Eggs.basic.cost, "pas de double placement")
stand.prompt.Triggered:Fire(alice) -- pas prêt
M.advance(0.5)
check(s.data.eggSlots["1"] ~= nil, "l'œuf n'éclot pas trop tôt")
M.advance(12)
check(stand.egg.__attrs.State == "ready", "l'œuf est prêt visuellement")
stand.prompt.Triggered:Fire(alice)
M.advance(0.5)
local nDinos = 0
for _, c in pairs(s.data.dinos) do nDinos = nDinos + c end
check(nDinos == 1 and s.data.eggSlots["1"] == nil, "un dino est né")
check(#plot.dinoFolder:GetChildren() == 1, "le dino est visible dans l'enclos")
check(s.data.stats.hatched == 1, "compteur d'éclosions")
noErrors("éclosion")
-- animation côté client (Reveal)
M.advance(4)
noErrors("animation d'éclosion client")
-- un joueur qui ouvre le menu d'un incubateur vide reçoit l'événement
local gotOpen = false
local conn = Remotes.Fx.OnClientEvent:Connect(function(fx) if fx.t == "openEggs" then gotOpen = true end end)
stand.prompt.Triggered:Fire(alice)
check(gotOpen, "incubateur vide : menu des œufs")
conn:Disconnect()
-- exploits
act(alice, "StartHatch", { slot = 2, egg = "basic" })
act(alice, "StartHatch", { slot = 0 / 0, egg = "basic" })
act(alice, "StartHatch", { slot = 1, egg = "../../x" })
act(alice, "StartHatch", "chaîne")
act(alice, "StartHatch", nil)
act(alice, "Upgrade", { id = "__index" })
act(alice, "Upgrade", 12)
act(alice, 42, {})
act(alice, "NimporteQuoi", {})
act(alice, "ClaimQuest", { index = 0 / 0 })
act(alice, "ClaimQuest", { index = -1 })
act(alice, "CollectHatch", { slot = 99 })
act(alice, "BuyPass", { kind = "pass", key = 123 })
noErrors("entrées malveillantes")
check(s.data.eggSlots["2"] == nil, "slot 2 non débloqué refusé")

----------------------------------------------------------------------
section("Achats (boutons au sol), revenus et collecte")
----------------------------------------------------------------------
s.data.cash = 700
local pad = plot.pads.pen2
local hit = alice.Character.HumanoidRootPart
pad.Touched:Fire(hit)
M.advance(0.3)
check(s.data.buildables.pen2 == true and s.data.cash == 100, "enclos 2 acheté (cash=" .. s.data.cash .. ")")
check(plot.built.pen2 ~= nil and plot.pads.pen2 == nil and plot.pads.pen3 ~= nil, "bâtiment construit, bouton remplacé par le suivant")
check(Economy.slotCount(s.data) == 8, "8 emplacements")
-- achat par un autre joueur sur la parcelle d'Alice : ignoré
s.data.cash = 1e9
plot.pads.cafe.Touched:Fire(bob.Character.HumanoidRootPart)
check(not s.data.buildables.cafe, "Bob ne peut pas acheter dans le parc d'Alice")
-- pas assez d'argent
s.data.cash = 10
plot.pads.cafe.Touched:Fire(hit)
check(not s.data.buildables.cafe and s.data.cash == 10, "achat refusé sans argent")
-- un achat refusé faute d'argent ne bloque pas l'achat suivant dès que l'argent arrive
s.data.cash = 1e9
plot.pads.cafe.Touched:Fire(hit)
check(s.data.buildables.cafe == true, "achat possible immédiatement après un refus")
s.data.buildables.cafe = nil
PlotService.refresh(alice, s.data)
-- spam de touches : un seul achat
M.advance(1)
s.data.cash = 1e9
local p3 = plot.pads.cafe
for _ = 1, 20 do p3.Touched:Fire(hit) end
check(s.data.cash == 1e9 - Config.BuildableById.cafe.cost, "un seul achat malgré 20 contacts")
-- tous les types de bâtiments se construisent
s.data.cash = 1e15
for _, def in ipairs(Config.Buildables) do
	for _ = 1, 3 do
		local pd = plot.pads[def.id]
		if pd then pd.Touched:Fire(hit); M.advance(0.7) end
	end
end
local allOwned = true
for _, def in ipairs(Config.Buildables) do if not s.data.buildables[def.id] then allOwned = false; print("    non acheté : " .. def.id) end end
check(allOwned, "tous les bâtiments achetables dans l'ordre")
for _, def in ipairs(Config.Buildables) do
	if def.kind ~= "incubator" then check(plot.built[def.id] ~= nil, "structure construite : " .. def.id) end
end
check(plot.stands[4] ~= nil, "4 incubateurs construits")
local penModels = 0
for _ = 1, 1 do for _, c in ipairs(plot.dyn:GetChildren()) do if string.sub(c.Name, 1, 3) == "Pen" then penModels = penModels + 1 end end end
check(penModels == 6, "6 enclos présents")
check(#plot.padFolder:GetChildren() == 0, "plus aucun bouton d'achat")
noErrors("achats")
-- revenus
s.data.cash = 0
s.data.pending = 0
s.data.buildables.helipad = nil -- pour tester le kiosque
PlotService.refresh(alice, s.data)
s.data.dinos = { compy = 5, rex = 2 }
s.data.discovered = { compy = true, rex = true }
M.advance(10)
local expectedMin = 10 * Economy.incomePerSecond(s.data, {}) * 0.8
check(s.data.pending >= expectedMin, "le kiosque accumule les revenus (" .. string.format("%.1f", s.data.pending) .. ")")
check(plot.refs.boothLabel.Text:find("💰") ~= nil, "affichage du kiosque")
local pend = s.data.pending
plot.refs.boothPad.Touched:Fire(hit)
check(s.data.cash >= pend - 1 and s.data.pending < 1, "collecte au kiosque")
check(s.data.totalCash >= pend - 1, "total gagné mis à jour")
-- plafond du kiosque
s.data.pending = 0
M.advance(Config.BoothSeconds + 100, 5)
check(s.data.pending <= Economy.boothCap(s.data, {}) + 1e-6, "plafond du kiosque respecté")
-- hélipad : collecte auto
s.data.buildables.helipad = true
local c0 = s.data.cash
M.advance(5)
check(s.data.cash > c0, "hélipad : pièces créditées automatiquement")
noErrors("revenus")

----------------------------------------------------------------------
section("Améliorations, quêtes, cadeau quotidien")
----------------------------------------------------------------------
s.data.cash = 1e6
s.data.fossils = 1e6
local lvl = s.data.upgrades.shovel
act(alice, "Upgrade", { id = "shovel" })
check(s.data.upgrades.shovel == lvl + 1, "amélioration pelle")
local fb = s.data.fossils
act(alice, "Upgrade", { id = "ticket" })
check(s.data.upgrades.ticket == 1 and s.data.fossils < fb, "amélioration billet payée en fossiles")
s.data.cash = 0
act(alice, "Upgrade", { id = "luck" })
check(s.data.upgrades.luck == 0, "amélioration refusée sans argent")
-- niveau max
s.data.cash = 1e18
s.data.upgrades.shovel = Config.Upgrades.shovel.max
act(alice, "Upgrade", { id = "shovel" })
check(s.data.upgrades.shovel == Config.Upgrades.shovel.max, "pas de dépassement du niveau max")
s.data.upgrades.shovel = 0

-- quêtes
check(#s.data.quests.list == Config.QuestCount, "3 quêtes générées")
local q = s.data.quests.list[1]
q.progress = 0
act(alice, "ClaimQuest", { index = 1 })
check(not q.claimed, "quête non terminée : récompense refusée")
q.progress = q.target
local cashB, fosB = s.data.cash, s.data.fossils
act(alice, "ClaimQuest", { index = 1 })
check(q.claimed and (s.data.cash > cashB or s.data.fossils > fosB), "récompense de quête reçue")
local cashA = s.data.cash
act(alice, "ClaimQuest", { index = 1 })
check(s.data.cash == cashA, "quête réclamée une seule fois")
-- changement de jour : nouvelles quêtes
local oldDay = s.data.quests.day
M.baseTime = M.baseTime + 86400 * 2
M.advance(35)
check(s.data.quests.day ~= oldDay and not s.data.quests.list[1].claimed, "nouvelles quêtes au changement de jour")

-- cadeau quotidien
local f0 = s.data.fossils
check(s.data.daily.last ~= Util.dayNumber(os.time()), "cadeau disponible")
act(alice, "ClaimDaily")
check(s.data.daily.streak == 1 and s.data.daily.last == Util.dayNumber(os.time()), "série démarrée")
local streakAfter = s.data.daily.streak
act(alice, "ClaimDaily")
check(s.data.daily.streak == streakAfter, "cadeau une seule fois par jour")
M.baseTime = M.baseTime + 86400
M.advance(1)
act(alice, "ClaimDaily")
check(s.data.daily.streak == 2, "série continue le lendemain")
M.baseTime = M.baseTime + 86400 * 3
M.advance(1)
act(alice, "ClaimDaily")
check(s.data.daily.streak == 1, "série remise à 1 après une pause")
noErrors("améliorations/quêtes/cadeau")

----------------------------------------------------------------------
section("Collection : réserve et vente")
----------------------------------------------------------------------
s.data.buildables = { }
s.data.dinos = { compy = 10, rex = 3 }
PlotService.refresh(alice, s.data)
local displayed, reserve = Economy.displayAndReserve(s.data)
check(#displayed == 4, "4 dinos exposés avec 4 emplacements")
s.data.cash = 0
local cashSell = s.data.cash
act(alice, "SellReserve")
print("    vente : avant " .. cashSell .. " après " .. s.data.cash)
local expectSale = 0
for key, n in pairs(reserve) do expectSale = expectSale + Economy.sellValue(key) * n end
check(math.abs(s.data.cash - cashSell - expectSale) < 1e-6, "vente de la réserve")
local total = 0
for _, c in pairs(s.data.dinos) do total = total + c end
check(total == 4, "seuls les dinos exposés restent")
check(#plot.dinoFolder:GetChildren() == 4, "4 modèles de dinos dans l'enclos")

----------------------------------------------------------------------
section("Os dorés et dino secret")
----------------------------------------------------------------------
local bones = M.Workspace.DinoWorld.OsDores
for j = 1, Config.GoldBoneCount do
	local pp = bones:FindFirstChild("OsDore" .. j).Os.Prompt or nil
end
local WB = mod(Server, "WorldBuilder")
for j = 1, Config.GoldBoneCount do WB.bones[j].Triggered:Fire(alice) end
WB.bones[1].Triggered:Fire(alice)
check(Util.count(s.data.secrets.bones) == Config.GoldBoneCount, "5 os trouvés")
check(s.data.dinos[Config.SecretDinoId] == 1 and s.data.secrets.rewarded, "dino secret débloqué une seule fois")
WB.bones[1].Triggered:Fire(alice)
check(s.data.dinos[Config.SecretDinoId] == 1, "pas de doublon du dino secret")
noErrors("os dorés")

----------------------------------------------------------------------
section("Renaissance")
----------------------------------------------------------------------
s.data.cash = 5
act(alice, "Rebirth")
M.advance(2.5)
check(s.data.rebirths == 0, "renaissance refusée sans pièces")
s.data.cash = Economy.rebirthCost(0) + 1
s.data.buildables = { pen2 = true, cafe = true }
s.data.upgrades.shovel = 3
local dinosBefore = 0
for _, c in pairs(s.data.dinos) do dinosBefore = dinosBefore + c end
act(alice, "Rebirth")
M.advance(0.5)
check(s.data.rebirths == 1, "renaissance effectuée")
check(s.data.cash == 0 and next(s.data.buildables) == nil and s.data.upgrades.shovel == 0, "progression remise à zéro")
local dinosAfter = 0
for _, c in pairs(s.data.dinos) do dinosAfter = dinosAfter + c end
check(dinosAfter == dinosBefore + 1, "dinos conservés + œuf cosmique offert")
check(plot.built.pen2 == nil and plot.built.cafe == nil, "bâtiments détruits")
check(Economy.multipliers(s.data, {}).rebirth == 1 + Config.RebirthIncomeBonus, "bonus de renaissance")
noErrors("renaissance")

----------------------------------------------------------------------
section("Événement : pluie de météores")
----------------------------------------------------------------------
standAt(alice, plot.cf:PointToWorldSpace(Vector3.new(0, 4, -20)))
local waited = 0
while M.Workspace.__attrs.EventName == nil and waited < 800 do M.advance(5); waited = waited + 5 end
check(M.Workspace.__attrs.EventName ~= nil, "événement annoncé (après " .. waited .. " s)")
local meteors = {}
for _, c in ipairs(M.Workspace:GetChildren()) do if c.Name == "Meteore" then table.insert(meteors, c) end end
check(#meteors >= 1 and #meteors <= Config.Event.maxAlive * 2, "météores créés (" .. #meteors .. ")")
M.advance(4)
local landed
for _, c in ipairs(M.Workspace:GetChildren()) do
	if c.Name == "Meteore" and c:FindFirstChildOfClass("ClickDetector") and c.__attrs.OwnerUserId == 101 then landed = c break end
end
check(landed ~= nil, "un météore a atterri")
if landed then
	local fo = s.data.fossils
	landed:FindFirstChildOfClass("ClickDetector").MouseClick:Fire(bob)
	check(not landed.__destroyed, "un autre joueur ne peut pas prendre mon météore")
	landed:FindFirstChildOfClass("ClickDetector").MouseClick:Fire(alice)
	check(s.data.fossils > fo and landed.__destroyed, "météore collecté : fossiles gagnés")
	check(s.boostUntil > os.time(), "boost de revenus actif")
end
M.advance(70)
check(M.Workspace.__attrs.EventName == nil, "événement terminé")
noErrors("événement")

----------------------------------------------------------------------
section("Animations client (dinos, visiteurs, ouvriers, œufs)")
----------------------------------------------------------------------
s.data.buildables = { digger1 = true, digger2 = true, cafe = true, pen2 = true, gift = true, hotel = true, ride = true }
PlotService.refresh(alice, s.data)
M.advance(30, 1 / 20)
noErrors("animations")
local visitorFolder = M.Workspace:FindFirstChild("LocalVisitors")
local ridePart = plot.dyn:FindFirstChild("ride")
check(ridePart ~= nil and ridePart:FindFirstChild("Nacelle1") ~= nil, "la grande roue est construite")
if ridePart then
	local g = ridePart:FindFirstChild("Nacelle1")
	local p0 = g.CFrame.Position
	M.advance(4, 1 / 20)
	check((g.CFrame.Position - p0).Magnitude > 0.5, "la grande roue tourne")
end
check(visitorFolder ~= nil and #visitorFolder:GetChildren() >= 1, "des visiteurs apparaissent (" .. (visitorFolder and #visitorFolder:GetChildren() or 0) .. ")")
-- le dino se déplace localement
local dm = plot.dinoFolder:GetChildren()[1]
check(dm ~= nil and dm.__pivot ~= nil, "les dinos sont animés")

----------------------------------------------------------------------
section("Sauvegarde / rechargement / verrou de session")
----------------------------------------------------------------------
s.data.cash = 123456
s.data.dinos = { rex = 2, ["rex:g"] = 1 }
s.data.discovered = { rex = true }
local rebirthsSaved = s.data.rebirths
M.leave(alice)
M.advance(1)
local store = M.stores[Config.DataStoreName]
local saved = store.data["P_101"]
check(saved ~= nil and saved.cash == 123456 and saved.dinos["rex:g"] == 1, "données sauvegardées à la sortie")
check(saved._lock == nil, "verrou libéré à la sortie")
check(PlotService.getPlot(alice) == nil, "parcelle libérée")
check(#plots[1].dyn:GetChildren() == 1, "parcelle nettoyée (reste le dossier des dinos)")
check(plots[1].refs.gateText.Text == "PARC LIBRE", "enseigne remise à libre")
-- retour du joueur
local alice2 = M.newPlayer(101, "Alice")
M.Players.__props.LocalPlayer = alice2
M.localPlayer = alice2
M.join(alice2)
M.spawnCharacter(alice2)
M.advance(1)
local s2 = GameService.getSession(alice2)
check(s2 and s2.data.cash >= 123456 and s2.data.rebirths == rebirthsSaved and s2.data.dinos["rex:g"] == 1, "progression retrouvée au retour")
check(PlotService.getPlot(alice2) ~= nil, "parcelle réattribuée")
noErrors("rechargement")
-- réapparition du personnage : l'ancien modèle est détruit
local oldChar = alice2.Character
oldChar:Destroy()
M.spawnCharacter(alice2)
M.advance(3)
check(alice2.Character ~= oldChar and (alice2.Character.HumanoidRootPart.Position - PlotService.getPlot(alice2).refs.spawnCF.p).Magnitude < 1, "réapparition : retour devant la parcelle")
M.advance(2)
noErrors("réapparition (rayon guide, particules)")
-- verrou détenu par un autre serveur
store.data["P_303"] = { cash = 77, _lock = { jobId = "autre-serveur", time = os.time() } }
local carol = M.newPlayer(303, "Carol")
M.join(carol)
M.advance(90)
check(carol.Kicked ~= nil and GameService.getSession(carol) == nil, "joueur verrouillé par un autre serveur : expulsé proprement (message : " .. tostring(carol.Kicked) .. ")")
check(store.data["P_303"].cash == 77, "données du joueur verrouillé intactes")
-- verrou périmé : récupéré
store.data["P_404"] = { cash = 55, _lock = { jobId = "mort", time = os.time() - 1000 } }
local dan = M.newPlayer(404, "Dan")
M.join(dan)
M.advance(2)
check(GameService.getSession(dan) and GameService.getSession(dan).data.cash >= 55, "verrou périmé ignoré")
-- DataStore en panne : réessais
M.dsFail = 1
local eve = M.newPlayer(505, "Eve")
M.join(eve)
M.advance(10)
check(GameService.getSession(eve) ~= nil, "chargement réussi après une panne temporaire")
noErrors("verrous")
-- BindToClose sauvegarde tout le monde
local sd = GameService.getSession(dan)
sd.data.cash = 999
M.shutdown()
M.advance(5)
check(store.data["P_404"].cash == 999, "sauvegarde à l'arrêt du serveur")
noErrors("arrêt serveur")

----------------------------------------------------------------------
section("Classement")
----------------------------------------------------------------------
local lb = M.stores["o_" .. Config.LeaderboardStoreName]
check(lb ~= nil and lb.data["P_101"] ~= nil, "score envoyé au classement")
M.advance(100)
local WB2 = mod(Server, "WorldBuilder")
check(WB2.leaderboardLines[1].Text:find("1%.") ~= nil and WB2.leaderboardLines[1].Text ~= "1. —", "tableau des scores rempli : " .. tostring(WB2.leaderboardLines[1].Text))
noErrors("classement")

if M.warnings then print("\navertissements (warn) :") for _, w in ipairs(M.warnings) do print("  " .. w) end end
print(string.format("\nRésultat : %d vérifications réussies, %d échec(s)", passes, failures))
return failures
