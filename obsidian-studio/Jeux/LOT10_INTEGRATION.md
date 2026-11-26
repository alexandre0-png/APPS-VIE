# Lot 10 : brief d'intégration (préparé par la gestion, 2026-11-26)

À faire APRÈS le lot 9b (calendrier), dans la session Jeu 2. Les fichiers nouveaux existent déjà (voir `roblox/LOT10_NOTES.md`, 106 assertions OK) : Odds, HatchPlan, IntroPlan, TypeFx (données + client), HatchFx, BattleIntro. Reste l'intégration.

## Étapes
1. Config : ajouter `Config.ODDS = { version = 1, billboardMin = 1000, REF = { 50, 25, 14, 7, 2.9, 0.85, 0.2, 0.04, 2, 0.01 } }` (vérifier REF contre les poids de rareté réels du lot 9), `Config.TYPE_FX = require(TypeFx).DATA`, `Config.SOUNDS` : ajouter toutes les clés du tableau ci-dessous (id non vide = son joué) ; garder `Config.SOUNDS_ENABLED`.
2. Renommer l'un des deux modules `TypeFx` (par ex. données `TypeFxData`) si `build_place.py` mappe par nom seul.
3. Serveur (Main/Hatch) : à l'éclosion, `slot.o = Odds.forPet(Config, petIdx, s, m)` une seule fois, `slot.ov = Config.ODDS.version` ; migration : les anciens slots sans `o` affichent « — » (jamais recalculé).
4. Client : Reveal utilise `HatchPlan.plan` + `HatchFx.play` (remplace `CinematicKit.hatchPlan`), compteur `Odds.label`, annonces `Odds.fx` (serveur/monde/pilier/bandeau/billboard N >= 1000).
5. Combat : `BattleIntro.play(IntroPlan.plan(...))` avant le premier tour, `TypeFx.play` à chaque attaque (spécial après 5 coups), texte d'efficacité `TypeFx.efficacy`.
6. Tests : brancher `run_lot10.py`/`lot10.luau` dans `run_tests.py` ; garder 0 échec ; ajouter un test de non-régression du profil (slots anciens).
7. Mobile/accessibilité : `reduced` sur mobile (particules /2), plafonds 220/120/80 instances, 30 FPS cible.

## Sons à brancher (assets approuvés, lot 28)
| clé | id |
|---|---|
| atk_ciel | 111809409022959 |
| atk_eau | 126099928196969 |
| atk_feu | 81620112328213 |
| atk_foudre | 75059811348237 |
| atk_glace | 77653528704078 |
| atk_lumiere | 108376562226076 |
| atk_ombre | 135006463398132 |
| atk_plante | 111056707806818 |
| atk_terre | 77231920160184 |
| battle_lose | 75714072353851 |
| battle_start | 133857375212321 |
| battle_win | 74841129152048 |
| belt_buy | 73924816898255 |
| belt_loop | 127299224836728 |
| calendar_claim | 97907407134977 |
| calendar_milestone | 134993322632871 |
| calendar_open | 119109992802741 |
| coin_pickup | 95726825095665 |
| egg_shake | 101268169244225 |
| hatch_r1 | 120743720926374 |
| hatch_r10 | 70399111166131 |
| hatch_r2 | 99352802477541 |
| hatch_r3 | 130524252980200 |
| hatch_r4 | 74396866627910 |
| hatch_r5 | 71692383904268 |
| hatch_r6 | 98693421307337 |
| hatch_r7 | 130739946095614 |
| hatch_r8 | 83413707310170 |
| hatch_r9 | 127058227889279 |
| house_levelup | 110371127961423 |
| jackpot_rare | 90004480091860 |
| kiosk_ambience | 82723287691994 |
| npc_ping | 79333917653019 |
| special_hit | 86601967046565 |
| special_ready | 131456268494739 |
| ui_click | 127134008433069 |
| ui_error | 85896764648966 |

Correspondance : hatch_r1..r10 = `plan.sound.key` par rareté ; `fanfare` = hatch_r8+ ; `secret` = N >= 1 M ; `divine` = hatch_r10 ; atk_<type> = TypeFx ; battle_start/win/lose = BattleIntro et fin de combat ; egg_shake = secousse de l'œuf ; coin_pickup = collecte ; calendar_* = lot 9b ; belt_* = tapis.

## Livrable
Commit non-WIP « Lot 10 intégré », tests verts, rapport : écarts, ce qui reste « À tester dans Studio ».
