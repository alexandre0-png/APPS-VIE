# Publier « Arène des Légendes » sur Roblox (tout dans Roblox, sans API externe)

Tout ce qui est préparable est déjà dans ce dossier. Les étapes ci-dessous exigent **votre compte Roblox** (connexion,
vérification d'identité, questionnaire d'âge) : je ne peux pas les faire à votre place.

## 1. Ouvrir et publier depuis Studio (≈ 10 min)
1. `rojo build -o ArenaDesLegendes.rbxl` (voir README), ouvrir le fichier dans Roblox Studio.
2. **File → Publish to Roblox** → *Create new game* : nom `Arène des Légendes`, genre **Combat**, appareils : Ordinateur, Téléphone, Tablette, Console.
3. **Home → Game Settings** : *Max Players* 20 · *Security → Enable Studio Access to API Services* (sauvegarde) · *Avatar → R15*.
4. Publier, puis jouer 2 clients (Test → Clients and Servers → 2 Players) : c'est le premier vrai test du jeu.

## 2. Fiche du jeu (Creator Hub → Creations → le jeu → Configure)
- **Nom** : Arène des Légendes
- **Description** (copier-coller) :

> ⚔ Entre dans l'Arène des Légendes, combat de blocs en ligne !
> Rejoins une manche en un clic : Mêlée générale, Guerre des couleurs (Rouges vs Bleus) ou Roi de la tour. Domine la tour centrale, évite la lave, attrape l'orbe de rage et enchaîne les éliminations.
> • 12 armes à débloquer : épée, arc, pistolet, katana, marteau, carabine, dague, bâton de feu, fusil à pompe, fusil d'assaut, rail, lame du Souverain
> • Séries, primes sur les joueurs en feu, assistances, tirs à la tête
> • 4 héros, une Chronique en 5 chapitres, 50 niveaux, titres, quêtes quotidiennes, cadeau de connexion, classement mondial
> • Zone d'entraînement pour tester tes armes
> • Jouable sur téléphone, tablette, PC et console
> Parle de ta meilleure série en commentaire !

- **Icône** : `publication/images/icone-512.png` (512×512)
- **Miniatures** (Media → Thumbnails, ordre conseillé) : `miniature-1-titre.png`, `miniature-2-modes.png`, `miniature-3-armes.png` (1920×1080)
- ⚠ Ces visuels sont des illustrations générées, pas des captures du jeu. Roblox demande des images fidèles : dès le premier playtest, remplacez-les (ou complétez) par de vraies captures Studio (Ctrl+Alt+P / outil Screenshot), notamment le hub, l'arène et la tour centrale.
- **Questionnaire de classification** (obligatoire) : violence fantastique/combat de blocs sans sang ; pas de chat libre risqué particulier ; pas d'argent réel hors achats Robux ; réponses à donner honnêtement, Roblox attribue l'âge.
- **Accès** : mettre en *Public* seulement après le playtest.

## 3. Achats intégrés (Creator Hub → le jeu → Monetization)
Créer ces objets, puis coller leurs Id dans `src/ReplicatedStorage/Shared/Config.luau` → `Config.Monetization`
(un Id à 0 est désactivé et s'affiche « Bientôt » : le jeu fonctionne sans). Rebuild/Publish ensuite.

| Type | Clé dans Config | Nom | Prix conseillé | Effet (déjà codé) |
|---|---|---|---|---|
| Game Pass | `DoubleXP` | XP x2 | 199 R$ | XP gagnée ×2 |
| Game Pass | `DoubleCoins` | Pièces x2 | 299 R$ | pièces gagnées ×2 |
| Game Pass | `VIP` | VIP | 399 R$ | étiquette ★ VIP, cadeau quotidien +50% |
| Developer Product | `Coins500` | 500 pièces | 49 R$ | +500 pièces |
| Developer Product | `Coins1500` | 1 500 pièces | 129 R$ | +1 500 pièces |
| Developer Product | `Coins5000` | 5 000 pièces | 349 R$ | +5 000 pièces |

Image de chaque pass : réutiliser `icone-512.png` au départ. Garde-fous déjà en place : aucun achat n'augmente les dégâts,
les reçus sont idempotents (jamais crédités deux fois) et sauvegardés avant validation, et l'achat est refusé si le profil n'a pas pu être chargé.

### Raccourci : script de préparation
Copiez `publication/ids.example.json` en `publication/ids.json`, remplissez les Id créés au point 3, puis lancez `tools/publish.sh`
(vérifications → injection des Id dans `Config.luau` → `rojo build`). Il produit `ArenaDesLegendes.rbxl` et ne publie rien :
ouvrez-le dans Studio puis *File → Publish to Roblox*. Un Id laissé à 0 reste désactivé.

## 4. Après publication
- Surveiller *Analytics* (rétention J1/J7) et les erreurs serveur (*Developer Console → F9*).
- Premier lot de correctifs prévu : prise des armes en main, hauteur des rampes, sons (voir README).
