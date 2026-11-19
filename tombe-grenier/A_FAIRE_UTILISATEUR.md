# À faire par toi (et seulement toi)

Liste mise à jour. Tout le reste est fait dans le code et les tests.

1. **Installer Roblox Studio** sur ton ordinateur, et te connecter avec ton compte.
2. **Publier les deux lieux** dans une même expérience :
   - `hub.rbxl` (accueil) ;
   - `game.rbxl` (partie).
   Fichiers construits par Rojo, à ouvrir dans Studio puis publier (Fichier > Publier sur Roblox).
3. **Publication** : les identifiants sont renseignés (`Config.Game.Places` : hub `77452764500707`, partie `88091909899710`, expérience unique « Sortir Du Grenier », univers `10776611603` ; l'ancien hub `124575462695705`, expérience séparée, n'est plus utilisé). Tu publies les deux lieux toi-même via l'API ou Studio ; rien n'a été publié par Claude.
4. **Tester à deux joueurs** dans Studio : réveil, énigmes, trappes, mort et réanimation, fin, retour au hub.
5. **Achats Robux** (optionnels) : créer les Game Pass et produits sur Roblox, puis renseigner leurs identifiants dans `Config.Shop`. Tant qu'ils valent 0, les achats sont désactivés.
6. **Vérifier les nouveautés dans Studio** :
   - horloge du hall (tag `Horloge`) : position, saisie de la date de la plaque ;
   - compteur de la cuisine et étiquette « Réserve » (énigme optionnelle) ;
   - fin 4 « le piège » : la date fausse du cahier scelle le cercueil. Décide si cette fin irréversible te convient, sinon retire-la dans `Quests.lua` (`submitDate`).
