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
- Cinématiques (Config.Cinematics) : arrivée devant la maison de nuit, enchaînée sur le réveil dans le grenier (33 à 34 s chacune) ; réveil plus long avec gros plans (plaque, malle, trappe, miroir) ; descente du monstre au sous-sol (30 s) ; fin 4 « le piège » (32 s) ; fin « vérité » (33 s).
  - Chacune se passe par Espace, Échap ou le bouton « Passer ». Pendant une cinématique, le personnage est immobilisé côté client (PlatformStand).
  - Logique de durée et de passage : src/shared/CinematicTimeline.lua, testée par tools/lua/test_cinematic.py (durées de 30 à 60 s lues dans Cinematic.lua).
- Animations (Config.Animations, chaque geste désactivable ; Enabled = false coupe tout) :
  - malle et coffret : le couvercle s'entrouvre (Gestures.lua) ;
  - objets ramassés : ils s'élèvent et s'effacent ;
  - lampes de plafond : quelques-unes se balancent doucement ;
  - pas et respiration : léger balancement de caméra en marche, respiration à l'arrêt (client) ;
  - réveil : battements de paupières (fondu en plusieurs temps) ;
  - débusquage : secousse courte de la caméra.
  - Calculs purs dans src/shared/Motion.lua, testés par tools/lua/test_motion.py.
  - Non faits : animation de tiroir, geste de lecture de document, réaction à l'apparition du monstre.
- Contrôle de portée (scope_check) : détecte une variable lue avant sa déclaration locale ; deux tests unitaires.
- Audio : options de lecture (vitesse, réverbération, boucle) dans Audio.play ; souffle de ventilation en boucle très bas au centre de la maison.
- Récit : quatre phrases de texture pour les livres sans marque-page (Quests.lua, BOOK_FLAVOUR).
- Audio : statique de coupure (statique_tv) quand la télévision s'éteint.
- Graphisme : poussière en suspension dans chaque pièce (Atmosphere.lua, Config.Visual.Dust / DustRate).
- A_FAIRE_UTILISATEUR.md : liste des seules actions réservées à l'utilisateur.
