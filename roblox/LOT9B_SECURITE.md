# Lot 9b : revue QA et sécurité tracée (calendrier des œufs sur 30 jours, rattrapages, reçus) — 2026-11-28

Périmètre : `Calendar.lua` (pur : `check`, `apply`, `plan`, `draw`, `normalize`), `Lot7.Cal.claim` et `actions.calClaim` (`Main.server.lua`), produit `CalendarCatchup` (3736695392) livré par `ProcessReceipt` / `L16.grant`, PolicyService (`Lot7.awaitPolicy`) pour le tirage payant du jour 30, éligibilité (âge du compte, minutes de jeu), titres `cal10/25/30`, monnaies `scrolls`, `plumes`, `fightTokens`, `cosm`. Revue par **lecture du code réel** + tests lupa (`run.luau` « Lot 9b », `lot11.luau` J30). **Rien n'a été joué dans Studio.**

**Bilan : 0 défaut critique ou élevé.**

| Sujet | Risque | Constat | État |
|---|---|---|---|
| Arguments forgés | jour hors bornes, mode inconnu | `calClaim` exige une table ; `how` hors liste = « today » ; `Calendar.check` valide jour, mode, éligibilité, jetons de rattrapage. | OK |
| Double réclamation | Deux demandes simultanées, rejeu | Verrou `s.calBusy` ; ordre « jour marqué -> sauvegarde -> octroi » : si la sauvegarde échoue, l'état d'avant est restauré et rien n'est donné. | OK |
| Profil remplacé pendant la sauvegarde | Récompense versée dans un profil orphelin | La renaissance ne remplace plus `s.data` (correctif 4c8bcf9) : le profil réclamé reste celui de la session ; `sessions[s.player] ~= s` et `s.leaving` sont relus après l'attente de PolicyService. | OK |
| Reçus Robux | Double crédit du rattrapage | `receipts` (identifiant de reçu) : un reçu rejoué = 1 seul jeton ; livré même base pleine (jeton, pas d'œuf). | OK (tests 9b) |
| Hasard payant | Tirage du jour 30 payé par un compte restreint | Rattrapage payé d'un jour à tirage : seulement si PolicyService confirme « non restreint » (échec ou attente = refus). | OK |
| Base pleine | Œuf perdu | Œuf du calendrier refusé avant marquage si base ET sac pleins (« rien n'est perdu »). | OK |
| Calendrier et renaissance | Calendrier remis à zéro | Avant le correctif, `cal`, `calStreak`, `calLast`, titres et monnaies du calendrier étaient perdus à la renaissance. | **Corrigé (4c8bcf9)**, testé `rebirth_e2e.luau` |

## Limites connues
- Affichage mural du calendrier et sons des paliers : à vérifier dans Studio (A_FAIRE §1quinquies).
