-- ModuleScript : ReplicatedStorage/Shared/Upgrade
-- Montée de niveau de la maison (REFONTE lot 5, D.4) : LOGIQUE PURE (aucun service Roblox), testée hors de Roblox. Calcule, pour un temps t (secondes),
-- l'état de chaque phase de l'animation ; le client (BaseUpgradeFx) l'applique aux objets. Ne lève jamais d'erreur (valeurs invalides = début).
-- Phases (Config.UPGRADE_FX) : ① échafaudage 0,8 s ② poussière + onde 0,4 s ③ l'ancienne maison s'enfonce, la nouvelle monte (squash & stretch) 1,5 s
-- ④ fête (confettis, bannière) 1,8 s ; total 4,5 s. Utilisation : require(Upgrade).new(Config, Easing).
local Upgrade = {}

function Upgrade.new(Config, Easing)
	local U = {}
	local F = Config.UPGRADE_FX

	local function clamp01(x)
		if type(x) ~= "number" or x ~= x then
			return 0
		end
		return math.min(1, math.max(0, x))
	end

	U.seconds = F.seconds
	U.dustAt = F.scaffold -- début de la poussière
	U.swapAt = F.scaffold + F.dust -- début de l'échange des maisons
	U.partyAt = F.scaffold + F.dust + F.swap -- début de la fête

	-- État au temps t : toutes les valeurs sont dans [0, 1] sauf sx / sy (squash & stretch de la nouvelle maison, > 0).
	--   scaffold : hauteur de l'échafaudage ; strip : retrait de l'échafaudage (pendant la fête) ; dust : poussière (0 -> 1 -> 0) ; wave : onde (0 avant, 1 pendant la poussière)
	--   drop : enfoncement de l'ancienne maison ; rise : montée de la nouvelle ; party : progression de la fête ; done : animation terminée
	function U.state(t)
		t = (type(t) == "number" and t == t) and math.max(t, 0) or 0
		local sc = clamp01(t / F.scaffold)
		local swap = clamp01((t - U.swapAt) / F.swap)
		local sx, sy = 1, 1
		if swap > 0 and swap < 1 then
			sx, sy = Easing.squashStretch(swap, 0.35)
		end
		local dustP = clamp01((t - U.dustAt) / F.dust)
		return {
			t = t,
			scaffold = Easing.outQuad(sc),
			strip = clamp01((t - U.partyAt) / 0.5),
			dust = dustP > 0 and dustP < 1 and math.sin(dustP * math.pi) or 0,
			wave = (t >= U.dustAt and t < U.swapAt) and 1 or 0,
			drop = swap * swap, -- l'ancienne maison accélère en s'enfonçant
			rise = Easing.outBack(swap), -- la nouvelle monte avec un léger dépassement
			sx = sx,
			sy = sy,
			party = clamp01((t - U.partyAt) / F.party),
			done = t >= U.seconds,
		}
	end

	-- Texte de la bannière : « 🏠 Niveau 5 : Maison au garage ! +2 emplacements, revenus +20 % ».
	function U.banner(level, from)
		return Config.upgradeBanner(level, from)
	end

	-- La caméra large est-elle permise ? Propriétaire seul, sans œuf porté, pas poursuivi (`chased`), vivant, aucune autre cinématique en cours.
	function U.canFrame(isOwner, carrying, chased, dead, busy)
		return isOwner == true and (carrying or 0) <= 0 and not chased and not dead and not busy
	end

	return U
end

return Upgrade
