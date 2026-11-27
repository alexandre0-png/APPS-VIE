# Chipe-Œufs, lot 14 : classé en direct (file MemoryStore, serveur réservé « ranked »)

Préparé hors de la branche de jeu : copie de `roblox/` au commit **91f6907** (exporté avec `git archive`, le worktree `wt/o2` ayant avancé depuis). Rien n'a été modifié dans `wt/o2`.
Aucune publication, aucune clé API. Spécification : `obsidian-studio/Jeux/LOTS_9_PLUS.md` E.3, E.4, K « Lot 14 », plus la décision utilisateur (file désactivée sous 60 joueurs simultanés).

## Contenu

| Fichier (arbre `roblox/`) | Rôle |
|---|---|
| `src/ReplicatedStorage/Ranked.lua` (nouveau, pur) | Ouverture de la file (seuil 60, échec = fermé), entrée en file, fenêtre de trophées et de puissance avec élargissement, appariement (le plus ancien d'abord, chaque joueur une fois), anti-abus (même serveur, serveur partagé < 10 min, revanche < 1 h), transformations `UpdateAsync` (bail d'apparieur, réservation d'entrée, rafraîchissement), match, ticket, admission à l'arène (match + `PrivateServerId` + membre), machine d'état de l'arène, résultat (gain `Config.pvpGain`, perte `PVP.loss`, plafond du jour, forfait), ligues, remise de saison (optionnelle), retour (partie ou hub), vues en miroir, quotas. |
| `src/ServerScriptService/PvpLive.lua` (nouveau) | Transport derrière un **runtime injectable** : file (SortedMap `PvpQueue_v1`), comptage des joueurs (SortedMap `PvpCcu_v1`), bail et comptage total (HashMap `PvpLock_v1`), tickets (`PvpTicket_v1`), matchs (`PvpMatch_v1`), `ReserveServerAsync` / `TeleportAsync`, combat à deux joueurs (tours de 10 s, action par défaut), forfait, retour. Aucun yield hors runtime, chaque appel réseau dans un `pcall`. `PvpLive.robloxRuntime` = runtime réel (non testé hors Roblox). |
| `patches/Config.lua.patch` | `Config.PVP_LIVE` (valeurs du cahier K + plafonds) et `Config.LEAGUES` (si absent). `enabled = false`. |
| `patches/Data.lua.patch` | `battle.live = Ranked.sanitizeLive(...)` dans `default()` et `merge()`, **sans changement de version** (champ facultatif assaini). |
| `patches/Main.server.lua.patch` | Création de `Lot7.Live` (aucune nouvelle variable locale : le bloc principal est à 200), actions `liveQueue` / `liveCancel`, routage `battleAct` / `battleQuit`, boucle 1 s, `TeleportInitFailed`, `serverMode = "ranked"` à l'arrivée, `arenaJoin`, `onLeave` avant la sauvegarde de départ. |
| `patches/run.luau.patch` | Ajoute `lot14` à la liste des suites de `tests/run.luau`. |
| `tests/lot14.luau`, `tests/run_lot14.py` | 129 assertions (voir Résultats). |

## Brancher

Depuis la racine du dépôt de jeu (le dossier qui contient `roblox/`) :

1. Copier `roblox/src/ReplicatedStorage/Ranked.lua`, `roblox/src/ServerScriptService/PvpLive.lua`, `roblox/tests/lot14.luau`, `roblox/tests/run_lot14.py` aux mêmes chemins.
2. `for p in <chemin>/lots-prep/chipe-14/patches/*.patch; do patch -p1 < "$p"; done`
   Testé : `patch -p1 --dry-run` OK pour les 4 patchs sur une copie neuve de 91f6907 ; application réelle + copie des fichiers = arbre **identique** à celui testé (`diff -r` vide).
   Si le lot 12, 13 ou 16 a touché les mêmes zones (Config près de `pvpSeasonReward`, `Data.default`/`merge` du bloc `battle`, `battleAct`/`battleQuit`, liste de `run.luau`), appliquer les blocs à la main : ils sont courts et commentés « lot 14 ». Si le lot 13 a déjà créé `Config.LEAGUES`, le patch le garde (`Config.LEAGUES = Config.LEAGUES or {...}`).
3. Client (non fourni, petit) : bouton « ⚔️ Classé en direct » dans le panneau Arène qui envoie l'action `liveQueue` (et `liveCancel` pendant l'attente). Messages `RBattle` nouveaux : `liveQueued {seconds}`, `liveFound {opp}`, `liveCancel`, `liveFallback` (afficher « Aucun adversaire en ligne de ton niveau. Combattre une équipe enregistrée ? » → action `pvpStart`), `liveArena {seconds}`, `liveVoid`. Les messages `start` / `turn` / `end` existants portent `live = true` ; le joueur B reçoit déjà la vue en miroir (son équipe en camp 1), donc `BattleUi` les affiche sans changement. Tant que la file est fermée, `liveQueue` lance directement le classé asynchrone (`actions.pvpStart`) : le bouton peut remplacer l'actuel sans risque.
4. Activer : `Config.PVP_LIVE.enabled = true` **seulement après** le test réel à 2 comptes (ci-dessous). Même activée, la file reste fermée sous `minCCU = 60` joueurs simultanés (comptage publié par chaque serveur toutes les 30 s, sommé par l'apparieur ; comptage absent ou périmé = fermé).

## Résultats (exécutés dans cet environnement)

- `python3 roblox/tests/run_lot14.py` (lupa, depuis la copie patchée) : **129 assertions réussies, 0 échec**.
- `python3 roblox/tools/run_tests.py` (suite complète, arbre patché) : **3368 réussies, 0 échec** (code de sortie 0), dont le démarrage réel du vrai `Main.server.lua` patché dans le runtime factice.
- `lune run roblox/tests/run.luau` (Lune, arbre patché, lot14 inclus) : **3368 réussies, 0 échec** (code de sortie 0).
- Référence 91f6907 sans patch (`run_tests.py`) : 3239 réussies, 0 échec : l'écart est exactement les 129 assertions du lot 14, aucune régression.
- Mutations (5 règles de `Ranked.lua` cassées une à une : seuil 60, réservation unique, présence des deux joueurs, forfait anti-nourrissage, revanche) : **toutes détectées** (1 à 4 échecs chacune, ou erreur d'exécution).
- `stylua --check` sur `Ranked.lua`, `PvpLive.lua`, `lot14.luau` : OK. (Config/Data/Main ne sont pas conformes stylua dès 91f6907 ; les patchs n'ont pas reformaté ces fichiers.)
- `selene` : la std `roblox` n'est pas téléchargeable ici (API dump, réseau restreint). Lancé avec une std minimale `luau` + globales Roblox : `Ranked.lua`, `PvpLive.lua` : 0 erreur, 0 avertissement ; `Main`/`Data`/`Config` : aucune nouvelle alerte par rapport à 91f6907 (seule différence : une utilisation de plus de la globale `script`, absente de la std minimale).

Ce que couvrent les 129 assertions : configuration (valeurs K, `enabled = false`, `minCCU = 60`, ligues E.4) ; ouverture (59 fermé, 60 ouvert, désactivé à 500, périmé/absent/futur/invalide fermé, somme des comptes) ; entrée en file (fermée, occupé, serveur d'arène ou de château, sans équipe, 15 combats, plafond, nouveau jour UTC) ; appariement (fenêtre 100/150/250/400, la plus courte attente décide, Δ 400 jamais dépassé, puissance avant/après 30 s, x1,8 toujours refusé, même serveur, serveur partagé, revanche dans les deux sens, 6 × 200 entrées aléatoires sans joueur apparié deux fois) ; bail (un seul leader sur 2 serveurs, renouvellement, reprise après expiration) ; réservations et tickets (expiré ignoré, malformé ignoré) ; admission (intrus, autre serveur réservé, expiré) ; arène (un seul présent → annulé à 25 s) ; trophées (gain/perte, plancher à 0, plafond rogné, forfait tôt = 0 pour le gagnant, forfait après 3 tours = gain normal) ; profil `battle.live` (assainissement, idempotence, bornes, adversaires récents) ; retour (partie existante, hub sinon) ; vues en miroir ; actions client ; aucun Robux/produit/pass/boost dans `Ranked.lua` et `PvpLive.lua` ; quotas (< 15 % de la limite à 60 et 1 000 joueurs).
Transport (faux nuage multi-serveurs, arène créée à la réservation) : file fermée à 59, ouverte à 60, interrupteur à false = zéro requête MemoryStore ; match complet entre 2 serveurs (sauvegarde avant téléport, file et tickets vidés, combat lancé seulement avec les deux, quota consommé à ce moment, vue miroir pour B, trophées exacts, retour A vers sa partie et B vers le hub, pas de revanche puis repli à 45 s) ; un seul arrive → annulé, personne ne perd ni ne consomme de combat, l'absent remis en file après 3 tentatives ; TeleportAsync en erreur → 2 nouvelles tentatives puis remise en file ; sauvegarde en échec → jamais de téléport ; annulation ; déconnexion après 3 tours = forfait (-15 / +25), au tour 0 = -15 / 0, abandon = forfait, 10 s sans action = attaque par défaut, action d'un tiers ignorée ; plafond journalier (+10 au lieu de +25, signalé, nouvelle entrée refusée, autorisée le lendemain) ; 8 serveurs, 40 joueurs, 20 % de pannes MemoryStore et lectures périmées : jamais deux leaders, aucun joueur dans deux arènes, aucun double téléport, aucun joueur perdu, aucune arène bloquée.

## Écarts avec le cahier (assumés)

1. **Module** : `Ranked.lua` (nom demandé) au lieu de `Matchmaking.lua` (cahier K) ; il contient aussi trophées, ligues et plafonds.
2. **Mode de serveur `"ranked"`** au lieu de `"arena"` : `"arena"` est DÉJÀ la valeur par défaut de `serverMode` et le mode des parties normales dans `Party.lua` ; le réutiliser aurait transformé chaque partie en arène.
3. **Un seul joueur arrive** : le cahier E.3.6 le fait combattre la défense enregistrée de l'absent avec un résultat classé. Décision utilisateur appliquée : **aucun trophée sans les deux joueurs** → match annulé, quota rendu, le présent retourne chez lui (il peut relancer la file ou l'asynchrone).
4. **Déconnexion** : forfait immédiat (décision utilisateur) au lieu de « 2 tours d'IA puis forfait ». Ajout anti-abus : forfait avant 3 tours = 0 trophée pour le gagnant (le partant perd quand même).
5. **Anti-abus ajoutés** : revanche interdite 1 h (`rematchCooldown`), entrées du même serveur refusées, plafond `dailyTrophyCap = 300` trophées gagnés par jour en direct (pertes non plafonnées).
6. **Builder** : pas de carte « colisée seul » pour le serveur d'arène (hors périmètre « patchs minimaux ») : le combat se joue par l'interface, la carte normale est construite. Les autres activités restent techniquement possibles pendant 1 à 3 min (rencontres PNJ, tour et PvP asynchrone bloqués par `pvpPending`).
7. **Fréquence de retour** : vérification de la partie d'origine sans `createdAt` (c'est un `os.clock()` du hub, non comparable) ; on s'appuie sur l'expiration MemoryStore du registre. Le retour vers la partie envoie `from = "hub"` + `partyId` pour passer la liste blanche existante de `Party.admitJoin`.
8. **Remise de saison E.4** (`× 0,6` au-delà de 300) : fournie (`Ranked.seasonReset`) mais **non branchée** ; le jeu garde `trophées // 4`. Interprétation retenue : jamais sous 300.
9. **Entrée périmée** : ignorée après 30 s sans rafraîchissement (3 × `refresh`) même si le MemoryStore la garde 90 s.
10. **Interface client** : non fournie (voir Brancher, point 3).

## Limites connues

- Sauvegarde avant téléport sans libérer le verrou (même schéma que `actions.toHub`) : le serveur d'arène attend la libération (Data.load réessaie jusqu'à 32 s) ; `waitArena = 25` compte depuis la première arrivée. Si le chargement du second joueur dépasse 25 s, le match est annulé (aucune perte).
- Fermeture du serveur d'arène pendant un combat (BindToClose) : aucun forfait appliqué, aucun trophée ne bouge.
- Pendant le déploiement, un serveur ancien qui charge le profil efface `battle.live` (il ne connaît pas le champ) : compteurs du jour et adversaires récents perdus, sans autre effet.
- `ReserveServerAsync` est supposé renvoyer `(code, privateServerId)` comme `ReserveServer` ; s'il ne renvoie que le code, la vérification `PrivateServerId` est sautée (le match et l'appartenance restent vérifiés).

