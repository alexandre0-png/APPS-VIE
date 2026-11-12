# Saute-Troupeau (Herd Hopper)

Jeu Roblox multijoueur en manches de 2 minutes. Tu bondis de bête en bête au lasso sur 3 200 m, tu domptes un maximum de créatures et tu restes devant un mur de lave qui accélère.

- Aperçu complet : `docs/apercu.html` (ouvrir dans un navigateur)
- Publication, achats Robux, textes de la page du jeu : `docs/PUBLICATION.md`
- Jeu prêt à ouvrir dans Studio : `build/SauteTroupeau.rbxlx` (régénérable avec `python3 tools/build_rbxlx.py`)
- Images de publication : `marketing/`
- Avec Rojo : `rojo build -o SauteTroupeau.rbxlx` (fichier `default.project.json`)

## Structure

```
src/shared   Config (tout l'équilibrage), Species, Util, Remotes
src/server   init.server + Modules : State, DataService, ProgressService, MonetizationService,
             CreatureService, RideService, WallService, EventService, MapBuilder, RoundService, Fx, Cosmetics
src/client   init.client + Modules : HUD, Menu, Controls, CameraRig, CreatureFx, Ambience, UI, Sfx, ClientState
tools/sim    simulation serveur + interface hors Roblox (fengari)
tools/marketing  générateur d'images
```

## Vérifications

Exécutées dans cet environnement :
- syntaxe des 27 scripts (parseur Lua 5.1, le code évite la syntaxe propre à Luau) : 0 erreur ;
- aucune variable globale inconnue ;
- simulation serveur avec 3 joueurs-robots sur 4 scénarios (manches complètes, mur de lave, arrivée, départ d'un joueur, boutique, achats Robux simulés, reçus rejoués) : 0 erreur Lua ;
- simulation de l'interface (HUD, menus, panneau Robux, contrôles) : 0 erreur.

Lancer : `cd tools/sim && npm install && node run.js A` (puis B, C, CLIENT).

Configurations fournies mais **non exécutées ici** (outils absents de l'environnement) : `stylua.toml`, `selene.toml`, `rojo build` (via `default.project.json`). Lance `tools/check.sh` sur ta machine : il signale chaque outil manquant. Aucun test Lune : la logique est couverte par la simulation fengari ci-dessus.

Audio : les musiques de `Config.Audio.Music` sont vides (aucun morceau libre de droits fourni). Les effets utilisent les sons intégrés au client Roblox, non vérifiés.

Non exécutées, faute de Roblox Studio ici : physique réelle (soudure du cavalier sur une bête ancrée, propriété réseau), rendu, tactile et manette, sons, DataStore et achats réels. Ce sont les points à regarder lors du premier test dans Studio.
