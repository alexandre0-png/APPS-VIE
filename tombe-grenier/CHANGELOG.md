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

### Modifié
- Formatage : stylua appliqué à tout le code (stylua.toml : Luau, tabulations, 120 colonnes ; MapData.lua généré exclu).
- Rôles des lieux inversés (le tableau de bord Roblox ne permet pas de changer le lieu de départ) : hub = 77452764500707 (lieu de départ), partie = 88091909899710. Aucun script ne suppose que le lieu de départ est le jeu : le rôle se déduit de `game.PlaceId` comparé à `Config.Game.Places` (Hub.lua).
- Hub : devient un lieu de la même expérience que la partie (univers 10776611603) ; `Config.Game.Places = { hub = 77452764500707, game = 88091909899710 }`, l'ancien hub 124575462695705 (expérience séparée) n'est plus utilisé. Repli sur un serveur public avec message clair si Roblox refuse le serveur privé. Tests : identifiants, ancien hub écarté, DataStore du profil partagé entre hub et partie, repli (test_places.py).

### Corrigé
- Apparition dans le ciel en partie, deuxième passe (le correctif f60aab2 ne suffisait pas). La géométrie est saine : sur la vraie construction de MapBuilder, CercueilSpawn (90, 24.5, 45) repose sur le plancher du grenier (dessus à y = 24), le SpawnLocation est actif et neutre, rien ne bouche l'espace au-dessus. Cause la plus probable : `Workspace.StreamingEnabled` (activé par défaut sur un lieu récent) : la carte est construite par le serveur et le client ne reçoit pas encore le sol sous son personnage quand celui-ci apparaît, il tombe donc. Corrections : `StreamingEnabled = false` dans game.project.json et hub.project.json (vérifié dans le fichier construit) ; personnage ancré `Config.Spawn.HoldSeconds` (2,5 s) à chaque apparition, avec `RequestStreamAroundAsync` si le flux est actif ; replacement sur le point d'apparition dès le premier point bas (sous `VoidY`) et dès une chute libre de plus de `FreefallSeconds` (1,5 s) pendant les `EarlyWindow` (10 s) premières secondes ; traces `[Spawn]` dans la console serveur (rôle, PlaceId, StreamingEnabled, carte prête, position à l'apparition puis toutes les 2 s avec le sol vu du serveur, replacements) désactivables par `Config.Spawn.Debug`. Tests : test_spawn_map.py (18, dont MapBuilder.build exécuté).
- Hub : murs et plafond invisibles autour de la zone (5 pièces, `HubLayout.boundBoxes`, collisionnables, non interrogeables, non détectables) : personne ne sort ni ne tombe ; le sol couvre toute la zone jouable. Tests dans test_hub_decor.py.
- Bug critique : à l'arrivée par téléportation dans le lieu de partie, le joueur apparaissait dans le ciel puis mourait. Cause : `CharacterAutoLoads` n'était coupé que dans `Respawn.init`, après `ModelLoader.ensure()` (chargements de modèles qui attendent) et `MapBuilder.build()` ; Roblox chargeait donc le personnage sans carte ni point d'apparition, et il tombait dans le vide. Correction : `CharacterAutoLoads = false` dès le début du script serveur ; porte d'apparition (SpawnGate, Respawn.setReady) : aucun `LoadCharacter` avant que la carte et un point d'apparition actif existent (les joueurs arrivés avant sont chargés à l'ouverture, `Player.RespawnLocation` défini) ; filet de sécurité SpawnSafety (hub et partie) : tout personnage sous `Config.Spawn.VoidY` est replacé sur le point d'apparition avec une protection brève, et un personnage déjà présent sans point d'apparition est retenu en l'air. Chemin de retour vérifié (la partie renvoie au hub par TeleportAsync ; le hub construit son point d'apparition avant l'arrivée et porte le même filet). Tests : tools/lua/test_spawn.py (16, dont l'ordre « joueur ajouté avant la carte » exécuté sur le vrai Respawn.lua).
- Lieu hub : identifiant de lieu (et non d'univers) ; test de validation des identifiants (test_places.py).
- Achats Robux : un achat n'est plus accordé au lieu hub (l'effet y serait perdu) ; il reste en attente jusqu'au lieu de jeu.
- Mort fatale (plus personne debout) : les minuteries de réapparition et les invites de réanimation en attente sont annulées avant la fin de partie.
- Nouvelle partie : les invites et minuteries de la partie précédente sont annulées.
- PlayerState : commentaires mélangés sur les champs `log` et `roomDark` séparés.

