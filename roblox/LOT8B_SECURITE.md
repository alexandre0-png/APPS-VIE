# Lot 8B : revue QA et sécurité tracée (kiosque central, décor de carte, meubles des maisons) — 2026-11-28

Périmètre : `Kiosk.lua` (construction, `Kiosk.handle`), prompts `KioskPrompt` routés par `ProximityPromptService` dans `Main.server.lua` (`K8.prompt`), remote `Kiosk` (serveur -> client), classement du kiosque (cache `K8.top`), `Decor.lua` / `DecorData.lua` (décor de carte), `HouseDecor.lua` / `HouseDecorData.lua` (meubles). Revue par **lecture du code réel** + tests lupa (`kiosk.luau`, `decor.luau`, `housedecor.luau`, intégration 8B dans `run.luau`). **Rien n'a été joué dans Studio.**

**Bilan : 0 défaut critique ou élevé.**

| Sujet | Risque | Constat | État |
|---|---|---|---|
| Remote `Kiosk` | Demandes client forgées | Remote **serveur -> client seulement** : aucun `OnServerEvent` ; la seule entrée client de la partie est `RAction` (vérifié : un seul `OnServerEvent` dans `src/ServerScriptService` ; le hub a son propre remote, hors périmètre). | OK |
| Prompts du kiosque | Ouverture à distance, action inconnue | Tag `KioskPrompt`, `Kiosk.handle` sur liste blanche d'actions ; distance et session relues côté serveur ; réponse = vue (boutique, calendrier, probabilités, classement), aucune écriture de profil. | OK (tests `kiosk.luau`) |
| Quotas DataStore | Classement lu à chaque ouverture | Cache `K8.top` de 30 s : au plus 1 lecture `OrderedDataStore` par fenêtre et par serveur. | OK |
| Décor / meubles | Objets ancrés manquants, collisions, triche de position | Construits une fois par le serveur, ancrés ; le décor évite le disque du kiosque et les emprises des vendeurs (lot 16) ; aucun meuble n'a de prompt ni de logique de gain. | OK (tests `decor.luau`, `housedecor.luau`) |
| Fuites mémoire | Reconstruction répétée | `K8.build` idempotent ; aucune table par joueur dans le kiosque (cache global unique). | OK |
| Modèles externes | Script caché dans un modèle chargé | Modèles Blender chargés par `Assets` (scripts retirés, plafond de Parts, repli procédural), voir `Config.Debug.AssetReport`. | OK |

## Limites connues
- Lisibilité réelle (taille des panneaux, éclairage) : à vérifier dans Studio (A_FAIRE §3sexies).