7. **Régler les effets** dans `Config.Visual` : `Vignette`, `VignetteMax`, `CandleFlicker`, `Dust`, `DustRate`. Mettre `false` pour couper un effet.
8. **Choisir la progression** : `Config.Design.ProgressionV2` (`true` = avec l'horloge, `false` = progression d'origine). Les deux sont couvertes par la simulation.
9. **Images et textures** : vérifier que les textures fournies s'affichent correctement dans Studio.
10. **Vérification d'identité** : si Roblox la demande pour publier ou pour les achats, c'est à toi de la faire.
11. **Animations** : régler ou couper chaque geste dans `Config.Animations` (malle, coffret, ramassage, lampes, pas et respiration, réveil, secousse). Vérifier dans Studio que les tweens de couvercle et de lampe ne gênent pas la prise en main des objets.
12. **Cinématiques** : régler `Config.Cinematics` (une par moment clé : intro, apparition, descente, fin 4, fin vérité ; ou `Enabled = false`). Vérifier dans Studio que les plans de caméra cadrent bien la maison, le sous-sol et le cercueil (coordonnées tirées de la carte, à contrôler), et que le bouton « Passer » est lisible sur téléphone.
13. **Tiroir et lecture de document** : vérifier dans Studio que le tiroir de la cuisine (tag `Tiroir`) se place bien contre le meuble, et que la feuille de lecture ne gêne pas (`Config.Animations.DocumentRead`).
14. **Modèles de décor** : dans Studio, vérifier que chacun des sept identifiants de `Config.Assets` se charge (avertissement `[ModelLoader]` sinon), que la chaise et la table remplacent bien les boîtes, et que les décors fixes (lampe, plante, chaise en bois, chaise bloquante) sont bien placés. Désactiver le chargement : `Config.Assets.Enabled = false`.
15. **Modèle du monstre** : dans Studio, vérifier qu'un des trois identifiants `Config.Assets.Monstre1` à `Monstre3` se charge (sinon, le rig de secours est utilisé et un avertissement `[MonsterAI]` apparaît).
16. **Hub** : dans Studio, vérifier les zones « Partie solo » et « Partie duo », les panneaux de file d'attente, et que la téléportation vers le serveur privé fonctionne. Les deux projets Rojo sont `hub.project.json` (lieu hub) et `game.project.json` (lieu de jeu).
17. **Interface** : vérifier sur téléphone, tablette et PC que rien ne masque le centre de la vue et que les textes restent lisibles (échelle réglable dans l'échelle UIScale de `src/client/init.client.lua`).
18. **Formatage stylua** : fait (stylua 2.6 compilé avec la prise en charge de Luau, `stylua.toml`, `.styluaignore` pour MapData.lua généré). Pour reformater : `stylua src tools`.
19. **Détails de pièces (passe 2)** : dans Studio, parcourir les 20 pièces et vérifier que les détails (dossier `Maison/Détails`) restent lisibles et ne gênent pas le regard (taches, flaques en verre, toiles). Ils n'ont ni collision ni tag. Pour en retirer un type, supprimer son nom dans `tools/map/details.py` puis relancer `python3 tools/map/generate_map.py`.
20. **Sauvegarde du profil (rangs, défis, tutoriel)** : dans Roblox Studio, activer Game Settings > Security > « Enable Studio Access to API Services » pour tester la sauvegarde ; en ligne elle fonctionne d'office. Pour couper : `Config.Replay.StoreProfile = false`.
21. **Régler la tension et la difficulté** : `Config.Tension` (durées du calme et de la montée, facteurs par temps), `Config.Balance` (solo et duo). Jouer une partie solo et une duo complètes pour juger le rythme ; couper la courbe avec `Config.Tension.Enabled = false`.
22. **Tutoriel et rangs** : vérifier avec un compte neuf que les trois indices apparaissent sans gêner, et que le rang s'affiche au-dessus du personnage (hub et partie). Réinitialiser un profil : supprimer sa clé dans le DataStore `TombeGrenierProfil` (clé `p<UserId>`).
23. **Décor du hub** : dans Studio, ouvrir `hub.rbxl` (rôle « hub » forcé) et vérifier : zone d'arrivée dégagée, panneaux solo et duo lisibles depuis l'arrivée, tableau des règles lisible, lueurs des bougies et lampes, orientation des modèles remplaçants (étagères, lampes, plantes : `Config.Assets.HubBibliotheque`, `LampeHorreur`, `Plante`). Couper le décor : `Config.Hub.Decor = false`.
24. **Arrivée dans la partie** : refaire le test réel hub vers partie (solo et duo) et confirmer l'apparition dans le cercueil du grenier, sans chute. Si cela échoue encore, ouvrir la console serveur (F9, onglet Serveur) et copier les lignes `[Spawn]` : elles donnent le rôle, le PlaceId, l'état de la carte, la position du joueur à chaque étape et le sol sous ses pieds. Réglages : `Config.Spawn` (`VoidY`, `HoldSeconds`, `FreefallSeconds`, `EarlyWindow`, `Debug`). Republier les deux lieux : `StreamingEnabled = false` est dans les fichiers de projet (vérifier dans Studio, Workspace, que la case est décochée).
25. **Vérifier le fichier publié sur chaque lieu** : le lieu hub (77452764500707) doit contenir `hub.rbxl` (un seul Script « Server », pas de modules MapBuilder, Respawn, Quests dans ServerScriptService/Server) ; le lieu de partie (88091909899710) doit contenir `game.rbxl`. Si la console serveur du hub affiche « le script de PARTIE tourne dans le lieu HUB », les fichiers sont inversés. Les lignes `[Spawn]` du hub commencent par « hub : démarrage ».
26. **Republier les deux lieux** après ce correctif (cause réelle : un chemin de module faux dans Shop.lua tuait le script serveur de partie dès son démarrage). Vérifier ensuite : plus d'« Infinite yield possible » sur `Remotes` dans la console client, lignes `[Spawn]` dans la console serveur, apparition dans le cercueil du grenier.

27. **Chaîne d'énigmes** : jouer une partie en suivant l'objectif affiché ; vérifier qu'aucune étape n'est faisable avant la précédente (message « Pas encore ») et que l'enfant n'est libérable qu'après la sortie par le sous-sol et le retour. Ordre modifiable dans `src/shared/Chain.lua`.
28. **Aspect en jeu (lisibilité, portes, meubles)** : vérifier dans Studio (Play) : halos et pastilles colorés sur les objets interactifs et rien sur le décor (coupe : `Config.Design.Markers = false`), portes qui pivotent du bon côté, seuils au sol, panneaux d'escalier, porte d'entrée qui s'ouvre vers le jardin. Donner d'autres identifiants de catalogue (canapé, table basse, cuisinière, lit) à ajouter dans `ModelLoader.MODELS` au nom exact du meuble ; sans identifiant, les boîtes de substitution restent.
