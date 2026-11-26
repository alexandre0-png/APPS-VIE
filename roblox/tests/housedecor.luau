--!nocheck
-- Tests du lot 8B-meubles (décor intérieur des maisons) : données (HouseDecorData) et logique de HouseDecor.apply, avec un faux Roblox
-- (Instance, CFrame, Vector3, Enum, typeof, InsertService). Le faux ignore la rotation des CFrame : on teste positions, cumul, budget,
-- repli, cache et idempotence, PAS l'orientation. Forme : `return function(env) ... end`, env = { check, suite, luau, fs } (tests/run_housedecor.py).
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local EPS = 1e-6

	---------------------------------------------------------------- faux Roblox
	local V = {}
	V.__index = V
	local function vec(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, V)
	end
	V.__add = function(a, b)
		return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	V.__sub = function(a, b)
		return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	local function scaleV(v, k)
		return vec(v.X * k, v.Y * k, v.Z * k)
	end

	local CF = {}
	CF.__index = CF
	local function cframe(pos)
		return setmetatable({ Position = pos }, CF)
	end
	-- Rotation ignorée : le produit de CFrame ajoute les positions (suffisant pour tester les positions).
	CF.__mul = function(a, b)
		return cframe(a.Position + b.Position)
	end
	local CFrameFake = {}
	CFrameFake.new = function(a, b, c)
		if type(a) == "table" then
			return cframe(vec(a.X, a.Y, a.Z))
		end
		return cframe(vec(a, b, c))
	end
	CFrameFake.Angles = function()
		return cframe(vec(0, 0, 0))
	end

	local ISA = {
		Part = { Part = true, BasePart = true },
		MeshPart = { MeshPart = true, BasePart = true },
		Model = { Model = true },
		Folder = { Folder = true },
	}
	local function isA(obj, cls)
		local t = ISA[obj.ClassName]
		return t ~= nil and t[cls] == true
	end

	local Methods = {}
	local Inst = {}
	Inst.__index = function(t, k)
		if k == "Parent" then
			return rawget(t, "_parent")
		end
		return Methods[k]
	end
	Inst.__newindex = function(t, k, v)
		if k == "Parent" then
			local old = rawget(t, "_parent")
			if old ~= nil then
				local kids = old._children
				for i = #kids, 1, -1 do
					if kids[i] == t then
						table.remove(kids, i)
					end
				end
			end
			rawset(t, "_parent", v)
			if v ~= nil then
				v._children[#v._children + 1] = t
			end
		else
			rawset(t, k, v)
		end
	end
	local function newInst(class)
		return setmetatable({ ClassName = class, Name = class, _children = {}, _attrs = {}, _isInst = true }, Inst)
	end
	Methods.IsA = function(self, cls)
		return isA(self, cls)
	end
	Methods.SetAttribute = function(self, k, v)
		self._attrs[k] = v
	end
	Methods.GetAttribute = function(self, k)
		return self._attrs[k]
	end
	Methods.GetChildren = function(self)
		local out = {}
		for i, c in ipairs(self._children) do
			out[i] = c
		end
		return out
	end
	Methods.FindFirstChild = function(self, name)
		for _, c in ipairs(self._children) do
			if c.Name == name then
				return c
			end
		end
		return nil
	end
	Methods.FindFirstChildWhichIsA = function(self, cls)
		for _, c in ipairs(self._children) do
			if isA(c, cls) then
				return c
			end
		end
		return nil
	end
	Methods.Destroy = function(self)
		if rawget(self, "_destroyed") then
			return
		end
		rawset(self, "_destroyed", true)
		local kids = Methods.GetChildren(self)
		for _, c in ipairs(kids) do
			Methods.Destroy(c)
		end
		self.Parent = nil
	end
	Methods.Clone = function(self)
		local c = newInst(self.ClassName)
		for k, v in pairs(self) do
			if k ~= "_children" and k ~= "_parent" and k ~= "_attrs" and k ~= "_pivot" and k ~= "_destroyed" then
				rawset(c, k, v)
			end
		end
		for k, v in pairs(self._attrs) do
			c._attrs[k] = v
		end
		for _, child in ipairs(self._children) do
			local cc = Methods.Clone(child)
			cc.Parent = c
		end
		return c
	end
	Methods.GetPivot = function(self)
		return self._pivot or cframe(vec(0, 0, 0))
	end
	Methods.PivotTo = function(self, cf)
		self._pivot = cf
	end
	Methods.GetExtentsSize = function(self)
		return self._ext or vec(0, 0, 0)
	end
	Methods.ScaleTo = function(self, k)
		if self._ext then
			self._ext = scaleV(self._ext, k)
		end
		if self._bbOff then
			self._bbOff = scaleV(self._bbOff, k)
		end
		self._scaleK = k
		self._scaleCalls = (self._scaleCalls or 0) + 1
	end
	-- Centre de la boîte englobante = pivot + décalage (le pivot n'est pas au centre, comme un vrai modèle).
	Methods.GetBoundingBox = function(self)
		local p = Methods.GetPivot(self).Position
		local off = self._bbOff or vec(0, 0, 0)
		return cframe(p + off), (self._ext or vec(0, 0, 0))
	end

	local function typeofFake(v)
		if type(v) == "table" and rawget(v, "_isInst") then
			return "Instance"
		end
		return type(v)
	end
	local enumFake = {
		Material = setmetatable({}, { __index = function(_, k)
			return "Mat:" .. k
		end }),
		PartType = { Block = "Block", Cylinder = "Cylinder", Ball = "Ball" },
	}

	-- Modèles source : chaque ID a un modèle de 6 x 9 x 4 studs, pivot décalé de (1, 2, 0) (le centrage doit corriger ce décalage).
	local function newInsertService()
		local svc = { calls = {}, fail = {}, noModel = {}, onLoad = nil }
		function svc:LoadAsset(id)
			self.calls[id] = (self.calls[id] or 0) + 1
			if self.onLoad then
				self.onLoad(id)
			end
			if self.fail[id] then
				error("LoadAsset : asset introuvable " .. tostring(id))
			end
			local container = newInst("Model")
			if self.noModel[id] then
				return container
			end
			local m = newInst("Model")
			m._ext = vec(6, 9, 4)
			m._bbOff = vec(1, 2, 0)
			m.Parent = container
			return container
		end
		return svc
	end

	local moduleEnv = {
		Instance = { new = newInst },
		Vector3 = { new = vec },
		CFrame = CFrameFake,
		Color3 = { fromRGB = function(r, g, b)
			return { R = r / 255, G = g / 255, B = b / 255 }
		end },
		Enum = enumFake,
		typeof = typeofFake,
	}

	local Data = luau.load(fs.readFile("roblox/src/ReplicatedStorage/HouseDecorData.lua"), { debugName = "HouseDecorData" })()
	local HouseDecor = luau.load(fs.readFile("roblox/src/ServerScriptService/HouseDecor.lua"), { debugName = "HouseDecor", environment = moduleEnv })()

	-- IDs attendus : sections « Lot 18 » et « Lot 19 » de Assets-crees-fresh.md (24 modèles).
	local EXPECTED = {
		books_stack = 75235784527086, branch_chandelier = 81736669133938, clock_wall = 95777609232622,
		coffee_maker = 112911908053394, oven_stove = 87903538253499, plant_pot_a = 86148706778494,
		plant_pot_b = 121510089986414, rug_round = 90438557881098, stool_side = 134719337565962,
		toaster = 139790299453025, vase_big = 123819297063677, coffee_table_round = 112871489043894,
		speaker_pair = 120384220519044, wall_lamp = 73563604591192, bed_double = 73424212171108,
		dining_set = 104316845432310, fridge_big = 131419976234083, shelf_drawers = 139964774272115,
		desk_study = 102305030833988, kitchen_run = 79053277599844, kitchen_upper = 111169784434252,
		sofa_corner = 107495439971094, tv_unit_stepped = 108277232894442, wardrobe_tall = 117500900219054,
	}
	local HOUSE_CF = cframe(vec(50, 0, -20))

	local function newHouse()
		local h = newInst("Model")
		h.Name = "House"
		h._pivot = HOUSE_CF
		return h
	end
	local function cfgOf(svc, useAssets)
		return { data = Data, insertService = svc or false, cache = {}, useAssets = useAssets }
	end
	local function folderOf(h)
		return h:FindFirstChild("HouseDecor")
	end
	local function kidsOf(h)
		local f = folderOf(h)
		if f == nil then
			return {}
		end
		return f:GetChildren()
	end
	local function idsOf(h)
		local out = {}
		for _, c in ipairs(kidsOf(h)) do
			out[#out + 1] = c:GetAttribute("HouseDecorId")
		end
		return out
	end
	local function idSet(list)
		local s = {}
		for _, it in ipairs(list) do
			s[it.id] = true
		end
		return s
	end
	local function countKeys(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end
	local function footprint(it)
		local hx, hz = it.size[1] / 2, it.size[3] / 2
		if it.rot % 180 == 90 then
			hx, hz = hz, hx
		end
		return it.pos[1] - hx, it.pos[1] + hx, it.pos[3] - hz, it.pos[3] + hz
	end
	local function overlaps(a, b)
		local ax0, ax1, az0, az1 = footprint(a)
		local bx0, bx1, bz0, bz1 = footprint(b)
		local ay0, ay1 = a.pos[2], a.pos[2] + a.size[2]
		local by0, by1 = b.pos[2], b.pos[2] + b.size[2]
		return ax0 < bx1 - EPS and bx0 < ax1 - EPS and az0 < bz1 - EPS and bz0 < az1 - EPS and ay0 < by1 - EPS and by0 < ay1 - EPS
	end
	local function near(a, b)
		return math.abs(a - b) < EPS
	end

	---------------------------------------------------------------- 1. données
	suite("Données : 8 niveaux, 24 modèles, IDs des lots 18 et 19")
	check("8 niveaux (LEVEL_COUNT = 8 = Config.BASE_LEVELS2)", #Data.LEVELS == 8 and Data.LEVEL_COUNT == 8)
	local all, seenId, seenAsset, dup = {}, {}, {}, false
	for lv = 1, #Data.LEVELS do
		for _, it in ipairs(Data.LEVELS[lv]) do
			all[#all + 1] = it
			if seenId[it.id] or seenAsset[it.assetId] then
				dup = true
			end
			seenId[it.id] = lv
			seenAsset[it.assetId] = true
		end
	end
	check("24 objets au total, sans ID ni assetId en double", #all == 24 and not dup)
	local idsMatch = countKeys(EXPECTED) == 24
	for id, aid in pairs(EXPECTED) do
		if seenId[id] == nil then
			idsMatch = false
		else
			for _, it in ipairs(Data.LEVELS[seenId[id]]) do
				if it.id == id and it.assetId ~= aid then
					idsMatch = false
				end
			end
		end
	end
	check("les 24 IDs correspondent exactement aux lots 18 et 19", idsMatch)
	local newOk = true
	for lv = 1, 8 do
		local n = #Data.LEVELS[lv]
		if n < 1 or n > Data.MAX_NEW_PER_LEVEL then
			newOk = false
		end
	end
	check("au plus 12 objets nouveaux par niveau (et au moins 1)", newOk)
	local fieldsOk, boundsOk, rotOk, fbOk = true, true, true, true
	for _, it in ipairs(all) do
		local s, p = it.size, it.pos
		if type(s) ~= "table" or #s ~= 3 or s[1] <= 0 or s[2] <= 0 or s[3] <= 0 then
			fieldsOk = false
		end
		if type(p) ~= "table" or #p ~= 3 or p[2] < 0 or p[2] + s[2] > 16 then
			fieldsOk = false
		end
		if type(it.parts) ~= "number" or it.parts < 1 or it.parts ~= math.floor(it.parts) then
			fieldsOk = false
		end
		if type(it.rot) ~= "number" or it.rot < 0 or it.rot >= 360 then
			rotOk = false
		end
		local x0, x1, z0, z1 = footprint(it)
		if x0 < -Data.REACH - EPS or x1 > Data.REACH + EPS or z0 < -Data.REACH - EPS or z1 > Data.REACH + EPS then
			boundsOk = false
		end
		local fb = it.fallback
		if type(fb) ~= "table" or (fb.shape ~= "Block" and fb.shape ~= "Cylinder") or type(fb.material) ~= "string" or type(fb.color) ~= "table" or #fb.color ~= 3 then
			fbOk = false
		else
			for c = 1, 3 do
				if type(fb.color[c]) ~= "number" or fb.color[c] < 0 or fb.color[c] > 255 then
					fbOk = false
				end
			end
		end
	end
	check("tailles, positions et budgets par objet bien formés", fieldsOk)
	check("rotations Y dans [0, 360)", rotOk)
	check("emprise de chaque objet dans REACH (|x|, |z| <= 18)", boundsOk)
	check("repli : forme Block ou Cylinder, couleur RGB 0-255, matière", fbOk)

	suite("Données : cumul, budget de Parts, chevauchements")
	local prefixOk, growOk = true, true
	local prev = {}
	for n = 1, 8 do
		local cur = Data.unlocked(n)
		if #cur ~= countKeys(idSet(cur)) then
			prefixOk = false
		end
		for i, it in ipairs(prev) do
			if cur[i] == nil or cur[i].id ~= it.id then
				prefixOk = false
			end
		end
		if #cur < #prev then
			growOk = false
		end
		prev = cur
	end
	check("unlocked(n) garde l'ordre et reprend tout le niveau précédent (cumul)", prefixOk and growOk)
	check("unlocked(8) = 24 objets, unlocked(1) = 3", #Data.unlocked(8) == 24 and #Data.unlocked(1) == 3)
	check("niveau hors bornes ou non numérique : borné à 1..8, jamais d'erreur", #Data.unlocked(0) == 3 and #Data.unlocked(-4) == 3 and #Data.unlocked(99) == 24 and #Data.unlocked("x") == 3 and #Data.unlocked(0 / 0) == 3)
	local budgetOk = true
	for n = 1, 8 do
		if Data.budget(n) > Data.PARTS_BUDGET then
			budgetOk = false
		end
	end
	check("budget de Parts <= 150 à chaque niveau", budgetOk and Data.budget(8) <= Data.PARTS_BUDGET)
	check("budget du niveau 8 = 136 Parts réservées (14 petits x 4 + 10 gros x 8)", Data.budget(8) == 136)
	local overlapFree = true
	local firstClash = ""
	for n = 1, 8 do
		local list = Data.unlocked(n)
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				if not (a.flat or b.flat) and overlaps(a, b) then
					overlapFree = false
					firstClash = a.id .. " / " .. b.id .. " (niveau " .. n .. ")"
				end
			end
		end
	end
	check("aucun chevauchement 3D entre objets d'un même décor (hors tapis) : " .. firstClash, overlapFree)

	---------------------------------------------------------------- 2. logique de apply (repli, sans service)
	suite("apply : repli procédural, cumul, idempotence, descente de niveau")
	local h1 = newHouse()
	local r1 = HouseDecor.apply(h1, 1, cfgOf(nil))
	check("niveau 1 : 3 objets placés en repli, aucun chargement", r1.placed == 3 and r1.fallback == 3 and r1.loaded == 0 and #idsOf(h1) == 3)
	check("dossier HouseDecor porte le niveau appliqué", folderOf(h1):GetAttribute("HouseDecorLevel") == 1)
	local before = {}
	for _, c in ipairs(kidsOf(h1)) do
		before[c] = true
	end
	local r2 = HouseDecor.apply(h1, 5, cfgOf(nil))
	check("montée 1 -> 5 : 13 ajoutés, 3 conservés, 0 retiré (cumul 3+3+3+3+4 = 16)", r2.placed == 13 and r2.kept == 3 and r2.removed == 0 and #idsOf(h1) == 16)
	local stillThere = true
	for c in pairs(before) do
		if c.Parent ~= folderOf(h1) then
			stillThere = false
		end
	end
	check("montée : les objets des niveaux précédents sont les mêmes instances (rien retiré)", stillThere)
	local r3 = HouseDecor.apply(h1, 5, cfgOf(nil))
	check("idempotence : même niveau rappelé -> 0 placé, 16 conservés, 0 retiré", r3.placed == 0 and r3.kept == 16 and r3.removed == 0 and #idsOf(h1) == 16)
	local r4 = HouseDecor.apply(h1, 8, cfgOf(nil))
	check("niveau 8 : 8 ajoutés, total 24", r4.placed == 8 and #idsOf(h1) == 24)
	check("report.parts = budget du niveau (136)", r4.parts == 136 and r4.parts <= Data.PARTS_BUDGET)
	local r5 = HouseDecor.apply(h1, 2, cfgOf(nil))
	check("descente 8 -> 2 : 18 retirés, 6 conservés (nettoyage propre)", r5.removed == 18 and r5.kept == 6 and r5.placed == 0 and #idsOf(h1) == 6)
	local want2 = idSet(Data.unlocked(2))
	local okDown = true
	for _, id in ipairs(idsOf(h1)) do
		if not want2[id] then
			okDown = false
		end
	end
	check("après descente, seuls les objets du niveau 2 restent", okDown)

	suite("apply : cumul vérifié pour chaque niveau 1..8 (repli)")
	local cumulOk = true
	for n = 1, 8 do
		local h = newHouse()
		HouseDecor.apply(h, n, cfgOf(nil))
		local want = Data.unlocked(n)
		local ids = idsOf(h)
		if #ids ~= #want then
			cumulOk = false
		end
		local set = idSet(want)
		for _, id in ipairs(ids) do
			if not set[id] then
				cumulOk = false
			end
		end
		for _, it in ipairs(want) do
			local found = h:FindFirstChild("HouseDecor"):FindFirstChild("HD_" .. it.id)
			if found == nil then
				cumulOk = false
			end
		end
	end
	check("niveau n : exactement les objets de unlocked(n), un par ID", cumulOk)

	suite("apply : niveaux invalides bornés, clear, nouvelle maison")
	local hg = newHouse()
	HouseDecor.apply(hg, "x", cfgOf(nil))
	check("niveau texte -> 1", folderOf(hg):GetAttribute("HouseDecorLevel") == 1)
	HouseDecor.apply(hg, 0 / 0, cfgOf(nil))
	check("niveau NaN -> 1", folderOf(hg):GetAttribute("HouseDecorLevel") == 1)
	HouseDecor.apply(hg, 2.9, cfgOf(nil))
	check("niveau 2.9 -> 2 (partie entière)", folderOf(hg):GetAttribute("HouseDecorLevel") == 2 and #idsOf(hg) == 6)
	HouseDecor.apply(hg, math.huge, cfgOf(nil))
	check("niveau infini -> 8", folderOf(hg):GetAttribute("HouseDecorLevel") == 8 and #idsOf(hg) == 24)
	HouseDecor.apply(hg, -4, cfgOf(nil))
	check("niveau négatif -> 1 (descente propre)", folderOf(hg):GetAttribute("HouseDecorLevel") == 1 and #idsOf(hg) == 3)

	local hj = newHouse()
	HouseDecor.apply(hj, 3, cfgOf(nil))
	local junk = newInst("Part")
	junk.Name = "Intrus"
	junk.Parent = folderOf(hj)
	local stray = newInst("Part")
	stray.Name = "HD_inconnu"
	stray:SetAttribute("HouseDecorId", "objet_inexistant")
	stray.Parent = folderOf(hj)
	local rj = HouseDecor.apply(hj, 3, cfgOf(nil))
	check("objets sans ID ou ID inconnu : retirés, décor du niveau intact", rj.removed == 2 and #idsOf(hj) == 9)

	HouseDecor.clear(hj)
	check("clear : dossier HouseDecor supprimé", folderOf(hj) == nil)
	local rc = HouseDecor.apply(hj, 3, cfgOf(nil))
	check("après clear, réapplication : 9 objets à nouveau", rc.placed == 9 and #idsOf(hj) == 9)

	local hn = newHouse()
	local hOld = newHouse()
	HouseDecor.apply(hOld, 5, cfgOf(nil))
	HouseDecor.apply(hn, 6, cfgOf(nil))
	check("nouvelle maison (échange de niveau) : dossier créé, ancienne maison intacte", #idsOf(hn) == 19 and #idsOf(hOld) == 16)

	---------------------------------------------------------------- 3. chargement, cache, placement
	suite("apply : chargement InsertService, centrage, mise à l'échelle")
	local svc = newInsertService()
	local cfgA = cfgOf(svc)
	local hA = newHouse()
	local rA = HouseDecor.apply(hA, 8, cfgA)
	check("niveau 8 chargé : 24 modèles, 0 repli", rA.loaded == 24 and rA.fallback == 0 and rA.placed == 24)
	local oneCall = true
	for _, aid in pairs(EXPECTED) do
		if svc.calls[aid] ~= 1 then
			oneCall = false
		end
	end
	check("LoadAsset appelé une fois par ID", oneCall)
	local fitOk, centreOk, tightOk = true, true, true
	for _, c in ipairs(kidsOf(hA)) do
		local it
		for _, cand in ipairs(all) do
			if cand.id == c:GetAttribute("HouseDecorId") then
				it = cand
			end
		end
		if not c:IsA("Model") or it == nil then
			fitOk = false
		else
			local bb, ext = c:GetBoundingBox()
			if ext.X > it.size[1] + EPS or ext.Y > it.size[2] + EPS or ext.Z > it.size[3] + EPS then
				fitOk = false
			end
			local ratio = math.max(ext.X / it.size[1], ext.Y / it.size[2], ext.Z / it.size[3])
			if not near(ratio, 1) then
				tightOk = false
			end
			local tx = 50 + it.pos[1]
			local ty = it.pos[2] + it.size[2] / 2
			local tz = -20 + it.pos[3]
			if not (near(bb.Position.X, tx) and near(bb.Position.Y, ty) and near(bb.Position.Z, tz)) then
				centreOk = false
			end
		end
	end
	check("modèle chargé : tient dans la boîte cible (mise à l'échelle uniforme)", fitOk)
	check("modèle chargé : tangent à une dimension de la boîte (k maximal)", tightOk)
	check("modèle chargé : centre de la boîte = maison + position + demi-hauteur", centreOk)

	local rB = HouseDecor.apply(newHouse(), 8, cfgA)
	check("cache : même service, autre maison -> aucun nouvel appel LoadAsset", rB.loaded == 24 and oneCall)
	local okCalls = true
	for _, aid in pairs(EXPECTED) do
		if svc.calls[aid] ~= 1 then
			okCalls = false
		end
	end
	check("cache : chaque ID toujours appelé une seule fois", okCalls)

	suite("apply : repli si LoadAsset échoue (échec mémorisé)")
	local svcF = newInsertService()
	local wardrobeId = EXPECTED.wardrobe_tall
	local ovenId = EXPECTED.oven_stove
	svcF.fail[wardrobeId] = true
	svcF.noModel[ovenId] = true
	local cfgF = cfgOf(svcF)
	local hF = newHouse()
	local rF = HouseDecor.apply(hF, 8, cfgF)
	check("échec LoadAsset et conteneur sans modèle -> 2 replis, 22 chargés", rF.fallback == 2 and rF.loaded == 22)
	local wardrobe = hF:FindFirstChild("HouseDecor"):FindFirstChild("HD_wardrobe_tall")
	check("repli : une Part Block de la taille et couleur de l'objet", wardrobe ~= nil and wardrobe.ClassName == "Part" and wardrobe.Shape == "Block" and wardrobe.Size.X == 5 and wardrobe.Size.Y == 8 and wardrobe.Size.Z == 2.5)
	check("repli : couleur RGB de la fiche (110, 80, 55)", wardrobe ~= nil and near(wardrobe.Color.R, 110 / 255) and near(wardrobe.Color.B, 55 / 255))
	local plant = nil
	local hP = newHouse()
	svcF.fail[EXPECTED.plant_pot_a] = true
	HouseDecor.apply(hP, 1, cfgOf(svcF)) -- cache neuf : le pot n'a pas encore été chargé avec succès
	plant = hP:FindFirstChild("HouseDecor"):FindFirstChild("HD_plant_pot_a")
	check("repli cylindre : Shape Cylinder, hauteur sur X, diamètre sur Y et Z", plant ~= nil and plant.Shape == "Cylinder" and near(plant.Size.X, 2.4) and near(plant.Size.Y, 2.2) and near(plant.Size.Z, 2.2))
	local callsBefore = svcF.calls[wardrobeId]
	HouseDecor.apply(newHouse(), 8, cfgF)
	check("échec mémorisé : pas de nouvelle tentative pour le même ID", svcF.calls[wardrobeId] == callsBefore and callsBefore == 1)
	check("l'échec ne fait pas planter le niveau (24 objets présents)", #idsOf(hF) == 24)

	suite("apply : modèles désactivés, service absent")
	local svcD = newInsertService()
	local rD = HouseDecor.apply(newHouse(), 8, cfgOf(svcD, false))
	check("useAssets = false : aucun LoadAsset, 24 replis", countKeys(svcD.calls) == 0 and rD.fallback == 24 and rD.loaded == 0)
	local rNo = HouseDecor.apply(newHouse(), 8, cfgOf(nil))
	check("service absent : repli complet sans erreur", rNo.fallback == 24)
	local hOff = newHouse()
	local cfgOff = cfgOf(nil)
	cfgOff.offset = { 3, 1.6, -5 }
	HouseDecor.apply(hOff, 1, cfgOff)
	local rug = hOff:FindFirstChild("HouseDecor"):FindFirstChild("HD_rug_round")
	check("offset : origine décalée (3, 1,6, -5) : tapis centré en (53, 1,7, -25)", rug ~= nil and near(rug.CFrame.Position.X, 53) and near(rug.CFrame.Position.Y, 1.7) and near(rug.CFrame.Position.Z, -25))

	suite("apply : garde contre la course pendant le chargement")
	local svcR = newInsertService()
	local hR = newHouse()
	svcR.onLoad = function(id)
		if id == EXPECTED.wardrobe_tall then
			local f = hR:FindFirstChild("HouseDecor")
			local intrus = newInst("Part")
			intrus.Name = "HD_wardrobe_tall"
			intrus:SetAttribute("HouseDecorId", "wardrobe_tall")
			intrus.Parent = f
		end
	end
	local rR = HouseDecor.apply(hR, 8, cfgOf(svcR))
	local nWardrobe = 0
	for _, id in ipairs(idsOf(hR)) do
		if id == "wardrobe_tall" then
			nWardrobe = nWardrobe + 1
		end
	end
	check("objet déjà placé pendant un yield : pas de doublon", nWardrobe == 1 and #idsOf(hR) == 24 and rR.placed == 23)

	return nil
end
