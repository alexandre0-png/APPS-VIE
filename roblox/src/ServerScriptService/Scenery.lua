-- ModuleScript : ServerScriptService/Scenery
-- Décor de la carte (REFONTE lot 2 : carte 700 x 500, géométrie de MapGeo) : place du marché, territoires, chemins, eau, château, arène, relief,
-- secrets. Tout en Parts de base ; les outils de construction de Builder sont injectés (h.part, h.ball, h.tree, h.torch, h.sign). Chaque fonction
-- retourne le nombre de Parts créées (budget mobile).
local CollectionService = game:GetService("CollectionService")

local Scenery = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function cyl(h, props, parent, diameter, height, pos, rotY)
	-- cylindre à axe vertical : height = hauteur, diameter = diamètre
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(pos) * CFrame.Angles(0, rotY or 0, math.pi / 2)
	return h.part(props, parent)
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

local function emitter(parent, color, rate, speed, life, size, accel)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = accel or Vector3.new(0, 0, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 0.8
	e.Parent = parent
	return e
end

---------------------------------------------------------------- Château : 5 salles à pièges, entrée, coffre final, tableau des temps
-- Construit le donjon décrit par Castle (géométrie pure). Retourne (monde, nombre de Parts) : monde.rooms[r] = { spikes = { {base, spikes} }, blades = {...},
-- balls = {...}, door }, monde.chest (Part), monde.entry (Part), monde.board (TextLabel). Les pièges sont animés côté serveur (voir Main).
-- REFONTE (lot 2) : `entry` (facultatif, Vector3) = porte du donjon sur le plateau du château ; l'entrée et le tableau des temps y sont posés.
function Scenery.castle(h, parent, Castle, entry)
	local world = { rooms = {} }
	local n = 0
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	local W, L = Castle.ROOM_WIDTH, Castle.ROOM_LENGTH
	for r = 1, Castle.ROOMS do
		local room = Castle.room(r)
		local cx, cz = Castle.toWorld(r, 0, L / 2)
		local rec = { spikes = {}, blades = {}, balls = {}, knights = {} }
		world.rooms[r] = rec
		P({ Name = "CastleFloor" .. r, Size = Vector3.new(W, 1, L), Position = Vector3.new(cx, -0.5, cz), Color = r % 2 == 0 and rgb(122, 118, 132) or rgb(104, 100, 114), Material = Enum.Material.Slate })
		for _, sx in ipairs({ -1, 1 }) do
			P({ Name = "CastleWall", Size = Vector3.new(2, 14, L), Position = Vector3.new(cx + sx * (W / 2 + 1), 7, cz), Color = rgb(96, 92, 106), Material = Enum.Material.Slate })
		end
		-- liseré de salle (couleur de difficulté : de vert à rouge) et torches
		local heat = (r - 1) / (Castle.ROOMS - 1)
		local ex, ez = Castle.toWorld(r, 0, 0.6)
		P({ Name = "CastleStartLine", Size = Vector3.new(W, 0.15, 1.2), Position = Vector3.new(ex, 0.08, ez), Color = Color3.fromRGB(math.floor(80 + 175 * heat), math.floor(230 - 150 * heat), 90), Material = Enum.Material.Neon, CanCollide = false })
		for _, sx in ipairs({ -1, 1 }) do
			local tx, tz = Castle.toWorld(r, sx * (W / 2 - 1), 4)
			local torch = P({ Name = "CastleTorch", Size = Vector3.new(1, 1, 1), Position = Vector3.new(tx, 6, tz), Color = rgb(255, 150, 60), Material = Enum.Material.Neon, CanCollide = false })
			light(torch, rgb(255, 170, 90), 22, 1)
		end
		-- pics : plaque + pointes (la pointe monte quand le danger approche)
		for i, sp in ipairs(Castle.spikes(room)) do
			local wx, wz = Castle.toWorld(r, sp.lx, sp.lz)
			local base = P({ Name = "SpikePlate", Size = Vector3.new(6.4, 0.3, 6.4), Position = Vector3.new(wx, 0.15, wz), Color = rgb(70, 70, 80), Material = Enum.Material.Metal, CanCollide = false })
			local tip = P({ Name = "SpikeTips", Size = Vector3.new(5, 1.6, 5), Position = Vector3.new(wx, -1, wz), Color = rgb(210, 214, 222), Material = Enum.Material.Metal, CanCollide = false })
			rec.spikes[i] = { base = base, tip = tip, wx = wx, wz = wz }
		end
		-- lames : un bras traversant (deux demi-bras) autour d'un moyeu
		for i, bl in ipairs(Castle.blades(room)) do
			local wx, wz = Castle.toWorld(r, bl.lx, bl.lz)
			P({ Name = "BladeHub", Size = Vector3.new(2.4, 2.4, 2.4), Position = Vector3.new(wx, 1.4, wz), Color = rgb(60, 60, 70), Material = Enum.Material.Metal, CanCollide = false })
			local arm = P({ Name = "BladeArm", Size = Vector3.new(bl.arm * 2, 0.5, 1.4), Position = Vector3.new(wx, 1.4, wz), Color = rgb(215, 220, 232), Material = Enum.Material.Metal, CanCollide = false })
			CollectionService:AddTag(arm, "CastleBlade") -- le client joue la boucle de la lame selon la distance
			rec.blades[i] = { arm = arm, wx = wx, wz = wz }
		end
		-- boulets : sphère qui traverse la salle (cachée sous le sol pendant la pause)
		for i, ba in ipairs(Castle.balls(room)) do
			local wx, wz = Castle.toWorld(r, 0, ba.lz)
			local ball = h.ball({ Name = "Boulder", Size = Vector3.new(ba.radius * 2, ba.radius * 2, ba.radius * 2), Position = Vector3.new(wx, -10, wz), Color = rgb(122, 127, 140), Material = Enum.Material.Slate }, parent)
			n += 1
			CollectionService:AddTag(ball, "CastleBall")
			rec.balls[i] = { part = ball, wz = wz }
		end
		-- chevaliers : silhouette d'armure (pilote de la logique ; remplacée par le modèle Blender si chargé)
		for i, kn in ipairs(Castle.knights(room)) do
			local wx, wz = Castle.toWorld(r, 0, kn.lz)
			local k = P({ Name = "CastleKnight", Size = Vector3.new(3, 6, 3), Position = Vector3.new(wx, 3, wz), Color = rgb(150, 156, 170), Material = Enum.Material.Metal, CanCollide = false })
			rec.knights[i] = { part = k, wz = wz }
		end
		-- porte de fin de salle (s'ouvre par intervalles)
		local dx, dz = Castle.toWorld(r, 0, L - 1)
		rec.door = P({ Name = "CastleDoor" .. r, Size = Vector3.new(W, 9, 1.2), Position = Vector3.new(dx, 4.5, dz), Color = rgb(74, 74, 82), Material = Enum.Material.Metal })
		rec.doorClosedY, rec.doorX, rec.doorZ = 4.5, dx, dz
	end
	-- entrée (le joueur peut y entrer depuis l'arène) : arche et invite
	local ex, ez = Castle.toWorld(1, 0, -6)
	local ey = 0
	if entry then
		ex, ey, ez = entry.X, entry.Y, entry.Z
	end
	local entryPart = P({ Name = "CastleEntry", Size = Vector3.new(14, 1, 8), Position = Vector3.new(ex, ey + 0.5, ez), Color = rgb(255, 110, 60), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.3 })
	for _, sx in ipairs({ -8, 8 }) do
		P({ Name = "CastleGatePillar", Size = Vector3.new(3, 16, 3), Position = Vector3.new(ex + sx, ey + 8, ez), Color = rgb(112, 108, 120), Material = Enum.Material.Slate })
	end
	P({ Name = "CastleGateTop", Size = Vector3.new(19, 3, 3), Position = Vector3.new(ex, ey + 17, ez), Color = rgb(96, 92, 104), Material = Enum.Material.Slate })
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Entrer"
	pr.ObjectText = "🏰 Le Château"
	pr.HoldDuration = 0.8
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	CollectionService:AddTag(pr, "CastleEntry")
	pr.Parent = entryPart
	world.entry = entryPart
	-- coffre final au bout de la salle 5
	local cx2, cz2 = Castle.toWorld(Castle.ROOMS, 0, L - 5)
	local chest = P({ Name = "CastleChest", Size = Vector3.new(6, 4, 4), Position = Vector3.new(cx2, 2, cz2), Color = rgb(150, 98, 44), Material = Enum.Material.Wood })
	P({ Name = "CastleChestLid", Size = Vector3.new(6.4, 1.4, 4.4), Position = Vector3.new(cx2, 4.4, cz2), Color = rgb(232, 185, 35), Material = Enum.Material.Metal, CanCollide = false })
	light(chest, rgb(255, 215, 90), 26, 1.6)
	local cp = Instance.new("ProximityPrompt")
	cp.ActionText = "Ouvrir le coffre"
	cp.ObjectText = "🏆 Trésor du Château"
	cp.HoldDuration = 1
	cp.MaxActivationDistance = 12
	cp.RequiresLineOfSight = false
	CollectionService:AddTag(cp, "CastleChest")
	cp.Parent = chest
	world.chest = chest
	-- tableau des meilleurs temps, à l'entrée
	local bx, bz = Castle.toWorld(1, 18, -6)
	if entry then
		bx, bz = ex - 18, ez
	end
	local board = P({ Name = "CastleBoard", Size = Vector3.new(11, 7, 0.7), Position = Vector3.new(bx, ey + 6, bz), Color = rgb(40, 30, 34), Material = Enum.Material.WoodPlanks })
	local bb = Instance.new("BillboardGui")
	bb.Adornee = board
	bb.Size = UDim2.fromOffset(360, 200)
	bb.MaxDistance = 110
	bb.LightInfluence = 0
	bb.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = rgb(255, 214, 120)
	label.Text = "🏰 Meilleurs temps\n(aucun pour l'instant)"
	label.Parent = bb
	world.board = label
	return world, n
end

---------------------------------------------------------------- Nid de paille sous un œuf (repli procédural de NidOeufs)
function Scenery.nest(h, position, parent)
	local n = 0
	cyl(h, { Name = "NestBase", Color = rgb(196, 150, 70), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false }, parent, 6, 0.5, position + Vector3.new(0, 0.3, 0))
	cyl(h, { Name = "NestRim", Color = rgb(150, 104, 44), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false }, parent, 6.8, 0.35, position + Vector3.new(0, 0.2, 0))
	n += 2
	for i = 1, 8 do -- brins de paille dépassant du bord
		local a = i / 8 * math.pi * 2
		h.part({ Name = "NestStraw", Size = Vector3.new(0.3, 0.25, 1.6), CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 3.2, 0.55, math.sin(a) * 3.2)) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = rgb(226, 190, 100), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false }, parent)
		n += 1
	end
	return n
end

---------------------------------------------------------------- Piédestal hexagonal des emplacements (lumières chaudes)
-- Trois dalles croisées à 60° dessinent un hexagone ; liseré néon chaud. Retourne le nombre de Parts.
function Scenery.pedestal(h, position, parent, warm, diam, noGlow)
	-- diam / noGlow (lot 5) : les 20 emplacements d'une base sont espacés de 9 studs : dalle de 8,6 studs et pas d'anneau lumineux (budget de Parts, aucun chevauchement coplanaire)
	local d = diam or 9.6
	cyl(h, { Name = "PedestalSlab", Color = rgb(210, 200, 184), Material = Enum.Material.Marble, CanCollide = false }, parent, d, 0.5, position)
	if noGlow then
		return 1
	end
	cyl(h, { Name = "PedestalGlow", Color = warm or rgb(255, 190, 90), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.45 }, parent, d + 0.8, 0.15, position + Vector3.new(0, -0.15, 0))
	return 2
end

---------------------------------------------------------------- Aura des raretés élevées : cercle runique au sol, piliers, particules
-- style = Config.auraStyle(...) ; color = couleur de rareté. Disparaît seule après style.seconds (Debris côté appelant). Retourne (ancre, nombre de Parts).
function Scenery.aura(h, position, parent, style, color)
	local n = 0
	local anchor = h.part({ Name = "AuraAnchor", Size = Vector3.new(1, 1, 1), Position = position, Transparency = 1, CanCollide = false, CanQuery = false }, parent)
	n += 1
	-- lot 8A : toutes les pièces sont ENFANTS de l'ancre (le Debris de l'appelant détruit l'ancre seule : avant, anneaux, glyphes et sommet du pilier
	-- restaient dans le Workspace à chaque éclosion Légendaire+ ; fuite trouvée par le test de charge de 10 min)
	cyl(h, { Name = "RuneRing", Color = color, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, CanQuery = false }, anchor, 11, 0.15, position + Vector3.new(0, 0.2, 0))
	cyl(h, { Name = "RuneRingInner", Color = color, Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false, CanQuery = false }, anchor, 7, 0.15, position + Vector3.new(0, 0.25, 0))
	n += 2
	for i = 1, style.runes do -- glyphes : petits blocs néon répartis sur le cercle
		local a = i / style.runes * math.pi * 2
		h.part({ Name = "Rune", Size = Vector3.new(0.5, 0.2, 1.1), CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 4.6, 0.3, math.sin(a) * 4.6)) * CFrame.Angles(0, -a, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }, anchor)
		n += 1
	end
	local em = emitter(anchor, color, style.rate, 7, 1.6, 0.5, Vector3.new(0, 2, 0))
	em.SpreadAngle = Vector2.new(25, 25)
	light(anchor, color, 24, 1.6)
	if style.pillar then -- Beam : pilier de lumière
		local top = h.part({ Name = "AuraTop", Size = Vector3.new(1, 1, 1), Position = position + Vector3.new(0, 26, 0), Transparency = 1, CanCollide = false, CanQuery = false }, anchor)
		n += 1
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent = anchor
		a1.Parent = top
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 3.2, 1.2
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new(0.3)
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Parent = anchor
	end
	return anchor, n
