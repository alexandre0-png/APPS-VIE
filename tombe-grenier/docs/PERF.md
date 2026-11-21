# Performance : audit et budgets

Mesures faites par `tools/lua/test_perf.py` sur la vraie carte (modèles Blender absents du test : Roblox les charge à la volée).

| Poste | Avant | Après | Budget |
|---|---|---|---|
| Parts de la carte (procédural) | 760 | 760 | < 2 500 |
| Lumières allumées en même temps, au pire | 28 (8 lueurs de pièce + 20 ampoules) | 16 (8 + 8 ampoules des pièces proches) | < 20 |
| Halos (Highlight) | 24 | 8 | ≤ 8 (Roblox : 31) |
| Particules (effets simultanés x particules par émetteur) | 960 (haut), 400 (moyen) | 400 (haut), 240 (moyen), 120 (bas) | ≤ 400 |
| IA du monstre | 10 passes de perception par seconde (raycasts) | 5 par seconde | `Config.Monster.Tick` ≥ 0,2 |
| Boucle audio client (battement de cœur) | 10 Hz | 5 Hz | |
| Ombres | toutes les pièces | pièces de plus de 3 studs seulement | `PerfRules.castsShadow` |
| Collision et toucher du décor | CanTouch actif | CanTouch, CanQuery, CanCollide coupés sur les modèles ; CanTouch coupé sur la carte | |

## Ce qui a été ajouté
- `Config.Perf` : budgets et réglages (`MaxParts`, `MaxLights`, `MaxParticles`, `MaxHalos`, `CullRooms`, `CullInterval`, `DebugOverlay`).
- `src/shared/PerfRules.lua` (logique pure, testée) et `src/client/RoomCull.lua` : le mobilier, le décor et les détails des pièces au-delà des 7 plus proches du joueur quittent le Workspace local (dossier `ReplicatedStorage.DecorMasque`) et reviennent à l'approche. Murs, dalles et escaliers ne sont jamais masqués, donc le sol reste intact. Le serveur n'est pas touché (raycasts, prompts, IA inchangés).
- Ampoules des pièces éloignées : éteintes (attribut `Culled`), sans scintillement, avec le budget de lueurs de pièce (`RoomBudget`).
- Compteur de debug : touche F7 (ou `Config.Perf.DebugOverlay = true`), FPS client, temps de frame serveur (attribut `Workspace.ServerFrameMs`, publié chaque seconde), ping, nombre de décors masqués.

## Boucles actives (liste de référence)
Serveur : IA du monstre (5 Hz), balancement du monstre (20 Hz, un seul monstre), halos des marqueurs (1 Hz), budget de lueurs (1 Hz), scintillement des ampoules (par ampoule, en pause à distance), quêtes (0,5 Hz), mesure de frame serveur (1 Hz).
Client : balancement de caméra (RenderStepped, une pcall), flèche d'objectif (RenderStepped limité à 10 Hz), compteur FPS (RenderStepped, un calcul), zones (2 Hz), actions tactiles (4 Hz), sons de jeu (5 Hz), invites (5 Hz), masquage de pièces (1,3 Hz), caméra de secours (0,5 Hz).
Réseau : tous les Remotes sont déclenchés par un événement de jeu (étape, message, effet). Aucun n'est envoyé par une boucle rapide (test `test_remotes_are_event_driven`).

## Limites connues
- Le chargement des modèles Blender reste global et en arrière-plan (priorité aux énigmes puis au mobilier courant). Un chargement par pièce n'est pas fait : le masquage de pièces limite le rendu mais pas le téléchargement initial.
- Aucune mesure sur un vrai appareil : les chiffres ci-dessus viennent du simulateur. Mesurer avec F7 sur téléphone après publication.
- Boucles d'ambiance sonore : seules celles des 8 pièces les plus proches jouent (`MapBuilder.startRoomBudget`).
