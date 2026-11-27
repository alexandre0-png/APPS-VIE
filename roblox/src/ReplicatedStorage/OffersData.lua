-- ModuleScript : ReplicatedStorage/Shared/OffersData
-- LOT 16 : DONNEES PURES des offres contextuelles à l'écran (une carte à la fois, fermable d'un geste). Aucune instance, aucun service Roblox.
-- Règles (décisions utilisateur, ACHATS_DEFINITIONS « Règles communes ») : jamais de fausse urgence, aucun minuteur affiché, aucune promesse de gain,
-- 3 offres par session, 300 s entre deux, aucune offre juste après un achat, jamais ce que le joueur possède, jamais un achat sans id ou masqué (PolicyService),
-- jamais Secret / Exclusif / Divin en offre contextuelle.
local OffersData = {}

OffersData.MAX = 3 -- offres par session (Config.OFFERS.max l'emporte s'il existe)
OffersData.GAP = 300 -- secondes minimales entre deux offres affichées (Config.OFFERS.gap)
OffersData.GRACE = 90 -- aucune offre pendant les premières secondes de la session (Config.OFFERS.graceSeconds)
OffersData.AFTER_BUY = 600 -- aucune offre pendant ce délai après TOUT achat (pas de relance incitative)
OffersData.TTL = 45 -- secondes avant que la carte se range d'elle-même (aucun compte à rebours affiché)
OffersData.STARTER_DAYS = 3 -- le Pack de départ n'est proposé que pendant les 3 premiers jours de jeu
OffersData.EGG_MIN_TIER, OffersData.EGG_MAX_TIER = 2, 4 -- « petite offre d'œuf » : Peu commun à Épique (15 à 49 R$)
OffersData.EGG_MIN_HATCHED = 5 -- (proposé) l'offre d'œuf n'apparaît qu'après 5 éclosions : pas pour un tout nouveau joueur
OffersData.TITLE_MAX, OffersData.TEXT_MAX = 28, 90

-- Contexte qui interdit toute offre (et fait ranger la carte ouverte) : vol, cinématique, combat, œuf porté, poursuite, éclosion en cours, chrono de château, menu ouvert.
OffersData.BUSY = { "flying", "cinematic", "inCombat", "carrying", "chased", "hatching", "castleTimer", "menuOpen" }

-- Offres fixes, par ordre de priorité. `when` = drapeau de ctx qui les déclenche ; `kind` = « product » (Config.PRODUCTS) ou « pass » (Config.PASSES).
-- `calm` = n'apparaît que dans un moment calme (ctx.calm), jamais en pleine action. `random` est lu dans la définition du Config (PolicyService).
OffersData.LIST = {
	{ id = "baseFull", key = "ExtraSlots", kind = "pass", when = "baseFull", title = "+4 emplacements", text = "Ta base est pleine. Ajoute 4 emplacements d'œufs, pour toujours." },
	{ id = "firstLegend", key = "DoubleLuck", kind = "product", when = "firstLegend", title = "Double chance", text = "30 min de points de chance doublés (70 points au maximum). Rien n'est garanti." },
	{ id = "streak", key = "StreakRestore", kind = "product", when = "streakAtRisk", title = "Sauvetage de série", text = "Rétablis ta série de connexion. Il existe un moyen gratuit : les 3 quêtes du jour." },
	{ id = "quota", key = "ArenaTickets", kind = "product", when = "towerQuotaExhausted", title = "Ticket d'arène", text = "5 combats de tour de plus aujourd'hui. Aucune force n'est vendue." },
	{ id = "starter", key = "StarterPack", kind = "product", when = "starterDays", calm = true, title = "Pack de départ", text = "Une seule fois : 20 000 pièces, 3 œufs Rares et une potion de chance." },
}

-- Offre d'œuf adaptée au palier : cherche l'achat dont eggTier == t (clé « EggR<t> » d'abord).
OffersData.EGG = { id = "egg", when = "eggOffer", calm = true, kind = "product", title = "Un œuf pour ta base" }

OffersData.EGG_TEXT = "Un œuf de rareté fixe %s, posé dans ta base. Espèce et taille tirées au sort."

-- Mots interdits dans les textes d'offre (fausse urgence, pression, promesse). Vérifié par les tests.
OffersData.FORBIDDEN_WORDS = { "dernière chance", "dépêche", "vite", "limité", "limitée", "stock", "expire", "plus que", "maintenant ou jamais", "offre spéciale", "promo", "-50", "gratuit à vie", "tu vas obtenir", "garanti !" }

return OffersData