end

---------------------------------------------------------------- Eau : rivières en polylignes, murs invisibles, ponts, lacs, pontons, cabane, cascade
-- REFONTE (lot 2). Hauteurs des dessus (jamais deux surfaces coplanaires qui se recouvrent, écart >= 0,06) : chemins de terre 0,04 / 0,10 (coudes 0,16),
-- disques des territoires 0,22, routes pavées 0,28 / 0,34 (coudes 0,40), bord de la place 0,46, place 0,52, place du Grand Œuf 0,58, rives des lacs 0,16,
-- rivière du Nord et ruisseau des Saules 0,64 / 0,70 (coudes 0,76), ruisseau du Moulin 0,88, lacs 0,94, douve 1,00, pontons 1,10, fontaine 1,30.
-- Une Part d'eau par segment (deux hauteurs alternées, disque aux sommets : jamais deux faces coplanaires), mur invisible le long
-- de la rivière du Nord SAUF aux ponts (G.riverWalls), pile sous le pont du château (on ne passe pas dessous), planches des ponts de bois.
local WATER = Color3.fromRGB(60, 150, 220)

local function flatSeg(h, props, parent, ax, az, bx, bz, width, y, thick)
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	props.Size = Vector3.new(width, thick or 0.3, len)
	props.CFrame = CFrame.lookAt(Vector3.new((ax + bx) / 2, y, (az + bz) / 2), Vector3.new(bx, y, bz))
	return h.part(props, parent)
