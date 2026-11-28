# Lot 9 : revue QA et sécurité tracée (10 raretés, migration v11, rythme, tapis, mesures) — 2026-11-28

Périmètre : `Data.lua` (migration v10 -> v11, `merge`, assainissement des emplacements / tapis privé / journal des vols / quêtes, sauvegarde `UpdateAsync`, version plus récente = lecture seule), `Config.TIER_MIGRATE`, `liveEggTier` / `nextLiveTier` / `foldWeights`, `Rules.rollPet` / `tierWeights` (amélioration d'un cran seulement), `Config.effectiveUp` (`needDiscovered`), `BOOST_CAP`, tapis (`Belt.lua`, tables standard / dorée, tapis privé), télémétrie `tele.log`. Revue par **lecture du code réel** + tests lupa (`run.luau` : migrations, « Lot 9 », probabilités annoncées = tirage réel ; `sim_economy.py`). **Rien n'a été joué dans Studio.**

**Bilan : 0 défaut critique ; 1 défaut élevé trouvé et corrigé (A5, commit d326132).**

| Sujet | Risque | Constat | État |
|---|---|---|---|
| Migration v11 | Perte de pets / œufs / pièces, double migration | Chaîne `migrate` versionnée, idempotente ; raretés remappées par `TIER_MIGRATE` ; aucun pet, œuf, pièce, reçu ni jeton perdu ; niveau de maison plancher (`baseLevelFloor`). Profil d'une version plus récente : **lecture seule** (aucune écriture). | OK (tests de migration v8 -> v13) |
| Données forgées / corrompues | NaN, rareté hors bornes, champs inconnus | `merge` : rareté entière 1..#TIERS, `Data.validPet`, `o` / `ov` bornés, `rv` / `rvAt` assainis ; champ invalide = valeur neuve. | OK |
| Espèces d'événement | Espèces Exclusif d'événement / de saison tirées toute l'année | `rollPet` tirait uniformément toutes les espèces de la rareté, y compris celles marquées `event`. | **Élevé, corrigé (A5)** : tirage limité aux fenêtres ouvertes, œuf Exclusif vendu seulement en fenêtre, 200 000 tirages hors fenêtre testés. |
| Amélioration / chance | Bonus payants cumulés, rareté jamais découverte | Une seule amélioration d'un cran (jamais de rétrogradation), plafond 70 points, bonus payants plafonnés ensemble (`BOOST_CAP.paidUp`), pas d'amélioration vers une rareté non découverte. | OK |
| Probabilités affichées | Écart affiché / réel | `Reveal.probability` = loi de `rollPet` (balayage exact et simulation) ; fenêtres A5 incluses. | OK |
| Tapis privé | Œufs en attente infinis, production hors ligne | 3 en attente au plus, aucune production hors ligne, table standard. | OK |
| Télémétrie | Données personnelles | Compteurs agrégés, aucun nom ni texte libre ; file bornée par joueur. | OK |

## Limites connues
- Rythme réel (temps jusqu'au premier Mythique, etc.) mesuré par simulation seulement (`LOT16_ECARTS.md`).
