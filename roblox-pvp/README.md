# ⚔ Arène des Légendes — jeu PVP Roblox (Jeu 7)

Jeu PVP multijoueur en blocs Roblox classiques : un **hub** médiéval (armurerie, quêtes, coffre quotidien,
zone d'entraînement, classement mondial) et une **forteresse-arène** (tour centrale, bunkers, lave,
jump pads, soins, orbe de rage) où s'enchaînent des manches de 3 minutes en **Mêlée générale** et
**Guerre des couleurs** (équipes Rouges / Bleues).

Inspiration analysée (captures « Combats de monstres » : Fluxo PVP, Kit PVP 1.8, Street PVP, RoWorld, 3v3, Un Tap…) :
ce qui attire dans ces jeux est la **boucle courte et lisible** (apparition immédiate, éliminations rapides,
retour visuel instantané), la **progression par armes débloquables**, et le **drop-in / drop-out** sans file d'attente.
Rien n'est copié : univers, carte, armes, UI et systèmes sont originaux.

## Ouvrir le jeu dans Roblox Studio

Le projet est au format [Rojo](https://rojo.space) 7.x (`default.project.json`).

```bash
rojo build -o ArenaDesLegendes.rbxl      # génère le fichier de place, à ouvrir dans Studio
# ou, pour travailler en direct :
rojo serve                               # puis plugin Rojo dans Studio -> Connect
```

Réglages Studio : *Game Settings → Security → Enable Studio Access to API Services* (pour tester la sauvegarde).
Sans cela le jeu fonctionne mais le profil est « éphémère » (rien n'est écrit : le serveur refuse d'écraser des données).

Tout le décor est **construit par script au démarrage** (`MapBuilder`) avec des blocs et matériaux Roblox natifs : aucune
ressource externe, aucun modèle à importer. Les sons utilisent les fichiers intégrés `rbxasset://sounds/…`
(remplaçables dans `Shared/Config.luau → Sounds`).

## Boucle de jeu

1. Apparition dans le **hub** (équipement de départ : épée de fer + arc de chasseur).
2. Portail ⚔ (ou bouton **ARÈNE**) → entrée immédiate dans l'arène, sans attente.
3. Machine à états : `Waiting → Intermission (12 s) → Playing (180 s ou limite de score) → Results (10 s)`.
   Modes alternés : Mêlée générale (20 éliminations) / Guerre des couleurs (30 éliminations d'équipe).
4. Éliminations → pièces + XP, séries, primes, assistances. Fin de manche → bonus de participation / victoire.
5. Dépenser dans la **boutique**, composer son **équipement** (3 slots), valider les **quêtes**, récupérer le **cadeau** quotidien.

## Contenu

| Système | Détail |
|---|---|
| Armes (10) | Épée de fer, Arc de chasseur, Katana, Pistolet photon, Marteau du titan (zone), Dague de l'ombre (×2,2 dans le dos), Bâton de braise (boule de feu explosive), Tonnerre (fusil à plombs), Rail de l'éclipse (1 tir à la tête = élimination), Lame du Souverain (vol de vie) |
| Types d'attaque | Mêlée en cône, impact de zone, hitscan, plombs, projectiles balistiques (gravité) avec explosion |
| Progression | Niveau 1→50, 6 titres (Recrue → Mythe) affichés au-dessus des joueurs, récompense à chaque niveau |
| Économie | Pièces : éliminations, série, tir à la tête, prime, assistance, victoire, quêtes, cadeaux |
| Quêtes | 3 quêtes/jour tirées d'un pool de 10 (déterministe par jour UTC), progression côté serveur |
| Cadeau quotidien | Cycle de 7 jours (50 → 500 pièces), série cassée après un jour manqué |
| Arène | Tour centrale à 4 rampes, 4 bunkers d'angle, 16 couvertures, 4 mares de lave (mort), 4 jump pads, 4 soins, orbe de rage (×1,5 dégâts 12 s) |
| Bots | Jusqu'à 3 gladiateurs complètent l'arène quand il y a moins de 4 combattants (récompense réduite, aucune série) |
| Classement | Top 10 mondial des éliminations (OrderedDataStore), repli « serveur » hors ligne |
| Équilibrage | Prime sur les séries ≥ 5, protection d'apparition 3 s (annulée si on attaque), apparition la plus éloignée des ennemis, équipes équilibrées |
| Appareils | UI mise à l'échelle (téléphone → console), bouton d'attaque tactile, L1/R1 manette, touches 1-2-3, viseur |

## Architecture

```
src/
  ReplicatedStorage/Shared/        données & logique pures (testables hors Roblox)
    Config · Weapons · Progression · Combat · QuestLogic · MatchLogic · Remotes
  ServerScriptService/Server/      autorité serveur
    init.server (boot) · MapBuilder · DataService · PlayerService · QuestService
    CombatService · WeaponService · WeaponFactory · MatchService · RequestService
    LeaderboardService · DummyService · RateLimiter
  StarterPlayer/StarterPlayerScripts/Client/
    init.client (boot) · UI · State · HUD · Menus · WeaponClient · Effects · World
tools/   check.py · check_api.py · test.sh      tests/   run.luau · sim.luau · mock.luau
```

### Sécurité (tout est décidé par le serveur)
- Le client envoie **uniquement une direction de visée** ; origine, portée, cadence, cible, dégâts, ligne de vue : serveur.
- Une seule `RemoteFunction` (`Request`) pour les actions du menu : action en liste blanche, arguments validés,
  limitée en débit (token bucket) ; achat / équipement / récompenses vérifiés (niveau, pièces, possession).
- Dégâts joueur→joueur uniquement si : manche `Playing`, deux joueurs dans l'arène, pas la même équipe, pas de ForceField.
- Knockback seulement si des dégâts ont réellement été infligés ; anti-farm (même victime > 3 fois : gains ×0,25).
- Sauvegarde : lecture avec tentatives, profil **éphémère non sauvegardé** si la lecture échoue (aucun écrasement),
  `UpdateAsync`, autosave 60 s, sauvegarde à la sortie et au `BindToClose`, nettoyage des données corrompues (`Reconcile`).

## Vérifications effectuées (réellement exécutées)

```bash
LUAU_ANALYZE=luau-analyze LUAU=luau ROBLOX_TYPES=globalTypes.d.luau tools/test.sh
```

1. **Analyse statique `luau-analyze`** de tous les scripts (syntaxe, variables non définies, types entre modules) : 0 message.
2. **Résolution des `require`**, membres de modules, noms de Remotes et attributs lus/écrits : cohérents.
3. **API Roblox** : 1 732 usages (classes `Instance.new`, propriétés, `Enum.*`, méthodes) vérifiés contre les définitions officielles.
4. **455 tests unitaires** (progression, dégâts, cônes, quêtes, logique de manche, cohérence des 10 armes).
5. **100 tests de simulation serveur** : les vrais modules `DataService`/`PlayerService`/`QuestService`/`CombatService`
   tournent dans un faux environnement Roblox (règles de dégâts, élimination, séries, prime, assistance, tir à la tête,
   rage, vol de vie, anti-farm, cibles d'entraînement, profils corrompus, cadeau quotidien, niveaux).

6. **Durcissement serveur** : sauvegarde sans perte (attente de l'autosave, profil abandonné si le joueur part pendant le chargement),
   limites strictes Join/Leave, arguments typés, intervalle global entre deux tirs, anti-farm, reçus Robux idempotents.

Outils de style prévus mais **non exécutés ici** (téléchargement refusé dans cet environnement) : `stylua.toml`, `selene.toml` et
`rojo build` sont configurés ; les tests de logique pure tournent sur l'interpréteur `luau` (équivalent de Lune pour ces fichiers).

### Limites de ces vérifications
Ce dépôt a été produit **sans Roblox Studio** : aucune partie n'a été jouée. Non vérifié en conditions réelles :
rendu visuel (proportions des armes tenues, éclairage), physique (rampes, jump pads, knockback), réseau/latence,
DataStore réel, ressenti du combat. Ces points demandent un premier playtest dans Studio (voir *À finaliser*).

## À finaliser / pistes
- **Playtest Studio** (2 clients) : régler prises d'armes (`Tool.Grip`), cadence, hauteur des rampes, volume des sons.
- Réglage en jeu des **bots d'arène** (déplacement par modèle ancré, sans animation de marche).
- **Sons / musique** personnalisés (assets à uploader) et animations d'attaque (le balancement est procédural).
- **Monétisation** optionnelle (Game Passes : double XP, effets d'élimination) — volontairement absente de cette V1.