### Ajouté
- Décor du hub (HubLayout.lua, HubDecor.lua, Config.Hub) : étagères, malles, bougies à PointLight, lampes chaudes, toiles d'araignée, tapis, cadres, plantes mortes, poutres et poussière, panneau explicatif devant chaque borne, tableau des règles, nappe douce très basse. Modèles Config.Assets chargés avec repli procédural ; limites de pièces et de lumières (RoomBudget) ; zone d'arrivée dégagée ; aucune collision, aucun clic, aucune plaque cachée. Tests : tools/lua/test_hub_decor.py (24).
- Hub seul en Studio : le script du hub force Config.Debug.PlaceRole = "hub" (ignoré en production, où le rôle vient de game.PlaceId).
- Corrigé : le panneau d'explication du hub affichait son texte sur la face avant (-Z), invisible depuis l'arrivée ; il est maintenant sur la face arrière.
- Passe 3 : courbe de tension en trois temps (Config.Tension, Tension.lua) reliée aux événements d'ambiance, aux chutes d'objets, aux coupures de courant, au volume de fond et au monstre (ouïe, poursuite, attaque surprise) ; difficulté distincte solo et duo (Config.Balance, Balance.lua : monstre, durées de recherche, vies, délai des indices) ; tutoriel discret de trois indices contextuels (Tutorial.lua) ; rangs et titres affichés au hub et en partie (Ranks.lua, Profile.lua, DataStore avec repli en mémoire) ; six défis optionnels (Challenges.lua) ; graine du jour et graines fraîches (Replay.lua). Fin de partie : points, rang et défis affichés à chaque joueur. Tests : tools/lua/test_pass3.py (33).
- scope_check : `type` reconnu comme fonction globale.
- Passe 2 terminée (mobilier et détails narratifs) : 143 détails dans les 20 pièces (taches, traînées, empreintes, flaques, cendres, papiers, valises, jouets, dessins à la craie, toise de l'enfant, griffures, toiles, cadres retournés, horloges arrêtées...). Données dans tools/map/details.py (catalogue + liste par pièce), pose déterministe et validée par generate_map.place_details(), construction dans MapBuilder (dossier Maison/Détails, sans collision, sans tag, attribut Room). Treize matériaux ajoutés (tache, terre, cendre, papiers, eau, verre, toile, craie, cire, linge, valise, jouet, fleurs). Mobilier existant et modèles de Config.Assets inchangés ; progression inchangée.
  - Tests (tools/map/test_details.py) : détails dans leur pièce, hors escalier, hors approche de porte, hors meubles et décor, hors repères de jeu et emplacements, sans chevauchement, déterministes, sans tag ; aucun indice en pièce fermée ; toutes les portes et pièces restent accessibles même si les détails étaient solides (grille d'accessibilité par niveau). Simulation relancée sur 60 graines.
- Passe 2 (partielle) : budget de lueurs de pièce. Seules les lueurs de la pièce du joueur et des plus proches restent allumées (RoomBudget.activeRooms, Config.Visual.RoomLights, RoomLightQuality : auto, bas, moyen, haut). Les repères de sol évitent les meubles (RoomBudget.landmarkSpot). Testé sur les vraies données de carte (tools/lua/test_budget.py).
- Passe 1 des zones : chaque pièce (20) a une lueur propre (couleur, intensité, portée), un son d'ambiance très bas en boucle, et un repère au sol nommé (src/shared/RoomMood.lua, MapBuilder.applyMoods). Testé par tools/lua/test_moods.py. Les lueurs n'ont pas d'ombre et n'affectent pas les lampes ni les pièces sombres.
- Hub : brume et lumière froide, lampes colorées aux piliers, panneau d'explication face à l'arrivée. Panneau de saisie (coffret) à l'échelle de l'écran.
- Hub : deux zones de lancement (« Partie solo », « Partie duo ») avec panneau de file d'attente ; la duo attend un second joueur 60 s au plus (HubRules.lua, testé). Décor du hub : piliers et banc.
- Projets Rojo : hub.project.json (src/hub + Common + Shared) et game.project.json (src/server + src/client + Common + Shared) ; dossier commun src/common (Hub.lua déplacé). Testé par tools/lua/test_projects.py.
- Interface : ancrage aux zones sûres (DeviceSafeInsets), échelle selon l'écran (UIScale, 0.8 à 1.3), messages et règles au tiers supérieur, centre réservé au coffret. Testé par tools/lua/test_ui.py.
- Modèle du monstre : ses trois identifiants sont dans Config.Assets (Monstre1 à Monstre3), chargés avec le même chargeur sûr (pcall, délai, scripts retirés) et désactivables via Config.Assets.Enabled. Sans modèle valide, le rig de secours reste.
- Modèles de décor (Config.Assets) : chaise de la salle à manger (remplace « chaise »), fauteuil antique (« fauteuil »), table longue (« table »), plante (« plante »), lampe avec lueur et chaise en bois (décor fixe), chaise bloquante devant une porte (décor seulement, jamais de collision ni de progression).
  - Chargement côté serveur seulement (InsertService, pcall, délai Config.Assets.Timeout). Scripts et événements retirés. Modèle vide ou corrompu refusé ; la pièce de remplacement actuelle reste.
  - Logique testée avec un chargeur factice (tools/lua/test_assets.py).
- Animations de suite : tiroir de la cuisine (coulisse hors du meuble, Config.Animations.Drawer) ; geste de lecture (la feuille monte à hauteur des yeux à chaque document, Config.Animations.DocumentRead) ; réaction à l'apparition du monstre (secousse et sursaut des bords, pendant et après la cinématique, Config.Animations.MonsterReaction).
- Cinématiques réduites aux moments clés : intro courte (arrivée de nuit), première apparition (avec la caméra qui se tourne), descente, fin 4, fin vérité. Le réveil dans le grenier n'est plus une cinématique (le battement de paupières le remplace).
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
