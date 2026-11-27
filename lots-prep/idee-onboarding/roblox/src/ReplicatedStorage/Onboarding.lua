-- ModuleScript : ReplicatedStorage/Shared/Onboarding
-- LOT 17 (idée 1 « Premières 5 minutes guidées ») : logique PURE de l'onboarding (aucun service Roblox, aucun os.time : le SERVEUR passe `now` en secondes).
-- Usage : local O = Onboarding.new(Config.ONBOARDING)   (cfg facultative : les valeurs absentes ou invalides prennent Onboarding.DEFAULTS)
-- Séquence FIXE de 5 étapes, une seule action attendue par étape :
--   1 gift   : « voici ton œuf offert » : validée quand le SERVEUR voit le joueur dans sa base (fait `near`)
--   2 hatch  : « éclosion commentée »   : validée quand le profil a au moins 1 éclosion (fait `hatched`, lu dans le profil)
--   3 income : « premier revenu »       : validée quand le revenu réellement versé atteint earnGoal pièces (événement `earn`)
--   4 house  : « première maison »      : validée quand la maison atteint le niveau houseLevel (fait `level`, lu côté serveur)
--   5 arena  : « premier pet à l'arène » : validée quand le serveur démarre un combat de tour (événement `arena`)
-- Garde-fous : une étape ne se valide QUE par le type d'événement qui lui correspond (les autres sont ignorés), avec des valeurs numériques saines ; on ne saute jamais
-- d'étape ; une étape reste affichée au moins minDwell secondes ; le client n'envoie jamais de fait : seul « Passer » (onbSkip) existe côté client, et il ne fait
-- que terminer le tutoriel. Après stepSeconds sans progrès, l'étape affiche son texte d'aide (jamais de validation automatique).
-- Champ de profil `onb` = { v, step, at, prog, skip } : step 1..5 = étape en cours, 6 = terminé ; at = début de l'étape (secondes, 0 = pas encore démarrée) ;
-- prog = pièces de revenu comptées pour l'étape 3 ; skip = passé par le joueur. Un tutoriel terminé ou passé ne se rejoue JAMAIS (rebirth compris : le serveur reporte `onb`).
-- Migration : `migrate(saved, now)` est idempotente. Profil sans `onb` (v13 actuel) : un profil neuf (0 éclosion et moins de legacyPlayedSeconds de jeu) démarre la séquence ;
-- tout autre profil existant est marqué terminé (legacy), SANS rien modifier d'autre. Un `onb` présent est seulement assaini, jamais réinitialisé.
-- Style : pas de `+=`, pas de `continue`, valeurs douteuses gardées par type avant toute comparaison.
local Onboarding = {}

Onboarding.VERSION = 1

Onboarding.DEFAULTS = {
	enabled = true,
	stepSeconds = 45, -- durée visée par étape : au-delà, le texte d'aide remplace le texte normal
	minDwell = 3, -- secondes minimales d'affichage d'une étape avant qu'elle puisse être validée (le texte est lu, pas d'enchaînement instantané)
	earnGoal = 10, -- étape 3 : pièces de revenu à voir tomber
	houseLevel = 2, -- étape 4 : niveau de maison à atteindre
	legacyPlayedSeconds = 120, -- profil sans `onb`, 0 éclosion et moins de temps de jeu que ça : considéré neuf
}

-- Étapes : kind = type d'événement accepté, text = consigne, hint = aide après stepSeconds, target = cible de la flèche du client (home / arena).
Onboarding.STEPS = {
	{ id = "gift", kind = "tick", target = "home", text = "🥚 Voici ton œuf offert ! Reste près de lui.", hint = "🥚 Retourne dans ta base : ton œuf offert t'attend." },
	{ id = "hatch", kind = "tick", target = "home", text = "🐣 Il va éclore : regarde bien ce que tu obtiens !", hint = "🐣 Patience : l'éclosion arrive dans quelques secondes." },
	{
		id = "income",
		kind = "earn",
		target = "home",
		text = "🪙 Ton pet gagne des pièces tout seul : attends d'en voir tomber.",
		hint = "💤 Bouge un peu : les pièces ne tombent que si tu es actif.",
	},
	{ id = "house", kind = "tick", target = "home", text = "🏠 Éclos d'autres œufs pour agrandir ta maison.", hint = "🛒 Achète un œuf au marché et pose-le dans ta base." },
	{
		id = "arena",
		kind = "arena",
		target = "arena",
		text = "⚔️ Envoie ton pet à l'Arène : choisis ton équipe puis lance l'étage 1.",
		hint = "⚔️ Va au portail de l'Arène, compose une équipe et lance l'étage 1.",
	},
}

local N = #Onboarding.STEPS
local MAX_TIME = 4e9
local MAX_PROG = 1e6

local function isnum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function int(v, lo, hi, def)
	if not isnum(v) then
		return def
	end
	v = math.floor(v)
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

