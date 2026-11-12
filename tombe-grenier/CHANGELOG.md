# Journal des modifications

## Non publié (branche claude/tombe-grenier-animations-5ilizr)

### Effets de peur (Config.Visual : Vignette, VignetteMax, CandleFlicker)
- Vignette : bords de l'écran assombris selon la sanité (client, sans image).
- Bougies : la lueur vacille pendant une minute (pcall).
- Non fait : déformation de l'image (demanderait un shader ou un asset, non fourni).

### Fin 4 « le piège » (choix du joueur)
- Confirmation : la première saisie de la date du cahier affiche un avertissement (« Tu ne pourras pas revenir en arrière ») ; il faut la ressaisir pour sceller. Toute autre saisie annule l'armement.
- Portée : la fin ne concerne que la partie en cours ; rien n'est sauvegardé.
- La date juste est sur la plaque, lue avant le cercueil.
- Au cercueil, saisir la date du cahier (fausse, barrée) scelle l'enfant : fin 4. Le total des fins passe à 4. La fin vérité reste la date de la plaque.

### Énigme optionnelle (cuisine, Config.Design.ExtraSafe)
- Une étiquette « Réserve » donne un code à 3 chiffres (tiré de la seed) ; le compteur de la cuisine le demande. Bonne réponse : une pile. Ne bloque aucune étape.

### Progression V2 (Config.Design.ProgressionV2 = true ; false rétablit l'ancienne progression)
- Nouvelle étape « horloge » entre la mélodie et la clé de la malle : régler l'horloge du hall (saisie de la date de la plaque, MMJJ).
- Génération : horloge du hall (tag Horloge) dans tools/map/generate_map.py ; rendu dans MapBuilder.
- Tests : solvabilité de l'horloge sur 60 graines (sim), position de l'horloge dans le hall (cartographie).

### Corrigé
- Achats Robux : un achat n'est plus accordé au lieu hub (l'effet y serait perdu) ; il reste en attente jusqu'au lieu de jeu.
- Mort fatale (plus personne debout) : les minuteries de réapparition et les invites de réanimation en attente sont annulées avant la fin de partie.
- Nouvelle partie : les invites et minuteries de la partie précédente sont annulées.
- PlayerState : commentaires mélangés sur les champs `log` et `roomDark` séparés.

### Ajouté
- Contrôle de portée (scope_check) : détecte une variable lue avant sa déclaration locale ; deux tests unitaires.
- Audio : options de lecture (vitesse, réverbération, boucle) dans Audio.play ; souffle de ventilation en boucle très bas au centre de la maison.
- Récit : quatre phrases de texture pour les livres sans marque-page (Quests.lua, BOOK_FLAVOUR).
- Audio : statique de coupure (statique_tv) quand la télévision s'éteint.
- Graphisme : poussière en suspension dans chaque pièce (Atmosphere.lua, Config.Visual.Dust / DustRate).
- A_FAIRE_UTILISATEUR.md : liste des seules actions réservées à l'utilisateur.
