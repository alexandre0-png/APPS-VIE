--!strict
-- Définition des armes (données pures, sans dépendance Roblox).
-- Les modèles sont décrits par une liste de blocs ; la première pièce est le "Handle".
-- Convention : le Handle est tenu au centre, l'axe Y est la verticale de l'arme,
-- le canon des armes à feu pointe vers -Z.

export type PartSpec = {
	Size: { number },
	Offset: { number },
	Rot: { number }?,
	Color: string,
	Material: string,
	Neon: boolean?,
	Shape: string?,
}

export type WeaponDef = {
	Id: string,
	Name: string,
	Description: string,
	Kind: string, -- "Melee" | "Slam" | "Hitscan" | "Shotgun" | "Projectile"
	Class: string, -- "Melee" | "Ranged"
	Rarity: string,
	Price: number,
	LevelReq: number,
	Damage: number,
	Cooldown: number,
	Range: number,
	Arc: number?,
	Radius: number?,
	HeadshotMult: number?,
	BackstabMult: number?,
	Speed: number?,
	Gravity: number?,
	Pellets: number?,
	Spread: number?,
	Splash: number?,
	Knockback: number?,
	LifeSteal: number?,
	Accent: string,
	Parts: { PartSpec },
}

local Weapons = {}

local list: { WeaponDef } = {
	{
		Id = "sword",
		Name = "Épée de fer",
		Description = "Fiable et équilibrée. L'arme de tous les débuts.",
		Kind = "Melee", Class = "Melee", Rarity = "Commune", Price = 0, LevelReq = 1,
		Damage = 26, Cooldown = 0.5, Range = 7.5, Arc = 110, Knockback = 18,
		Accent = "D0D6DE",
		Parts = {
			{ Size = { 0.45, 1.3, 0.45 }, Offset = { 0, 0, 0 }, Color = "6B4A2B", Material = "Wood" },
			{ Size = { 1.9, 0.3, 0.5 }, Offset = { 0, 0.8, 0 }, Color = "8A8F98", Material = "Metal" },
			{ Size = { 0.5, 3.6, 0.14 }, Offset = { 0, 2.7, 0 }, Color = "D0D6DE", Material = "Metal" },
		},
	},
	{
		Id = "bow",
		Name = "Arc de chasseur",
		Description = "Flèches à trajectoire courbe. Visez un peu plus haut de loin.",
		Kind = "Projectile", Class = "Ranged", Rarity = "Commune", Price = 0, LevelReq = 1,
		Damage = 30, Cooldown = 0.85, Range = 300, Speed = 130, Gravity = 40, HeadshotMult = 1.5,
		Accent = "C89B5B",
		Parts = {
			{ Size = { 0.3, 1.0, 0.3 }, Offset = { 0, 0, 0 }, Color = "5A3A1E", Material = "Wood" },
			{ Size = { 0.25, 1.7, 0.25 }, Offset = { 0, 1.2, -0.25 }, Rot = { -22, 0, 0 }, Color = "8B5A2B", Material = "Wood" },
			{ Size = { 0.25, 1.7, 0.25 }, Offset = { 0, -1.2, -0.25 }, Rot = { 22, 0, 0 }, Color = "8B5A2B", Material = "Wood" },
			{ Size = { 0.06, 3.3, 0.06 }, Offset = { 0, 0, 0.35 }, Color = "EDE6D3", Material = "Fabric" },
		},
	},
	{
		Id = "pistol",
		Name = "Pistolet photon",
		Description = "Facile à prendre en main : tir instantané et précis. Les tirs à la tête font très mal.",
		Kind = "Hitscan", Class = "Ranged", Rarity = "Commune", Price = 150, LevelReq = 1,
		Damage = 17, Cooldown = 0.32, Range = 220, HeadshotMult = 1.7,
		Accent = "35E0FF",
		Parts = {
			{ Size = { 0.35, 0.9, 0.5 }, Offset = { 0, 0, 0 }, Color = "2E3440", Material = "Metal" },
			{ Size = { 0.35, 0.4, 1.8 }, Offset = { 0, 0.55, -0.6 }, Color = "4C566A", Material = "Metal" },
			{ Size = { 0.2, 0.2, 0.3 }, Offset = { 0, 0.55, -1.6 }, Color = "35E0FF", Material = "Neon", Neon = true },
		},
	},
	{
		Id = "katana",
		Name = "Katana de l'aube",
		Description = "Frappes très rapides, portée généreuse.",
		Kind = "Melee", Class = "Melee", Rarity = "Rare", Price = 450, LevelReq = 3,
		Damage = 19, Cooldown = 0.28, Range = 7.5, Arc = 100, Knockback = 10,
		Accent = "FF6B81",
		Parts = {
			{ Size = { 0.4, 1.4, 0.4 }, Offset = { 0, 0, 0 }, Color = "2B2B35", Material = "Fabric" },
			{ Size = { 1.2, 0.2, 0.7 }, Offset = { 0, 0.8, 0 }, Color = "FFD166", Material = "Metal" },
			{ Size = { 0.3, 4.0, 0.1 }, Offset = { 0, 2.9, 0 }, Color = "F4F7FA", Material = "Metal" },
		},
	},
	{
		Id = "hammer",
		Name = "Marteau du titan",
		Description = "Lent mais dévastateur : dégâts de zone et projection.",
		Kind = "Slam", Class = "Melee", Rarity = "Rare", Price = 1000, LevelReq = 6,
		Damage = 52, Cooldown = 1.25, Range = 8, Radius = 10, Knockback = 55,
		Accent = "FFA94D",
		Parts = {
			{ Size = { 0.5, 2.0, 0.5 }, Offset = { 0, 0, 0 }, Color = "6B4A2B", Material = "Wood" },
			{ Size = { 1.8, 1.3, 1.3 }, Offset = { 0, 1.5, 0 }, Color = "7D8590", Material = "Slate" },
			{ Size = { 1.9, 0.25, 1.4 }, Offset = { 0, 1.5, 0 }, Color = "FFA94D", Material = "Metal" },
		},
	},
	{
		Id = "carbine",
		Name = "Carabine Marée",
		Description = "Rafale précise et régulière : maintenez pour arroser.",
		Kind = "Hitscan", Class = "Ranged", Rarity = "Rare", Price = 1400, LevelReq = 7,
		Damage = 11, Cooldown = 0.16, Range = 170, HeadshotMult = 1.5,
		Accent = "35C9D8",
		Parts = {
			{ Size = { 0.4, 0.9, 0.7 }, Offset = { 0, 0, 0 }, Color = "2B3A42", Material = "Metal" },
			{ Size = { 0.35, 0.45, 2.6 }, Offset = { 0, 0.55, -1.1 }, Color = "3B4F5C", Material = "Metal" },
			{ Size = { 0.2, 0.2, 0.4 }, Offset = { 0, 0.55, -2.5 }, Color = "35C9D8", Material = "Neon", Neon = true },
			{ Size = { 0.3, 0.7, 0.4 }, Offset = { 0, -0.6, -0.4 }, Color = "20282D", Material = "Metal" },
		},
	},
	{
		Id = "dagger",
		Name = "Dague de l'ombre",
		Description = "Cadence folle. Dégâts x2,2 dans le dos de l'adversaire.",
		Kind = "Melee", Class = "Melee", Rarity = "Épique", Price = 1800, LevelReq = 9,
		Damage = 13, Cooldown = 0.2, Range = 5.5, Arc = 90, BackstabMult = 2.2, Knockback = 4,
		Accent = "9B5DE5",
		Parts = {
			{ Size = { 0.35, 0.9, 0.35 }, Offset = { 0, 0, 0 }, Color = "1B1B26", Material = "Fabric" },
			{ Size = { 1.0, 0.2, 0.4 }, Offset = { 0, 0.55, 0 }, Color = "9B5DE5", Material = "Neon", Neon = true },
			{ Size = { 0.3, 1.9, 0.1 }, Offset = { 0, 1.6, 0 }, Color = "5B3E8F", Material = "Metal" },
		},
	},
	{
		Id = "staff",
		Name = "Bâton de braise",
		Description = "Boule de feu explosive : dégâts de zone à l'impact.",
		Kind = "Projectile", Class = "Ranged", Rarity = "Épique", Price = 2200, LevelReq = 11,
		Damage = 38, Cooldown = 1.05, Range = 260, Speed = 90, Gravity = 0, Splash = 9,
		Accent = "FF5E1A",
		Parts = {
			{ Size = { 0.4, 4.2, 0.4 }, Offset = { 0, 0, 0 }, Color = "4A2E1A", Material = "Wood" },
			{ Size = { 1.1, 1.1, 1.1 }, Offset = { 0, 2.5, 0 }, Color = "FF5E1A", Material = "Neon", Neon = true, Shape = "Ball" },
			{ Size = { 1.5, 0.25, 1.5 }, Offset = { 0, 1.9, 0 }, Color = "FFC857", Material = "Metal" },
		},
	},
	{
		Id = "shotgun",
		Name = "Tonnerre",
		Description = "7 plombs : redoutable à courte portée.",
		Kind = "Shotgun", Class = "Ranged", Rarity = "Épique", Price = 3000, LevelReq = 14,
		Damage = 9, Cooldown = 0.95, Range = 70, Pellets = 7, Spread = 6, HeadshotMult = 1.3,
		Accent = "FFC857",
		Parts = {
			{ Size = { 0.45, 1.0, 0.6 }, Offset = { 0, 0, 0 }, Color = "5A3A1E", Material = "Wood" },
			{ Size = { 0.5, 0.5, 2.6 }, Offset = { 0, 0.6, -1.0 }, Color = "3B4252", Material = "Metal" },
			{ Size = { 0.55, 0.15, 0.6 }, Offset = { 0, 0.9, -0.3 }, Color = "FFC857", Material = "Metal" },
		},
	},
	{
		Id = "assault",
		Name = "Fusil Brasier",
		Description = "Cadence soutenue et dégâts solides à moyenne portée.",
		Kind = "Hitscan", Class = "Ranged", Rarity = "Épique", Price = 3800, LevelReq = 16,
		Damage = 15, Cooldown = 0.2, Range = 150, HeadshotMult = 1.6,
		Accent = "FF8A3D",
		Parts = {
			{ Size = { 0.45, 1.0, 0.8 }, Offset = { 0, 0, 0 }, Color = "5A3A1E", Material = "Wood" },
			{ Size = { 0.4, 0.5, 2.8 }, Offset = { 0, 0.6, -1.2 }, Color = "3B4252", Material = "Metal" },
			{ Size = { 0.2, 0.2, 0.4 }, Offset = { 0, 0.6, -2.7 }, Color = "FF8A3D", Material = "Neon", Neon = true },
			{ Size = { 0.3, 0.8, 0.5 }, Offset = { 0, -0.7, -0.5 }, Color = "2E3440", Material = "Metal" },
		},
	},
	{
		Id = "rail",
		Name = "Rail de l'éclipse",
		Description = "Un tir, une élimination à la tête. Rechargement long.",
		Kind = "Hitscan", Class = "Ranged", Rarity = "Légendaire", Price = 5000, LevelReq = 18,
		Damage = 68, Cooldown = 1.7, Range = 400, HeadshotMult = 2.0,
		Accent = "7DF9FF",
		Parts = {
			{ Size = { 0.5, 1.0, 0.7 }, Offset = { 0, 0, 0 }, Color = "20232B", Material = "Metal" },
			{ Size = { 0.4, 0.4, 3.6 }, Offset = { 0, 0.6, -1.4 }, Color = "2F3542", Material = "Metal" },
			{ Size = { 0.2, 0.2, 3.2 }, Offset = { 0, 0.6, -1.4 }, Color = "7DF9FF", Material = "Neon", Neon = true },
			{ Size = { 0.3, 0.3, 0.7 }, Offset = { 0, 1.0, -0.2 }, Color = "20232B", Material = "Metal" },
		},
	},
	{
		Id = "sovereign",
		Name = "Lame du Souverain",
		Description = "Large balayage et vol de vie : 30% des dégâts soignent.",
		Kind = "Melee", Class = "Melee", Rarity = "Légendaire", Price = 7500, LevelReq = 25,
		Damage = 34, Cooldown = 0.55, Range = 9, Arc = 140, Knockback = 28, LifeSteal = 0.3,
		Accent = "FFD700",
		Parts = {
			{ Size = { 0.5, 1.5, 0.5 }, Offset = { 0, 0, 0 }, Color = "7A1F2B", Material = "Fabric" },
			{ Size = { 2.6, 0.35, 0.6 }, Offset = { 0, 0.95, 0 }, Color = "FFD700", Material = "Metal" },
			{ Size = { 0.7, 4.6, 0.16 }, Offset = { 0, 3.3, 0 }, Color = "FFF3B0", Material = "Neon", Neon = true },
		},
	},
}

local byId: { [string]: WeaponDef } = {}
for _, def in ipairs(list) do
	byId[def.Id] = def
end

Weapons.List = list
Weapons.StarterOwned = { "sword", "bow" }
Weapons.StarterLoadout = { "sword", "bow" }

function Weapons.Get(id: string): WeaponDef?
	return byId[id]
end

function Weapons.IsValid(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

return Weapons
