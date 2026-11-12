# Vérifications : ce qui est exécuté, relu ou à tester

À lancer depuis la racine du dépôt. Colonne « Statut » = état lors de la dernière passe (2026-11-12).

| Outil | Commande | Statut |
|---|---|---|
| Contrôle automatique du projet (syntaxe Luau via le compilateur officiel, classes / enums / membres Roblox contre le dump de l'API, cohérence des Remotes, variables inutilisées, place à jour) | `python3 roblox/tools/check.py` | **Exécuté, 0 problème.** Testé en injectant 6 erreurs volontaires : toutes détectées. |
| Construction de la place `.rbxlx` | `python3 roblox/tools/build_place.py` | **Exécuté.** XML valide, sources identiques aux fichiers. Non ouverte dans Studio. |
| Formatage stylua (`stylua.toml`) | `stylua roblox/src roblox/tests` | **Non exécuté** : binaire téléchargé mais son exécution a été refusée par le contrôle d'autorisation de la session. Le code n'est donc pas passé par stylua. |
| Lint selene (`selene.toml`) | `selene generate-roblox-std` puis `selene roblox/src` | **Non exécuté** (même raison). |
| Build Rojo | `rojo build roblox/default.project.json -o roblox/build/ChipeOeufs.rbxl` | **Non exécuté** (même raison). `default.project.json` n'a donc pas été validé par Rojo. |
| Tests Lune sur la logique pure (`roblox/tests/run.luau`, ~120 assertions sur `Config` : formats, vitesse, coûts, tables, probabilités) | `lune run roblox/tests/run.luau` | **Non exécuté.** Le fichier compile (syntaxe valide) et les valeurs numériques attendues ont été recoupées à la main (deux erreurs de mes tests trouvées et corrigées), mais aucune exécution réelle. |
| Playtest Roblox Studio (2 joueurs) | voir `publication/LISTING.md` §5 | **Non fait.** Tout ce qui touche au rendu, au réseau, aux DataStore et aux achats n'a été que relu. |

## Relu seulement (à confirmer dans Studio)

- Rendu : éclairage, bloom, couleurs, matériaux, SurfaceGui des panneaux, Fire des torches, placement des modèles sur les pads.
- Animations locales : pop-in des pets (`ScaleTo`), onde de choc, œuf volant, rayures du tapis, œuf qui blanchit.
- Sauvegarde : verrou de session, migration de version, nouvelles tentatives, libération du verrou à la sortie.
- Anti-triche : `PromptButtonHoldBegan` côté serveur, contrôle de vitesse.
