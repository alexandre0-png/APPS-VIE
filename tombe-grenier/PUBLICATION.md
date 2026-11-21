# Publication : « Sortir Du Grenier » (La Tombe du Grenier)

Document de préparation du passage en public. Rien n'est publié par le code : chaque case de la checklist est une action humaine dans le Creator Hub.

## 1. Fiche de l'expérience

**Nom** : Sortir Du Grenier

**Description courte** (moins de 100 caractères) :
> Réveille-toi au grenier, résous les énigmes d'une maison hantée et échappe à l'ombre. Solo ou duo.

**Description longue** (moins de 1000 caractères) :
> Tu te réveilles dans un cercueil, au grenier d'une vieille maison. Quelque chose rôde en bas.
>
> Sortir Du Grenier est un jeu d'horreur en première personne pour un joueur ou un duo. Explore trois étages, une cave et un sous-sol, lis les notes laissées par la famille, trouve la clé, le coffret, l'horloge, la mélodie du gramophone, descends dans la cave pour libérer l'enfant qu'on y a enfermé, puis enfuis-toi.
>
> Une ombre patrouille la maison. Elle entend tes pas, ta course, ta lampe. Cache-toi dans une armoire, accroupis-toi, lance un objet pour la détourner et garde ton sang-froid : ta sanité baisse dans le noir.
>
> • Une chaîne d'énigmes claire : chaque étape ouvre la suivante, le journal (J) et la flèche d'objectif te guident
> • Solo ou duo, avec un hub d'accueil et une partie privée
> • Aucune scène sanglante : la peur vient de l'ambiance, du son et de la poursuite
> • Jouable sur PC, téléphone et manette
>
> Éteins la lumière si tu l'oses.

**Genres** : Horreur (principal), Aventure, Énigmes. **Appareils** : ordinateur, téléphone, tablette, console (manette). **Joueurs max** : 2 par serveur.

**Cinq accroches** (miniatures, annonces, vidéos) :
1. « Tu te réveilles dans un cercueil. La maison, elle, ne dort pas. »
2. « Une ombre entend chacun de tes pas. »
3. « Un grenier, une cave, une clé : combien de temps tiens-tu dans le noir ? »
4. « À deux, on a moins peur. À peine. »
5. « Horreur sans une goutte de sang. »

## 2. Avertissement et maturité

**Avertissement à afficher en tête de description** :
> Contenu d'horreur : ambiance sombre, bruits soudains et poursuite par une créature. Déconseillé aux joueurs sensibles aux effets de peur et de lumière clignotante.

**Âge conseillé** : 13 ans et plus (à confirmer par le questionnaire).

**Réponses prévues au questionnaire de maturité Roblox** (à reporter dans le Creator Hub, Paramètres, Maturité) :

| Critère | Réponse prévue | Justification dans le jeu |
|---|---|---|
| Violence | Aucune représentation de violence réaliste ; les coups se traduisent par un voile sombre et un son | Pas de sang, pas de blessure visible (règle de conception) |
| Sang, gore | Non | Aucune texture, particule ni modèle de sang |
| Peur, contenu effrayant | Oui, modérée à marquée | Créature, ambiance sombre, sursauts sonores, thème de maison hantée |
| Langage cru, humour cru | Non | Textes narratifs sobres |
| Thèmes sensibles (deuil, enfant en danger) | Oui, léger | Récit d'une famille disparue, enfant à libérer, traité sans détail |
| Alcool, drogues, tabac | Non | Seulement des bouteilles de décor |
| Jeux d'argent | Non | Aucun mécanisme de hasard payant |
| Discussion libre, tchat | Tchat standard de la plateforme | Aucun tchat propre au jeu |
| Achats | Non par défaut | `Config.Shop` vaut 0 : le jeu est gratuit et complet ; tout achat reste désactivé |
| Lumières clignotantes | Oui, modérées | Lampes qui scintillent et coupures de courant (réglage `Lights`) |