## À tester dans Studio / sur le lieu publié

1. **Démarrage** (Studio, Play) : aucune erreur `[PvpLive]` dans la sortie ; bouton classé (ou action `liveQueue`) → classé asynchrone lancé (file fermée car `enabled = false`).
2. **Serveur réservé** (lieu publié, `enabled = true` et `minCCU = 2` sur une copie de test seulement) : 2 comptes de test dans 2 parties différentes, file en même temps → « Adversaire trouvé » en moins de 10 s, téléport des deux vers le même serveur réservé, combat en direct (chacun voit son équipe à gauche), fin : trophées +gain/-15, retour du joueur dans sa partie d'origine (ou au hub). Vérifier dans la sortie du serveur d'arène : `game.PrivateServerId` non vide et égal au `psid` du match.
3. **File** : un seul compte en file → repli proposé à 45 s ; annulation pendant l'attente → plus aucune entrée `PvpQueue_v1` (MemoryStore Observability du Creator Dashboard) ; même paire relancée juste après → jamais réappariée (repli à 45 s).
4. **Absent / déconnexion** : un compte quitte pendant le téléport → l'autre attend 25 s, « Ton adversaire n'est pas arrivé », trophées inchangés ; un compte quitte au 4e tour → forfait, -15 pour lui (vérifier à sa reconnexion), +gain pour l'autre ; quitter au 1er tour → 0 pour l'autre.
5. **Quotas** : Creator Dashboard > MemoryStore : requêtes/min pendant le test (attendu : quelques dizaines par minute, très loin de 1 000 + 100 × joueurs) ; aucune erreur de limitation.
6. **Seuil 60** : en production, laisser `enabled = false` ; une fois activé, vérifier qu'avec moins de 60 joueurs simultanés le bouton lance l'asynchrone (HashMap `PvpLock_v1`, clé `ccu`, valeur `n`).
7. **Plafonds** : 15 combats en direct puis refus ; +300 trophées gagnés dans la journée puis refus « plafond », remise à 0 à 00:00 UTC.