end
Scenery.flatSeg = flatSeg

function Scenery.rivers(h, parent, cfg, G)
	local n = 0
	local M2 = cfg.Map2
	for ri, rv in ipairs(M2.rivers) do
		local pts = rv.pts
		for k = 1, #pts - 1 do
			local segTop = ri == 2 and 0.88 or ((k % 2 == 1) and 0.64 or 0.70)
			flatSeg(h, { Name = rv.name, Color = WATER, Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false, CanQuery = false }, parent, pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2], rv.width, segTop - 0.15)
			n += 1
			if k > 1 then
				cyl(h, { Name = rv.name, Color = WATER, Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false, CanQuery = false }, parent, rv.width, 0.3, Vector3.new(pts[k][1], 0.76 - 0.15, pts[k][2]))
				n += 1
			end
		end
		if rv.ford then -- gué : trois pierres plates au milieu du ruisseau
			local m = math.floor(#pts / 2)
			local fx, fz = (pts[m][1] + pts[m + 1][1]) / 2, (pts[m][2] + pts[m + 1][2]) / 2
			for s = -1, 1 do
				cyl(h, { Name = "FordStone", Color = rgb(150, 146, 140), Material = Enum.Material.Slate }, parent, 2.6, 0.5, Vector3.new(fx + s * 0.4, 0.6, fz + s * 2.4))
				n += 1
			end
		end
	end
	-- murs invisibles de la rivière du Nord : le seul passage est un pont
	local WH = M2.wallHeight
	for _, w in ipairs(G.riverWalls(1)) do
		local len = math.sqrt((w[3] - w[1]) ^ 2 + (w[4] - w[2]) ^ 2)
		h.part({ Name = "RiverWall", Size = Vector3.new(1.5, WH, len + 0.5), CFrame = CFrame.lookAt(Vector3.new((w[1] + w[3]) / 2, WH / 2, (w[2] + w[4]) / 2), Vector3.new(w[3], WH / 2, w[4])), Transparency = 1, CanCollide = true, CanQuery = false, CanTouch = false }, parent)
		n += 1
	end
	-- ponts
	for _, b in ipairs(G.bridges) do
		local ns = b.axis == "NS"
		local dx, dz = ns and 0 or 1, ns and 1 or 0 -- axe du pont
		if b.stone then
			-- pont de pierre du château : rampe de 0 (rive sud) à la hauteur du plateau (rive nord), pile sous le tablier à la rivière
			local H = M2.castle.h
			local ax, az = b.x + dx * b.len / 2, b.z + dz * b.len / 2 -- extrémité sud (rive des joueurs)
			local bx, bz = b.x - dx * b.len / 2, b.z - dz * b.len / 2 -- extrémité nord (plateau)
			local mid = Vector3.new(b.x, H / 2 - 0.4, b.z)
			local len = math.sqrt(b.len * b.len + H * H)
			h.part({ Name = "CastleBridge", Size = Vector3.new(b.w, 1, len + 0.6), CFrame = CFrame.lookAt(mid, Vector3.new(bx, H - 0.4, bz)), Color = rgb(150, 146, 140), Material = Enum.Material.Slate }, parent)
			for _, side in ipairs({ -1, 1 }) do
				local ox, oz = dz * side * (b.w / 2 - 0.4), dx * side * (b.w / 2 - 0.4)
				h.part({ Name = "CastleBridgeRail", Size = Vector3.new(0.8, 1.6, len), CFrame = CFrame.lookAt(mid + Vector3.new(ox, 1.2, oz), Vector3.new(bx + ox, H + 0.8, bz + oz)), Color = rgb(120, 116, 112), Material = Enum.Material.Slate }, parent)
			end
			local rx, rz = b.cross.x, b.cross.z
			local tY = (az - rz) / b.len * H -- hauteur du tablier au-dessus de la rivière
			local pierH = math.max(1, tY - 1.6)
			h.part({ Name = "RiverWall", Size = Vector3.new(b.w + 2, pierH, 1.5), Position = Vector3.new(rx, pierH / 2, rz), Color = rgb(120, 116, 112), Material = Enum.Material.Slate, CanQuery = false }, parent)
			n += 4
		else
			local planks = 5
			local step = b.len / planks
			local py = b.river == 1 and 0.55 or 0.75 -- tablier au-dessus de l'eau du cours d'eau franchi
			for k = 0, planks - 1 do
				local off = (k - (planks - 1) / 2) * step
				h.part({ Name = "BridgePlank", Size = ns and Vector3.new(b.w, 0.45, step + 0.1) or Vector3.new(step + 0.1, 0.45, b.w), Position = Vector3.new(b.x + dx * off, py, b.z + dz * off), Color = rgb(150, 104, 62), Material = Enum.Material.WoodPlanks }, parent)
				n += 1
			end
			for _, side in ipairs({ -1, 1 }) do
				h.part({ Name = "BridgeRail", Size = ns and Vector3.new(0.35, 0.35, b.len) or Vector3.new(b.len, 0.35, 0.35), Position = Vector3.new(b.x + dz * side * (b.w / 2 - 0.2), py + 1.25, b.z + dx * side * (b.w / 2 - 0.2)), Color = rgb(120, 82, 48), Material = Enum.Material.Wood, CanCollide = false }, parent)
				n += 1
			end
		end
	end
	return n
end

-- Lacs (disque d'eau, rive de sable plus basse), pontons, cabane du pêcheur, cascade du château, douve.
function Scenery.lakes(h, parent, cfg, G)
	local n = 0
	local M2 = cfg.Map2
	for _, lk in ipairs(M2.lakes) do
		cyl(h, { Name = "LakeShore", Color = rgb(214, 190, 140), Material = Enum.Material.Sand, CanCollide = false }, parent, (lk.r + lk.shore) * 2, 0.3, Vector3.new(lk.x, 0.01, lk.z))
		cyl(h, { Name = lk.name, Color = WATER, Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false, CanQuery = false }, parent, lk.r * 2, 0.3, Vector3.new(lk.x, 0.79, lk.z))
		n += 2
	end
	for _, dk in ipairs(G.docks) do
		flatSeg(h, { Name = "Dock", Color = rgb(150, 104, 62), Material = Enum.Material.WoodPlanks }, parent, dk.ax, dk.az, dk.bx, dk.bz, dk.w, 0.9, 0.4)
		n += 1
	end
	local cab = M2.cabin
	h.part({ Name = "CabinWalls", Size = Vector3.new(cab.w, 7, cab.d), Position = Vector3.new(cab.x, 3.5, cab.z), Color = rgb(150, 104, 62), Material = Enum.Material.WoodPlanks }, parent)
	h.part({ Name = "CabinRoof", Size = Vector3.new(cab.w + 2, 1, cab.d + 2), Position = Vector3.new(cab.x, 7.5, cab.z), Color = rgb(150, 70, 52), Material = Enum.Material.Wood }, parent)
	h.part({ Name = "CabinDoor", Size = Vector3.new(2.4, 4.4, 0.3), Position = Vector3.new(cab.x, 2.2, cab.z - cab.d / 2 - 0.1), Color = rgb(96, 64, 40), Material = Enum.Material.Wood, CanCollide = false }, parent)
	n += 3
	-- cascade : du bord du plateau du château vers la douve, et bassin d'écume
	local wf = M2.waterfall
	local fall = h.part({ Name = "Waterfall", Size = Vector3.new(8, wf.h, 0.6), Position = Vector3.new(wf.x, wf.h / 2, M2.castle.z1 + 0.4), Color = rgb(170, 215, 245), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false, CanQuery = false }, parent)
	emitter(fall, rgb(235, 248, 255), 10, 3, 1.4, 1.2, Vector3.new(0, -6, 0))
	local mo = G.moat
	h.part({ Name = "CastleMoat", Size = Vector3.new(mo.x1 - mo.x0, 0.3, mo.z1 - mo.z0), Position = Vector3.new((mo.x0 + mo.x1) / 2, 0.85, (mo.z0 + mo.z1) / 2), Color = WATER, Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false, CanQuery = false }, parent)
	n += 2
	return n
end

---------------------------------------------------------------- Marqueur d'élément interactif
-- Tout ce avec quoi on peut agir (nids à chiper, secrets) porte un anneau doré pulsant (tag Interactive, animé côté client) et une icône :
-- les décors n'utilisent jamais ce doré, on distingue donc d'un coup d'œil ce qui est cliquable de ce qui est décoratif.
function Scenery.marker(h, position, parent, icon, diameter)
	local ring = cyl(h, { Name = "InteractiveMarker", Color = rgb(255, 214, 64), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false }, parent, diameter or 7, 0.2, position + Vector3.new(0, 0.3, 0))
	ring:SetAttribute("BaseT", 0.35)
	CollectionService:AddTag(ring, "Interactive")
	local bb = Instance.new("BillboardGui")
	bb.Name = "InteractiveIcon"
	bb.Adornee = ring
	bb.Size = UDim2.fromOffset(40, 40)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = ring
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Text = icon or "✋"
	t.Parent = bb
	return ring
end

---------------------------------------------------------------- Territoires : décor identitaire (REFONTE lot 2 : centré sur le territoire, rayon r)
-- Chaque thème reste dans son disque (rayon r) et évite les nids et les postes des gardiens (5 studs). Retourne le nombre de Parts.
local function clearOf(t, x, z)
	for _, p in ipairs(t.nests or {}) do
		if math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2) < 7 then
			return false
		end
	end
	for _, p in ipairs(t.posts or {}) do
		if math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2) < 7 then
			return false
		end
	end
	return true