## 3. Tableau d'audit

| Domaine | Constat | Preuve ou test | Reste à faire |
|---|---|---|---|
| Remotes | 19 RemoteEvents, 9 du client vers le serveur | `Remotes.lua` ; `Guard.lua` valide chaque argument (texte, vecteurs finis, booléens) et limite le débit par joueur | Relire `Remotes.lua` si un événement est ajouté |
| Remotes dans les modèles | Aucun Remote ni script ne vient d'un modèle chargé | `AssetLoad.sanitize` retire Script, LocalScript, ModuleScript, RemoteEvent, RemoteFunction, Bindable* | Rien |
| Autorité serveur | La chaîne d'énigmes, les objets et la fin de partie sont décidés par le serveur (`Chain.lua`) | `test_chain.py`, `test_robust.py` | Rien |
| DataStore | Un seul magasin, `TombeGrenierProfil` : lecture et écriture sous `pcall`, nouvel essai, profil en mémoire en cas d'échec | `Profile.lua`, `Retry.lua`, `test_robust.py` | Activer « Autoriser l'accès aux services d'API Studio » pour tester la sauvegarde réelle |
| Fuites mémoire | Les tables par joueur sont vidées à `PlayerRemoving` (`Respawn`, `PlayerState`, `Profile`, `Hub`, `SpawnSafety`, serveur de partie) | Revue du code ; 4 minutes virtuelles en duo sans erreur (`test_zero_warn.py`) | Surveiller le panneau « Memory » du Developer Console sur une partie de 30 minutes |
| Démarrage | La partie démarre sans attendre les modèles ; chaque étape isolée et tracée `[Boot]` | `test_boot_async.py`, `test_spawn_roles.py` | Vérifier `[Boot] modèles chargés : N ok, 0 de côté` après publication |
| Erreurs | Aucune erreur ni avertissement inattendu pendant 4 minutes virtuelles (serveur et client) | `test_zero_warn.py`, `test_client.py` | Lire la sortie réelle du serveur au premier lancement |
| Client | Chaque module et gestionnaire isolé ; un module en erreur ne bloque pas le HUD | `test_client.py` | Rien |
| Mobile : pièces | Carte seule sous 1200 pièces ; accessoires plafonnés | `test_mobile.py` | Mesurer le nombre de pièces avec tous les modèles dans Studio (Stats) |
| Mobile : lumières | 4 lueurs actives en qualité basse, 8 en moyenne ; pas plus de 60 lampes construites | `test_mobile.py`, `RoomBudget.lua` | Tester sur un téléphone d'entrée de gamme |
| Mobile : particules | Une poussière par pièce, 3 particules par seconde | `test_mobile.py` | Rien |
| Mobile : interface | Texte d'au moins 14 px, boutons tactiles de 110 × 54 avec mise à l'échelle | `test_mobile.py` | Vérifier en mode émulateur « téléphone » de Studio |
| Chargement des modèles | Plafond global de 10 s, 8 tâches en parallèle, repli procédural | `ModelLoader.lua`, `test_boot_async.py` | Surveiller que `de côté` reste à 0 |
| Sauvegarde du hub | Le rang et le profil se chargent sans bloquer l'arrivée | `Profile.lua`, `test_hub_flow.py` | Rien |

## 4. Checklist avant passage en public

À cocher dans l'ordre. Les trois premières sont bloquantes.

