--!nocheck
-- Graphismes 9 : musique par zone (ReplicatedStorage/Music pur, StarterPlayerScripts/Music.client.lua). Aucun identifiant inventé : Config.MUSIC a des pistes
-- vides, le système est prêt mais muet. Mesuré : zones, volume bas plafonné, coupure en combat, fondu borné, SOUNDS_ENABLED et volume général respectés,
-- identifiants refusés s'ils ne sont pas « rbxassetid://<chiffres> », script client muet sans piste, BattleUi lu sans être modifié.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs }. Style : pas de `+=`, pas de `continue`.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local T = {}
	local C3 = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } }
	local Config = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = C3 })()
	local M = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Music.lua"), { debugName = "Music" })()
	local function has(s, w)
		return string.find(s, w, 1, true) ~= nil
	end
	-- Config de test avec des pistes FACTICES (jamais publiées : seulement pour exercer la logique)
	local Fake = { MUSIC = { enabled = true, volume = 0.15, fade = 2.5, tracks = { hub = "rbxassetid://111", arena = "rbxassetid://222", castle = "rbxassetid://333" } } }

	suite("Graphismes 9 : musique par zone (prête, sans pistes)")
	check("Config.MUSIC : 3 zones (hub, arène, château), identifiants VIDES (aucun inventé), volume bas", type(Config.MUSIC) == "table" and Config.MUSIC.tracks.hub == "" and Config.MUSIC.tracks.arena == "" and Config.MUSIC.tracks.castle == "" and Config.MUSIC.volume <= 0.2)
	check("sans piste : prêt mais muet (hasTracks = false, volume cible 0 partout)", M.hasTracks(Config) == false and M.target(Config, "hub", { zone = "hub", master = 1, soundsEnabled = true }) == 0)
	check("identifiants : seuls rbxassetid://<chiffres> non nuls sont acceptés", M.trackId("rbxassetid://123") == "rbxassetid://123" and M.trackId("") == nil and M.trackId("rbxassetid://0") == nil and M.trackId("http://x") == nil and M.trackId("rbxassetid://12a") == nil and M.trackId(5) == nil)
	check("zones : village et parcelles -> hub, arène, château ; inconnue -> hub", M.zoneOf("hub") == "hub" and M.zoneOf("plots") == "hub" and M.zoneOf("arena") == "arena" and M.zoneOf("castle") == "castle" and M.zoneOf(nil) == "hub")
	T.ctx = { zone = "arena", battle = false, master = 1, soundsEnabled = true }
	check("une seule piste jouée à la fois : celle de la zone, au volume bas", M.target(Fake, "arena", T.ctx) == 0.15 and M.target(Fake, "hub", T.ctx) == 0 and M.target(Fake, "castle", T.ctx) == 0)
	check("coupée pendant un combat (interface de combat ouverte)", M.target(Fake, "arena", { zone = "arena", battle = true, master = 1, soundsEnabled = true }) == 0)
	check("Config.SOUNDS_ENABLED = false : muette", M.target(Fake, "arena", { zone = "arena", master = 1, soundsEnabled = false }) == 0)
	check("volume général du menu Plus : 60 % -> 0,09 ; muet (0) -> 0", math.abs(M.target(Fake, "arena", { zone = "arena", master = 0.6, soundsEnabled = true }) - 0.09) < 1e-9 and M.target(Fake, "arena", { zone = "arena", master = 0, soundsEnabled = true }) == 0)
	check("plafond dur : un volume réglé trop haut est ramené à 0,3", M.cfg({ MUSIC = { volume = 5, tracks = {} } }).volume == M.MAX_VOLUME and M.MAX_VOLUME <= 0.3)
	check("enabled = false : muette", M.target({ MUSIC = { enabled = false, tracks = Fake.MUSIC.tracks } }, "hub", { zone = "hub", master = 1, soundsEnabled = true }) == 0)
	-- fondu : de 0 à 0,15 en ~1,25 s (fade 2,5 s pour 0,3), pas à pas de 0,05 s ; jamais de dépassement ; descente symétrique
	T.v, T.t, T.over = 0, 0, false
	while T.v < 0.15 and T.t < 10 do
		T.v = M.step(T.v, 0.15, 0.05, 2.5)
		T.t = T.t + 0.05
		if T.v > 0.15 then
			T.over = true
		end
	end
	check("fondu d'entrée progressif (" .. string.format("%.2f", T.t) .. " s pour atteindre 0,15) sans dépassement", not T.over and T.t >= 1 and T.t <= 1.5)
	T.n = 0
	while T.v > 0 and T.n < 1000 do
		T.v = M.step(T.v, 0, 0.05, 2.5)
		T.n = T.n + 1
	end
	check("fondu de sortie progressif (" .. T.n .. " pas) jusqu'au silence exact", T.v == 0 and T.n >= 20)
	check("fondu robuste aux valeurs invalides (NaN, négatif, dt nul)", M.step(0 / 0, 0.1, 0.05, 2.5) > 0 and M.step(0.1, -1, 0.05, 2.5) < 0.1 and M.step(0.1, 0.2, 0, 2.5) == 0.1)

	suite("Graphismes 9 : script client et besoins")
	local cli = fs.readFile("roblox/src/StarterPlayerScripts/Music.client.lua")
	check("client : arrêt immédiat sans piste (aucun Sound créé)", has(cli, "if not cfg.enabled or not Music.hasTracks(Config) then"))
	check("client : combat détecté en LISANT BattleGui.ArenaPanel (BattleUi non modifié)", has(cli, 'FindFirstChild("ArenaPanel")') and not has(fs.readFile("roblox/src/StarterPlayerScripts/BattleUi.lua"), "Music"))
	check("client : SOUNDS_ENABLED et volume général (attribut local MasterVolume posé par Client)", has(cli, "soundsEnabled = Config.SOUNDS_ENABLED") and has(cli, 'GetAttribute("MasterVolume")') and has(fs.readFile("roblox/src/StarterPlayerScripts/Client.client.lua"), 'player:SetAttribute("MasterVolume", masterVolume())'))
	check("client : boucle avec task.wait et arrêt propre en cas d'erreur", has(cli, "task.wait(cfg.interval)") and has(cli, "s:Destroy()"))
	check("besoins listés : pistes à fournir (A_FAIRE_UTILISATEUR.md)", has(fs.readFile("roblox/A_FAIRE_UTILISATEUR.md"), "pistes à fournir"))
	check("module pur : pas de += / continue / GetService", not has(fs.readFile("roblox/src/ReplicatedStorage/Music.lua"), "+=") and not has(fs.readFile("roblox/src/ReplicatedStorage/Music.lua"), "continue") and not has(fs.readFile("roblox/src/ReplicatedStorage/Music.lua"), "GetService"))
end