end

-- Ferme de Gus : grange (Nord-Ouest) ou meules et épouvantail (Sud-Ouest).
function Scenery.gus(h, t, parent, rng, y0)
	local n = 0
	y0 = y0 or 0
	local cx, cz = t.x, t.z
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	if t.key == "gusNW" then
		local bx, bz = cx - 22, cz + 18
		P({ Name = "BarnWalls", Size = Vector3.new(14, 8, 11), Position = Vector3.new(bx, y0 + 4, bz), Color = rgb(168, 52, 46), Material = Enum.Material.WoodPlanks })
		for _, side in ipairs({ -1, 1 }) do
			P({ Name = "BarnRoof", Size = Vector3.new(8, 0.8, 12.5), CFrame = CFrame.new(bx + side * 3.4, y0 + 9.6, bz) * CFrame.Angles(0, 0, -side * 0.62), Color = rgb(96, 70, 52), Material = Enum.Material.Wood })
		end
		P({ Name = "BarnDoor", Size = Vector3.new(4.6, 6, 0.5), Position = Vector3.new(bx + 7.2, y0 + 3, bz), Color = rgb(235, 225, 205), Material = Enum.Material.Wood, CanCollide = false })
	end
	for k = 1, 3 do
		local a = k * 2.1 + (t.key == "gusSW" and 0.7 or 0)
		local x, z = cx + math.cos(a) * 22, cz + math.sin(a) * 22
		if clearOf(t, x, z) then
			n += 1
			cyl(h, { Name = "HayBale", Color = rgb(226, 196, 98), Material = Enum.Material.Fabric }, parent, 3.6, 3.2, Vector3.new(x, y0 + 1.8, z), rng:NextNumber(0, 3))
		end
	end
	if t.key == "gusSW" then
		local sx, sz = cx + 16, cz - 16
		P({ Name = "ScarecrowPole", Size = Vector3.new(0.5, 5, 0.5), Position = Vector3.new(sx, y0 + 2.5, sz), Color = rgb(120, 88, 58), Material = Enum.Material.Wood })
		P({ Name = "ScarecrowArms", Size = Vector3.new(4.6, 0.5, 0.5), Position = Vector3.new(sx, y0 + 4, sz), Color = rgb(120, 88, 58), Material = Enum.Material.Wood })
		n += 1
		h.ball({ Name = "ScarecrowHead", Size = Vector3.new(1.6, 1.6, 1.6), Position = Vector3.new(sx, y0 + 5.6, sz), Color = rgb(235, 200, 120) }, parent)
	end
	return n
