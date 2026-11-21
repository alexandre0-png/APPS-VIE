# Chipe-Œufs : fiche de publication et vérifications avant le passage en public

Ce fichier résume ce qu'il faut renseigner et contrôler avant de rendre le jeu public. Rien n'a été publié par l'agent : tout se fait par toi dans Studio et le Creator Hub (kit détaillé : `publication/LISTING.md`, tâches : `A_FAIRE_UTILISATEUR.md`). Aucun playtest Studio n'a été fait à ce jour : la qualité décrite plus bas est celle de l'analyse statique et des simulations.

## 1. Fiche du jeu

**Nom** (50 caractères max) : `Chipe-Œufs : Vole des Œufs ! 🥚`

**Description courte** (réseaux, partages, ~120 caractères) : `Chipe des œufs, fais-les éclore, collectionne 18 pets et défie le Château avec tes amis !`

**Description longue** (1000 caractères max, à coller dans le Creator Hub) :

```
🥚 Bienvenue dans Chipe-Œufs !

La Grande Couvée s'est brisée : reprends ses œufs, fais-les éclore et deviens Roi des Couvées !

🥚 Chipe des œufs gardés par un chien, un loup et un ours... ou à d'autres joueurs
🏰 Le Château : 5 salles à pièges, chevaliers et coffre final, en solo ou jusqu'à 5 amis, avec classement des temps
👥 Lance une partie depuis le hub, tes amis te rejoignent quand ils veulent
🐣 18 pets, 6 raretés, tailles et mutations (Doré, Néon, Arc-en-ciel, Alien)
📖 Un index de collection : chaque série d'espèces découvertes donne un bonus définitif
💰 Tes pets rapportent des pièces, même quand tu es absent
⭐ Échange tes doublons, améliore ta base, 🌅 renais pour des bonus permanents
🎯 Missions du jour avec œufs en récompense, énigme quotidienne, événements

Un œuf posé dans ta base est protégé quelques secondes, puis les autres joueurs peuvent te le voler. Les probabilités d'éclosion sont affichées dans le jeu.
```

**Genres** : principal Adventure ; secondaires Fantasy, Comedy (choisir ceux proposés par le Creator Hub). **Appareils** : Ordinateur, Téléphone, Tablette ; Console seulement après un test à la manette (non testé). **Joueurs max** : 5 pour le lieu de jeu (87012762353093) ; le hub (115261336085924) est le lieu de départ.

**Âge et questionnaire de classification** : à remplir honnêtement (violence très légère de dessin animé : coups non mortels des gardiens et des pièges ; vol d'objets virtuels entre joueurs ; achats Robux à probabilité non payante : aucun œuf n'est vendu avec une probabilité modifiée, les passes de chance sont des bonus fixes affichés).

## 2. Cinq phrases d'accroche

1. Chipe l'œuf, évite le loup, deviens Roi des Couvées !
2. 18 pets à faire éclore : lequel sera ton premier Cosmique ?
3. Affronte le Château avec jusqu'à 4 amis : pics, lames, boulets et chevaliers.
4. Ton armée de pets travaille pour toi, même quand tu dors.
5. Un œuf mal gardé ne reste pas longtemps dans ta base… sauras-tu le défendre ?

## 3. Achats à créer (IDs à renseigner dans `Config.PASSES` / `Config.PRODUCTS`)

Voir le tableau complet (noms, prix, descriptions) dans `A_FAIRE_UTILISATEUR.md` §4. Tant qu'un ID vaut 0, l'achat reste désactivé avec un message clair et aucune offre d'achat n'apparaît dans le jeu.

## 4. État de la qualité (constaté par lecture et tests, pas en Studio)

