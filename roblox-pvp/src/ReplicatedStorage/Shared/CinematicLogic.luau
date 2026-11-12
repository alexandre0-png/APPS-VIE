--!strict
-- Cinématiques : séquences, machine d'état, durées, reprise après skip/interruption (pure, testable hors Roblox).
local CinematicLogic = {}

export type Vec = { number }
export type Shot = {
	Duration: number,
	Caption: string,
	Sub: string,
	Hero: string?, -- clé de héros mise en avant
	From: Vec?, -- caméra de départ (nil = pas de mouvement de caméra)
	To: Vec?,
	Look: Vec?,
}
export type Sequence = { Key: string, Camera: boolean, Shots: { Shot } }
export type State = { Seq: Sequence, Index: number, Elapsed: number, Done: boolean, Reason: string? }

local MONUMENT: Vec = { 0, 14, 0 }
local PORTAL: Vec = { 0, 10, 44 }
local TOWER: Vec = { 0, 8, 600 }

CinematicLogic.Sequences = {
	intro = {
		Key = "intro",
		Camera = true,
		Shots = {
			{ Duration = 6, Caption = "LES ROYAUMES DU BRASIER", Sub = "Le Brasier s'éteint. Seule l'Arène des Légendes peut le rallumer.", From = { 40, 18, -40 }, To = { -40, 18, -40 }, Look = MONUMENT },
			{ Duration = 3.6, Caption = "KAEL, GARDIEN DE LA BRAISE", Sub = "Dernier veilleur du feu sacré.", Hero = "kael", From = { 24, 9, -24 }, To = { 20, 11, -18 }, Look = { 0, 10, 0 } },
			{ Duration = 3.6, Caption = "MIRA DES MARÉES", Sub = "Elle suit le courant de l'arène.", Hero = "mira", From = { -24, 9, -24 }, To = { -20, 11, -18 }, Look = { 0, 10, 0 } },
			{ Duration = 3.6, Caption = "ORIN L'OMBRE", Sub = "Il a vu la tour silencieuse.", Hero = "orin", From = { -24, 9, 24 }, To = { -20, 11, 18 }, Look = { 0, 10, 0 } },
			{ Duration = 3.6, Caption = "ZYLA L'ÉCLAT", Sub = "Née de l'orbe éclatée.", Hero = "zyla", From = { 24, 9, 24 }, To = { 20, 11, 18 }, Look = { 0, 10, 0 } },
			{ Duration = 5, Caption = "RALLUME LE BRASIER", Sub = "Passe le portail, gagne des manches, grimpe les paliers de la saison.", From = { 0, 8, 18 }, To = { 0, 10, 32 }, Look = PORTAL },
		},
	},
	tutorial = {
		Key = "tutorial",
		Camera = false,
		Shots = {
			{ Duration = 6, Caption = "SE DÉPLACER", Sub = "Clavier : ZQSD / WASD · Manette : stick gauche · Mobile : joystick" },
			{ Duration = 7, Caption = "COMBATTRE", Sub = "Clic ou bouton ⚔ : attaquer · 1 2 3 : changer d'arme · Q esquive · C glissade · F garde" },
			{ Duration = 7, Caption = "LES MODES", Sub = "Mêlée générale · Guerre des couleurs · Roi de la tour : tiens le plateau central" },
		},
	},
	season = {
		Key = "season",
		Camera = true,
		Shots = {
			{ Duration = 6, Caption = "{SEASON}", Sub = "Une nouvelle saison commence : 10 paliers de récompenses et un titre de champion.", From = { 0, 60, 520 }, To = { 0, 40, 570 }, Look = TOWER },
			{ Duration = 8, Caption = "LA TOUR VOUS ATTEND", Sub = "Éliminations, parties et victoires font monter votre palier.", From = { 70, 30, 640 }, To = { -70, 30, 640 }, Look = TOWER },
		},
	},
	hill = {
		Key = "hill",
		Camera = true,
		Shots = {
			{ Duration = 5, Caption = "ROI DE LA TOUR", Sub = "Un nouveau mode : montez sur le plateau central.", From = { 55, 34, 560 }, To = { 0, 28, 575 }, Look = TOWER },
			{ Duration = 5, Caption = "1 POINT PAR SECONDE", Sub = "Tenez la tour : le premier à 60 points règne sur l'arène.", From = { 28, 18, 625 }, To = { -28, 18, 625 }, Look = TOWER },
		},
	},
} :: { [string]: Sequence }