end

-- Bois ensorcelés de Mara : arbres morts, champignons lumineux, tombes, mare violette.
function Scenery.mara(h, t, parent, rng, y0)
	local n = 0
	y0 = y0 or 0
	local cx, cz = t.x, t.z
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + 0.4
		local x, z = cx + math.cos(a) * (t.r - 8), cz + math.sin(a) * (t.r - 8)
		if clearOf(t, x, z) then
			local s = rng:NextNumber(0.9, 1.3)
			P({ Name = "DeadTrunk", Size = Vector3.new(1.6 * s, 11 * s, 1.6 * s), CFrame = CFrame.new(x, y0 + 5.5 * s, z) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.12, 0.12)), Color = rgb(52, 40, 52), Material = Enum.Material.Slate })
			for b = 1, 2 do
				P({ Name = "DeadBranch", Size = Vector3.new(0.7, 5 * s, 0.7), CFrame = CFrame.new(x, y0 + (6 + b * 1.6) * s, z) * CFrame.Angles(0, b * 2.1, 0.9 + b * 0.1) * CFrame.new(0, 2.2 * s, 0), Color = rgb(52, 40, 52), Material = Enum.Material.Slate, CanCollide = false })
			end
		end
	end
	local colors = { rgb(190, 110, 255), rgb(90, 235, 235), rgb(255, 110, 200) }
	for k = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, t.r - 6)
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		if clearOf(t, x, z) then
			local s = rng:NextNumber(0.8, 1.6)
			local col = colors[(k % #colors) + 1]
			P({ Name = "MushroomStem", Size = Vector3.new(0.7 * s, 1.8 * s, 0.7 * s), Position = Vector3.new(x, y0 + 0.9 * s, z), Color = rgb(230, 225, 235), CanCollide = false })
			n += 1
			local cap = h.ball({ Name = "MushroomCap", Size = Vector3.new(2.6 * s, 1.6 * s, 2.6 * s), Position = Vector3.new(x, y0 + 2 * s, z), Color = col, Material = Enum.Material.Neon }, parent)
			if k % 3 == 0 then
				light(cap, col, 14, 0.9)
			end
		end
	end
	for k = 1, 4 do
		local x, z = cx - 12 + k * 5, cz - t.r + 10
		if clearOf(t, x, z) then
			P({ Name = "Tombstone", Size = Vector3.new(2.4, 3.4, 0.7), CFrame = CFrame.new(x, y0 + 1.7, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.08, 0.08)), Color = rgb(120, 118, 130), Material = Enum.Material.Slate })
		end
	end
	n += 1
	local pond = cyl(h, { Name = "WitchPond", Color = rgb(150, 70, 230), Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false }, parent, 10, 0.3, Vector3.new(cx, y0 + 0.4, cz - 4))
	emitter(pond, rgb(220, 255, 140), 6, 2, 3, 0.35, Vector3.new(0, 0.6, 0))
	light(pond, rgb(170, 90, 255), 28, 1.2)
	return n
end

-- Cour de Zed : aiguilles d'obsidienne et lacs de lave (sur le plateau, hauteur y0).
function Scenery.zed(h, t, parent, rng, y0)
	local n = 0
	y0 = y0 or 0
	local cx, cz = t.x, t.z
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + 0.3
		local x, z = cx + math.cos(a) * (t.r - 7), cz + math.sin(a) * (t.r - 7)
		if clearOf(t, x, z) then
			local hgt = rng:NextNumber(8, 16)
			h.part({ Name = "ObsidianSpire", Size = Vector3.new(3.5, hgt, 3.5), CFrame = CFrame.new(x, y0 + hgt / 2, z) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(0, 3), rng:NextNumber(-0.1, 0.1)), Color = rgb(36, 32, 44), Material = Enum.Material.Slate }, parent)
			n += 1
		end
	end
	for k = 1, 3 do
		local a = k * 2.2
		local x, z = cx + math.cos(a) * 12, cz + math.sin(a) * 12
		if clearOf(t, x, z) then
			n += 1
			local lava = cyl(h, { Name = "LavaPool", Color = rgb(255, 110, 30), Material = Enum.Material.Neon, CanCollide = false }, parent, 7, 0.3, Vector3.new(x, y0 + 0.22, z))
			light(lava, rgb(255, 120, 40), 22, 1.4)
			if k == 2 then
				emitter(lava, rgb(255, 160, 60), 10, 8, 2, 0.5, Vector3.new(0, 4, 0))
			end
		end
	end
	return n
end

