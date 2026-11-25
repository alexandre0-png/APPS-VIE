-- Runtime Roblox factice PERMISSIF pour exécuter le vrai démarrage des scripts serveur (hub et partie) hors de Roblox.
-- Principe : toute propriété ou méthode inconnue est un « proxy universel » qui accepte tout (appel, arithmétique, signaux) ; les services
-- dont la logique compte sont simulés pour de vrai : DataStore (en mémoire), MemoryStore, TeleportService (appels enregistrés, échecs
-- injectables), Players, RunService.Heartbeat, ordonnanceur de tâches (task.spawn / wait / delay) avec temps virtuel, require() des vrais
-- modules du dépôt. Détecte : erreur au démarrage, require cassé, boucle sans wait (garde d'instructions), Remote jamais créé.
-- Ne simule NI la physique, NI le rendu : c'est un test de fumée de la logique de démarrage et de la validation des Remotes.
local Fake = {}

-- Garde-fous stricts : aucune suite ne peut boucler ni attendre. Horloge RÉELLE capturée avant tout remplacement de `os`.
local realClock = os.clock
local MAX_RESUMES = 300000 -- reprises de coroutines au total par runtime
local MAX_REAL_SECONDS = 20 -- temps réel maximum par runtime (jamais d'attente du vrai temps : task.wait est virtuel)

function Fake.runtime(opts)
	local RT = {
		now = 0, players = {}, errors = {}, prints = {}, warns = {}, teleports = {}, conns = {}, tags = {},
		remotes = {}, fired = {}, bindToClose = {}, waiting = {}, kicked = {}, renderSteps = {},
	}
	local fs, luau = opts.fs, opts.luau
	local startedAt, resumes = realClock(), 0
	local proxyMeta = {}
	local services = {}
	local newProxy

	local function isProxy(v)
		return type(v) == "table" and getmetatable(v) == proxyMeta
	end
	RT.isProxy = isProxy

	local function child(t, k)
		local props = rawget(t, "__props")
		local v = props[k]
		if v == nil then
			v = newProxy(rawget(t, "__path") .. "." .. tostring(k), "Unknown")
			props[k] = v
		end
		return v
	end

	local function addChild(parent, ch)
		local kids = rawget(parent, "__children")
		kids[#kids + 1] = ch
	end
	local function removeChild(parent, ch)
		local kids = rawget(parent, "__children")
		for i, c in ipairs(kids) do
			if c == ch then
				table.remove(kids, i)
				return
			end
		end
	end

	local methods = {}
	function methods.FindFirstChild(self, name, recursive)
		for _, c in ipairs(rawget(self, "__children")) do
			if rawget(c, "__props").Name == name then
				return c
			end
		end
		if recursive then
			for _, c in ipairs(rawget(self, "__children")) do
				local found = methods.FindFirstChild(c, name, true)
				if found then
					return found
				end
			end
		end
		return nil
	end
	methods.WaitForChild = methods.FindFirstChild
	methods.FindFirstChildOfClass = function(self, cls)
		for _, c in ipairs(rawget(self, "__children")) do
			if rawget(c, "__class") == cls then
				return c
			end
		end
		return nil
	end
	function methods.GetChildren(self)
		local out = {}
		for i, c in ipairs(rawget(self, "__children")) do
			out[i] = c
		end
		return out
	end
	function methods.GetDescendants(self)
		local out = {}
		local function walk(n)
			for _, c in ipairs(rawget(n, "__children")) do
				out[#out + 1] = c
				walk(c)
			end
		end
		walk(self)
		return out
	end
	-- Géométrie numérique réelle (jamais de proxy dans une comparaison : voir NUMERIC_DEFAULTS)
	-- Géométrie à état : taille « Blender » brute (rawset __fakeSize) x échelle courante (ScaleTo absolu, comme Roblox). Défaut 4 x 6 x 4.
	local function fakeExtents(self)
		local sz = rawget(self, "__fakeSize") or RT.vec(4, 6, 4)
		local k = rawget(self, "__scale") or 1
		return RT.vec(sz.X * k, sz.Y * k, sz.Z * k)
	end
	function methods.GetBoundingBox(self)
		return RT.cf(0, 0, 0), fakeExtents(self)
	end
	function methods.GetExtentsSize(self)
		return fakeExtents(self)
	end
	function methods.GetScale(self)
		return rawget(self, "__scale") or 1
	end
	function methods.GetPivot(self)
		return rawget(self, "__pivot") or RT.cf(0, 0, 0)
	end
	function methods.ScaleTo(self, k)
		rawget(self, "__props").lastScale = k
		rawset(self, "__scale", k)
	end
	function methods.PivotTo(self, cf)
		rawset(self, "__pivot", cf) -- mémorisé : les tests de déplacement lisent GetPivot
	end
	function methods.GetAttribute(self, k)
		return rawget(self, "__attrs")[k]
	end
	function methods.SetAttribute(self, k, v)
		rawget(self, "__attrs")[k] = v
	end
	function methods.IsA(self, cls)
		local c = rawget(self, "__class")
		if c == cls then
			return true
		end
		if cls == "BasePart" then
			return c == "Part" or c == "SpawnLocation" or c == "MeshPart"
		end
		if cls == "Instance" then
			return true
		end
		return false
	end
	function methods.Destroy(self)
		local par = rawget(self, "__props").Parent
		if par then
			removeChild(par, self)
		end
		rawget(self, "__props").Parent = nil
	end
	function methods.Clone(self)
		local c = newProxy(rawget(self, "__path") .. "(clone)", rawget(self, "__class"))
		for k, v in pairs(rawget(self, "__props")) do
			if k ~= "Parent" then
				rawget(c, "__props")[k] = v
			end
		end
		rawset(c, "__fakeSize", rawget(self, "__fakeSize"))
		rawset(c, "__scale", rawget(self, "__scale"))
		for _, child in ipairs(rawget(self, "__children")) do -- copie profonde, comme Instance:Clone()
			methods.Clone(child).Parent = c
		end
		return c
	end
	function methods.GetService(self, name)
		return services[name] or error("service factice inconnu : " .. tostring(name))
	end
	function methods.GetPlayers()
		local out = {}
		for i, p in ipairs(RT.players) do
			out[i] = p
		end
		return out
	end
	function methods.GetPlayerByUserId(_, uid)
		for _, p in ipairs(RT.players) do
			if rawget(p, "__props").UserId == uid then
				return p
			end
		end
		return nil
	end
	function methods.FireClient(self, player, ...)
		RT.fired[#RT.fired + 1] = { rawget(self, "__props").Name, player, ... }
		if RT.localPlayer ~= nil and player == RT.localPlayer then
			RT.fire(self, "OnClientEvent", ...)
		end
	end
	function methods.FireServer(self, ...)
		if RT.localPlayer ~= nil then
			RT.fire(self, "OnServerEvent", RT.localPlayer, ...)
		end
	end
	function methods.FireAllClients(self, ...)
		RT.fired[#RT.fired + 1] = { rawget(self, "__props").Name, "all", ... }
	end
	function methods.Kick(self, msg)
		RT.kicked[#RT.kicked + 1] = { rawget(self, "__props").Name, msg }
	end
	function methods.BindToClose(_, fn)
		RT.bindToClose[#RT.bindToClose + 1] = fn
	end
	function methods.AddTag(_, inst, tag)
		RT.tags[tag] = RT.tags[tag] or {}
		RT.tags[tag][inst] = true
	end
	function methods.HasTag(_, inst, tag)
		return RT.tags[tag] ~= nil and RT.tags[tag][inst] == true
	end
	function methods.GetTagged(_, tag)
		local out = {}
		for inst in pairs(RT.tags[tag] or {}) do
			out[#out + 1] = inst
		end
		return out
	end
	function methods.RemoveTag(_, inst, tag)
		if RT.tags[tag] then
			RT.tags[tag][inst] = nil
		end
	end

	proxyMeta.__index = function(t, k)
		if type(k) == "number" then
			return nil
		end
		local props = rawget(t, "__props")
		if props[k] ~= nil then
			return props[k]
		end
		if methods[k] then
			return methods[k]
		end
		if k == "Connect" or k == "Once" then
			return function(self, fn)
				RT.conns[self] = RT.conns[self] or {}
				table.insert(RT.conns[self], fn)
				return newProxy("connection", "Connection")
			end
		end
		if k == "Wait" then
			return function()
				return 0.03
			end
		end
		return child(t, k)
	end
	proxyMeta.__newindex = function(t, k, v)
		local props = rawget(t, "__props")
		if k == "Parent" then
			local old = props.Parent
			if old then
				removeChild(old, t)
			end
			props.Parent = v
			if isProxy(v) then
				addChild(v, t)
			end
			return
		end
		props[k] = v
	end
	proxyMeta.__call = function(self, ...)
		return newProxy(rawget(self, "__path") .. "()", "Unknown")
	end
	for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__idiv" }) do
		proxyMeta[op] = function(a)
			return isProxy(a) and a or newProxy("arith", "Unknown")
		end
	end
	proxyMeta.__unm = function(a)
		return a
	end
	proxyMeta.__lt = function()
		return false
	end
	proxyMeta.__le = function()
		return false
	end
	proxyMeta.__concat = function(a, b)
		return tostring(isProxy(a) and "<proxy>" or a) .. tostring(isProxy(b) and "<proxy>" or b)
	end
	proxyMeta.__len = function()
		return 0
	end
	proxyMeta.__tostring = function(t)
		return "<" .. rawget(t, "__path") .. ">"
	end
	proxyMeta.__pairs = function()
		return function()
			return nil
		end
	end

	newProxy = function(path, class)
		return setmetatable({ __path = path, __class = class, __props = { Name = path:match("[^%.]*$") }, __children = {}, __attrs = {} }, proxyMeta)
	end
	RT.newProxy = newProxy

	---------------------------------------------------------------- Instance.new, signaux
	RT.all = {}
	-- Valeurs par défaut NUMÉRIQUES réelles (jamais des proxies) pour les propriétés que le code compare ou additionne : sous Luau, comparer une
	-- table à un nombre lève une erreur (contrairement à Lua 5.x avec __lt), donc aucune comparaison ne doit toucher un proxy.
	local vecFn, cfFn = nil, nil
	local NUMERIC_DEFAULTS = { Transparency = 0, Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, Volume = 0.5, Rotation = 0, Value = 0, Magnitude = 0 }
	local function instance(class, name)
		local p = newProxy(name or class, class)
		RT.all[#RT.all + 1] = p
		if vecFn then
			local pr = rawget(p, "__props")
			pr.Position, pr.CFrame, pr.Size = vecFn(0, 0, 0), cfFn(0, 0, 0), vecFn(1, 1, 1)
			pr.AssemblyLinearVelocity, pr.Velocity = vecFn(0, 0, 0), vecFn(0, 0, 0)
			for k, v in pairs(NUMERIC_DEFAULTS) do
				pr[k] = v
			end
		end
		rawget(p, "__props").Name = name or class
		rawget(p, "__props").ClassName = class
		return p
	end
	local function service(name)
		local s = instance(name, name)
		services[name] = s
		return s
	end

	function RT.fire(obj, event, ...) -- déclenche les callbacks d'un signal : RT.fire(remote, "OnServerEvent", player, "action", arg)
		local sig = obj[event]
		for _, fn in ipairs(RT.conns[sig] or {}) do
			local co = coroutine.create(fn)
			RT.resume(co, ...)
		end
	end
	function RT.signalCount(obj, event)
		return #(RT.conns[obj[event]] or {})
	end

	---------------------------------------------------------------- ordonnanceur de tâches (temps virtuel)
	local alive = {}
	function RT.resume(co, ...)
		resumes = resumes + 1
		if resumes > MAX_RESUMES then
			error("garde-fou : plus de " .. MAX_RESUMES .. " reprises de coroutines (boucle d'attente virtuelle ?)")
		end
		if realClock() - startedAt > MAX_REAL_SECONDS then
			error("garde-fou : plus de " .. MAX_REAL_SECONDS .. " s de temps réel dans un runtime factice")
		end
		if opts.hook then
			pcall(opts.hook, co)
		end
		local ok, res = coroutine.resume(co, ...)
		if not ok then
			RT.errors[#RT.errors + 1] = tostring(res)
			return
		end
		if coroutine.status(co) == "suspended" then
			local wake = type(res) == "table" and res.wake or (RT.now + 0.03)
			RT.waiting[#RT.waiting + 1] = { co = co, wake = wake }
		end
	end
	local task = {}
	function task.spawn(fn, ...)
		local co = coroutine.create(fn)
		RT.resume(co, ...)
		return co
	end
	task.defer = task.spawn
	function task.wait(sec)
		coroutine.yield({ wake = RT.now + (sec or 0.03) })
		return sec or 0.03
	end
	function task.delay(sec, fn, ...)
		local args = { ... }
		local co = coroutine.create(function()
			task.wait(sec)
			fn(table.unpack(args))
		end)
		RT.resume(co)
		return co
	end
	function task.cancel() end
	RT.task = task

	function RT.step(seconds, dt)
		dt = dt or 0.05
		if seconds > 600 then
			error("garde-fou : RT.step(" .. tostring(seconds) .. ") dépasse 600 s virtuelles")
		end
		local target = RT.now + seconds
		while RT.now < target do
			RT.now = RT.now + dt
			local due, rest = {}, {}
			for _, w in ipairs(RT.waiting) do
				if w.wake <= RT.now then
					due[#due + 1] = w
				else
					rest[#rest + 1] = w
				end
			end
			RT.waiting = rest
			for _, w in ipairs(due) do
				RT.resume(w.co)
			end
			RT.fire(services.RunService, "Heartbeat", dt)
			for name, fn in pairs(RT.renderSteps) do -- fonctions liées par BindToRenderStep (caméra des cinématiques)
				local okR, errR = pcall(fn, dt)
				if not okR then
					RT.errors[#RT.errors + 1] = "RenderStep " .. tostring(name) .. " : " .. tostring(errR)
				end
			end
		end
	end

	---------------------------------------------------------------- services simulés
	local ds = {}
	local function dataStore()
		local store = { data = {} }
		local function copy(v)
			if type(v) ~= "table" then
				return v
			end
			local c = {}
			for k, x in pairs(v) do
				c[k] = copy(x)
			end
			return c
		end
		function store.UpdateAsync(_, key, fn)
			if RT.dataStoreFail then
				error(RT.dataStoreFail)
			end
			local new = fn(copy(store.data[key]))
			if new ~= nil then
				store.data[key] = copy(new)
			end
			return copy(store.data[key])
		end
		function store.GetAsync(_, key)
			return copy(store.data[key])
		end
		function store.SetAsync(_, key, v)
			if RT.dataStoreFail then
				error(RT.dataStoreFail)
			end
			store.data[key] = copy(v)
		end
		function store.GetSortedAsync(_, ascending, count)
			local list = {}
			for k, v in pairs(store.data) do
				list[#list + 1] = { key = k, value = v }
			end
			table.sort(list, function(a, b)
				local x, y = type(a.value) == "number" and a.value or 0, type(b.value) == "number" and b.value or 0
				if x ~= x then
					x = 0 -- NaN : comparaison cohérente (sinon tri instable)
				end
				if y ~= y then
					y = 0
				end
				if x ~= y then
					if ascending then
						return x < y
					end
					return x > y
				end
				return tostring(a.key) < tostring(b.key)
			end)
			local page = {}
			for i = 1, math.min(count or #list, #list) do
				page[i] = list[i]
			end
			return { GetCurrentPage = function() return page end }
		end
		return store
	end
	RT.dataStores = {}
	local dss = service("DataStoreService")
	rawget(dss, "__props").GetDataStore = function(_, name)
		RT.dataStores[name] = RT.dataStores[name] or dataStore()
		return RT.dataStores[name]
	end
	rawget(dss, "__props").GetOrderedDataStore = function(_, name)
		RT.dataStores[name] = RT.dataStores[name] or dataStore()
		return RT.dataStores[name]
	end

	local mss = service("MemoryStoreService")
	rawget(mss, "__props").GetHashMap = function(_, name)
		RT.memory = RT.memory or {}
		RT.memory[name] = RT.memory[name] or {}
		local map = RT.memory[name]
		return {
			GetAsync = function(_, k) return map[k] end,
			UpdateAsync = function(_, k, fn)
				local new = fn(map[k])
				if new ~= nil then
					map[k] = new
				end
				return new
			end,
			RemoveAsync = function(_, k) map[k] = nil end,
			ListItemsAsync = function()
				return { GetCurrentPage = function()
					local out = {}
					for k, v in pairs(map) do
						out[#out + 1] = { key = k, value = v }
					end
					return out
				end }
			end,
		}
	end

	local tps = service("TeleportService")
	rawget(tps, "__props").ReserveServerAsync = function()
		if RT.reserveFail then
			error(RT.reserveFail)
		end
		return "CODE-" .. tostring(#RT.teleports + 1)
	end
	rawget(tps, "__props").TeleportAsync = function(_, place, players, options)
		if RT.teleportFail then
			error(RT.teleportFail)
		end
		RT.teleports[#RT.teleports + 1] = { place = place, n = #players, options = options, players = players }
	end

	local http = service("HttpService")
	local guid = 0
	rawget(http, "__props").GenerateGUID = function()
		guid = guid + 1
		return string.format("GUID-%08d-%04d", guid * 7919, guid)
	end

	local players = service("Players")
	rawget(players, "__props").CharacterAutoLoads = true
	rawget(players, "__props").LocalPlayer = nil
	rawget(players, "__props").GetFriendsAsync = function()
		return { GetCurrentPage = function() return RT.friendsPage or {} end, IsFinished = true, AdvanceToNextPageAsync = function() end }
	end
	rawget(players, "__props").GetNameFromUserIdAsync = function(_, uid)
		return "Joueur" .. tostring(uid)
	end
	local run = service("RunService")
	rawget(run, "__props").IsStudio = function() return false end
	service("ReplicatedStorage")
	service("ServerScriptService")
	service("ServerStorage")
	service("Lighting")
	service("Debris")
	rawget(services.Debris, "__props").AddItem = function(_, obj, seconds)
		task.delay(tonumber(seconds) or 10, function()
			pcall(function()
				obj:Destroy() -- comme Roblox : l'objet est détruit après le délai
			end)
		end)
	end
	service("TweenService")
	service("CollectionService")
	service("ProximityPromptService")
	rawget(run, "__props").BindToRenderStep = function(_, name, _, fn)
		RT.renderSteps[name] = fn
	end
	rawget(run, "__props").UnbindFromRenderStep = function(_, name)
		RT.renderSteps[name] = nil
	end
	service("MarketplaceService")
	rawget(services.MarketplaceService, "__props").UserOwnsGamePassAsync = function() return false end
	service("MessagingService")
	local insert = service("InsertService")
	RT.loadedIds = {}
	rawget(insert, "__props").LoadAsset = function(_, id)
		RT.loadedIds[#RT.loadedIds + 1] = id
		if RT.loadAssetDelay then
			RT.task.wait(RT.loadAssetDelay) -- chargement lent : les modèles arrivent après l'entrée des joueurs
		end
		if RT.loadAssetFail then
			error(RT.loadAssetFail)
		end
		local model = RT.instance("Model", "Asset" .. tostring(id))
		if RT.assetSizes and RT.assetSizes[id] then
			rawset(model, "__fakeSize", RT.assetSizes[id]) -- taille brute du modèle Blender (peut être énorme)
		end
		for i, nm in ipairs({ "Corps__FF8800", "Detail__000000", "Socle" }) do
			local part = RT.instance("Part", nm)
			part.Parent = model
		end
		if RT.assetDecals and RT.assetDecals[id] then -- ID de décal : le modèle contient un Decal dont la Texture est l'URL d'image
			local decal = RT.instance("Decal", "Decal")
			rawget(decal, "__props").Texture = RT.assetDecals[id]
			decal.Parent = model
		end
		for _, nm in ipairs(RT.assetParts and RT.assetParts[id] or {}) do -- pièces animées par code (Pics, Lame...) d'un modèle précis
			local part = RT.instance("Part", nm)
			part.Parent = model
		end
		return model
	end
	service("StarterPlayer")
	service("PhysicsService")
	local pathfinding = service("PathfindingService")
	rawget(pathfinding, "__props").CreatePath = function()
		return {
			ComputeAsync = function()
				if RT.pathFail then
					error(RT.pathFail)
				end
			end,
			Status = "Enum.PathStatus.NoPath",
			GetWaypoints = function() return {} end,
		}
	end
	local cas = service("ContextActionService")
	RT.actions = {}
	rawget(cas, "__props").BindAction = function(_, name, fn)
		RT.actions[name] = fn
	end
	rawget(cas, "__props").UnbindAction = function() end
	service("SoundService")
	service("GuiService")
	service("UserInputService")
	local marketplaceMsg = services.MessagingService
	rawget(marketplaceMsg, "__props").SubscribeAsync = function() return newProxy("sub", "Connection") end
	rawget(marketplaceMsg, "__props").PublishAsync = function() end

	local ws = instance("Workspace", "Workspace")
	RT.workspace = ws
	local camera = instance("Camera", "Camera")
	rawget(camera, "__props").ViewportSize = { X = opts.viewport and opts.viewport[1] or 1280, Y = opts.viewport and opts.viewport[2] or 720 }
	rawget(ws, "__props").CurrentCamera = camera
	local game = instance("DataModel", "game")
	rawget(game, "__props").PlaceId = opts.placeId or 0
	rawget(game, "__props").JobId = "JOB-1"
	rawget(game, "__props").Workspace = ws
	services.Workspace = ws

	---------------------------------------------------------------- arbre des scripts (depuis les fichiers réels)
	local function scriptObject(cls, name, path, parent)
		local o = instance(cls, name)
		rawget(o, "__source") -- (champ brut absent : on garde la source dans une table à part)
		RT.sources = RT.sources or {}
		-- Lecture du fichier ICI (thread principal) et jamais dans une coroutine du runtime : sous Lune, fs.readFile est asynchrone et rend la main
		-- à l'ordonnanceur de Lune ; appelée depuis une coroutine créée ici, elle n'est jamais reprise (blocage à 0 % CPU).
		RT.sources[o] = { path = path, name = name, text = fs.readFile(path) }
		o.Parent = parent
		return o
	end
	local function loadDir(dir, parent, skipClasses)
		local main = nil
		for _, f in ipairs(fs.readDir(dir)) do
			if f:sub(-11) == ".server.lua" then
				main = scriptObject("Script", f:sub(1, -12), dir .. "/" .. f, parent)
			elseif f:sub(-11) == ".client.lua" then
				scriptObject("LocalScript", f:sub(1, -12), dir .. "/" .. f, parent)
			elseif f:sub(-4) == ".lua" then
				scriptObject("ModuleScript", f:sub(1, -5), dir .. "/" .. f, parent)
			end
		end
		return main
	end
	function RT.buildTree(srcRoot, hubSide)
		local rs, sss = services.ReplicatedStorage, services.ServerScriptService
		local shared = instance("Folder", "Shared")
		shared.Parent = rs
		loadDir(srcRoot .. "/ReplicatedStorage", shared)
		return loadDir(srcRoot .. (hubSide and "/Hub" or "") .. "/ServerScriptService", sss)
	end

	-- Scripts client : StarterPlayer.StarterPlayerScripts (objets rangés sous le même parent, comme dans Roblox). Retourne nom -> objet.
	function RT.buildClient(srcRoot)
		local folder = instance("Folder", "StarterPlayerScripts")
		folder.Parent = services.StarterPlayer
		local out = {}
		for _, f in ipairs(fs.readDir(srcRoot .. "/StarterPlayerScripts")) do
			if f:sub(-11) == ".client.lua" then
				out[f:sub(1, -12)] = scriptObject("LocalScript", f:sub(1, -12), srcRoot .. "/StarterPlayerScripts/" .. f, folder)
			elseif f:sub(-4) == ".lua" then
				out[f:sub(1, -5)] = scriptObject("ModuleScript", f:sub(1, -5), srcRoot .. "/StarterPlayerScripts/" .. f, folder)
			end
		end
		return out
	end

	function RT.setLocalPlayer(p)
		RT.localPlayer = p
		rawget(services.Players, "__props").LocalPlayer = p
		local gui = instance("PlayerGui", "PlayerGui")
		gui.Parent = p
	end

	local cache = {}
	local baseEnv
	function RT.require(obj)
		local src = RT.sources and RT.sources[obj]
		if not src then
			error("require : l'objet n'est pas un ModuleScript du dépôt (" .. tostring(obj) .. ")")
		end
		if cache[obj] == nil then
			cache[obj] = { RT.runScript(obj) }
		end
		return cache[obj][1]
	end

	function RT.runScript(obj)
		local src = RT.sources[obj]
		local env = {}
		for k, v in pairs(baseEnv) do
			env[k] = v
		end
		env.script = obj
		local chunk = luau.load(src.text, { debugName = src.name, environment = env })
		return chunk()
	end

	---------------------------------------------------------------- environnement des scripts
	local function vec(x, y, z)
		local v = { X = x, Y = y, Z = z }
		return setmetatable(v, {
			__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
			__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
			__mul = function(a, b)
				if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
				if type(a) == "number" then return vec(b.X * a, b.Y * a, b.Z * a) end
				return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
			end,
			__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end,
			__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end,
			__index = function(_, k)
				if k == "Magnitude" then return math.sqrt(x * x + y * y + z * z) end
				if k == "Unit" then
					local m = math.sqrt(x * x + y * y + z * z)
					return m > 0 and vec(x / m, y / m, z / m) or vec(0, 0, 0)
				end
				if k == "Dot" then return function(_, o) return x * o.X + y * o.Y + z * o.Z end end
				if k == "Lerp" then return function(_, o, t) return vec(x + (o.X - x) * t, y + (o.Y - y) * t, z + (o.Z - z) * t) end end
			end,
		})
	end
	local function cf(x, y, z)
		local c = { X = x or 0, Y = y or 0, Z = z or 0 }
		c.Position = vec(c.X, c.Y, c.Z)
		return setmetatable(c, {
			__mul = function(a, b)
				if b.Position then return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
				return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
			end,
			__add = function(a, b) return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
			__sub = function(a, b) return cf(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
			__index = function(t, k)
				if k == "LookVector" then return vec(0, 0, -1) end
				if k == "Rotation" then return t end
				if k == "PointToObjectSpace" or k == "PointToWorldSpace" or k == "VectorToWorldSpace" or k == "Lerp" or k == "ToObjectSpace" or k == "ToWorldSpace" or k == "Inverse" then
					return function(self, v) return v or self end
				end
			end,
		})
	end
	local function color(r, g, b)
		local c = { R = r, G = g, B = b }
		function c:Lerp(o, t) return color(r + (o.R - r) * t, g + (o.G - g) * t, b + (o.B - b) * t) end
		return c
	end
	local rngState = 99
	local enum = setmetatable({}, { __index = function(t, k)
		local sub = setmetatable({}, { __index = function(_, k2)
			if k == "RenderPriority" then
				return { Value = 100 + #k2 } -- les priorités de rendu sont lues avec .Value
			end
			return k .. "." .. k2
		end })
		rawset(t, k, sub)
		return sub
	end })
	RT.Enum = enum
	local function udim() return {} end
	baseEnv = {
		game = game, workspace = ws, task = task, require = function(o) return RT.require(o) end,
		Instance = { new = function(class) return instance(class) end },
		Vector3 = { new = function(x, y, z) return vec(x or 0, y or 0, z or 0) end, zero = vec(0, 0, 0), one = vec(1, 1, 1), yAxis = vec(0, 1, 0) },
		Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end },
		CFrame = {
			new = function(x, y, z)
				if type(x) == "table" and x.X then return cf(x.X, x.Y, x.Z) end
				return cf(x, y, z)
			end,
			Angles = function() return cf(0, 0, 0) end,
			lookAt = function(from, to) -- REFONTE (lot 2) : garde la direction horizontale visée (empreinte tournée dans le test de z-fighting)
				local c = cf(from.X, from.Y, from.Z)
				if type(to) == "table" and to.X then
					rawset(c, "LookFlat", { to.X - from.X, to.Z - from.Z })
				end
				return c
			end,
			fromEulerAnglesXYZ = function() return cf(0, 0, 0) end,
		},
		Color3 = { fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end, new = color, fromHSV = function() return color(1, 1, 1) end },
		UDim2 = { fromOffset = udim, fromScale = udim, new = udim }, UDim = { new = udim },
		Enum = enum, TweenInfo = { new = function() return {} end },
		ColorSequence = { new = function() return {} end }, NumberRange = { new = function() return {} end },
		NumberSequence = { new = function() return {} end }, NumberSequenceKeypoint = { new = function() return {} end }, ColorSequenceKeypoint = { new = function() return {} end },
		Random = { new = function(seed)
			local s = seed or 1
			local r = {}
			function r:NextNumber(a, b)
				s = (s * 16807) % 2147483647
				return (a or 0) + (s / 2147483647) * ((b or 1) - (a or 0))
			end
			function r:NextInteger(a, b) return math.floor(self:NextNumber(a, b + 1)) end
			return r
		end },
		typeof = function(v) return isProxy(v) and "Instance" or type(v) end,
		print = function(...)
			local t = {}
			for i = 1, select("#", ...) do
				t[#t + 1] = tostring((select(i, ...)))
			end
			RT.prints[#RT.prints + 1] = table.concat(t, " ")
		end,
		warn = function(...)
			local t = {}
			for i = 1, select("#", ...) do
				t[#t + 1] = tostring((select(i, ...)))
			end
			RT.warns[#RT.warns + 1] = table.concat(t, " ")
		end,
		os = { clock = function() return RT.now end, time = function() return 1700000000 + math.floor(RT.now) end, date = os.date },
		tick = function() return RT.now end,
		table = setmetatable({ clone = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end }, { __index = table }),
		math = setmetatable({ clamp = function(x, a, b) return math.max(a, math.min(b, x)) end, round = function(x) return math.floor(x + 0.5) end }, { __index = math }),
	}
	RT.env = baseEnv

	---------------------------------------------------------------- joueurs
	function RT.addPlayer(name, userId, joinData)
		local p = instance("Player", name)
		local pr = rawget(p, "__props")
		pr.UserId, pr.DisplayName = userId, name
		pr.GetJoinData = function() return { TeleportData = joinData } end
		pr.LoadCharacterAsync = function(self)
			local char = instance("Model", name)
			local root = instance("Part", "HumanoidRootPart")
			rawget(root, "__props").Position = vec(0, 5, 40)
			rawget(root, "__props").CFrame = cf(0, 5, 40)
			rawget(root, "__props").AssemblyLinearVelocity = vec(0, 0, 0)
			root.Parent = char
			local hum = instance("Humanoid", "Humanoid")
			rawget(hum, "__props").Health = 100
			rawget(hum, "__props").WalkSpeed = 16
			hum.Parent = char
			char.Parent = ws
			pr.Character = char
			RT.fire(p, "CharacterAdded", char)
			RT.characterLoads = (RT.characterLoads or 0) + 1
		end
		pr.GetFriendsOnline = function() return {} end
		RT.players[#RT.players + 1] = p
		p.Parent = players
		RT.fire(players, "PlayerAdded", p)
		return p
	end
	function RT.removePlayer(p)
		for i, q in ipairs(RT.players) do
			if q == p then
				table.remove(RT.players, i)
				break
			end
		end
		RT.fire(services.Players, "PlayerRemoving", p)
		p.Parent = nil
	end

	-- Auto-vérification : l'environnement factice est-il réellement appliqué par luau.load ? Sinon (moteur qui ignore ou fusionne mal
	-- `environment`), les scripts lanceraient de VRAIES tâches (task.spawn / task.wait réels) qui retiendraient le processus : les suites
	-- qui dépendent du runtime doivent alors être sautées et le signaler.
	function RT.selfCheck()
		local ok, res = pcall(function()
			local probe = luau.load("return task, warn, require, os", { debugName = "probe", environment = RT.env })
			local t, w, r, o = probe()
			return t == RT.task and w == RT.env.warn and o == RT.env.os
		end)
		return ok and res == true
	end

	vecFn, cfFn = vec, cf
	RT.game = game
	RT.services = services
	RT.instance = instance
	RT.vec = vec
	RT.cf = cf
	return RT
end

return Fake
