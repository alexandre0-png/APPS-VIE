# Studio Roblox : mémoire de gestion

Fichier lu en premier par la session de gestion. Pas de secret ici (jamais de clé API).
Mise à jour : 2026-11-20.

## Règles non négociables
- Jamais de clé ni de mot de passe dans un fichier, un commit ou le chat. Les clés passent par `request_credential`.
- Hôpital Sainte-Aurore (Jeu 1, public, 16+) : on ne publie jamais par l'API. La session Jeu 1 livre des scripts à remplacer à la main.
- Aucune expérience publique sans demande explicite « publie en live ». Tous les jeux 2 à 8 sont privés (« Testeurs »).
- Ne pas faire la vérification d'identité, le questionnaire de maturité, ni les vignettes à la place du propriétaire.
- Jeux 4 à 8 en pause jusqu'à la publication des jeux 2 et 3.

## Jeu 2 : Sortir Du Grenier (privé)
- Univers 10776611603.
- Hub : lieu 77452764500707 (lieu de départ, 50 joueurs).
- Partie : lieu 88091909899710 « Partie du Grenier » (Max Players 2).
- Rôle déduit de `game.PlaceId` dans `Config.Game.Places`.
- Dernier publié : commit f98bdc7 (hub v21, partie v14).
- Dossier : `tombe-grenier/`, branche `claude/tombe-grenier-animations-5ilizr`, session `session_0164z8QRKAjeEQzGAp6T7swM`.

## Jeu 3 : Chipe-Œufs (privé)
- Univers 10776613087.
- Hub : lieu 115261336085924 (lieu de départ).
- Partie : lieu 87012762353093 « Partie Chipe-Oeufs » (Max Players 5).
- Dernier publié : commit 3ee934e (hub v11, partie v7).
- Dossier : `roblox/`, branche `claude/lucid-wozniak-o23lf0`, session `session_0164z8QSjguKxoDaDm6aN2MU`.
- Obsolètes : lieu 106358102689021 et univers 10776613783 (ancien hub séparé).

## Autres jeux (en pause)
- Jeu 1 Hôpital : session `session_0164z8QPgeknqvjB5PW7FVca`, pas de dépôt git, public.
- Festin du t-rex : univers 10776614241, lieu 111055882646208 (hub séparé univers 10776614638, lieu 134299502323007).
- Rodeo Stampede (zoo, Jeu 5) : univers 10776615016, lieu 92973490999349 (à confirmer).
- Sessions : Jeu 4 `QNkbMwxqwFNdbhvMzy`, Jeu 5 `QRnxKWaAv1uVejRxtq`, Jeu 6 `QTUe3r6BKc4EXFT2ev`, Jeu 7 `QRyyrTjyqMZ6HWDmXa`, Jeu 8 `QPhB1SuURKY4KQpDcZ` (préfixe `session_0164z8`).
- Les IDs « 10776… » donnés par l'utilisateur sont des IDs d'univers, pas de lieux.

## Publier (Open Cloud, la clé est injectée par le proxy)
1. Récupérer le commit de la session, `git fetch` puis worktree dans le scratchpad.
2. Vérifier soi-même : `stylua --check`, tests du jeu, `rojo build hub.project.json` et `game.project.json`.
3. `curl -X POST https://apis.roblox.com/universes/v1/{univers}/places/{lieu}/versions?versionType=Published -H "Content-Type: application/octet-stream" --data-binary @fichier.rbxl`
4. Erreur 409 « Server is busy » : Roblox Studio ouvert ou Création en équipe active. Faire fermer Studio.
5. Ne jamais écrire la clé dans une commande.
- Lire un univers : `GET /cloud/v2/universes/{id}` ; lieu : `GET /cloud/v2/universes/{id}/places/{lieu}`.
- Max Players : `PATCH /cloud/v2/universes/{id}/places/{lieu}?updateMask=serverSize`.
- Assets : `POST /assets/v1/assets` (multipart), suivi par `GET /assets/v1/operations/{id}`.
- Propriétaire des univers : utilisateur ahmzk0 (`users/11905484366`).
- Hôtes bloqués depuis le sandbox : develop.roblox.com, github.com (téléchargements), obsidian.md, figma.com.

## Pièges déjà rencontrés
- Un `require(script.Parent.Common...)` mal résolu fait planter tout le script serveur avant les Remotes (symptôme : client « Infinite yield on Remotes », joueur dans le ciel). Garde-fou : tests de chemins sur l'arbre Rojo réel.
- Le lieu de départ ne se change pas depuis le tableau de bord de l'utilisateur : on inverse les rôles des lieux à la place.
- `StreamingEnabled=false` dans les `.project.json` des deux lieux.
- Studio ne téléporte pas entre lieux : tester depuis roblox.com (bouton Jouer).
- stylua doit être compilé avec `--features luau` ; il plante sur l'opérateur `//` (Jeu 3), c'est un bug de l'outil.
- Les sessions de jeu n'ont pas toutes le droit d'exécuter rojo/stylua/Lune : la session de gestion refait toujours les vérifications.
- Modèles catalogue refusés à `LoadAsset` (« Requester does not have permission ») : repli procédural.
- Un message à une session partage son contexte : toujours vérifier l'ID de session avant d'envoyer.

## Outils
- Binaires dans `/tmp/claude-0/cargo-out/bin` (stylua, selene, lune, rojo) à remettre dans le PATH ; `scripts/setup-roblox-toolchain.sh` et `scripts/check-game.sh <jeu>`.
- Blender : `pip install bpy` dans un venv (testé), scripts de modélisation dans le scratchpad ; export FBX vers l'API Assets.
- Les binaires téléchargés depuis GitHub sont refusés par le classificateur : ne pas en demander aux sessions.

## À faire côté utilisateur (une fois)
- « Allow Third Party Teleports » et « Enable Studio Access to API Services » sur les deux expériences.
- Désactiver Création en équipe sur le Grenier.
- Obtenir sur le catalogue les 3 œufs refusés (légendaire 2937230482, orange 147144059, glitch 2937218888).
- Supprimer les anciennes clés API devenues inutiles.