---------------------------------------------------------------- Chemins : routes pavées et chemins de terre (une dalle par segment, un disque à chaque coude)
-- Hauteurs distinctes par segment (aucune face coplanaire, même aux croisements) ; la partie dans la place (déjà pavée) n'est pas dessinée.
function Scenery.paths(h, parent, cfg, G)
	local n = 0
	local M2 = cfg.Map2
	local px, pz, pr = M2.plaza.x, M2.plaza.z, M2.plaza.r - 2
	for _, p in ipairs(M2.paths) do
		local paved = p.kind ~= "dirt"
		local half = paved and M2.pathHalf or M2.dirtHalf
		local base = p.y or 0
		local col = paved and rgb(196, 180, 150) or rgb(150, 118, 80)
		local mat = paved and Enum.Material.Cobblestone or Enum.Material.Ground
		for k = 1, #p.pts - 1 do
			local ax, az, bx, bz = p.pts[k][1], p.pts[k][2], p.pts[k + 1][1], p.pts[k + 1][2]
			local inA = (ax - px) ^ 2 + (az - pz) ^ 2 < pr * pr
			local inB = (bx - px) ^ 2 + (bz - pz) ^ 2 < pr * pr
			if base == 0 and inA and not inB then -- départ dans la place : on commence au bord de la place
				local dx, dz = bx - ax, bz - az
				local qa, qb, qc = dx * dx + dz * dz, 2 * ((ax - px) * dx + (az - pz) * dz), (ax - px) ^ 2 + (az - pz) ^ 2 - pr * pr
				local t = (-qb + math.sqrt(qb * qb - 4 * qa * qc)) / (2 * qa)
				ax, az = ax + dx * t, az + dz * t
			end
			if not (base == 0 and inA and inB) then
				local top = base + (paved and ((k % 2 == 1) and 0.28 or 0.34) or ((k % 2 == 1) and 0.04 or 0.10))
				flatSeg(h, { Name = paved and "PathStone" or "DirtPath", Color = col, Material = mat, CanCollide = false }, parent, ax, az, bx, bz, half * 2, top - 0.1, 0.2)
				n += 1
				if k > 1 then
					cyl(h, { Name = paved and "PathJoint" or "DirtPath", Color = col, Material = mat, CanCollide = false }, parent, half * 2, 0.2, Vector3.new(ax, base + (paved and 0.40 or 0.16) - 0.1, az))
					n += 1
				end
			end
		end
	end
	return n
end

---------------------------------------------------------------- Place du marché : dallage, halle à dôme, fontaine, étals
function Scenery.plaza(h, parent, cfg)
	local n = 0
	local M2 = cfg.Map2
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	local pl = M2.plaza
	cyl(h, { Name = "PlazaRim", Color = rgb(150, 136, 110), Material = Enum.Material.Cobblestone, CanCollide = false }, parent, pl.r * 2 + 3, 0.2, Vector3.new(pl.x, 0.36, pl.z))
	cyl(h, { Name = "Plaza", Color = rgb(206, 192, 162), Material = Enum.Material.Cobblestone, CanCollide = false }, parent, pl.r * 2, 0.2, Vector3.new(pl.x, 0.42, pl.z))
	n += 2
	-- halle à dôme : 8 piliers, dôme en gradins (haut `hall.h`), comptoir de la boutique d'œufs
	local hl = M2.hall
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		P({ Name = "HallPillar", Size = Vector3.new(1.6, 15, 1.6), Position = Vector3.new(hl.x + math.cos(a) * (hl.r - 2), 7.5, hl.z + math.sin(a) * (hl.r - 2)), Color = rgb(226, 214, 190), Material = Enum.Material.Marble })
	end
	for k, tier in ipairs({ { hl.r * 2 + 2, 15.5 }, { hl.r * 1.5, 19.5 }, { hl.r, 23.5 } }) do
		n += 1
		cyl(h, { Name = "HallDome", Color = k == 1 and rgb(176, 96, 70) or rgb(196, 110, 80), Material = Enum.Material.Slate }, parent, tier[1], 4, Vector3.new(hl.x, tier[2] + 2, hl.z))
	end
	n += 1
	local top = h.ball({ Name = "HallDomeTop", Size = Vector3.new(hl.r * 0.7, hl.r * 0.7, hl.r * 0.7), Position = Vector3.new(hl.x, hl.h - hl.r * 0.35, hl.z), Color = rgb(255, 214, 120), Material = Enum.Material.Metal }, parent)
	light(top, rgb(255, 224, 160), 30, 0.8)
	local counter = P({ Name = "EggCounter", Size = Vector3.new(10, 3.4, 2.4), Position = Vector3.new(hl.x - 4, 1.7, hl.z), Color = rgb(150, 104, 62), Material = Enum.Material.WoodPlanks })
	h.sign(counter, "🥚 Boutique d'œufs", rgb(255, 220, 140), 4, 220)
	-- bassin-fontaine
	local f = M2.fountain
	cyl(h, { Name = "FountainRim", Color = rgb(190, 184, 176), Material = Enum.Material.Marble }, parent, f.r * 2, 1.4, Vector3.new(f.x, 0.7, f.z))
	cyl(h, { Name = "Fountain", Color = WATER, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false, CanQuery = false }, parent, f.r * 2 - 1.4, 0.3, Vector3.new(f.x, 1.15, f.z))
	cyl(h, { Name = "FountainColumn", Color = rgb(206, 200, 190), Material = Enum.Material.Marble }, parent, 1.6, 5, Vector3.new(f.x, 2.5, f.z))
	n += 3
	local spout = h.ball({ Name = "FountainSpout", Size = Vector3.new(2.4, 2.4, 2.4), Position = Vector3.new(f.x, 5.4, f.z), Color = rgb(170, 215, 245), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false }, parent)
	n += 1
	emitter(spout, rgb(200, 235, 255), 18, 6, 1.2, 0.5, Vector3.new(0, -14, 0))
	-- étals : Améliorations, Pets / vente, Boutique Robux
	local labels = { "⬆️ Améliorations", "🐾 Pets / vente", "💎 Boutique" }
	local awn = { rgb(230, 80, 80), rgb(90, 170, 240), rgb(255, 190, 60) }
	for k, st in ipairs(M2.stalls) do
		P({ Name = "StallCounter", Size = Vector3.new(10, 3, 3), Position = Vector3.new(st.x, 1.5, st.z - 2.5), Color = rgb(150, 104, 62), Material = Enum.Material.WoodPlanks })
		for _, sx in ipairs({ -4.6, 4.6 }) do
			P({ Name = "StallPost", Size = Vector3.new(0.5, 7, 0.5), Position = Vector3.new(st.x + sx, 3.5, st.z + 2.5), Color = rgb(110, 76, 46), Material = Enum.Material.Wood })
		end
		local roof = P({ Name = "StallAwning", Size = Vector3.new(11, 0.4, 8.6), CFrame = CFrame.new(st.x, 7.2, st.z) * CFrame.Angles(0.18, 0, 0), Color = awn[k] or awn[1], Material = Enum.Material.Fabric, CanCollide = false })
		h.sign(roof, labels[k] or "", rgb(255, 240, 200), 2.5, 200)
	end
	return n