- [ ] Publier **les deux lieux** (hub puis partie) avec la dernière version de la branche, puis jouer une partie complète en solo et en duo sur les versions publiées
- [ ] Vérifier la sortie serveur : `[Boot] carte ok`, `[Boot] Respawn ok`, `[Boot] modèles chargés : N ok, 0 de côté`, aucun `[Client] module ... : erreur`
- [ ] Vérifier que le joueur apparaît dans le cercueil du grenier en moins de 15 secondes
- [ ] Remplir le questionnaire de maturité avec les réponses du tableau du §2
- [ ] Coller nom, descriptions, genres et avertissement du §1 ; ajouter icône et trois captures (grenier, couloir éclairé, poursuite)
- [ ] Paramètres : serveurs privés autorisés pour le hub et la partie, maximum 2 joueurs par serveur, appareils ordinateur, téléphone, tablette, console
- [ ] Tester sur un vrai téléphone : boutons, journal (J), flèche d'objectif, lisibilité du texte
- [ ] Tester à la manette : indice (haut), journal (bas)
- [ ] Contrôler les droits audio : chaque son de `AudioManifest.lua` doit être autorisé pour l'expérience
- [ ] Vérifier que les modèles Blender sont approuvés et utilisables dans les deux lieux
- [ ] Laisser l'expérience en accès privé 24 heures avec deux testeurs, relever les erreurs de la console
- [ ] Passer en public, puis surveiller les analyses (arrivées, durée de session, départs avant la première énigme) pendant 48 heures

## 5. Après la publication
- Consulter chaque jour la console des erreurs serveur ; une ligne `[Boot] ... ERREUR` indique l'étape fautive.
- Relever la part de joueurs qui quittent avant la première énigme : si elle dépasse 40 %, revoir l'introduction et la promesse du hub.

## 6. Boutique (Game Passes et produits développeur)

Tout est optionnel : tant que l'identifiant d'un article vaut 0 dans `Config.Shop`, il n'est pas proposé et le jeu reste entièrement jouable gratuitement. Rien n'est « payer pour gagner » : un indice supplémentaire n'est volontairement pas vendu (l'indice, touche H, est gratuit et illimité). À créer par l'utilisateur sur le site Roblox (Creator Hub > expérience > Monétisation), puis à renseigner dans `Config.Shop` :

| Clé `Config.Shop` | Type | Nom | Description | Prix suggéré | Icône à fournir (512×512) | Identifiant attendu |
|---|---|---|---|---|---|---|
| `GamePasses.LampeRenforcee` | Game Pass | Lampe renforcée | Ta lampe se vide deux fois moins vite, toute la partie. | 149 R$ | `icone_lampe_renforcee.png` | ID du Game Pass, nombre |
| `GamePasses.LanterneDoree` | Game Pass | Lanterne dorée | Cosmétique : ton faisceau de lampe devient doré. Aucun avantage de jeu. | 99 R$ | `icone_lanterne_doree.png` | ID du Game Pass, nombre |
| `Products.Pile` | Produit développeur | Pile de rechange | Recharge ta lampe de 45 points, tout de suite. | 25 R$ | `icone_pile.png` | ID du produit, nombre |
| `Products.Cailloux` | Produit développeur | Cinq cailloux | Cinq cailloux à lancer pour détourner l'ombre. | 25 R$ | `icone_cailloux.png` | ID du produit, nombre |
| `Products.Soutien` | Produit développeur | Soutenir le jeu | Un merci. N'apporte aucun avantage de jeu. | 49 R$ | `icone_soutien.png` | ID du produit, nombre |

Comportement : un bouton « Boutique » apparaît à droite de l'écran seulement si au moins un identifiant est renseigné ; les produits ne se vendent que dans la partie (au hub, seuls les Game Passes) ; les produits sont accordés par `ProcessReceipt` (une seule fois par achat) ; le Game Pass s'applique dès l'achat.

## 7. Textes et images de la page de l'expérience

- Titre, description courte, description longue et les 5 accroches : §1 ci-dessus (à coller tels quels).
- Vignette de l'expérience : **1920×1080** px (16:9), format PNG ou JPG, sans texte important dans les 10 % du bord.
- Icône de l'expérience : **512×512** px, PNG ; icônes des articles de la boutique : **512×512** px chacune.
- La gestion fournit les images ; trois captures à ajouter en plus (grenier, couloir éclairé, poursuite).
