---
type: guide-pc
maj: 2026-11-21
---
# Blender sur le PC : tout est prêt

Paquet : `blender-pc.zip` (fichiers .blend, FBX, textures cuites, scripts). Blender est déjà installé sur le PC de l'utilisateur.

## 1. Contenu du paquet
- `blend/` : 5 fichiers .blend, un par lot. Chaque modèle est dans sa collection, rangés en grille, avec les couleurs de ses pièces (suffixe `Nom__RRGGBB`).
- `fbx_sources/outB2 … outB6` : les 130 modèles tels que téléversés sur Roblox (pièces séparées par couleur, biseautés).
- `baked/outB2 … outB6` : les mêmes modèles en UN SEUL maillage avec UV et `*_ColorMap.png` (256 x 256) : version prête pour une texture Roblox (SurfaceAppearance).
- `textures_sources/` : les 22 textures tuilables (PNG 1024).
- `scripts/` : générateurs et outils Python Blender (`make_*.py`, `build_blend.py`, `bake_atlas.py`, `update_all.py`, `scenes.py`, `lib.py`).

## 2. Ouvrir
1. Blender, Fichier, Ouvrir, `blend/01_…blend`.
2. Panneau Collections (haut droite) : un modèle par collection. Touche `/` isole l'objet sélectionné. Unités : 1 unité = 1 stud, devant vers -Y, origine au centre-bas.

## 3. À faire à la main, par priorité
1. **Monstre « OmbreRampante »** (Grenier, fichier lot 2) : sculpter une vraie silhouette (épaules, mains aux longs doigts, cou), garder 1500 faces au plus. Option : 5 os (torse, tête, 2 bras, queue) pour un cycle de marche.
2. **Gardiens** loup, chien, ours, chevalier (fichier lot 3) : museau, oreilles, pattes mieux formés ; garder pattes séparées pour l'animation par code.
3. **Pets** (14 espèces, lots 2 et 3) : expressions, yeux, détails ; préparer 4 variantes de ColorMap par pet : Doré, Néon, Arc-en-ciel, Alien.
4. **Œufs** (6 raretés) : peindre les motifs directement sur `*_ColorMap.png` (UV déjà dépliés), un style par rareté.
5. **Textures tuilables** (22) : repeindre ou affiner en gardant la répétition sans couture (test : décaler de 50 % et corriger le joint).
6. **Vignettes** : relancer `scenes.py` (caméra, lumières) et retoucher.

## 4. Import dans Roblox Studio (sur le PC)
1. Studio : onglet Avatar, Importer 3D (ou Fichier, Importer 3D). Choisir un `*_UV.fbx` du dossier `baked`.
2. Cocher la création du MeshPart et du SurfaceAppearance, puis choisir `*_ColorMap.png` pour la ColorMap.
3. Vérifier l'échelle (1 unité = 1 stud) et l'orientation (devant = Z+ Roblox pour un avant -Y Blender, sinon règle `Config.Assets.Front`).
4. Clic droit sur le modèle, Enregistrer dans Roblox : copier l'ID de l'asset.
5. Donner à Claude le nom du modèle et l'ID : il le branche dans `Config.Assets` (le jeu garde son repli si l'asset échoue).
- Pour garder la **même ID** qu'un modèle déjà en jeu : exporter le FBX final de Blender et le donner à Claude, qui le téléverse en place (`PATCH /assets/v1/assets/{id}`, script `update_all.py`).

## 5. Contrôles avant d'envoyer
- Moins de 2000 faces par modèle, 1 matériau par couleur si pièces séparées, pas de scripts, pas de sons dans le FBX.
- Nommer les pièces `Nom__RRGGBB` si le modèle n'a pas de texture.
- Pas de modèle plus gros que 20 studs sans accord (budget mobile).

## 6. Avec Claude Code local et le MCP Roblox_Studio
- Ouvrir Studio avec le lieu de test, lancer `claude` dans `roblox-travail`.
- Phrases utiles : « Importe le FBX X et place-le dans Workspace », « Lis la console de Studio », « Lance un playtest et dis-moi les erreurs ».
- Studio ouvert bloque les publications par API (erreur 409) : le fermer avant que la session de gestion publie.

## 7. Retour à la gestion
Envoyer à la session de gestion : fichier modifié, ou ID d'asset par nom de modèle. Elle met à jour le coffre `obsidian-studio` et publie après vérification.
