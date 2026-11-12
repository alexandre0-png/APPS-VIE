--!strict
-- Univers et histoire : les Royaumes du Brasier, quatre héros jouables, cinq chapitres de la Chronique.
-- Données pures (aucune dépendance Roblox).
local Lore = {}

Lore.Intro = {
	Title = "LES ROYAUMES DU BRASIER",
	Text = "Le Brasier s'éteint. Dans l'Arène des Légendes, chaque victoire rallume une flamme. Choisis ton héros.",
}

export type Hero = { Key: string, Name: string, Epithet: string, Color: string, Story: string }
export type Chapter = {
	Id: string, Title: string, Text: string, Stat: string, Target: number,
	Coins: number, XP: number, Unlock: string?,
}

Lore.Heroes = {
	{ Key = "kael", Name = "Kael", Epithet = "Gardien de la Braise", Color = "FF8A3D", Story = "Dernier veilleur du feu sacré, il combat pour le ranimer." },
	{ Key = "mira", Name = "Mira", Epithet = "des Marées", Color = "35C9D8", Story = "Elle suit le courant de l'arène comme d'autres suivent une étoile." },
	{ Key = "orin", Name = "Orin", Epithet = "l'Ombre", Color = "9B5DE5", Story = "On dit qu'il a vu la tour silencieuse. Il n'en parle jamais." },
	{ Key = "zyla", Name = "Zyla", Epithet = "l'Éclat", Color = "FFD166", Story = "Née de l'orbe éclatée, elle brille quand elle gagne." },
} :: { Hero }

Lore.Chapters = {
	{ Id = "c1", Title = "L'Appel de la Braise", Text = "Une étincelle te guide jusqu'au portail violet. L'arène t'attend.", Stat = "Level", Target = 2, Coins = 100, XP = 60 },
	{ Id = "c2", Title = "Le Pacte des Marées", Text = "Rouges et Bleus s'affrontent, mais tous cherchent la même flamme. Prouve ta valeur.", Stat = "Kills", Target = 10, Coins = 200, XP = 120, Unlock = "orin" },
	{ Id = "c3", Title = "La Tour Silencieuse", Text = "Au centre, la tour garde l'orbe de rage. Gagne trois manches pour y entrer.", Stat = "Wins", Target = 3, Coins = 350, XP = 200 },
	{ Id = "c4", Title = "L'Orbe Éclatée", Text = "Un éclat de l'orbe s'attache à ton nom. Une héroïne s'éveille.", Stat = "Level", Target = 12, Coins = 500, XP = 300, Unlock = "zyla" },
	{ Id = "c5", Title = "Légende de l'Arène", Text = "Le Brasier brûle de nouveau. Les bardes chanteront tes 150 victoires.", Stat = "Kills", Target = 150, Coins = 1500, XP = 800 },
} :: { Chapter }

local heroByKey: { [string]: Hero } = {}
for _, h in ipairs(Lore.Heroes) do
	heroByKey[h.Key] = h
end
local chapterById: { [string]: Chapter } = {}
for _, c in ipairs(Lore.Chapters) do
	chapterById[c.Id] = c
end

function Lore.Hero(key: string): Hero?
	return heroByKey[key]
end

function Lore.Chapter(id: string): Chapter?
	return chapterById[id]
end

-- Progression d'un chapitre à partir des statistiques du joueur.
function Lore.Progress(chapter: Chapter, stats: { [string]: number }): number
	return math.min(chapter.Target, math.max(0, stats[chapter.Stat] or 0))
end

-- Un héros est disponible s'il n'est verrouillé par aucun chapitre, ou si ce chapitre est récupéré.
function Lore.IsHeroUnlocked(key: string, claimed: { [string]: boolean }): boolean
	for _, c in ipairs(Lore.Chapters) do
		if c.Unlock == key then
			return claimed[c.Id] == true
		end
	end
	return heroByKey[key] ~= nil
end

return Lore
