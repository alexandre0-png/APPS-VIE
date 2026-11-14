# Vérifications : ce qui est exécuté, relu ou à tester

À lancer depuis la racine du dépôt. Colonne « Statut » = état lors de la dernière passe (2026-11-12).

| Outil | Commande | Statut |
|---|---|---|
| Contrôle automatique du projet (syntaxe Luau via le compilateur officiel, classes / enums / membres Roblox contre le dump de l'API, cohérence des Remotes, variables inutilisées, place à jour) | `python3 roblox/tools/check.py` | **Exécuté, 0 problème.** Testé en injectant 6 erreurs volontaires : toutes détectées. |
| Détection des API dépréciées (classes, membres du dump officiel, appels globaux `wait` / `spawn` / `delay` / `LoadCharacter`) | `python3 roblox/tools/check.py` (inclus) | **Exécuté.** A détecté `Player:LoadCharacter` (corrigé). Testé en injectant des usages dépréciés : détectés. |
| Construction de la place `.rbxlx` | `python3 roblox/tools/build_place.py` | **Exécuté.** XML valide, sources identiques aux fichiers. Non ouverte dans Studio. |
| Formatage stylua (`stylua.toml`) | `stylua roblox/src roblox/tests` | **Non exécuté** : binaire téléchargé mais son exécution est refusée par le contrôle d'autorisation de la session (nouvel essai le 2026-11-12 après consigne de l'utilisateur : refus identique). Le code n'est donc pas passé par stylua. |
| Lint selene (`selene.toml`) | `selene generate-roblox-std` puis `selene roblox/src` | **Non exécuté** (même raison). |
| Build Rojo | `rojo build roblox/default.project.json -o roblox/build/ChipeOeufs.rbxl` | **Non exécuté** (même raison). `default.project.json` n'a donc pas été validé par Rojo. |
| Tests de logique pure (`roblox/tests/run.luau` : `Config` et `Rules`) **avec Lua 5.x via `lupa`** (Lune non disponible ici) | `python3 roblox/tools/run_tests.py` (aussi lancé par `check.py`) | **Exécuté : 1104 réussis, 0 échoué** (454 avant l'ajout des énigmes et des succès, total identique à l'exécution Lune rapportée par l'autre environnement à ce moment-là). Le runner détecte bien un échec (testé en cassant 2 valeurs : 2 échecs signalés, code de sortie 1). Différences avec Lune : Lua 5.x et non Luau, `+=` converti, `luau.load` simulé. |
| Les mêmes tests avec Lune | `lune run roblox/tests/run.luau` | Exécuté par l'autre environnement (454 réussis à l'époque, selon son rapport ; non relancé avec les nouveaux tests) ; non exécutable ici. |
| Playtest Roblox Studio (2 joueurs) | voir `publication/LISTING.md` §5 | **Non fait.** Tout ce qui touche au rendu, au réseau, aux DataStore et aux achats n'a été que relu. |

## Relu seulement (à confirmer dans Studio)

- Hub et parties : la logique (`Party`) est testée avec un faux TeleportService ; `Hub.server`, `HubWorld`, `HubClient` (zones, MemoryStore, GetFriendsAsync, TeleportAsync réels) ne sont que relus. `ReserveServerAsync` et `TeleportOptions.ReservedServerAccessCode` sont dépréciés dans le dump de l'API et limités à une expérience : voir CHANGELOG.
- Interface : `Layout` testé sur 10 écrans, mais l'affichage réel (UIScale, insets de sécurité, boutons) n'est pas vu.
- Carte : le décor est exécuté avec un Roblox factice (pas d'erreur d'exécution, compte de Parts exact), pas rendu. StreamingEnabled non éprouvé avec les scripts clients.

- Mode « Studio sans accès API » : la reconnaissance du message est testée (`Diag`) ; le basculement en mode mémoire dans `Data` n'est que relu.
- Apparences d'œufs du code (`EggFx`) : données testées (distinctes, plafonds) ; le rendu (anneau, coque scintillante, particules, performance à 10 joueurs) est à voir dans Studio.
- Carte d'objectif (HUD) : le texte et la progression (`Config.objective`) sont testés ; la mise en page (téléphone, chevauchement avec la bannière d'événement) est à voir dans Studio.
- Économie : la simulation est un modèle (joueur-robot sans vol, quêtes, événements ni renaissance), pas un test de jeu réel.

- Modèles d'œufs : le chargement réel (`InsertService:LoadAsset`), la disponibilité et l'autorisation des 5 IDs, l'aspect et l'échelle des modèles, le comportement avec les animations de saut/tremblement ; seuls le module `Assets` (chargeur factice) et la configuration sont testés. `dressEgg` (Builder) n'est que relu et vérifié contre le dump de l'API.

- Cinématiques : application des plans à la caméra, interface (barres, légende, boutons), restitution de la caméra en conditions réelles (mort, attaque, déconnexion), position des ancres dans le vrai monde ; seules la logique (`Cinema`), les définitions et la configuration sont testées.
- Animations : application aux objets Roblox (œufs, visages des pets, barrières, confettis, FOV, menus) ; seules les courbes, le garde-fou et la configuration sont testées.
- Énigme des runes : prompts, symboles locaux, panneau d'énoncé, validation et récompense (la logique de génération de l'énigme est testée, pas le câblage Roblox).
- Rendu : éclairage, bloom, couleurs, matériaux, SurfaceGui des panneaux, Fire des torches, placement des modèles sur les pads.
- Animations locales : pop-in des pets (`ScaleTo`), onde de choc, œuf volant, rayures du tapis, œuf qui blanchit.
- Sauvegarde : verrou de session, migration de version, nouvelles tentatives, libération du verrou à la sortie.
- Anti-triche : `PromptButtonHoldBegan` côté serveur, contrôle de vitesse.