function CinematicLogic.TotalDuration(seq: Sequence): number
	local total = 0
	for _, shot in ipairs(seq.Shots) do
		total += shot.Duration
	end
	return total
end

function CinematicLogic.New(seq: Sequence): State
	return { Seq = seq, Index = 1, Elapsed = 0, Done = false, Reason = nil }
end

-- Fait avancer la cinématique de dt secondes (passe aux plans suivants, termine si fini).
function CinematicLogic.Step(state: State, dt: number): State
	if state.Done then
		return state
	end
	state.Elapsed += math.max(0, dt)
	while not state.Done and state.Elapsed >= state.Seq.Shots[state.Index].Duration do
		state.Elapsed -= state.Seq.Shots[state.Index].Duration
		state.Index += 1
		if state.Index > #state.Seq.Shots then
			state.Index = #state.Seq.Shots
			state.Elapsed = state.Seq.Shots[state.Index].Duration
			state.Done = true
			state.Reason = "completed"
		end
	end
	return state
end

-- Raison : "skipped" (bouton), "interrupted" (mort, portail, début de manche...).
function CinematicLogic.End(state: State, reason: string): State
	if not state.Done then
		state.Done = true
		state.Reason = reason
	end
	return state
end

function CinematicLogic.Skip(state: State): State
	return CinematicLogic.End(state, "skipped")
end

-- Progression globale 0..1.
function CinematicLogic.Progress(state: State): number
	local total = CinematicLogic.TotalDuration(state.Seq)
	if total <= 0 then
		return 1
	end
	local before = 0
	for i = 1, state.Index - 1 do
		before += state.Seq.Shots[i].Duration
	end
	return math.clamp((before + state.Elapsed) / total, 0, 1)
end

-- Fraction (0..1) dans le plan courant, pour interpoler la caméra.
function CinematicLogic.ShotAlpha(state: State): number
	local shot = state.Seq.Shots[state.Index]
	return math.clamp(state.Elapsed / shot.Duration, 0, 1)
end

-- Reprise : un skip ou une fin normale comptent comme « vu » ; une interruption rejouera la prochaine fois.
function CinematicLogic.ShouldMarkSeen(reason: string?): boolean
	return reason == "completed" or reason == "skipped"
end

-- Clés valides pour le marquage « vu » (liste blanche côté serveur) pour la saison donnée.
function CinematicLogic.SeenKeys(seasonId: number): { [string]: boolean }
	return { intro = true, tutorial = true, hill = true, ["season" .. tostring(seasonId)] = true }
end

-- Interpolation linéaire de deux vecteurs {x,y,z} avec lissage.
function CinematicLogic.Lerp(a: Vec, b: Vec, t: number): Vec
	local s = t * t * (3 - 2 * t)
	return { a[1] + (b[1] - a[1]) * s, a[2] + (b[2] - a[2]) * s, a[3] + (b[3] - a[3]) * s }
end

-- Première cinématique à jouer parmi `order`, selon réglages, éléments déjà vus et contexte.
-- ctx : { InArena: boolean, SeasonId: number, NextMode: string }
function CinematicLogic.NextToPlay(cfg: { [string]: any }, seen: { [string]: boolean }, order: { string }, ctx: { InArena: boolean, SeasonId: number, NextMode: string }): string?
	if cfg.Enabled == false then
		return nil
	end
	for _, name in ipairs(order) do
		local seenKey = if name == "season" then "season" .. tostring(ctx.SeasonId) else name
		local cfgKey = if name == "intro" then "Intro" elseif name == "tutorial" then "Tutorial" elseif name == "season" then "Season" else "Hill"
		if cfg[cfgKey] ~= false and not seen[seenKey] then
			local ok = true
			if name == "hill" then
				ok = ctx.InArena and ctx.NextMode == "HILL"
			else
				ok = not ctx.InArena -- intro / tutoriel / saison : jamais en pleine arène
			end
			if ok then
				return name
			end
		end
	end
	return nil
end

return CinematicLogic
