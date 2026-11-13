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
- Histoire en 5 chapitres (un par stade du T-Rex) et 2 zones à débloquer (Cuisine du Chef niv. 10, Terrasse du Titan niv. 25 + évolution) avec coffre quotidien.
- Les achats Robux restent un confort (x1,5 pièces, +1 emplacement, visée) : aucune zone ni progression gratuite n'est bloquée par un paiement.
- Modèles Roblox externes (optionnels, `Config.Assets`) : tables de festin (1338860741, 1452069624) et salon des invités (10551600237) posés côté serveur ; T-Rex alternatif au choix (`DinoModel` = "builtin" par défaut | "roblox" 71422282686175 | "trex2" 10683798442). Chargement par `InsertService:LoadAsset` dans un `pcall` avec délai maximum, tout script/événement supprimé, repli sur les pièces actuelles en cas d'échec. Un T-Rex alternatif n'est adopté que s'il contient une mâchoire reconnaissable (sinon le T-Rex intégré est conservé) ; hitbox, festin, rugissement, marche et mâchoire restent ceux du jeu. 1312960740 et 1166118062 (véhicules) sont refusés.
- Moments clés seulement (`Config.Cinematics`) : courte intro qui explique le contexte et le but (24 s), mini tutoriel interactif au premier lancement (lancer, viser, récolter), cinématique du passage au Titan Rex et de la fin de l'histoire. Tout est skippable (bouton « Passer », arrêt si le joueur bouge), en pcall, mémorisé côté serveur. Les séquences sauce/victoire/zones existent mais sont désactivées (le reste se joue en gameplay).
- Animations (toutes activables dans `Config.Animations`, protégées par pcall) : T-Rex qui piétine/danse (festin, sauce, frénésie), tête tournée vers le lanceur, rebond des aliments, éclaboussures sur la vague, coffres qui s'ouvrent, œuf qui tremble, fenêtres qui glissent, salut de bienvenue.
- Énigme du jour (QCM, 3 essais, réponses uniquement côté serveur) : 12 questions qui tournent, œuf + pièces à la clé.
- 5 fourchettes d'or cachées sur la carte (+ bonus si toutes trouvées).
- Étiquette de niveau (et couronne VIP) au-dessus des joueurs, rayon doré vers le stand le plus proche quand le panier est vide.
- Niveau gourmet, classement mondial (OrderedDataStore) affiché sur un panneau dans le monde et dans l'interface.

## Publication
Voir **[PUBLISH.md](PUBLISH.md)** : textes, images (`dist/store/`), Game Passes et produits développeur, check-list.

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

## Vérifications — état réel
| Contrôle | Statut |
|---|---|
| `python3 tools/blockcheck.py src` (équilibre `end`/`until`, parenthèses, guillemets, 27 fichiers) | ✅ **exécuté**, tout passe |
| `python3 tools/undefcheck.py src` (identifiants non déclarés ; 7 candidats, tous des champs de types ou paramètres typés = faux positifs)  | ✅ **exécuté** |
| `python3 tools/build_rbxlx.py` (XML bien formé, 26 scripts dans l'arborescence attendue) | ✅ **exécuté** |
| Rendu des visuels de page (`node tools/store_assets/render.js`) | ✅ exécuté, icône et miniature relues à l'œil |
| `tools/check.sh` (luau-lsp, types Roblox) | ⚠️ **non exécuté** : binaire téléchargé refusé par le bac à sable |
| `tests/run.sh` (CLI Luau ; tests rédigés pour Lune/Luau CLI, logique pure + verrou DataStore) | ⚠️ **écrit, non exécuté** (même raison) |
| stylua, selene, `rojo build` | ⚠️ **non exécutés** (même raison) ; `default.project.json` n'a pas été validé par Rojo |
| Relecture manuelle (références, signatures des remotes, ordre d'initialisation) | ✅ relu |
| Partie jouée dans Roblox Studio (rendu, animations, achats, sauvegarde) | ❌ **à tester dans Studio** |

## Reste à finaliser / limites connues
- Sons : chemins `rbxasset://sounds/...` intégrés à Roblox, non vérifiés ; remplaçables dans `Config.Sounds`.
- Game Passes et produits développeur codés (`MonetizationService`) mais désactivés tant que leurs IDs (créés sur ton compte) ne sont pas saisis dans `Config.Monetization` ; ce code n'a jamais été exécuté non plus.
- Les visuels de `dist/store/` sont des illustrations, pas des captures du jeu.
- Les animations de lancer sont un simple mouvement d'épaule (aucun ID d'animation externe).
- Équilibrage (prix, durées, récompenses) calculé sur papier, non éprouvé en jeu : tout est dans `Config.luau`.
- Pas de test de charge ; budget visé : < 700 Parts statiques, aucun objet réseau par projectile (arcs rejoués côté client).