function Onboarding.new(cfgIn)
	local O = {}
	local cfg = {}
	local src = type(cfgIn) == "table" and cfgIn or {}
	local def = Onboarding.DEFAULTS
	cfg.enabled = src.enabled ~= false
	cfg.stepSeconds = isnum(src.stepSeconds) and src.stepSeconds > 0 and src.stepSeconds or def.stepSeconds
	cfg.minDwell = isnum(src.minDwell) and src.minDwell >= 0 and src.minDwell or def.minDwell
	cfg.earnGoal = isnum(src.earnGoal) and src.earnGoal > 0 and src.earnGoal or def.earnGoal
	cfg.houseLevel = isnum(src.houseLevel) and src.houseLevel >= 2 and math.floor(src.houseLevel) or def.houseLevel
	cfg.legacyPlayedSeconds = isnum(src.legacyPlayedSeconds) and src.legacyPlayedSeconds >= 0 and src.legacyPlayedSeconds or def.legacyPlayedSeconds
	O.cfg = cfg
	O.STEPS = Onboarding.STEPS
	O.TOTAL = N

	-- Séquence neuve : étape 1, pas encore démarrée (at = 0 : le premier appel avec `now` la démarre).
	function O.default()
		return { v = Onboarding.VERSION, step = 1, at = 0, prog = 0, skip = false }
	end

	-- Séquence terminée d'office (profil existant avant le lot 17 : jamais de tutoriel rejoué).
	local function finished()
		return { v = Onboarding.VERSION, step = N + 1, at = 0, prog = 0, skip = false }
	end

	-- Retourne une copie assainie ; ne modifie jamais `raw`. Une valeur absente ou corrompue prend la valeur neuve, jamais celle d'un autre champ.
	function O.sanitize(raw)
		if type(raw) ~= "table" then
			return nil
		end
		return {
			v = Onboarding.VERSION,
			step = int(raw.step, 1, N + 1, 1),
			at = int(raw.at, 0, MAX_TIME, 0),
			prog = isnum(raw.prog) and math.min(MAX_PROG, math.max(0, raw.prog)) or 0,
			skip = raw.skip == true,
		}
	end

	-- Migration idempotente depuis un profil sauvegardé (nil ou table). Retourne le champ `onb` à poser ; ne touche à rien d'autre.
	function O.migrate(saved)
		if type(saved) == "table" and type(saved.onb) == "table" then
			return O.sanitize(saved.onb)
		end
		if type(saved) ~= "table" then
			return O.default()
		end
		local hatched = isnum(saved.hatched) and saved.hatched or 0
		local played = isnum(saved.played) and saved.played or 0
		if hatched <= 0 and played < cfg.legacyPlayedSeconds then
			return O.default()
		end
		return finished()
	end

	-- "active" | "skipped" | "done" (un état absent ou invalide compte pour "done" : on ne rejoue rien).
	function O.status(st)
		if type(st) ~= "table" or not isnum(st.step) then
			return "done"
		end
		if st.step > N then
			return "done"
		end
		if st.skip == true then
			return "skipped"
		end
		return "active"
	end

	function O.active(st)
		return cfg.enabled and O.status(st) == "active"
	end

	-- Reprise à la connexion : l'étape en cours repart de maintenant (aucun texte d'aide immédiat après une absence).
	function O.resume(st, now)
		if O.active(st) and isnum(now) and now >= 0 then
			st.at = math.floor(now)
		end
	end

	-- Le joueur passe le tutoriel : définitif. Retourne vrai si l'état a changé.
	function O.skip(st)
		if not O.active(st) then
			return false
		end
		st.skip = true
		return true
	end

	-- Vue pour le client (nil si rien à afficher).
	function O.view(st, now)
		if not O.active(st) then
			return nil
		end
		local step = Onboarding.STEPS[st.step]
		if not step then
			return nil
		end
		local stalled = isnum(now) and st.at > 0 and now - st.at > cfg.stepSeconds
		local goal = step.id == "income" and cfg.earnGoal or 0
		return {
			index = st.step,
			total = N,
			id = step.id,
			text = stalled and step.hint or step.text,
			target = step.target,
			stalled = stalled == true,
			prog = goal > 0 and math.min(goal, math.floor(st.prog)) or 0,
			goal = goal,
			seconds = cfg.stepSeconds,
		}
	end

	-- Événement serveur. kind : "tick" (arg = faits { near, hatched, level }), "earn" (arg = pièces versées), "arena" (arg ignoré).
	-- Retourne (avancé, info) : info = "step" | "done" si avancé, sinon la raison ("inactive", "wrong_step", "bad_arg", "bad_now", "dwell", "unmet").
	function O.event(st, kind, arg, now)
		if not O.active(st) then
			return false, "inactive"
		end
		if not isnum(now) or now < 0 then
			return false, "bad_now"
		end
		now = math.floor(now)
		local step = Onboarding.STEPS[st.step]
		if not step or type(kind) ~= "string" or step.kind ~= kind then
			return false, "wrong_step"
		end
		if not isnum(st.at) or st.at <= 0 then
			st.at = now -- première observation : l'étape démarre maintenant
		end
		local met = false
		if kind == "tick" then
			if type(arg) ~= "table" then
				return false, "bad_arg"
			end
			if step.id == "gift" then
				met = arg.near == true
			elseif step.id == "hatch" then
				met = isnum(arg.hatched) and arg.hatched >= 1
			elseif step.id == "house" then
				met = isnum(arg.level) and arg.level >= cfg.houseLevel
			end
		elseif kind == "earn" then
			if not isnum(arg) or arg <= 0 then
				return false, "bad_arg"
			end
			st.prog = math.min(cfg.earnGoal, (isnum(st.prog) and st.prog or 0) + arg)
			met = st.prog >= cfg.earnGoal
		else -- arena : le serveur n'appelle cet événement qu'après avoir accepté le combat
			met = true
		end
		if not met then
			return false, "unmet"
		end
		if now - st.at < cfg.minDwell then
			return false, "dwell"
		end
		st.step = st.step + 1
		st.at = now
		st.prog = 0
		if st.step > N then
			return true, "done"
		end
		return true, "step"
	end

	return O
end

return Onboarding
