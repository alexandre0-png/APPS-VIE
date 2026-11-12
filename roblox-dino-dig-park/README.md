# Dino Dig Park (Roblox)

Tycoon original : fouille de fossiles, éclosion d'œufs, 18 dinos en blocs Roblox, parc à agrandir, renaissance, quêtes, cadeau quotidien, événement de météores, classement, dino secret.
Tout est généré par code (aucun asset externe). Projet Rojo : `default.project.json`. Publication : `publication/PUBLICATION.md`.

## Structure
- `src/shared` : Config (données), Economy (équilibrage pur), DinoShapes/DinoFactory, HumanFactory, Util, Remotes
- `src/server` : DataService (DataStore + verrou de session), WorldBuilder, PlotService, GameService, EventService, Monetization, Leaderboard
- `src/client` : Ui, Hud, Panels, Reveal, World (animations locales), StateStore

## Vérifications (reproductibles)
Prérequis : `npm i fengari luaparse`, puis `FENGARI_PATH=<chemin>/fengari`.
- Syntaxe + globales inconnues (luaparse) : toutes les sources passent.
- `node tests/run.js` : données, économie, sauvegardes, simulation de progression (VM Lua).
- `node tests/run_integration.js` : code serveur et client réel sur un mini-moteur Roblox simulé (`tests/roblox_mock.lua`).
Limite : ce n'est pas Roblox Studio. Rendu, physique, sons et signatures exactes de l'API restent à confirmer en Studio.
