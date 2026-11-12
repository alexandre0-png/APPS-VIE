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
| Tests Lune sur la logique pure (`roblox/tests/run.luau` : `Config` (formats, vitesse, coûts, tables, probabilités affichées) et `Rules` (tirage pondéré, rareté, mutations, revenus, capacités, distributions statistiques à graine fixe)) | `lune run roblox/tests/run.luau` | **Non exécuté.** Le fichier compile (syntaxe valide). Les valeurs numériques de `Config` ont été recoupées à la main (deux erreurs de mes tests corrigées) et l'algorithme de `Rules` recopié en Python avec graine fixe donne les distributions attendues (12,2 % de rareté supérieure, 1,4 % d'Alien, 6,8 % avec le Biome Alien). Ce recoupement valide l'algorithme, pas l'exécution du fichier Lua. |
| Playtest Roblox Studio (2 joueurs) | voir `publication/LISTING.md` §5 | **Non fait.** Tout ce qui touche au rendu, au réseau, aux DataStore et aux achats n'a été que relu. |

## Relu seulement (à confirmer dans Studio)

- Rendu : éclairage, bloom, couleurs, matériaux, SurfaceGui des panneaux, Fire des torches, placement des modèles sur les pads.
- Animations locales : pop-in des pets (`ScaleTo`), onde de choc, œuf volant, rayures du tapis, œuf qui blanchit.
- Sauvegarde : verrou de session, migration de version, nouvelles tentatives, libération du verrou à la sortie.
- Anti-triche : `PromptButtonHoldBegan` côté serveur, contrôle de vitesse.
