# Passe de combat (lot 16) : notes d'intégration

Modules PURS, non branchés : `src/ReplicatedStorage/Season.lua` (logique), `src/ReplicatedStorage/SeasonData.lua` (données). Tests : `tests/season.luau`, lanceur `tests/run_season.py` (101 assertions). Rien n'a été joué dans Studio.

## API

```lua
local Season = require(Shared.Season)
local S = Season.new(Config, require(Shared.SeasonData))   -- Config : TIERS (raretés par NOM) et PETS
```
Le serveur passe `nowUtc` (secondes, `os.time()`). Aucune fonction n'octroie : elle renvoie `grants` à appliquer.

| Fonction | Rôle |
|---|---|
| `S.currentSeason(now)` | `{ n, theme, name, startsAt, endsAt, dayIndex, daysLeft }` ; `n = 0` avant le début (`preseason`) |
| `S.migrate(profil, now)` | crée / assainit `profil.season`, verse l'ancien `profil.seasonXp` (lot 15) puis le remet à 0, bascule de saison. Idempotent. Appelée par toutes les autres |
| `S.addXp(profil, source, now)` | sources `pve`, `pvp`, `duel`, `daily`, `weekly`, `hatch` ; renvoie `{ ok, gained, xp, tier, tiersUp, capped }` ; plafond 400/jour UTC (sauf `weekly`) |
| `S.hatchQualifies(tierIdx)` | l'éclosion est-elle Épique ou mieux (par nom) |
| `S.claim(profil, tier, "free"/"premium", now, which)` | idempotent ; `which = "prev"` pour la saison précédente pendant la grâce ; raisons : `bad locked premium already none expired noseason` |
| `S.claimAll(profil, now, which)` | tout ce qui est réclamable ; `{ grants, claimed }` |
| `S.buyPremium(profil, kind, now)` | `premium` (399), `premiumPlus` (799), `upgradePlus` (400) ; crédite UNE fois les paliers premium déjà atteints ; raisons : `kind noseason owned plusUsed needPremium` |
| `S.recap(profil, now)` / `S.ackRecap(profil, now)` | écran de fin de saison (paliers, non réclamé, cosmétiques perdus, jours de grâce) / acquittement |
| `S.view(profil, now)` | données pour l'UI (30 lignes, XP, jours restants, premium) |
| `S.rewardFor(n, tier, track)`, `S.tierOf(xp)`, `S.xpForTier(t)` | utilitaires |

`grants` (liste) : `{ kind = "coins", minutes }` (minutes de revenu, le serveur applique son plancher) ; `{ kind = "egg", tier, name, n }` (indice via `Config.TIERS`, à placer base / sac / coffre de débordement) ; `{ kind = "token", n }` (jetons de combat) ; `{ kind = "scroll", n }` (parchemins d'XP de pet) ; `{ kind = "cosmetic" | "aura", id = "s<n>_<clé>", label, season }` ; `{ kind = "species", name, tier }` (espèce Exclusif de la saison). Si l'espèce n'existe pas dans `Config.PETS` avec la rareté Exclusif, `claim` renvoie à la place un cosmétique `s<n>_trophy` (`fallback = true`).

## Champs de profil

`profil.season = { n, xp, day, dayXp, claimedFree, claimedPrem, premium, plus, prev }`
- `claimedFree` / `claimedPrem` : masques de bits (bit t-1 = palier t réclamé), entiers < 2^30.
- `premium` : numéro de la saison dont la piste premium est achetée (0 = non). `plus` : saison où Premium+ / complément a été utilisé (une fois par saison). Ces deux champs complètent la liste de la spec (`plus` est ajouté).
- `prev` : saison précédente gardée 7 jours (`{ n, xp, claimedFree, claimedPrem, premium, seen }`), sinon `nil`.
- `profil.seasonXp` (lot 15) : versé dans `season.xp` à la première migration puis 0 ; garder le champ dans `Data.lua` (assaini) pour les anciens profils.

## Lignes à ajouter par l'intégrateur

- **Config** : `Config.SEASON = SeasonData.SEASON` (ou `require`), `Config.SEASONS = SeasonData.SEASONS` ; `Config.PRODUCTS.SeasonPremium` (399), `SeasonPremiumPlus` (799), `SeasonUpgradePlus` (400) avec leurs ids ; texte sans le mot « plafond » d'achat.
- **Data** : `season` ajouté au profil neuf `{}` et à la migration (`S.migrate` suffit : appeler `Season.migrate` à la connexion) ; sanitize optionnel (déjà fait par `migrate`).
- **Main** : `local Season = require(Shared.Season).new(Config, require(Shared.SeasonData))` ; à la connexion `migrate` + `recap` ; actions client `seasonClaim { tier, track, prev }` (le serveur rappelle `claim`, jamais le client) et `seasonAck` ; `ProcessReceipt` : produit saison -> `buyPremium(kind)`, appliquer `grants` ; un reçu rejoué ne crédite pas deux fois (`owned` / `plusUsed` + reçu déjà traité). Contrôle de place avant l'invite d'achat inutile ici (aucun œuf aléatoire) mais les œufs des grants vont au sac / coffre de débordement.
- **build_place.py SHARED** : `Season`, `SeasonData`.
- **tests/run.luau** : `luau.load(fs.readFile("roblox/tests/season.luau"), { debugName = "season" })()({ check = check, suite = suite, luau = luau, fs = fs })`. **tools/run_tests.py** : idem (ou appeler `run_season.py`).
- **check.py** : rien de spécial (modules sans service Roblox).

## Sources d'XP à câbler dans Main (appeler `Season.addXp(profil, source, os.time())`, sur chaque événement validé côté serveur)

| Événement | Source |
|---|---|
| victoire PvE (tour / château) | `pve` |
| victoire PvP asynchrone ou duel | `pvp` / `duel` |
| quête du jour terminée (au même endroit que son octroi) | `daily` |
| quêtes de la semaine 7/7 (remplace l'ajout à `seasonXp`, ligne ~4054 de Main) | `weekly` |
| éclosion Épique+ (`S.hatchQualifies(rareté)`) | `hatch` |

## Rythme mesuré (joueur-robot, saison de 60 jours, 16 500 XP au total)

- actif régulier (6 jours/7, plafond atteint) : palier 20 au jour 27, **palier 30 au jour 43** ;
- occasionnel (5 jours/7, ~350 XP) : palier 20 au jour 36, **palier 30 au jour 57** ;
- très peu actif (2 jours/7) : palier 9 à la fin, ne termine pas.
La piste gratuite a un cadeau à chaque palier jusqu'au 20, puis aux paliers 25 et 30 (Légendaire).

## Décisions

- `weekly` n'entre pas dans le plafond de 400/jour (une fois par semaine) ; les autres sources oui.
- Premium+ / complément : +10 paliers (XP portée au seuil), puis crédit unique des récompenses premium des paliers atteints.
- Bascule : aucune XP ne traverse deux saisons ; la saison précédente reste réclamable 7 jours (`which = "prev"`), puis `expired`. Absent plus d'une saison : perdu.
- Espèces de saison 1 à 6 : noms inventés dans `SeasonData.SPECIES` ; aucune n'existe encore dans `Config.PETS` (repli en trophée) : à créer avec la rareté Exclusif pour les activer.
- Date de début : 2026-12-01 00:00 UTC (`SEASON.start`), à valider.
