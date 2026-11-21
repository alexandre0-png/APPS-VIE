---
type: jeu
jeu: 2
statut: prive-publie
---
# Jeu 2 : Sortir Du Grenier (La Tombe du Grenier)
- Univers **10776611603**.
- **Hub** : lieu **77452764500707** (lieu de départ, 50 joueurs).
- **Partie** : lieu **88091909899710** « Partie du Grenier » (Max Players 2).
- Rôle choisi par `game.PlaceId` dans `Config.Game.Places`.
- Dossier `tombe-grenier/`, branche `claude/tombe-grenier-animations-5ilizr`.
- Session de développement : `session_0164z8QRKAjeEQzGAp6T7swM`.
- **Dernier publié** : commit f98bdc7 (retour arrière, hub v25, partie v17). Les commits 095bf86 (modèles) et de5b47a (style) ont été retirés : ils empêchaient le lancement chez l'utilisateur.

## Contenu et règles
- Chaîne stricte des énigmes : papier, reflet, coffret, malle, clé, mélodie, horloge, statues, photos, sortie, cave, sous-sol, retour, enfant. L'enfant n'est sauvable qu'après la sortie par le sous-sol (verrou serveur).
- Halos : 24 au plus (limite Roblox environ 31), l'étape active en fort. Journal d'objectifs touche J. Indice automatique après 180 s.
- Hub : décor, murs et plafond invisibles, file solo/duo, retour au hub avec essais répétés.
- Sauvegarde : DataStore « TombeGrenierProfil », partagé hub et partie, fusion par `Ranks.merge`.
- Assets Blender prévus : voir [[Assets/Assets-crees]].

## Reste à faire
- Intégrer les modèles Blender et les sons (session en cours).
- Retour de test utilisateur sur lisibilité, taille des modèles, ambiance.

- 21 nov : dernier publié = 608d3a5 (hub v36, partie v27). Les mentions de f98bdc7 plus haut sont obsolètes. Toutes les demandes de BLENDER_REQUESTS du Grenier sont livrées et branchées.
