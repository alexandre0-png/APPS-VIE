# Lot 17 (idées 1, 2, 3) : revue de sécurité courte — 2026-11-28

Revue par lecture du code intégré et par les tests lupa (runtime factice, vrai `Main.server.lua` + `Data.lua`). **Rien n'a été testé dans Studio ni avec de vrais joueurs malveillants.**

## Idée 1 : onboarding en 5 étapes (`Onboarding.lua`, champ de profil `onb`, action `onbSkip`)

| Point | Constat |
|---|---|
| Remote | Une seule action nouvelle, `onbSkip` (sans argument lu). Elle ne fait que TERMINER le tutoriel (`skip = true`), idempotente (refusée si déjà terminé ou passé). Aucun gain, aucune récompense. Débit borné par le dispatcher (`lastAct` 0,08 s). |
| Faits | Le client n'envoie AUCUN fait : présence dans la base (`inPlot` sur la position serveur), éclosions (`d.hatched`), niveau de maison (`s.baseLevel`), revenu réellement versé par le tick, combat de tour ACCEPTÉ. Étapes dans l'ordre, jamais de saut, 3 s minimum par étape, valeurs non numériques / NaN / infinies / négatives refusées. |
| Profil | `onb` assaini à chaque lecture (`Onboarding.migrate`, idempotente, testée sur 12 profils, profils corrompus compris) ; jamais réinitialisé ; v13 inchangée (un serveur ancien ignore le champ, sans perte : au pire il le supprime, et le joueur est alors classé « existant » s'il a éclos ou joué 120 s). |
| Renaissance | `onb` n'est pas dans la liste blanche de remise à zéro du correctif 4c8bcf9 (`coins`, `up`, `slots`, `equip`, `pendingAway`, `last`) : il survit, un tutoriel fini ne repart jamais. Testé (bout en bout). |
| Télémétrie | 6 noms fermés ajoutés à `Telemetry.ONBOARDING` (`tut_step2..5`, `tut_done`, `tut_skip`) : au plus un événement par étape franchie (3 s minimum entre deux) et un pour « Passer » (une fois) ; même file que le reste (<= 1 événement / s / joueur). |
| Mémoire | Un seul compteur de session (`s.onbT`), libéré avec la session. Tick serveur : 1 lecture de position par seconde et par joueur en tutoriel seulement. |

**Bilan idée 1 : 0 défaut critique, élevé ou moyen.**