end

---------------------------------------------------------------- Château : plateau (h), palier du pont, cour fermée par des murs (herse), donjon
-- Retourne (nombre de Parts, position de la porte du donjon).
function Scenery.castlePlateau(h, parent, cfg, G)
	local n = 0
	local M2 = cfg.Map2
	local C = M2.castle
	local H = C.h
	local function P(props)
		n += 1
		return h.part(props, parent)
	end
	local w, d = C.x1 - C.x0, C.z1 - C.z0
	P({ Name = "CastleCliff", Size = Vector3.new(w, H + 1.5, d), Position = Vector3.new((C.x0 + C.x1) / 2, (H - 0.5 - 2) / 2, (C.z0 + C.z1) / 2), Color = rgb(128, 122, 118), Material = Enum.Material.Slate })
	P({ Name = "CastlePlateau", Size = Vector3.new(w - 1, 0.5, d - 1), Position = Vector3.new((C.x0 + C.x1) / 2, H - 0.25, (C.z0 + C.z1) / 2), Color = rgb(108, 150, 84), Material = Enum.Material.Grass })
	local L = G.landing
	P({ Name = "CastleLanding", Size = Vector3.new(L.x1 - L.x0 + 0.5, H, L.z1 - L.z0), Position = Vector3.new((L.x0 + L.x1) / 2 + 0.25, H / 2, (L.z0 + L.z1) / 2), Color = rgb(150, 146, 140), Material = Enum.Material.Slate })
	-- cour de Zed : disque pavé et mur circulaire (rayon r + 2), rabattu le long du bord sud du plateau ; herse à l'entrée (Map2/TERR : traps.gate)
	local zt = G.terr("zed")
	cyl(h, { Name = "CourtFloor", Color = rgb(96, 88, 92), Material = Enum.Material.Cobblestone, CanCollide = false }, parent, zt.r * 2, 0.2, Vector3.new(zt.x, H + 0.08, zt.z))
	n += 1
	local R = zt.r + 2
	local segs = 18
	local pts = {}
	for k = 0, segs - 1 do
		local a = k / segs * math.pi * 2
		pts[k + 1] = { zt.x + math.cos(a) * R, math.min(zt.z + math.sin(a) * R, C.z1 - 4) }
	end
	local gate = zt.entry
	local gateK, gd = 1, math.huge
	for k = 1, segs do
		local a, b = pts[k], pts[k % segs + 1]
		local mx, mz = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
		local dd = math.sqrt((mx - gate.x) ^ 2 + (mz - gate.z) ^ 2)
		if dd < gd then
			gateK, gd = k, dd
		end
	end
	for k = 1, segs do
		local a, b = pts[k], pts[k % segs + 1]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		if len > 0.5 then
			local mid = Vector3.new((a[1] + b[1]) / 2, H + 4, (a[2] + b[2]) / 2)
			if k == gateK then
				-- herse levée au-dessus du passage (le cycle ouvert/fermé est un piège du lot 4) et piliers
				P({ Name = "CourtGate", Size = Vector3.new(1, 3, len), CFrame = CFrame.lookAt(mid + Vector3.new(0, 5.5, 0), Vector3.new(b[1], H + 9.5, b[2])), Color = rgb(70, 70, 78), Material = Enum.Material.Metal, CanCollide = false })
			else
				P({ Name = "CourtWall", Size = Vector3.new(2, 8, len + 1.2), CFrame = CFrame.lookAt(mid, Vector3.new(b[1], H + 4, b[2])), Color = rgb(96, 92, 106), Material = Enum.Material.Slate })
			end
		end
	end
	-- donjon : bloc, quatre tours d'angle, toit ; la porte (Map2.castle.door) est l'entrée du mode Château
	local K = G.keep
	P({ Name = "Keep", Size = Vector3.new(K.half * 2, 22, K.half * 2), Position = Vector3.new(K.x, H + 11, K.z), Color = rgb(112, 108, 120), Material = Enum.Material.Slate })
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		n += 1
		cyl(h, { Name = "KeepTower", Color = rgb(104, 100, 114), Material = Enum.Material.Slate }, parent, 6, 28, Vector3.new(K.x + c[1] * K.half, H + 14, K.z + c[2] * K.half))
	end
	P({ Name = "KeepRoof", Size = Vector3.new(K.half * 2 - 2, 2, K.half * 2 - 2), Position = Vector3.new(K.x, H + 23, K.z), Color = rgb(150, 60, 52), Material = Enum.Material.Slate })
	local flag = P({ Name = "KeepFlag", Size = Vector3.new(0.3, 4, 6), Position = Vector3.new(K.x, H + 28, K.z), Color = rgb(224, 87, 90), Material = Enum.Material.Fabric, CanCollide = false })
	light(flag, rgb(255, 140, 100), 40, 0.8)
	return n, Vector3.new(C.door.x, H, C.door.z)
end

---------------------------------------------------------------- Arène (colisée procédural simple) : sable, gradins, mur extérieur ouvert vers l'entrée
function Scenery.arena(h, parent, cfg)
	local n = 0
	local A = cfg.Map2.arena
	cyl(h, { Name = "ArenaSand", Color = rgb(214, 190, 140), Material = Enum.Material.Sand, CanCollide = false }, parent, A.sand * 2, 0.3, Vector3.new(A.x, 0.12, A.z))
	n += 1
	local ex, ez = A.entry.x - A.x, A.entry.z - A.z
	local el = math.sqrt(ex * ex + ez * ez)
	local function ring(radius, segs, height, thick, name, col)
		for k = 0, segs - 1 do
			local a0, a1 = k / segs * math.pi * 2, (k + 1) / segs * math.pi * 2
			local am = (a0 + a1) / 2
			local mx, mz = math.cos(am), math.sin(am)
			if (mx * ex + mz * ez) / el < math.cos(math.pi / segs * 1.2) then -- pas de segment devant l'entrée
				local ax, az = A.x + math.cos(a0) * radius, A.z + math.sin(a0) * radius
				local bx, bz = A.x + math.cos(a1) * radius, A.z + math.sin(a1) * radius
				local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
				h.part({ Name = name, Size = Vector3.new(thick, height, len + 0.8), CFrame = CFrame.lookAt(Vector3.new((ax + bx) / 2, height / 2, (az + bz) / 2), Vector3.new(bx, height / 2, bz)), Color = col, Material = Enum.Material.Slate }, parent)
				n += 1
			end
		end
	end
	ring(A.sand + 3, 12, 2.4, 5, "ArenaSteps", rgb(196, 184, 164))
	ring(A.r - 2, 16, 9, 3, "ArenaWall", rgb(176, 160, 134))
	local post = h.part({ Name = "ArenaSign", Size = Vector3.new(1, 8, 1), Position = Vector3.new(A.entry.x + 6, 4, A.entry.z - 6), Color = rgb(90, 60, 40), Material = Enum.Material.Wood }, parent)
	n += 1
	h.sign(post, "⚔️ ARÈNE DES PETS\nDéfie la tour des Dresseurs", rgb(255, 220, 140), 6, 280)
	return n
