---
type: procedure
---
# Publier un lieu par Open Cloud
Prérequis : la clé API est injectée par le proxy (ne jamais l'écrire). Studio doit être fermé.

1. `git fetch` la branche du jeu, créer un worktree sur le commit.
2. Vérifier soi-même : `stylua --check`, les tests du jeu, `rojo build hub.project.json` et `game.project.json`.
3. Publier chaque lieu :
   `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published` avec `Content-Type: application/octet-stream` et le `.rbxl` en corps. Réponse 200 + `versionNumber`.
4. Contrôler par lecture : `GET https://apis.roblox.com/cloud/v2/universes/{id}/places/{placeId}`.

## Autres appels utiles
- Max Players : `PATCH /cloud/v2/universes/{id}/places/{placeId}?updateMask=serverSize` avec `{"serverSize": N}`.
- Renommer un lieu : même appel avec `updateMask=displayName`.
- Assets (modèles, sons) : `POST /assets/v1/assets` en multipart (`request` JSON + `fileContent`), puis `GET /assets/v1/operations/{operationId}` jusqu'à `done`. `moderationState` doit valoir `Approved`.
- Propriétaire des expériences : `users/11905484366` (compte ahmzk0).

## Erreurs
- 409 « Server is busy » : Roblox Studio ouvert, ou Création en équipe active. Faire fermer Studio.
- 403 « Scope not authorized » : la clé n'a pas la permission. Permissions actuelles : universe-places écrire, universe écrire, universe.place écrire, Assets lire et écrire.
- « Could not get the Universe associated with Place » : l'ID donné est un ID d'univers, pas de lieu.
- Ne jamais mettre la clé dans une commande : le proxy l'ajoute tout seul.

## Clé API v2 (21 nov) : lecture/écriture sur toutes les expériences actuelles
- Game Passes : `POST https://apis.roblox.com/game-passes/v1/universes/{U}/game-passes` (multipart : name, description, isForSale=true, price) ; liste : `GET .../game-passes/creator?pageSize=N`.
- Produits : `POST https://apis.roblox.com/developer-products/v2/universes/{U}/developer-products` (name, description, price) puis `PATCH .../{productId}` avec `price` et `isForSale=true` (HTTP 204). Le champ `priceInRobux` est ignoré.
- Visibilité (PRIVATE/PUBLIC) et description d'expérience : `PATCH /cloud/v2/universes/{U}` répond 200 mais NE CHANGE RIEN. À faire par l'utilisateur dans le Creator Hub.
- Fichier de lieu : téléchargement impossible (403). Ne jamais publier un lieu existant sans son fichier source.
