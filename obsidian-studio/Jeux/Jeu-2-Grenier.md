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
- 21 nov (après-midi) : retours utilisateur (lancement auto du hub, invite permanente, répliques sans encadré, enfant dans la cave, meubles). Commits e3fa521 à cb1c5f5 publiés : partie v29, hub v40. Vue 1re personne forcée (StarterPlayer). Lot 4 Blender créé (lot 9 des assets), branchement demandé à la session.
- 21 nov : lot 4 branché (dfa20a9), publié : partie v30, hub v41.
- 21 nov : bc4360c (déroulé pièce par pièce, perf) publié : partie v31, hub v42. Demandé : lot 13 meubles, boutique, textes de publication.
- 21 nov : 53f7a97 (11 meubles m_*, boutique 2 passes + 3 produits à ID 0, textes de publication) publié : partie v32, hub v43.
- 21 nov : boutique créée par API : passes LampeRenforcee 2094131168 (149), LanterneDoree 2096725189 (99) ; produits Pile 3734229107 (25), Cailloux 3734229116 (25), Soutien 3734229125 (49). Commit c8f2dac publié : partie v33, hub v44. Bouton Boutique déplacé à gauche (corrigé : dépassait l'écran en paysage téléphone).
