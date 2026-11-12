# À faire par vous (seul(e) possible avec votre compte / Studio)

Tout le reste est fait et vérifié (voir CHANGELOG.md). Cette liste ne contient que ce que je ne peux pas faire.

## 1. Installer Rojo et construire le jeu
- Installer Rojo (rojo.space), puis `tools/publish.sh` (ou `rojo build -o ArenaDesLegendes.rbxl`).
- Optionnel : `stylua --check src` et `selene src` (configs fournies : `stylua.toml`, `selene.toml`).

## 2. Tester dans Roblox Studio (jamais fait : aucune partie n'a été jouée)
- Test → Clients and Servers → 2 joueurs. Vérifier : apparition, portail, 3 modes, armes en main, rampes, jump pads, lave, bots, désintégration, interface mobile (émulateur), manette, cinématiques (intro, tutoriel, saison, Roi de la tour : vérifier caméra, lisibilité, bouton « Passer » ; désactivables dans `Config.Cinematics`), animations (glissade C, esquive Q, garde F) : si l'une pose problème, mettre sa clé à `false` dans `Config.Animations`.
- Activer *Game Settings → Security → Enable Studio Access to API Services* pour tester la sauvegarde.

## 3. Créer les achats dans le Creator Hub, puis me donner / saisir les Id
Copier `publication/ids.example.json` en `publication/ids.json` et remplir (ou coller dans `Config.Monetization`) :

| Clé attendue | Type | Nom conseillé | Prix |
|---|---|---|---|
| `DoubleXP` | Game Pass | XP x2 | 199 R$ |
| `DoubleCoins` | Game Pass | Pièces x2 | 299 R$ |
| `VIP` | Game Pass | VIP | 399 R$ |
| `Coins500` | Developer Product | 500 pièces | 49 R$ |
| `Coins1500` | Developer Product | 1 500 pièces | 129 R$ |
| `Coins5000` | Developer Product | 5 000 pièces | 349 R$ |

Puis `tools/publish.sh` injecte les Id (un Id à 0 reste désactivé).

## 4. Images
- Remplacer/compléter `publication/images/*` par de vraies captures Studio (icône 512×512, miniatures 1920×1080) et les téléverser.

## 5. Publication (compte Roblox)
- Connexion, vérification d'identité si demandée, questionnaire de classification, File → Publish to Roblox, fiche du jeu (texte prêt dans `publication/PUBLICATION.md`).
- Mettre le jeu en Public seulement après le test à deux joueurs.
