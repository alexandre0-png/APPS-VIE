# Lot 10 : revue QA et sécurité tracée (compteur « 1 sur N », écran d'éclosion, intro et effets de combat, sons, icônes) — 2026-11-28

Périmètre : `Odds.lua` (pur), calcul et gel du compteur à l'éclosion (`hatch` : `slot.o`, `slot.ov`), assainissement `Data.lua` (`o`, `ov`), annonce serveur / billboard (`Debris`), `HatchPlan.lua`, `HatchFx.lua`, `RevealFx.lua`, `SlotFx.lua`, `BattleIntro.lua`, `IntroPlan.lua`, `TypeFx`, sons (`Config.SOUNDS`), icônes (`Config.ICONS`), rapport `Config.Debug.AssetReport`, crochet `Config.Debug.forceHatch` (A9). Revue par **lecture du code réel** + tests lupa (`lot10.luau` : 113 assertions dont A9, `battlelayout.luau`). **Rien n'a été joué dans Studio.**

**Bilan : 0 défaut critique ou élevé ; 1 point faible noté.**

| Sujet | Risque | Constat | État |
|---|---|---|---|
| Compteur gonflé | Achat ou client qui fait monter le « 1 sur N » | `Odds.forPet` ne reçoit aucun bonus (chance, passe, potion, événement) ; calculé UNE fois par le serveur, figé dans le profil (`o`, `ov`), jamais recalculé ; le client ne fait qu'afficher. Valeur hors bornes à la relecture = retirée. | OK |
| Annonces | Spam d'annonces serveur / monde | Seuils fixes (`Odds.fx` : 10 000 / rareté 7 pour le serveur, 1 000 000 / rareté 8 pour le monde) ; billboard détruit par `Debris` après `HATCH_FX.billboardSeconds`. | OK |
| Effets client | Fuite d'instances, chute de FPS | Plans bornés (30 objets, 40 objets/s, version réduite <= 50 %), connexions posées sur des racines détruites en fin d'effet (déconnexion automatique), chien de garde de fin (`BattleIntro.WATCHDOG_MARGIN`). | OK (pas de mesure FPS réelle) |
| Crochet de test | `forceHatch` actif en production | `false` par défaut ; lu seulement avec `RunService:IsStudio()` (`Config.debugForceTier`) ; testé : inactif par défaut et hors Studio, tirage inchangé. | OK (ajouté par A9) |
| Rapport d'assets | Information de diagnostic visible des joueurs | `Config.Debug.AssetReport = true` affiche « Blender N/M » en bas à gauche et un rapport par F3 **à tous les joueurs**, y compris en production (identifiants d'assets publics, aucune donnée personnelle). | **Faible, non corrigé volontairement** : le test Studio en cours en a besoin (A_FAIRE §3quinquies) ; à repasser à `false` avant le passage en public (ajouté à A_FAIRE §1quater). |
| Sons / icônes | Assets non approuvés | Identifiants branchés tels que fournis ; un son absent ne bloque rien (pcall). | OK |
