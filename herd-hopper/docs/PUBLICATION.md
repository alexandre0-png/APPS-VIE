# Publier Saute-Zoo sur Roblox

Tout se fait dans Roblox Studio et sur le Creator Dashboard (create.roblox.com), sans API. Rien n'a été publié.
La liste courte de ce que toi seul peux faire est dans `A_FAIRE_UTILISATEUR.md` (avec les noms, prix et identifiants des achats).

Fichiers prêts : `build/SauteTroupeau.rbxlx` (le jeu), `marketing/` (icône, 3 vignettes, 4 icônes de pass, 7 icônes de produits).

## 1. Test dans Studio
Voir la check-list de `A_FAIRE_UTILISATEUR.md` (section 1). Le jeu n'a pas encore tourné dans Roblox.

## 2. Publier
Fichier > Publier sur Roblox sous... > nouveau jeu :
- Nom : **Saute-Zoo**
- Genre : Action (ou Aventure) · Appareils : ordinateur, téléphone, tablette, console
- Joueurs max : 12 à 16 · Avatar : R15

## 3. Page du jeu
Icône `icone-experience-512.png` ; vignettes dans l'ordre `vignette-1`, `vignette-2`, `vignette-3` ; questionnaire de classification (réponses honnêtes : pas de violence réaliste, achats facultatifs).

## 4. Achats Robux
Le code est prêt (`MonetizationService`) : reçus sans doublon, annulation si la sauvegarde échoue, « Continuer » utilisable pendant la fenêtre de mort ou stocké pour l'expédition suivante. La partie de base (1 vie, 3 lassos de capture, zoo de 6 enclos, 4 zones) reste gratuite.
Noms, prix, icônes et ordre des identifiants : `A_FAIRE_UTILISATEUR.md`, section 3.

## 5. Textes de la page du jeu

**Description (français)**

> Tu as hérité d'un zoo vide. Pars en expédition, saute d'animal en animal et récupère ceux qui portent un cœur rose pour les ramener dans ton zoo !
>
> - Le sol est mortel : ne rate pas ton saut
> - Un cœur rose sur un animal ? Monte-le, gagne sa confiance, puis récupère-le
> - Lasse les animaux à distance avec la visée assistée
> - 4 zones : savane, marais, désert, volcan, chacune avec ses animaux, ses dangers et son boss
> - 14 animaux en 3 versions (Normal, Cristal, Doré) et 4 boss géants à capturer
> - Plus ton zoo est grand, plus tes visiteurs te rapportent d'or, même quand tu es absent
> - Améliore tes animaux avec des os, agrandis ton zoo, déroule l'histoire et les quêtes du jour
> - Expéditions à plusieurs de 4 minutes maximum

**Description (anglais)**

> You inherited an empty zoo. Go on expeditions, hop from animal to animal and bring back the ones with a pink heart!
>
> - The ground is deadly: don't miss a jump
> - Pink heart on an animal? Ride it, earn its trust, then recruit it
> - Lasso animals from a distance with assisted aim
> - 4 zones (savanna, swamp, desert, volcano), each with its animals, hazards and boss
> - 14 animals in 3 versions and 4 giant bosses to capture
> - The bigger your zoo, the more gold it earns, even while you are away
> - Upgrade animals with bones, expand your zoo, follow the story and daily quests
> - Multiplayer expeditions of up to 4 minutes

**Mots-clés** : zoo, animaux, lasso, saut, collection, boss, multijoueur, simulation, aventure.

## 6. Mise en ligne
Repasser le jeu en Public, surveiller la console développeur (F9) le premier jour, mettre à jour avec Fichier > Publier sur Roblox.

## Remarques
- Les images de `marketing/` sont originales (blocs du jeu) ; régénérables avec `node tools/marketing/make.js` (Playwright).
- Roblox garde une commission sur les ventes ; le retrait d'argent réel suit les règles du programme d'échange de développeur (à consulter sur le site Roblox).
