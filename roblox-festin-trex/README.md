# 🦖 Festin du T-Rex — jeu Roblox (Jeu 4)

Coopératif, multijoueur, graphismes Roblox classiques (Parts natives, aucun asset externe).
Un T-Rex géant a faim : les joueurs prennent de la nourriture aux stands et la lancent dans sa bouche.

## Analyse de la capture « Charts »

| Jeu repéré | Ce qui fonctionne | Ce que le jeu en retient |
|---|---|---|
| Lancer de la nourriture (94 % 👍, 147 k) | Boucle ultra lisible : prendre → viser → lancer → récompense | Boucle centrale, adaptée au tactile |
| Survivre à vos idées / Tsunami (87 %, 53 k) | Événement de survie court et spectaculaire | « Marée de sauce » : vague à esquiver en grimpant |
| Voler un œuf (91 %, 490 k) | Œufs, collection, rareté | Œufs, compagnons, 5 raretés |
| Poupée réaliste / physique (en plein essor) | Réactions physiques drôles | Projection des joueurs éclaboussés, T-Rex qui mâche |
| Brookhaven, Murder Mystery 2, Blox Fruits | Sociabilité, progression longue | Multijoueur partagé, évolutions, classement |

Rien n'est copié : concept, noms, carte et systèmes sont originaux.

## Boucle de jeu
1. **Stand** (touche E / bouton) : remplit le panier avec une nourriture (pomme gratuite, 5 autres à débloquer).
2. **Lancer** : clic, tap, bouton LANCER (mobile/manette) ou touche F. Viser la **bouche** du T-Rex.
3. **Pièces** : valeur × combo (jusqu'à x2,5) × plat préféré (x3) × « faim de loup » (x1,5) × événement × bonus permanents.
4. **Festin** : quand la jauge du T-Rex est pleine, tous les contributeurs reçoivent pièces (+ œuf possible), le T-Rex grandit (5 stades : Bébé Rex → Titan Rex).
5. **Événements** toutes les ~3 min : 🌊 Marée de sauce (grimpe sur une table, récompense de survie), 🍗 Pluie gourmande (boules dorées), 🔥 Frénésie (pièces x2).

## Progression et fidélisation
- 6 améliorations (portée, cadence, panier, gourmandise, visée, vitesse), 6 nourritures.
- Œufs (classique 4 K / doré 40 K / gratuits) → 11 compagnons, 5 raretés, bonus de pièces, 3 emplacements (4 dès l'évolution 5).
- Quêtes du jour (3 tirées parmi 6 types) et série de connexion sur 7 jours.
- Évolution (renaissance) : x1,5 / x2 / x2,5… permanent.
- 5 fourchettes d'or cachées sur la carte (+ bonus si toutes trouvées).
- Niveau gourmet, classement mondial (OrderedDataStore) affiché sur un panneau dans le monde et dans l'interface.

## Installation
**Sans outil** : ouvrir `dist/FestinDuTRex.rbxlx` dans Roblox Studio → Play. Le monde est construit par script au démarrage.
Régénérer le fichier après modification : `python3 tools/build_rbxlx.py`.

**Avec Rojo** : `rojo serve default.project.json` puis se connecter depuis Studio.

Pour tester la sauvegarde en Studio : Game Settings → Security → *Enable Studio Access to API Services*.
Sans cela le jeu reste jouable avec un profil temporaire (message affiché, rien n'est enregistré).

## Architecture
```
src/shared   Config (tout l'équilibrage), Util, Economy, QuestLogic, DinoCore, Ballistics (purs, testables), Remotes
src/server   Main + Services : DataService (verrou de session), PlayerService, FoodService (lancers),
             DinoService, EventService, QuestService, PetService, ShopService (routeur des requêtes),
             LeaderboardService, MapBuilder (monde procédural)
src/client   Main, Store, HUD, Panels (boutique, nid, quêtes, top, évolution), Effects, Pets, Input, UIKit
tests/       test_all.luau + run.sh (logique pure + verrou DataStore avec faux magasin)
tools/       build_rbxlx.py, check.sh (analyse luau-lsp avec les types Roblox)
```

## Sécurité (serveur autoritaire)
- Le client n'envoie que la **position visée** : origine, portée, cadence, munitions et résultat sont calculés côté serveur (trajectoire simulée par raycasts, les clients ne font que la rejouer).
- Types, finitude et bornes de tous les arguments vérifiés ; limiteur par jeton sur `Throw`, les stands et `Request`.
- Un seul `RemoteFunction` (`Request`) pour tous les achats : existence, propriété, prix, niveau max, emplacements validés.
- Tirage des œufs côté serveur. Aucune donnée n'est écrite par le client.
- Sauvegarde avec verrou de session (`UpdateAsync`, expiration 150 s) contre la duplication entre serveurs ; si le chargement échoue, le profil est temporaire et **n'écrase jamais** la sauvegarde.

## Vérifications réalisées — état réel
| Contrôle | Résultat |
|---|---|
| Génération du `.rbxlx` : XML bien formé, 25 scripts dans l'arborescence attendue | ✅ exécuté |
| Analyse Luau avec types Roblox (`tools/check.sh`) | ⚠️ **non exécutée** : le bac à sable a refusé de lancer le binaire `luau-lsp` téléchargé |
| Tests unitaires (`tests/run.sh`) | ⚠️ **écrits mais non exécutés** (même raison, binaire `luau`) |
| Partie jouée dans Roblox Studio | ❌ **jamais lancée** (aucun Studio dans l'environnement) |
| Relecture manuelle ligne à ligne (références, signatures des remotes, ordre d'initialisation, identifiants Luau) | ✅ effectuée |

Le code n'a donc **pas été prouvé fonctionnel** : premier réflexe attendu à l'ouverture, lancer `tools/check.sh`, `tests/run.sh`, puis Play en Studio et lire la fenêtre Output.

## Reste à finaliser / limites connues
- Sons : chemins `rbxasset://sounds/...` intégrés à Roblox, non vérifiés ; remplaçables dans `Config.Sounds`.
- Pas de Game Pass ni de produit développeur (aucun ID à inventer) : à ajouter avec vos propres IDs.
- Les animations de lancer sont un simple mouvement d'épaule (aucun ID d'animation externe).
- Équilibrage (prix, durées, récompenses) calculé sur papier, non éprouvé en jeu : tout est dans `Config.luau`.
- Pas de test de charge ; budget visé : < 700 Parts statiques, aucun objet réseau par projectile (arcs rejoués côté client).