end

---------------------------------------------------------------- Relief : sol, bornes, collines (calottes sphériques), montagnes de fond, forêts procédurales
-- `forest` = Placement.forest() : { {x, z, y} } (2 Parts par arbre : tronc et feuillage). Retourne le nombre de Parts.
function Scenery.relief(h, parent, cfg, forest)
	local n = 0
	local M2 = cfg.Map2
	local B = M2.bounds
	local WH = M2.wallHeight
	for _, w in ipairs({ { 0, B.z0 - 1, B.x1 - B.x0 + 4, 2 }, { 0, B.z1 + 1, B.x1 - B.x0 + 4, 2 }, { B.x0 - 1, 0, 2, B.z1 - B.z0 + 4 }, { B.x1 + 1, 0, 2, B.z1 - B.z0 + 4 } }) do
		h.part({ Name = "BoundWall", Size = Vector3.new(w[3], WH * 2.5, w[4]), Position = Vector3.new(w[1], WH * 1.25, w[2]), Transparency = 1, CanQuery = false, CanTouch = false }, parent)
		n += 1
	end
	for _, hl in ipairs(M2.hills) do -- collines praticables : calotte sphérique (pente < 50° au pied)
		local R = (hl.r * hl.r + hl.h * hl.h) / (2 * hl.h)
		n += 1
		local b = h.ball({ Name = "Hill", Size = Vector3.new(R * 2, R * 2, R * 2), Position = Vector3.new(hl.x, hl.h - R, hl.z), Color = rgb(96, 158, 84), Material = Enum.Material.Grass }, parent)
		b.CanCollide = true
		b.CastShadow = false
	end
	-- montagnes au nord, collines ailleurs : décor de fond hors des bornes, sans collision ni ombre
	local bw, bd = M2.backdrop.w / 2, M2.backdrop.d / 2
	for k, m in ipairs({ { -260, -bd + 10, 150, 70 }, { -60, -bd + 5, 170, 85 }, { 150, -bd + 8, 150, 75 }, { 330, -bd + 20, 130, 60 }, { -bw + 10, 60, 120, 40 }, { bw - 10, 90, 120, 40 }, { 0, bd - 5, 180, 35 } }) do
		n += 1
		local b = h.ball({ Name = "Backdrop", Size = Vector3.new(m[3], m[3], m[3]), Position = Vector3.new(m[1], m[4] - m[3] / 2, m[2]), Color = k <= 4 and rgb(116, 128, 120) or rgb(90, 150, 82), Material = k <= 4 and Enum.Material.Slate or Enum.Material.Grass, CanCollide = false }, parent)
		b.CastShadow = false
	end
	for i, t in ipairs(forest or {}) do -- arbres procéduraux : tronc et feuillage (2 Parts)
		local y = t.y or 0
		local st = h.forestStyle and h.forestStyle[i] -- lot graphismes : { shape = { w, h, trunk, y }, scale, leaf = { r, g, b } } (Graphics.styleForest)
		if st then
			local sc, sh, lf = st.scale, st.shape, st.leaf
			h.part({ Name = "Trunk", Size = Vector3.new(1.8 * sc, sh.trunk * sc, 1.8 * sc), Position = Vector3.new(t.x, y + sh.trunk * sc / 2, t.z), Color = rgb(110, 78, 50), Material = Enum.Material.Wood }, parent)
			h.ball({ Name = "Leaves", Size = Vector3.new(sh.w * sc, sh.h * sc, sh.w * sc), Position = Vector3.new(t.x, y + sh.y * sc, t.z), Color = rgb(lf[1], lf[2], lf[3]), Material = Enum.Material.Grass }, parent)
		else
			local s = 0.9 + ((math.floor(t.x * 7 + t.z * 3) % 5) * 0.08)
			h.part({ Name = "Trunk", Size = Vector3.new(1.8 * s, 8 * s, 1.8 * s), Position = Vector3.new(t.x, y + 4 * s, t.z), Color = rgb(110, 78, 50), Material = Enum.Material.Wood }, parent)
			h.ball({ Name = "Leaves", Size = Vector3.new(10 * s, 10 * s, 10 * s), Position = Vector3.new(t.x, y + 10.5 * s, t.z), Color = (t.z < -180 or t.grove) and rgb(54, 120, 70) or rgb(70, 146, 72), Material = Enum.Material.Grass }, parent)
		end
		n += 2
	end
	return n
end

---------------------------------------------------------------- Secrets : un sanctuaire par domaine, fouillable une fois par jour
function Scenery.secrets(h, parent, cfg)
	local n = 0
	for _, sct in ipairs(cfg.SECRETS) do
		local base = Vector3.new(sct.x, 0, sct.z)
		n += 3
		cyl(h, { Name = "ShrineBase", Color = rgb(150, 146, 140), Material = Enum.Material.Marble }, parent, 12, 1.2, base + Vector3.new(0, 0.6, 0))
		h.part({ Name = "ShrinePillar", Size = Vector3.new(2.4, 7, 2.4), Position = base + Vector3.new(0, 4.7, 0), Color = rgb(190, 184, 176), Material = Enum.Material.Marble }, parent)
		local gem = h.ball({ Name = "Secret_" .. sct.id, Size = Vector3.new(3, 3, 3), Position = base + Vector3.new(0, 9.4, 0), Color = rgb(255, 214, 90), Material = Enum.Material.Neon }, parent)
		light(gem, rgb(255, 214, 120), 34, 1.4)
		emitter(gem, rgb(255, 230, 140), 5, 2, 2, 0.4, Vector3.new(0, 1, 0))
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Fouiller"
		pr.ObjectText = sct.emoji .. " " .. sct.name
		pr.HoldDuration = 1
		pr.MaxActivationDistance = 12
		pr.RequiresLineOfSight = false
		pr:SetAttribute("SecretId", sct.id)
		CollectionService:AddTag(pr, "SecretPrompt")
		pr.Parent = gem
		Scenery.marker(h, base + Vector3.new(0, 0.4, 0), parent, "🔍", 14)
		n += 1
	end
	return n
end

return Scenery