| Domaine | Constat | Source |
|---|---|---|
| Remotes | Tous les clients passent par `Action` (hub : `HubRemote`) : nom d'action string, arguments typés et bornés (emplacement entier 1..12, rareté entière, clés connues), limite 12 appels/s et par joueur (0,4 s au hub), aucune action ne crédite de monnaie sur la foi du client (achats : serveur seul). Rien n'est lu dans un `RemoteFunction` | `Main.server.lua`, `Hub.server.lua`, tests e2e |
| Achats | `ProcessReceipt` : `PurchaseGranted` seulement après sauvegarde réussie, relivraison impossible, reçu dédoublonné, achat unique contrôlé, base pleine gérée | lot H, tests |
| DataStore | `UpdateAsync` avec verrou de session (120 s), 3 tentatives, version 7 avec migrations, sauvegarde automatique 60 s, `BindToClose` (25 s max), valeurs JSON invalides assainies, mode dégradé sans API | `Data.lua`, `Main.server.lua` |
| Fuites | Tables par joueur nettoyées à la sortie (`sessions`, `holds`, `lastReq`, `friendCache`, `launching`, verrou de sauvegarde) ; reçus anciens purgés (30 jours) ; clones Blender détruits ou ancrés une seule fois | relecture, tests de 30 minutes simulées |
| Mobile | Budget carte 7 000 Parts (procédural), accessoires 2 600, château 1 700, arène 500, sol 600 (mesuré) : ce sont des pires cas ; effets de révélation et aura réduits sur tactile ; lumières et émetteurs plafonnés | `Config.Map`, `Config.Assets`, tests de budget |
| Accessibilité | Texte fixe de 11 minimum (test), contrastes vérifiés par `Config.contrast`, bords sûrs et zone centrale libre sur 10 tailles d'écran (test de mise en page), boutons de 52 px minimum | tests |

Limites connues : rien n'a été mesuré sur un vrai téléphone ; la taille et l'orientation des modèles Blender n'ont pas été vues (devant supposé = -Z) ; pas de test manette ; pas de test à 5 joueurs réels ; les chronos de sauvegarde et de téléportation sont simulés.

## 5. Liste de vérifications avant le passage en public

À cocher dans Studio, dans cet ordre. Chaque point dit comment savoir que ça marche.

**A. Configuration**
- [ ] Les deux lieux sont dans la même expérience et publiés : `Hub.rbxlx` dans 115261336085924 (lieu de départ), `ChipeOeufs.rbxlx` dans 87012762353093. *Preuve : un clic sur un portail du hub arrive dans la partie.*
- [ ] **Enable Studio Access to API Services** activé. *Preuve : aucun avertissement « mode mémoire » dans la sortie.*
- [ ] **Max Players = 5** sur le lieu de jeu.
- [ ] IDs des passes et produits collés dans `Config.lua`, build régénéré (`python3 roblox/tools/build_place.py`).
- [ ] Les modèles Blender se chargent : sortie `[Assets]` sans « refusé » ; sinon ouvrir chaque modèle avec ton compte et l'ajouter à l'inventaire.

**B. Playtest Studio (Test > Clients and Servers, 2 puis 5 joueurs)**
- [ ] Sortie sans erreur rouge pendant 15 minutes. *Preuve : fenêtre Output.*
- [ ] Hub, portails, amis, retour au hub, mode Château (entrée, chrono, coffre, classement).
- [ ] Un gardien ne tue jamais d'un coup (barre de vie), les pièges et chevaliers non plus.
- [ ] Orientation et taille des modèles (gardiens, pièges, herses, pales du moulin, bancs) : sinon dis-moi lesquels, je corrige l'échelle et la rotation.
- [ ] Achats : tester avec un compte de test que chaque passe et produit livre une fois, qu'un échec de sauvegarde (couper l'accès API) ne livre pas deux fois.
- [ ] Sauvegarde : quitter puis revenir, tout est retrouvé (pièces, œufs, pets, quêtes, pack de départ).

**C. Appareils**
- [ ] Émulateur téléphone 360x640 et 844x390 : rien ne se chevauche, texte lisible, zone centrale libre.
- [ ] Vrai téléphone si possible : fluidité (>= 30 images/s) dans le domaine de Zed et le château. Si lent : `Config.REVEAL.forceReduced = true`, réduire `Config.Assets.*BudgetParts`, couper `Config.Animations.*`.
- [ ] Manette (si Console cochée) : X boutique, Y missions, B fermer.

**D. Fiche et conformité**
- [ ] Nom, descriptions, genres, icône 512x512, miniatures 1920x1080 (dans `publication/art/` et la scène de miniature faite par ailleurs).
- [ ] Questionnaire de classification rempli ; vérification d'identité si exigée pour la monétisation.
- [ ] Probabilités visibles dans le jeu (menu Plus) : obligatoire pour les mécaniques d'œufs.
- [ ] Aucun nom, modèle ou asset copié d'un autre jeu.

**E. Lancement**
- [ ] Publier d'abord en **privé** puis en **amis uniquement** : 24 h de retours, regarder les erreurs serveur dans le Creator Hub (Analytics > Performance).
- [ ] Passer en public, surveiller la première heure : taux d'erreur, durée des sessions, fuites mémoire (courbe de mémoire serveur).
